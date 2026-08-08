import json, os, time, re, hashlib, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# =========================================================================
# KFAI router - proxy OpenAI-compativel com fallback, economia de tokens,
# cooldown, cache e log.
#
# router.conf (1 rota por linha, separado por |):
#   rota|modelo_uplink|base_url|VARIAVEL_CHAVE[|modo]
#   modo: full (intacto) | eco (resume historico + compressao de tool) |
#         auto (escolhe por request via heuristica)
#
# Ajustes (variaveis de ambiente):
#   KFAI_ROUTER_PORT     porta (default 20129)
#   KFAI_ECO_MODE        modo padrao quando linha nao define (default full)
#   KFAI_SUMMARY_BASE    base Ollama p/ resumo (default http://localhost:11434/v1)
#   KFAI_SUMMARY_MODEL   modelo de resumo (default llama3.2:3b)
#   KFAI_ECO_KEEP_TURNS  ultimos N turnos mantidos verbatim (default 6)
#   KFAI_ECO_MAX_TOKENS  orcamento de tokens aproximados (default 8000)
#   KFAI_COOLDOWN_SEC    cooldown em s apos falha de um uplink (default 60)
#   KFAI_CACHE_SEC       TTL do cache exato em s; 0 desliga (default 300)
#   KFAI_CACHE_MAX       max de entradas no cache (default 200)
#   KFAI_LOG_FILE        arquivo de log JSONL; vazio desliga (default logs/router.log)
#   KFAI_NUM_CTX         contexto (num_ctx) injetado para uplinks locais (Ollama).
#                        Default 32768: evita o truncamento silencioso em 4096
#                        que quebra agentes com tool calling. 0 desliga.
# =========================================================================

BASE = os.path.dirname(os.path.abspath(__file__))
CONF = os.path.join(BASE, "router.conf")
PORT = int(os.environ.get("KFAI_ROUTER_PORT", "20129"))
ECO_BASE = os.environ.get("KFAI_ECO_BASE", "http://localhost:11434/v1")
ECO_MODEL = os.environ.get("KFAI_ECO_MODEL", "llama3.2:3b")
KEEP_TURNS = int(os.environ.get("KFAI_ECO_KEEP_TURNS", "6"))
MAX_TOKENS = int(os.environ.get("KFAI_ECO_MAX_TOKENS", "8000"))
DEFAULT_MODE = os.environ.get("KFAI_ECO_MODE", "full")
COOLDOWN_SEC = int(os.environ.get("KFAI_COOLDOWN_SEC", "60"))
CACHE_SEC = int(os.environ.get("KFAI_CACHE_SEC", "300"))
CACHE_MAX = int(os.environ.get("KFAI_CACHE_MAX", "200"))
LOG_FILE = os.environ.get("KFAI_LOG_FILE", os.path.join(BASE, "logs", "router.log"))
NUM_CTX = int(os.environ.get("KFAI_NUM_CTX", "32768"))

# --- estado em memoria ---
ROUTES = {}
COOLDOWNS = {}   # id_uplink -> timestamp em que expira
CACHE = {}       # hash -> (expira, corpo de resposta)


class Retryable(Exception):
    def __init__(self, status, msg):
        self.status = status
        super().__init__(msg)


class NotRetryable(Exception):
    """Erro do cliente (4xx) — nao faz fallback nem cooldown; propaga."""
    def __init__(self, status, msg):
        self.status = status
        super().__init__(msg)


def is_retryable_status(code):
    """429 (rate limit), 5xx e timeouts merecem fallback/cooldown.
    400/401/403/404 sao erros de configuracao: propagam sem fallback."""
    if code >= 500:
        return True
    if code in (429,):
        return True
    return False


def uplink_id(up):
    return up["base"] + "|" + up["model"]


# ---------------------------------------------------------------------------
# config / heuristica / compressao
# ---------------------------------------------------------------------------

def load_conf():
    routes = {}
    if not os.path.exists(CONF):
        return routes
    with open(CONF, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) < 4:
                continue
            route, upl_model, base, keyvar = parts[:4]
            mode = parts[4].strip().lower() if len(parts) > 4 else DEFAULT_MODE
            routes.setdefault(route.strip(), []).append({
                "model": upl_model.strip(),
                "base": base.strip(),
                "key": os.environ.get(keyvar.strip(), ""),
                "mode": mode,
            })
    return routes


def est_toks(text):
    return max(1, len(str(text)) // 4)


def summarize_old(messages):
    try:
        blob = "\n".join(f"{m.get('role','?')}: {m.get('content','')}" for m in messages)
        body = {
            "model": ECO_MODEL,
            "messages": [
                {"role": "system",
                 "content": "Voce e um compactador de historico. Resuma o que foi "
                            "combinado e discutido, mantendo decisoes, fatos e "
                            "detalhes importantes. Use poucos tokens."},
                {"role": "user", "content": "Resuma:\n" + blob},
            ],
            "stream": False,
        }
        req = urllib.request.Request(
            ECO_BASE.rstrip("/") + "/chat/completions",
            data=json.dumps(body).encode(), method="POST",
            headers={"Content-Type": "application/json", "Authorization": "Bearer ollama"},
        )
        with urllib.request.urlopen(req, timeout=120) as r:
            out = json.loads(r.read())
        text = out["choices"][0]["message"]["content"].strip()
        return "[resumo KFAI] " + text
    except Exception:
        return None


def compress_tool_output(content, max_chars=2000, max_dup=3):
    """Colapsa linhas repetidas consecutivas e trunca saidas longas de ferramenta."""
    if not content:
        return content
    s = str(content)
    lines = s.splitlines()
    out = []
    i = 0
    while i < len(lines):
        j = i
        while j < len(lines) and lines[j] == lines[i]:
            j += 1
        count = j - i
        if count > max_dup:
            out.append(lines[i])
            out.append(f"    ... ({count - max_dup} linhas repetidas omitidas)")
        else:
            out.extend(lines[i:j])
        i = j
    joined = "\n".join(out)
    if len(joined) > max_chars:
        joined = joined[:max_chars] + f"\n    ... [saida truncada pelo KFAI: {len(s)} chars originais]"
    return joined


def compress(messages):
    msgs = [m for m in messages if m.get("role") != "system"]
    sys_ = [m for m in messages if m.get("role") == "system"]
    for m in msgs:
        if m.get("role") == "tool" and isinstance(m.get("content"), str):
            m["content"] = compress_tool_output(m["content"])
    if len(msgs) <= KEEP_TURNS + 1:
        return messages
    old, recent = msgs[:-KEEP_TURNS], msgs[-KEEP_TURNS:]
    summary = summarize_old(old)
    as_tokens = est_toks(" ".join(m.get("content", "") for m in recent))
    final = list(sys_)
    if summary is not None:
        final.append({"role": "system", "content": summary})
    else:
        while len(recent) > 2 and as_tokens > MAX_TOKENS:
            recent.pop(0)
            as_tokens = est_toks(" ".join(m.get("content", "") for m in recent))
        if as_tokens > MAX_TOKENS:
            final.append({"role": "system",
                          "content": "[KFAI aviso] historico foi podado por limite de tokens."})
    final += recent
    return final


def is_complex_request(body):
    """Heuristica deterministica (sem chamar LLM): o request pede contexto intacto?"""
    msgs = body.get("messages", [])
    if not msgs:
        return False
    # conversa longa -> resumir economiza muito; mas pedidos com tool_call
    # recente precisam do historico completo para o modelo entender o estado.
    total_chars = sum(len(str(m.get("content", ""))) for m in msgs if m.get("role") != "system")
    if total_chars > 6000:
        return True
    # tool_calls no ultimo turno do assistant = estado a preservar
    for m in msgs[-3:]:
        if m.get("role") == "assistant" and m.get("tool_calls"):
            return True
        if m.get("role") == "tool":
            return True
    # sinais de pedido complexo (raciocinio/debug/arquitetura)
    text = " ".join(str(m.get("content", "")) for m in msgs).lower()
    strong = ["debug", "refactor", "arquitetura", "architecture", "explica como",
              "projeto um", "design", "seguranca", "vulnerabil", "otimiza"]
    if any(k in text for k in strong):
        return True
    return False


def decide_mode(up_mode, body):
    """'auto' escolhe eco/full por request; 'eco'/'full' sao fixos."""
    if up_mode != "auto":
        return up_mode
    return "full" if is_complex_request(body) else "eco"


# ---------------------------------------------------------------------------
# cooldown / cache / log
# ---------------------------------------------------------------------------

def now_cooldown(up):
    exp = COOLDOWNS.get(uplink_id(up), 0)
    return exp > time.time()


def mark_cooldown(up):
    COOLDOWNS[uplink_id(up)] = time.time() + COOLDOWN_SEC


def cache_put(body, data):
    if CACHE_SEC <= 0 or body.get("stream"):
        return
    key = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
    CACHE[key] = (time.time() + CACHE_SEC, data)
    if len(CACHE) > CACHE_MAX:
        now = time.time()
        for k in [k for k, (e, _) in CACHE.items() if e < now]:
            del CACHE[k]
        while len(CACHE) > CACHE_MAX:
            del CACHE[next(iter(CACHE))]


def cache_get(body):
    if CACHE_SEC <= 0 or body.get("stream"):
        return None
    key = hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()
    entry = CACHE.get(key)
    if entry and entry[0] > time.time():
        return entry[1]
    if entry:
        del CACHE[key]
    return None


def log_event(event):
    if not LOG_FILE:
        return
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# chamada ao uplink
# ---------------------------------------------------------------------------

def call_upl(route, body):
    last = None
    used = None
    for up in route:
        if now_cooldown(up):
            continue
        mode = decide_mode(up["mode"], body)
        b = dict(body)
        if mode == "eco":
            b["messages"] = compress(b.get("messages", []))
        b["model"] = up["model"]
        if NUM_CTX > 0 and "11434" in up["base"]:
            # Ollama local usa num_ctx 4096 por padrao e trunca silenciosamente,
            # quebrando agentes com tool calling. Injetamos contexto maior.
            opts = dict(b.get("options") or {})
            opts["num_ctx"] = NUM_CTX
            b["options"] = opts
        req = urllib.request.Request(
            up["base"].rstrip("/") + "/chat/completions", data=json.dumps(b).encode(), method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer " + (up["key"] or "ollama"),
            },
        )
        try:
            resp = urllib.request.urlopen(req, timeout=300)
            return resp, up, mode
        except urllib.error.HTTPError as e:
            if not is_retryable_status(e.code):
                raise NotRetryable(e.code, f"erro nao recuperavel ({e.code}) em {up['base']}")
            last = e
            used = up
            mark_cooldown(up)
            continue
        except (urllib.error.URLError, TimeoutError, OSError):
            last = type("Err", (), {"code": 0})()
            used = up
            mark_cooldown(up)
            continue
    raise Retryable(last.code if last else 502, body.get("mode", body.get("model", "")))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path == "/v1/models":
            items = [{"id": r, "object": "model", "created": 0, "owned_by": "kfai-router"}
                     for r in ROUTES]
            self._send(json.dumps({"object": "list", "data": items}))
        elif self.path == "/healthz":
            self._send(json.dumps({"ok": True, "rotas": len(ROUTES)}))
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            self.send_error(404)
            return
        t0 = time.time()
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length) if length else b"{}")
        except Exception:
            self.send_error(400, "Corpo JSON invalido")
            return
        route = ROUTES.get(body.get("model", ""))
        if not route:
            self.send_error(404, "Rota nao encontrada. Confira router.conf.")
            return

        cached = cache_get(body)
        if cached is not None:
            stream = bool(body.get("stream"))
            if stream:
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()
                self.wfile.write(cached)
            else:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(cached)))
                self.end_headers()
                self.wfile.write(cached)
            log_event({"t": time.time(), "rota": body.get("model"), "cache": True,
                       "ms": round((time.time() - t0) * 1000)})
            return

        try:
            resp, up, mode = call_upl(route, body)
        except NotRetryable as e:
            self.send_error(e.status or 400, f"Uplink rejeitou: {e}")
            log_event({"t": time.time(), "rota": body.get("model"), "erro": e.status,
                       "nao_retryable": True, "ms": round((time.time() - t0) * 1000)})
            return
        except Retryable as e:
            self.send_error(e.status or 502, f"Todos os uplinks de {body.get('model','')} falharam")
            log_event({"t": time.time(), "rota": body.get("model"), "erro": e.status,
                       "ms": round((time.time() - t0) * 1000)})
            return

        stream = bool(body.get("stream"))
        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            total = 0
            while True:
                chunk = resp.read(8192)
                if not chunk:
                    break
                total += len(chunk)
                self.wfile.write(chunk)
                self.wfile.flush()
            log_event({"t": time.time(), "rota": body.get("model"), "uplink": uplink_id(up),
                       "modo": mode, "stream": True, "bytes": total,
                       "ms": round((time.time() - t0) * 1000)})
        else:
            data = resp.read()
            cache_put(body, data)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            log_event({"t": time.time(), "rota": body.get("model"), "uplink": uplink_id(up),
                       "modo": mode, "cache": False, "bytes": len(data),
                       "ms": round((time.time() - t0) * 1000)})

    def _send(self, payload):
        data = payload.encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    ROUTES = load_conf()
    if not ROUTES:
        print(f"[aviso] router.conf vazio ou ausente. Crie em: {CONF}")
        print("formato: rota|modelo_uplink|base_url|VARIAVEL_CHAVE|modo(full|eco|auto)")
    print(f"KFAI router ligado em http://127.0.0.1:{PORT}/v1")
    print(f"Rotas: {', '.join(ROUTES) if ROUTES else '(nenhuma)'}")
    print(f"cooldown={COOLDOWN_SEC}s cache={CACHE_SEC}s log={LOG_FILE}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
