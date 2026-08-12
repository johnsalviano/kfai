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

## 8) Ollama (local — sem chave)

- Não precisa de chave nenhuma. Só instale o [Ollama](https://ollama.com) e o
  KFAI baixa o modelo certo para seu PC automaticamente (via `install.ps1`).
- Use nos combos **Cloud + Local** (fallback) ou **Full Local** (100% offline).

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
| Ollama | (sem chave) | grátis |

> Quer um atalho? Rode `.\kfai-config-chaves.ps1` e ele mostra na tela quais
> chaves ainda faltam com o link certo de cada uma.

## Onde colocar a sua chave

- **No 9Router**: painel em `http://localhost:20128/dashboard` → conexões →
  escolha o provider gratuito → cole a chave. O 9Router é o **único lugar** que
  guarda chaves de nuvem hoje; o KFAI só aponta para ele.

> Nunca coloque a chave em arquivo que você vá mandar para alguém. O 9Router
> guarda as chaves localmente, no seu PC, e o KFAI nunca as usa nem envia.