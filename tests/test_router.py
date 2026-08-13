"""Testes unitarios do roteador KFAI (router.py).

Cobrem: is_retryable_status, heuristica auto/eco (is_complex_request,
decide_mode), compressao de tool output, compress de historico, cooldown,
cache, load_conf e o fallback de call_upl (incluindo a regra 9Router e a
injecao de num_ctx).

Rodar localmente (sem dependencias):  py -3.14 -m unittest tests.test_router
Rodar com pytest:                       pytest tests/ -q
"""

import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import router


class FakeResp:
    def __init__(self, data=b'{"ok": true}'):
        self.data = data

    def read(self, *a):
        return self.data


class TestRetryableStatus(unittest.TestCase):
    def test_recuperaveis(self):
        for code in (401, 429, 500, 502, 503):
            self.assertTrue(router.is_retryable_status(code), f"{code} deveria ser retryable")

    def test_nao_recuperaveis(self):
        for code in (200, 400, 403, 404):
            self.assertFalse(router.is_retryable_status(code), f"{code} nao deveria ser retryable")


class TestUplinkId(unittest.TestCase):
    def test_id(self):
        up = {"base": "http://localhost:20128/v1", "model": "todas-free"}
        self.assertEqual(router.uplink_id(up), "http://localhost:20128/v1|todas-free")


class TestEstToks(unittest.TestCase):
    def test_est_toks(self):
        self.assertEqual(router.est_toks("abcd"), 1)
        self.assertEqual(router.est_toks("a" * 40), 10)
        self.assertEqual(router.est_toks(""), 1)


class TestCompressToolOutput(unittest.TestCase):
    def test_dedup_linhas_repetidas(self):
        out = router.compress_tool_output("a\na\na\na\na\na\nb\nb")
        self.assertIn("linhas repetidas omitidas", out)
        self.assertEqual(out.count("a\n"), 1)
        self.assertEqual(out.count("b\n"), 1)

    def test_linhas_curtas_nao_sao_alteradas(self):
        out = router.compress_tool_output("x\ny\nx\n")
        self.assertIn("x", out)
        self.assertIn("y", out)
        self.assertNotIn("omitidas", out)

    def test_trunca_saida_longa(self):
        out = router.compress_tool_output("z" * 5000)
        self.assertIn("truncada pelo KFAI", out)
        self.assertLessEqual(len(out), 2200)

    def test_conteudo_vazio(self):
        self.assertIsNone(router.compress_tool_output(None))


class TestCompress(unittest.TestCase):
    def setUp(self):
        self._sum = router.summarize_old
        router.summarize_old = lambda msgs: None  # offline: usa poda

    def tearDown(self):
        router.summarize_old = self._sum

    def test_historico_curto_fica_intacto(self):
        msgs = [{"role": "user", "content": "oi"},
                {"role": "assistant", "content": "olá"}]
        out = router.compress(list(msgs))
        self.assertEqual(out, msgs)

    def test_historico_longo_prune_para_keep_turns(self):
        msgs = [{"role": "user", "content": f"msg {i}"} for i in range(30)]
        out = router.compress(list(msgs))
        recent = [m for m in out if m["role"] == "user"]
        self.assertLessEqual(len(recent), router.KEEP_TURNS)

    def test_system_rol_nao_sao_removidos(self):
        msgs = [{"role": "system", "content": "voz do sistema"}]
        msgs += [{"role": "user", "content": "x"}] * 20
        out = router.compress(list(msgs))
        self.assertEqual(out[0]["role"], "system")

    def test_tool_output_e_comprimido(self):
        msgs = [{"role": "tool", "content": "t\n" * 50}]
        router.compress(msgs)
        self.assertIn("omitidas", msgs[0]["content"])


class TestIsComplexRequest(unittest.TestCase):
    def test_conversa_long_e_complexa(self):
        body = {"messages": [{"role": "user", "content": "x" * 7000}]}
        self.assertTrue(router.is_complex_request(body))

    def test_tool_call_preserva_estado(self):
        body = {"messages": [{"role": "assistant", "tool_calls": [{"id": "1"}]}]}
        self.assertTrue(router.is_complex_request(body))

    def test_palavra_chave(self):
        body = {"messages": [{"role": "user", "content": "me ajuda a debugar isso"}]}
        self.assertTrue(router.is_complex_request(body))

    def test_simples(self):
        body = {"messages": [{"role": "user", "content": "quem e voce?"}]}
        self.assertFalse(router.is_complex_request(body))

    def test_sem_mensagens(self):
        self.assertFalse(router.is_complex_request({"messages": []}))


class TestDecideMode(unittest.TestCase):
    def test_modo_fixo(self):
        self.assertEqual(router.decide_mode("eco", {}), "eco")
        self.assertEqual(router.decide_mode("full", {}), "full")

    def test_auto_escolhe(self):
        complex_body = {"messages": [{"role": "user", "content": "vamos debugar o crash"}]}
        simple_body = {"messages": [{"role": "user", "content": "oi"}]}
        self.assertEqual(router.decide_mode("auto", complex_body), "full")
        self.assertEqual(router.decide_mode("auto", simple_body), "eco")


class TestCooldown(unittest.TestCase):
    def tearDown(self):
        router.COOLDOWNS.clear()

    def test_mark_e_now(self):
        up = {"base": "http://localhost:20128/v1", "model": "m", "key": "", "mode": "full"}
        self.assertFalse(router.now_cooldown(up))
        router.mark_cooldown(up)
        self.assertTrue(router.now_cooldown(up))

    def test_cooldown_expirado(self):
        up = {"base": "http://localhost:20128/v1", "model": "m", "key": "", "mode": "full"}
        router.COOLDOWNS[router.uplink_id(up)] = router.time.time() - 9999
        self.assertFalse(router.now_cooldown(up))


class TestCache(unittest.TestCase):
    def setUp(self):
        router.CACHE.clear()

    def test_put_e_get(self):
        router.CACHE_SEC = 300
        body = {"model": "m", "messages": [{"role": "user", "content": "oi"}]}
        router.cache_put(body, b"resposta")
        self.assertEqual(router.cache_get(body), b"resposta")

    def test_desligado(self):
        router.CACHE_SEC = 0
        body = {"model": "m"}
        router.cache_put(body, b"x")
        self.assertIsNone(router.cache_get(body))

    def test_stream_nao_cacheia(self):
        router.CACHE_SEC = 300
        body = {"model": "m", "stream": True}
        router.cache_put(body, b"x")
        self.assertIsNone(router.cache_get(body))

    def test_expirado_e_removido(self):
        router.CACHE_SEC = 300
        body = {"model": "m"}
        router.cache_put(body, b"x")
        router.CACHE[next(iter(router.CACHE))] = (router.time.time() - 1, b"x")
        self.assertIsNone(router.cache_get(body))

    def test_evict_quando_excede_max(self):
        router.CACHE_SEC = 300
        router.CACHE_MAX = 5
        for i in range(10):
            router.cache_put({"model": "m", "i": i}, b"x")
        self.assertLessEqual(len(router.CACHE), 5)


class TestLoadConf(unittest.TestCase):
    def test_parseia_rotas(self):
        with tempfile.TemporaryDirectory() as d:
            conf = os.path.join(d, "router.conf")
            with open(conf, "w", encoding="utf-8") as f:
                f.write("# comentario\n")
                f.write("rota1|modelo-x|http://localhost:20128/v1|K1|full\n")
                f.write("rota1|modelo-y|http://localhost:11434/v1|K2\n")  # modo default
                f.write("linha_invalida\n")
            old = router.CONF
            router.CONF = conf
            try:
                routes = router.load_conf()
            finally:
                router.CONF = old
            self.assertEqual(len(routes["rota1"]), 2)
            self.assertEqual(routes["rota1"][0]["mode"], "full")
            self.assertEqual(routes["rota1"][1]["mode"], router.DEFAULT_MODE)
            self.assertEqual(routes["rota1"][1]["base"], "http://localhost:11434/v1")


class TestCallUpl(unittest.TestCase):
    def setUp(self):
        router.COOLDOWNS.clear()
        router.CACHE.clear()
        self._orig_urlopen = router.urllib.request.urlopen
        self._orig_num_ctx = router.NUM_CTX

    def tearDown(self):
        router.urllib.request.urlopen = self._orig_urlopen
        router.NUM_CTX = self._orig_num_ctx
        router.COOLDOWNS.clear()

    def _make_route(self):
        return [
            {"base": "http://localhost:20128/v1", "model": "todas-free", "key": "", "mode": "full"},
            {"base": "http://localhost:11434/v1", "model": "qwen3-64k", "key": "", "mode": "full"},
        ]

    def test_fallback_9router_4xx_cai_para_proximo(self):
        router.urllib.request.urlopen = mock.Mock(side_effect=[
            router.urllib.error.HTTPError("u", 404, "not found", None, None),
            FakeResp(b'{"choices":[{"message":{"content":"ok"}}]}'),
        ])
        route = self._make_route()
        _, up, _ = router.call_upl(route, {"model": "r"})
        self.assertEqual(up["base"], "http://localhost:11434/v1")

    def test_todos_uplinks_falham_levanta_retryable(self):
        def boom(*a, **k):
            raise router.urllib.error.URLError("offline")
        router.urllib.request.urlopen = boom
        route = self._make_route()
        with self.assertRaises(router.Retryable):
            router.call_upl(route, {"model": "r"})

    def test_erro_nao_retryable_de_provider_direto_propaga(self):
        def boom(*a, **k):
            raise router.urllib.error.HTTPError("u", 400, "bad", None, None)
        router.urllib.request.urlopen = boom
        route = [{"base": "https://api.example.com/v1", "model": "m", "key": "k", "mode": "full"}]
        with self.assertRaises(router.NotRetryable):
            router.call_upl(route, {"model": "r"})

    def test_num_ctx_injetado_no_ollama(self):
        captured = {}

        def fake_urlopen(req, timeout=300):
            captured["data"] = req.data
            captured["auth"] = req.get_header("Authorization")
            return FakeResp(b"{}")

        router.urllib.request.urlopen = fake_urlopen
        router.NUM_CTX = 65536
        route = [{"base": "http://localhost:11434/v1", "model": "qwen3-64k", "key": "", "mode": "full"}]
        router.call_upl(route, {"model": "r"})
        body = __import__("json").loads(captured["data"])
        self.assertEqual(body["options"]["num_ctx"], 65536)
        self.assertEqual(body["model"], "qwen3-64k")

    def test_chave_sanitizada_sem_crlf(self):
        captured = {}

        def fake_urlopen(req, timeout=300):
            captured["auth"] = req.get_header("Authorization")
            return FakeResp(b"{}")

        router.urllib.request.urlopen = fake_urlopen
        route = [{"base": "https://api.example.com/v1", "model": "m",
                  "key": "segred\r\nX-Injected: 1", "mode": "full"}]
        router.call_upl(route, {"model": "r"})
        self.assertNotIn("\r", captured["auth"])
        self.assertNotIn("\n", captured["auth"])

    def test_uplink_nuvem_sem_chave_e_pulado(self):
        router.urllib.request.urlopen = mock.Mock(side_effect=[
            FakeResp(b"{}"),
        ])
        route = [
            {"base": "https://api.example.com/v1", "model": "m", "key": "", "mode": "full"},
            {"base": "http://localhost:20128/v1", "model": "todas-free", "key": "", "mode": "full"},
        ]
        _, up, _ = router.call_upl(route, {"model": "r"})
        self.assertEqual(up["base"], "http://localhost:20128/v1")


if __name__ == "__main__":
    unittest.main()
