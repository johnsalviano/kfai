import json, os, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONF = os.path.join(os.path.dirname(os.path.abspath(__file__)), "router.conf")
PORT = int(os.environ.get("KFAI_ROUTER_PORT", "20129"))


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
            routes.setdefault(route.strip(), []).append({
                "model": upl_model.strip(),
                "base": base.strip(),
                "key": os.environ.get(keyvar.strip(), ""),
            })
    return routes


def call_upl(route, body):
    last = None
    for up in route:
        url = up["base"].rstrip("/") + "/chat/completions"
        b = dict(body)
        b["model"] = up["model"]
        req = urllib.request.Request(
            url, data=json.dumps(b).encode(), method="POST",
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
    raise Retryable(last.code if last else 502, body.get("model", ""))


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
        print("formato: rota|modelo_uplink|base_url|VARIAVEL_CHAVE")
    print(f"KFAI router ligado em http://127.0.0.1:{PORT}/v1")
    print(f"Rotas: {', '.join(ROUTES) if ROUTES else '(nenhuma)'}")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()