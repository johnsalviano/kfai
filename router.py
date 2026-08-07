import json, os, urllib.request, urllib.error, re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# =========================================================================
# KFAI router - proxy OpenAI-compativel com fallback entre providers e
# economia de tokens OPCIONAL por rota.
#
# router.conf (1 rota por linha, separado por |):
#   rota|modelo_uplink|base_url|VARIAVEL_CHAVE[|modo]
#   modo: full (padrao, texto intacto) | eco (resume historico + poda)
#
# Ajustes (variaveis de ambiente):
#   KFAI_ROUTER_PORT   porta (default 20129)
#   KFAI_ECO_MODE      modo padrao quando linha nao define (default full)
#   KFAI_SUMMARY_BASE  base Ollama p/ resumo (default http://localhost:11434/v1)
#   KFAI_SUMMARY_MODEL modelo de resumo (default llama3.2:3b)
#   KFAI_ECO_KEEP_TURNS  ultimos N turnos mantidos verbatim (default 6)
#   KFAI_ECO_MAX_TOKENS  orcamento de tokens aproximados (default 8000)
# =========================================================================

CONF = os.path.join(os.path.dirname(os.path.abspath(__file__)), "router.conf")
PORT = int(os.environ.get("KFAI_ROUTER_PORT", "20129"))
ECO_BASE = os.environ.get("KFAI_ECO_BASE", "http://localhost:11434/v1")
ECO_MODEL = os.environ.get("KFAI_ECO_MODEL", "llama3.2:3b")
KEEP_TURNS = int(os.environ.get("KFAI_ECO_KEEP_TURNS", "6"))
MAX_TOKENS = int(os.environ.get("KFAI_ECO_MAX_TOKENS", "8000"))
DEFAULT_MODE = os.environ.get("KFAI_ECO_MODE", "full")


class Retryable(Exception):
    def __init__(self, status, msg):
        self.status = status
        super().__init__(msg)


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


def compress(messages):
    msgs = [m for m in messages if m.get("role") != "system"]
    sys_ = [m for m in messages if m.get("role") == "system"]
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


def call_upl(route, body):
    last = None
    for up in route:
        if up["mode"] == "eco":
            body = dict(body)
            body["messages"] = compress(body.get("messages", []))
        b = dict(body)
        b["model"] = up["model"]
        req = urllib.request.Request(
            up["base"].rstrip("/") + "/chat/completions", data=json.dumps(b).encode(), method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer " + (up["key"] or "ollama"),
            },
        )
        try:
            return urllib.request.urlopen(req, timeout=300)
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 401, 403, 500, 502, 503, 504):
                continue
            raise Retryable(e.code, body.get("model", ""))
        except (urllib.error.URLError, TimeoutError, OSError):
            last = type("Err", (), {"code": 0})()
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
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            self.send_error(404)
            return
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
        try:
            resp = call_upl(route, body)
        except Retryable as e:
            self.send_error(e.status or 502, f"Todos os uplinks de {body.get('model','')} falharam")
            return
        stream = bool(body.get("stream"))
        if stream:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            while True:
                chunk = resp.read(8192)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        else:
            data = resp.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

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
        print("formato: rota|modelo_uplink|base_url|VARIAVEL_CHAVE|modo(full|eco)")
    print(f"KFAI router ligado em http://127.0.0.1:{PORT}/v1")
    print(f"Rotas: {', '.join(ROUTES) if ROUTES else '(nenhuma)'}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
