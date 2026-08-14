---
name: kfai-capacidades
description: Capacidades de IA do kit KFAI via router local (chat, imagem, áudio, embeddings, busca web). Use quando o usuário quiser gerar imagem, converter texto em fala, transcrever áudio, buscar na web, obter embeddings ou listar modelos por capacidade.
---

# KFAI — Capacidades de IA

O KFAI expõe uma API OpenAI-compatível em `http://127.0.0.1:20129/v1` (router local) que faz proxy para o 9Router (porta 20128) nas capacidades além de chat.

Requer o 9Router rodando (instalado pelo `01-install.ps1` com a opção correspondente).

## Configuração

```bash
# Se o 9Router exigir chave (Dashboard → Keys → requireApiKey):
$env:NINEROUTER_KEY = "sk-..."
# O router KFAI repassa Authorization automaticamente se definido no router.conf
```

Verifique: `curl http://127.0.0.1:20129/healthz` → `{"ok":true}`

## Descoberta de modelos

```bash
# Chat / LLM (padrão)
curl http://127.0.0.1:20129/v1/models

# Por capacidade
curl http://127.0.0.1:20129/v1/models/image      # geração de imagem
curl http://127.0.0.1:20129/v1/models/tts        # text-to-speech
curl http://127.0.0.1:20129/v1/models/stt        # speech-to-text
curl http://127.0.0.1:20129/v1/models/embedding  # embeddings
curl http://127.0.0.1:20129/v1/models/web        # web search + fetch (campo kind)

# Metadados de um modelo (contextWindow, params suportados)
curl "http://127.0.0.1:20129/v1/models/info?id=gemini/gemini-3-pro-image-preview"
```

Use `data[].id` como campo `model` nas requisições. Combos aparecem com `owned_by:"combo"`.

---

## 1. Chat / Code-gen

**Endpoint:** `POST /v1/chat/completions` (formato OpenAI) ou `POST /v1/messages` (formato Anthropic)

```bash
curl -X POST http://127.0.0.1:20129/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"todas-free","messages":[{"role":"user","content":"Olá"}],"stream":false}'
```

Streaming: adicione `"stream":true` → SSE `data: {...}\n\n` ... `data: [DONE]\n\n`.

---

## 2. Geração de Imagem

**Endpoint:** `POST /v1/images/generations`

```bash
curl -X POST "http://127.0.0.1:20129/v1/images/generations?response_format=binary" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini/gemini-3-pro-image-preview","prompt":"montanhas ao nascer do sol em aquarela","size":"1024x1024"}' \
  --output imagem.png
```

Campos: `model` (de `/v1/models/image`), `prompt`, `n`, `size`, `quality`, `response_format` (`url` ou `b64_json`). Query `?response_format=binary` retorna bytes da imagem.

---

## 3. Text-to-Speech (TTS)

**Endpoint:** `POST /v1/audio/speech`

```bash
curl -X POST http://127.0.0.1:20129/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"edge-tts/pt-BR-FranciscaNeural","input":"Olá, mundo"}' \
  --output fala.mp3
```

`model` = voice ID de `/v1/models/tts` (ex.: `edge-tts/pt-BR-FranciscaNeural`, `openai/tts-1/alloy`, `el/voice_id`). Default MP3; use `?response_format=json` para base64.

---

## 4. Speech-to-Text (STT)

**Endpoint:** `POST /v1/audio/transcriptions` (multipart/form-data)

```bash
curl -X POST http://127.0.0.1:20129/v1/audio/transcriptions \
  -F "model=groq/whisper-large-v3-turbo" \
  -F "file=@audio.mp3" \
  -F "language=pt"
```

Formatos: mp3, wav, m4a, webm, ogg, flac. `response_format`: `json` (padrão), `text`, `verbose_json`, `srt`, `vtt`.

---

## 5. Embeddings (RAG / Busca Semântica)

**Endpoint:** `POST /v1/embeddings`

```bash
curl -X POST http://127.0.0.1:20129/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini/text-embedding-004","input":["texto 1","texto 2"]}'
```

`input` pode ser string ou array. `encoding_format`: `float` (padrão) ou `base64`. `dimensions` só em OpenAI v3.

---

## 6. Busca Web

**Endpoint:** `POST /v1/search`

```bash
curl -X POST http://127.0.0.1:20129/v1/search \
  -H "Content-Type: application/json" \
  -d '{"model":"tavily","query":"KFAI instalador MSI","max_results":5}'
```

`model` = provedor de `/v1/models/web` com `kind:"webSearch"` (ex.: `tavily`, `brave`, `search-combo`). Campos opcionais: `max_results`, `search_type` (`web`/`news`), `country`, `language`, `time_range`, `domain_filter`.

---

## 7. Fetch de URL → Markdown

**Endpoint:** `POST /v1/web/fetch`

```bash
curl -X POST http://127.0.0.1:20129/v1/web/fetch \
  -H "Content-Type: application/json" \
  -d '{"model":"jina-reader","url":"https://9router.com","format":"markdown"}'
```

`model` = provedor de `/v1/models/web` com `kind:"webFetch"` (ex.: `jina-reader`, `firecrawl`, `fetch-combo`). `format`: `markdown` (padrão), `text`, `html`. `max_characters` opcional.

---

## Erros

- **401** → chave expirada/ausente: atualize `NINEROUTER_KEY` no 9Router Dashboard
- **400 Invalid model format** → modelo não existe em `/v1/models/<kind>`
- **503 All accounts unavailable** → aguarde `retry-after` ou adicione outra conta no 9Router
- **502/503 do router** → 9Router não está rodando ou não configurado no `router.conf`