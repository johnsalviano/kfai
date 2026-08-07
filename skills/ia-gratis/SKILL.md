---
name: ia-gratis
description: Guia de ferramentas de IA gratuitas. Mostra quais agentes, modelos e provedores o usuário pode usar sem pagar, como gerar chaves de API gratuitas e como ampliar o combo de IAs. Use quando a pessoa perguntar o que dá para usar de IA de graça, onde conseguir chave grátis, como instalar/configurar agentes ou como combinar várias IAs.
---

# Skill: IA Gratuita (guia)

Ajude a pessoa a usar agentes de IA **gratuitos** para realizar tarefas. Foco é
**mostrar o caminho**, nunca prometer o que não existe nem pedir pagamento.

## O que o usuário pode usar de graça (explicar de forma simples)

### 1. Motor local (Ollama) — sem internet, sem chave
- instalar [Ollama](https://ollama.com/download/windows)
- roda modelos no próprio PC. Pode ser lento em PC fraco.

### 2. Nuvem gratuita (9Router + chaves grátis)
- [9Router](https://9router.com): combina várias IAs gratuitas, com troca
  automática quando uma acaba o limite.
- Proveedores com chave grátis: **OpenRouter** (`:free`), **Google Gemini**
  (AI Studio), **NVIDIA NIM**, **Cloudflare**. Ver `docs/GUIA-CHAVES-GRATIS.md`.

### 3. Agentes/interface
- **Opencode** (terminal) e **AionUi** (interface gráfica).

## Como responder
1. Pergunte o que a pessoa quer fazer (escrever, criar planilha, otimizar PC, estudar…).
2. Sugira o combo mais leve/grátis que atenda. Recomende **Cloud + Local** na
   maioria dos casos e **Full Cloud** se o PC for fraco.
3. Se exigir IA mais forte que a grátis, diga com honestidade os limites e o
   caminho (chaves grátis) — nunca invente.
4. Conduza para gerar a chave: site → criar conta → API key → colar no 9Router.
5. Aponte as skills do kit para a tarefa concreta.

## Scripts
- `scripts/modelos-gratis.ps1` — lista modelos gratuitos sugeridos por categoria.

## Campos
- Nunca peça senha, cookie ou key do usuário para "testar". Ele mesmo cola a
  dele. Nunca exponha sua própria cred.