# Guia de Chaves Gratuitas — KFAI

O KFAI usa o **9Router** (roteador local de IA em nuvem, porta 20128) como
"tomada" para a IA: você configura uma ou mais chaves **gratuitas** e o KFAI
escolhe o melhor modelo disponível para cada perfil.

Este guia mostra **todos os provedores gratuitos** que o 9Router entende, o
link para gerar a chave de cada um e o jeito mais fácil de configurar.

> **Regra deste guia:** só provedores que **não cobram nada** (limites
> gratuitos diários/mensais ou totalmente grátis). Nada de créditos de trial
> ou contas que exijam cartão.
>
> **Segurança:** cada chave é sua e pessoal. O 9Router guarda as chaves
> localmente, no seu PC. O KFAI nunca as usa, nunca as envia e nunca as grava
> em arquivo.

---

## Como usar o KFAI para configurar (o caminho rápido)

Rode o assistente. Ele mostra o que já está configurado e o que falta:

```
.\02-kfai-config-chaves.ps1            # mostra o estado
.\02-kfai-config-chaves.ps1 -Adicionar # cola a chave e salva direto no 9Router
```

O fluxo **-Adicionar** faz tudo sozinho:

1. Mostra os provedores gratuitos e marca quais já têm chave (`[OK]`);
2. Você escolhe um pelo número e cola a chave (ela fica mascarada na tela);
3. O script salva a chave **direto no 9Router** (API local), sem abrir painel;
4. Ele **testa** a conexão e avisa se a chave está certa;
5. Pergunta se quer adicionar os modelos ao combo **`todas-free`** (usado
   pelos perfis `full-cloud` e `cloud-plus-local`).

A chave digitada vai direto do seu teclado para o 9Router — o KFAI só faz a
ponte, não guarda nem imprime nada.

> Alternativa manual: gerar a chave no site e colar no painel do 9Router
> (`http://localhost:20128/dashboard`).

---

## Tipos de provedores gratuitos

| Tipo | O que é | Como configura |
|---|---|---|
| **Com chave de API** | O site dá uma chave (`sk-or-…`, `AIza…`, `gsk_…`) | Fluxo `-Adicionar` (cola a chave) |
| **Por login (OAuth)** | Entra com sua conta Google/X/outra | No painel do 9Router, clique em "Conectar" |
| **Sem chave** | Grátis, não pede nada | Só ative/instale (alguns rodam no seu PC) |

---

## 1) Provedores com chave de API (grátis)

Para estes, use `.\02-kfai-config-chaves.ps1 -Adicionar`.

### OpenRouter — o mais fácil para começar
- Agrega **centenas de modelos** num lugar só, inclusive modelos `:free`.
- **Como:** https://openrouter.ai/keys → crie a conta → **Keys** → gere (`sk-or-…`).
- **Custo:** grátis (modelos `:free` + crédito inicial pequeno).

### Google Gemini — multimodal (texto, imagem, áudio)
- **Como:** https://aistudio.google.com/apikey → login Google → **Get API key** (`AIza…`).
- **Custo:** free tier (cota mensal), suficiente para uso pessoal.

### NVIDIA NIM — modelos de código/raciocínio de graça
- **Como:** https://build.nvidia.com → cadastre-se → **Get API Key** (`nvapi-…`).
- **Custo:** gratuito (uso limitado por mês).

### Cloudflare AI (Workers AI) — cota diária generosa
- **Como:** https://dash.cloudflare.com → Workers & Pages → AI → gere um **API Token**.
- **Custo:** free tier (10.000 neurônios/dia).

### Groq — velocidade máxima
- Modelos abertos (Llama, Kimi, gpt-oss) rodando muito rápido.
- **Como:** https://console.groq.com/keys → conta sem cartão → **Create API Key** (`gsk_…`).
- **Custo:** até **14.400 requisições/dia**.

### Cerebras — folga diária grande
- **Como:** https://cloud.cerebras.ai → **API Keys** → **Generate key**.
- **Custo:** até **14.400 req/dia** / 1M tokens por dia.

### Mistral — o maior volume de tokens grátis
- **Como:** https://console.mistral.ai/api-keys → conta (verificação por
  **telefone** + opt-in) → **Create new key**.
- **Custo:** plano Experiment, **1 bilhão de tokens/mês**.

### Cohere — foco em recuperação de informação (RAG)
- **Como:** https://dashboard.cohere.com/api-keys → **Create key**.
- **Custo:** 1.000 req/mês.

### HuggingFace Inference — milhares de modelos open source
- **Como:** https://huggingface.co/settings/tokens → **Access Tokens** → criar (`hf_…`).
- **Custo:** modelos serverless gratuitos.

### API.airforce — agregador com chave pronta no painel
- **Como:** https://api.airforce → conta grátis → a chave primária já aparece no
  Dashboard (`sk-air-…`).
- **Custo:** cota gratuita para uso pessoal.

### Poolside — modelos abertos
- **Como:** https://poolside.ai → conta → **API Keys** → **New key**.
- **Custo:** plano gratuito.

### BytePlus ModelArk (ByteDance) — família Doubao
- **Como:** https://www.byteplus.com → conta → **IAM** → gerar um **Access Key**.
- **Custo:** cota inicial gratuita.

### Bazaarlink — agregador free tier
- **Como:** https://bazaarlink.ai → conta → gerar chave no painel.
- **Custo:** free tier.

### Kilo Gateway — free tier
- **Como:** https://kilo-gateway.com → conta → gerar chave.
- **Custo:** free tier.

### Vercel AI Gateway — um gateway para vários provedores
- **Como:** https://vercel.com → **AI Gateway** → gerar a chave.
- **Custo:** free tier (cota).

### Ollama Cloud — modelo via nuvem da Ollama
- **Como:** https://ollama.com → conta → gerar chave no painel.
- **Custo:** free tier.

---

## 2) Provedores por login (OAuth) — grátis, sem chave

Estes não usam chave de API: você **conecta sua conta** no painel do 9Router
(`http://localhost:20128/dashboard` → o provedor → "Conectar"). São os mais
simples — se você já tem a conta, é um clique.

| Provedor | Site | O que conecta |
|---|---|---|
| **Gemini CLI** | https://aistudio.google.com | Sua conta Google |
| **Kiro AI** | https://kiro.ai | Sua conta Kiro |
| **Kimchi** | https://kimchi.ai | Sua conta Kimchi |
| **MiMo Code Free** | https://xiaomi.com | Sem login (ativo no 9Router) |
| **OpenCode Free** | https://opencode.ai | Sem login (ativo no 9Router) |

> Dica: `gemini-cli` e `kiro` dão uso gratuito bem generoso e são ótimos
> primeiros provedores para testar sem gerar chave nenhuma.

---

## 3) Sem chave / rodam no seu PC

Nada para digitar. Instale/ative e use.

| Provedor | O que é | Como ativa |
|---|---|---|
| **Ollama (local)** | IA que roda no seu PC (100% offline) | Instale https://ollama.com — o KFAI baixa o modelo certo (usado nos perfis `cloud-plus-local` e `full-local`) |
| **SearXNG** | Busca na web privada | Self-hosted: https://github.com/searxng/searxng |
| **Edge TTS** | Voz (texto→fala) | Ative no 9Router (gratuito) |
| **Coqui TTS** | Voz self-hosted | https://github.com/coqui-ai/TTS |
| **Tortoise TTS** | Voz self-hosted | https://github.com/neonbjb/tortoise-tts |
| **Local Device** | Modelos locais em geral | https://github.com/9router/local-ai-docs |

---

## O que já está configurado neste PC

Este PC já tem as chaves destes provedores salvas no 9Router (verificado agora):

`OpenRouter`, `Gemini`, `NVIDIA NIM`, `Cloudflare AI`, `Poolside`,
`BytePlus`, `API.airforce` e `Ollama`.

Os perfis do KFAI usam o combo **`todas-free`** (que já agrega 17 modelos
gratuitos) e, para IA local, o Ollama (`qwen2.5-coder`, `llama3.2:3b`).

---

## Resumo rápido

| Provedor | Link | Tipo | Custo |
|---|---|---|---|
| OpenRouter | https://openrouter.ai/keys | chave | grátis (`:free`) |
| Google Gemini | https://aistudio.google.com/apikey | chave | free tier |
| NVIDIA NIM | https://build.nvidia.com | chave | gratuito |
| Cloudflare AI | https://dash.cloudflare.com | chave | free tier |
| Groq | https://console.groq.com/keys | chave | 14.400 req/dia |
| Cerebras | https://cloud.cerebras.ai | chave | 14.400 req/dia |
| Mistral | https://console.mistral.ai/api-keys | chave | 1B tokens/mês |
| Cohere | https://dashboard.cohere.com/api-keys | chave | 1.000 req/mês |
| HuggingFace | https://huggingface.co/settings/tokens | chave | serverless grátis |
| API.airforce | https://api.airforce | chave | gratuito |
| Poolside | https://poolside.ai | chave | gratuito |
| BytePlus | https://www.byteplus.com | chave | cota inicial |
| Bazaarlink | https://bazaarlink.ai | chave | free tier |
| Kilo Gateway | https://kilo-gateway.com | chave | free tier |
| Vercel AI Gateway | https://vercel.com | chave | free tier |
| Ollama Cloud | https://ollama.com | chave | free tier |
| Gemini CLI | https://aistudio.google.com | login | grátis |
| Kiro AI | https://kiro.ai | login | grátis |
| Kimchi | https://kimchi.ai | login | grátis |
| MiMo Code Free | https://xiaomi.com | sem chave | grátis |
| OpenCode Free | https://opencode.ai | sem chave | grátis |
| Ollama (local) | https://ollama.com | sem chave | grátis |

---

## Onde ficam as chaves

- **No 9Router** (`http://localhost:20128/dashboard`): único lugar que guarda
  as chaves de nuvem hoje. O KFAI só aponta para ele.
- Nunca coloque a chave em arquivo que você vá mandar para alguém.
- Se uma chave vazar ou parecer comprometida, **regere** no site do provedor e
  adicione de novo com `.\02-kfai-config-chaves.ps1 -Adicionar`.

---

## Provedor fora do catálogo (custom)

O 9Router tem uma lista de provedores prontos, mas se você usa um serviço de IA
**que não está nessa lista** (e que aceite API no formato OpenAI ou Anthropic),
dá para conectar mesmo assim com o assistente de **provedores custom**:

```
.\03-kfai-config-provider-nodes.ps1            # mostra os que você já cadastrou
.\03-kfai-config-provider-nodes.ps1 -Adicionar # conecta um novo (passo a passo)
.\03-kfai-config-provider-nodes.ps1 -Remover   # apaga um que não quer mais
```

O assistente pede o tipo do endpoint, um nome, um **prefixo** (o "nome" do
provedor dentro do 9Router e nos combos) e o **endereço base** da API; depois
ele testa com a sua chave e salva direto no 9Router. Nos agentes, o modelo
aparece como `<prefixo>/<modelo>` (ex.: `meu-gw/gpt-x`).
