# Guia de Chaves Gratuitas — KFAI

Para usar os combos **Full Cloud** e **Cloud + Local**, você precisa de chaves
de API **gratuitas** de provedores. Este guia mostra o caminho para gerar cada
uma. Você pode começar **sem nenhuma chave** (o 9Router já oferece alguns
modelos gratuitos) e ir adicionando conforme precisar.

> **Importante**: cada chave é **sua** e pessoal. Não compartilhe. O KFAI nunca
> usa nem guarda chaves de ninguém.

## Como funciona

Cada provedor dá um tanto de uso grátis por conta. Você se cadastra, gera a
chave e cola no 9Router (ou no arquivo de configuração) no lugar do
`SUA_CHAVE_AQUI`.

---

## 1) OpenRouter (mais fácil para começar)

- O que é: agrega **centenas de modelos** de vários criadores em um só lugar.
- Tem modelos grátis (marcados com `:free`) e um saldo inicial gratuito.
- Roteiro:
  1. Acesse https://openrouter.ai
  2. Crie conta (Google ou e-mail)
  3. Vá em "Keys" / "API Keys"
  4. Gere uma chave (`sk-or-...`)
  5. Cole no 9Router (provider `openrouter`) ou em `config/opencode/*.json`
- Grátis: modelos `:free` sem custo; saldo pequeno de crédito inicial.

## 2) Google Gemini

- O que é: o modelo multimodal do Google (texto + imagem + áudio).
- Tem chave **gratuita** (AI Studio / Gemini API), com cota mensal.
- Roteiro:
  1. Acesse https://aistudio.google.com
  2. Faça login com conta Google
  3. **Get API key** → cria a chave (`AIza...`)
  4. Cole no 9Router (provider `gemini`)
- Grátis: plano **free tier** (algumas requisições por dia), suficiente para uso pessoal.

## 3) NVIDIA NIM (modelos NVIDIA de graça)

- O que é: modelos (Nemotron, DeepSeek, GLM, MiniMax) rodando no NVIDIA, grátis.
- Roteiro:
  1. Acesse https://build.nvidia.com (NVIDIA NIM / NGC)
  2. Cadastre-se → **API Key** (NVIDIA NIM)
  3. Cole no 9Router (provider `nvidia`)
- Grátis: uso limitado por mês, bom para testes e tarefas leves.

## 4) Cloudflare (Worker AI)

- O que é: Cloudflare oferece modelos de IA gratuitos com cota diária generosa.
- Roteiro:
  1. Acesse https://dash.cloudflare.com → Workers & Pages → AI
  2. Crie a conta → gere API Key/Token
  3. Cole no 9Router (provider `cloudflare-ai`)
- Grátis: 10.000 neurônios/dia (cota que você usa sem pagar).

## 5) API.airforce

- O que é: provedor agregador com modelos gratuitos e acessível.
- Roteiro:
  1. Acesse https://api.airforce
  2. Crie uma conta grátis
  3. Sua chave primária já aparece no Dashboard (`sk-air-...`)
  4. Cole no 9Router (provider `api-airforce`)
- Grátis: cota gratuita para uso pessoal.

## 6) Poolside

- O que é: provedor com modelos de IA de código aberto.
- Roteiro:
  1. Acesse https://platform.poolside.ai
  2. Entre com sua conta
  3. Aba **API Keys** → **New key**
  4. Cole no 9Router (provider `poolside`)
- Grátis: plano gratuito com cota para uso pessoal.

## 7) BytePlus ModelArk (Volcengine)

- O que é: plataforma de modelos da ByteDance (Doubao etc.).
- Roteiro:
  1. Acesse https://console.volcengine.com/iam
  2. Crie a conta
  3. Vá em **IAM** (Identity and Access Management) e gere um **Access Key**
  4. Cole no 9Router (provider `byteplus`)
- Grátis: cota inicial gratuita de uso.

## 8) Groq (velocidade máxima)

- O que é: inferência **muito rápida** com modelos abertos (Llama 3.3 70B,
  Llama 4 Scout, Kimi K2, gpt-oss-120b) e suporte a áudio (Whisper).
- Um dos **uplinks principais recomendados** para o combo `full-cloud` em PC fraco.
- Roteiro:
  1. Acesse https://console.groq.com
  2. Crie a conta (Google ou e-mail) — sem cartão
  3. Aba **API Keys** → **Create API Key** (`gsk_...`)
  4. Cole no 9Router (provider `groq`)
- Grátis: até **14.400 req/dia** (limite diário muito generoso).

## 9) Cerebras (folga diária grande)

- O que é: inferência em chip especializado, também com limites diários altos.
- Modelos: gpt-oss-120b, Qwen 3 235B, Llama 3.3 70B.
- Roteiro:
  1. Acesse https://cloud.cerebras.ai
  2. Crie a conta → **API Keys** → **Generate key**
  3. Cole no 9Router (provider `cerebras`)
- Grátis: até **14.400 req/dia** / 1M tokens por dia.
- Dica: no OpenRouter os modelos são `:free` com limite pequeno; direto na
  Cerebras a folga é bem maior.

## 10) Mistral La Plateforme (maior volume de tokens grátis)

- O que é: o maior volume gratuito — **1 bilhão de tokens/mês** no plano
  Experiment (Mistral Large, Nemo, Small).
- Roteiro:
  1. Acesse https://console.mistral.ai
  2. Crie a conta → verificação por **telefone** (obrigatória)
  3. Aceite o opt-in de uso dos dados para treinamento
  4. **API Keys** → **Create new key**
  5. Cole no 9Router (provider `mistral`)
- Grátis: plano Experiment (1B tokens/mês). Exige telefone + opt-in.

## 11) Mistral Codestral (foco em código)

- O que é: modelos de geração de código do Mistral.
- Roteiro:
  1. Acesse https://console.mistral.ai/codestral
  2. Crie a conta (ou use a mesma da seção 10)
  3. Gere uma chave para a API do Codestral
  4. Cole no 9Router (provider `mistral-codestral`)
- Grátis: **2.000 req/dia**.

## 12) Cohere (bom para RAG/corporativo)

- O que é: modelos Command A / Command R+, conhecidos por contexto longo e
  recuperação de informações (RAG).
- Roteiro:
  1. Acesse https://dashboard.cohere.com
  2. Crie a conta → **API Keys** → **Create key**
  3. Cole no 9Router (provider `cohere`)
- Grátis: 1.000 req/mês, 20 req/min.

## 13) HuggingFace Inference Providers (milhares de modelos open source)

- O que é: um endpoint único para os modelos da comunidade (serverless, até 10GB).
- Roteiro:
  1. Acesse https://huggingface.co/settings/tokens
  2. Crie a conta → **Access Tokens** → **Create new token** (`hf_...`)
  3. Cole no 9Router (provider `huggingface`)
- Grátis: modelos serverless gratuitos + ~$0,10/mês de créditos.

## 14) Vercel AI Gateway (um gateway para vários provedores)

- O que é: roteia para vários provedores de IA num gateway só (útil como
  camada extra de fallback).
- Roteiro:
  1. Acesse https://vercel.com → **AI Gateway**
  2. Crie a conta → gere a chave do gateway
  3. Cole no 9Router (provider `vercel-ai-gateway`)
- Grátis: plano free (~$5/mês de uso no plano pago; free tem cota).

## 15) Ollama (local — sem chave)

- Não precisa de chave nenhuma. Só instale o [Ollama](https://ollama.com) e o
  KFAI baixa o modelo certo para seu PC automaticamente (via `install.ps1`).
- Use nos combos **Cloud + Local** (fallback) ou **Full Local** (100% offline).

---

## Com créditos de trial (opção no `kfai-config-chaves`)

Provedores que dão créditos de teste. Úteis como **fallback adicional** ou para
experimentar um modelo específico. Exigem cadastro e, em alguns, verificação.

| Provedor | Crédito | Observações |
|---|---|---|
| Alibaba Cloud Model Studio | 1M tokens/modelo | família Qwen |
| SambaNova Cloud | ~$5 / 3 meses | DeepSeek, Llama, Qwen |
| Scaleway Generative APIs | 1M tokens | — |
| Hyperbolic | ~$1 | modelos open (DeepSeek, Qwen, Llama) |
| Fireworks / Nebius / Novita / Inference.net | $1–25 | créditos iniciais |
| AI21 / Upstage | ~$10 / 3 meses | — |
| NLP Cloud | ~$15 | exige telefone |

> **Não recomendado**: GitHub Models (descontinuado em jul/2026) e Vertex AI
> (grátis em preview, mas exige cartão de pagamento).

---

## Resumo rápido

| Provedor | Link da chave | Custo |
|---|---|---|
| OpenRouter | https://openrouter.ai/keys | grátis (`:free` + crédito inicial) |
| Google Gemini | https://aistudio.google.com | free tier |
| NVIDIA NIM | https://build.nvidia.com | gratuito |
| Cloudflare | https://dash.cloudflare.com | free tier (cota diária) |
| API.airforce | https://api.airforce | gratuito |
| Poolside | https://platform.poolside.ai | gratuito |
| BytePlus ModelArk | https://console.volcengine.com/iam | cota inicial gratuita |
| Groq | https://console.groq.com | grátis (14.400 req/dia) |
| Cerebras | https://cloud.cerebras.ai | grátis (14.400 req/dia) |
| Mistral | https://console.mistral.ai | 1B tokens/mês (Experiment) |
| Mistral Codestral | https://console.mistral.ai/codestral | 2.000 req/dia |
| Cohere | https://dashboard.cohere.com | 1.000 req/mês |
| HuggingFace | https://huggingface.co/settings/tokens | modelos serverless grátis |
| Vercel AI Gateway | https://vercel.com | free tier |
| Ollama | (sem chave) | grátis |

> Quer um atalho? Rode `.\kfai-config-chaves.ps1` e ele mostra na tela quais
> chaves ainda faltam com o link certo de cada uma.

## Onde colocar a sua chave

- **No 9Router**: painel em `http://localhost:20128/dashboard` → conexões →
  escolha o provider gratuito → cole a chave. O 9Router é o **único lugar** que
  guarda chaves de nuvem hoje; o KFAI só aponta para ele.

> Nunca coloque a chave em arquivo que você vá mandar para alguém. O 9Router
> guarda as chaves localmente, no seu PC, e o KFAI nunca as usa nem envia.