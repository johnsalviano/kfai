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

- O que é: o modelo multimodai do Google (texto + imagem + áudio).
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

## 5) Ollama (local — sem chave)

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
| Ollama | (sem chave) | grátis |

## Onde colocar a sua chave

- No **9Router**: menu de connection/provider → `apikey`.
- No **Opencode**: arquivo `config/opencode/<combo>.json`, campo `apiKey` da
  seção `9router`, troque `{env:KFAI_NINEROUTER_KEY}` pela nave de ambiente
  `KFAI_NINEROUTER_KEY`, definida no seu sistema com a sua chave.

> Nunca coloque a chave em arquivo que você vá mandar para alguém. Defina como
> **variável de ambiente** e use `{env:...}` (é o jeito seguro, que o KFAI já
> preparou nos arquivos de exemplo).