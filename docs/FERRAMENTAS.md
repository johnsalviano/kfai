# Ferramentas do KFAI — o que cada uma faz

O KFAI não inventa ferramentas. Ele **instala, configura e integra** ferramentas
open source que já existem. Abaixo, cada uma com seu papel, versão atual
(verificada em ago/2026) e onde encontrar a fonte oficial.

---

## Node.js

| | |
|---|---|
| **Para quê** | Base de tudo: o 9Router, a CLI do opencode e a CLI do 9Router são pacotes npm. Sem Node.js, nada roda. |
| **O que faz** | Runtime JavaScript que executa pacotes npm na linha de comando. |
| **Versão** | LTS mais recente no momento da instalação (baixada de https://nodejs.org/dist/index.json). |
| **Instalado como** | Se você tem admin: winget (`OpenJS.NodeJS.LTS`). Se não: zip oficial extraído para `%LOCALAPPDATA%\Programs\nodejs` (sem precisar de senha). |
| **Fonte oficial** | https://nodejs.org · GitHub: https://github.com/nodejs/node |

---

## Ollama

| | |
|---|---|
| **Para quê** | Rodar modelos de IA **dentro do seu PC** (offline, sem custo por token, sem enviar dados). |
| **O que faz** | Baixa e executa modelos open source (qwen3, llama3.2, etc.) localmente. Expõe uma API compatível com OpenAI em `http://localhost:11434/v1`. |
| **Versão** | 0.32.9 (ago/2026). Instalador baixa sempre a mais recente de https://ollama.com/download/OllamaSetup.exe. |
| **Modelo padrão do KFAI** | `qwen3:4b` (2.5 GB, 256K contexto, suporta ferramentas) para PC com 6GB+ VRAM. Para PC com 8-16GB RAM (CPU), `qwen3:4b` também. |
| **Variáveis configuradas pelo KFAI** | `OLLAMA_KEEP_ALIVE=30m` (modelo fica 30 min na RAM, evita cold start), `OLLAMA_NUM_PARALLEL=2` (requisições paralelas), `OLLAMA_KV_CACHE_TYPE=q8_0` (corta ~50% da memória do cache de contexto). Fonte: https://docs.ollama.com/faq |
| **Fonte oficial** | https://ollama.com/download · GitHub: https://github.com/ollama/ollama · Docs: https://docs.ollama.com |

---

## 9Router

| | |
|---|---|
| **Para quê** | Gateway de nuvem: guarda suas chaves de IA gratuitas e expõe um único endpoint. O router KFAI encaminha para ele; ele sabe qual provedor usar. |
| **O que faz** | Roda localmente (porta 20128). Cadastra chaves dos provedores (OpenRouter, Gemini, NVIDIA, Cloudflare, etc.) num banco SQLite local. Expõe API compatível com OpenAI. Dashboard em `http://localhost:20128/dashboard`. |
| **Versão** | 0.5.50 (npm, ago/2026). Instalado via `npm install -g 9router`. |
| **Chaves** | Você gera nos sites oficiais e cola no dashboard. O KFAI nunca toca nas suas chaves — nem copia, nem loga, nem commita. |
| **Fonte oficial** | https://github.com/decolua/9router · npm: https://www.npmjs.com/package/9router · Site: https://9router.com |

> **Atenção:** provedores gratuitos do 9Router mudam de tempos em tempos (alguns encerraram free tier em 2026). Confira sempre o README oficial antes de fixar um provedor.

---

## Opencode (CLI)

| | |
|---|---|
| **Para quê** | O agente de IA que roda no **terminal**. Lê seu projeto, edita arquivos, executa comandos, chama ferramentas. |
| **O que faz** | CLI que conecta a provedores de IA (via `opencode.json`) e age como assistente de código generalista. É open source e roda no Windows, macOS e Linux. |
| **Versão** | 1.18.16 (npm, ago/2026). Instalado via `npm install -g opencode-ai`. |
| **Config** | O KFAI grava um provider `kfai` no `~/.config/opencode/opencode.json` com três combos: `full-cloud`, `cloud-plus-local`, `full-local`. |
| **Fonte oficial** | https://opencode.ai · GitHub: https://github.com/anomalyco/opencode · Docs: https://opencode.ai/docs |

> Opencode exige **contexto de 64k+** em modelos locais. O KFAI cria um modelo derivado com `num_ctx=65536` automaticamente. Fonte: https://docs.ollama.com/integrations/opencode

---

## OpenCode Desktop

| | |
|---|---|
| **Para quê** | Versão gráfica (app de janela) do opencode, pra quem não quer usar terminal. |
| **O que faz** | Mesma engine do opencode, mas com interface visual. Abre arquivos, mostra diff, executa comandos. |
| **Versão** | 1.18.16 (GitHub release, ago/2026). Baixado de `github.com/anomalyco/opencode/releases`. |
| **Instalado como** | Instalador NSIS silencioso (`/S`) a partir do release oficial. |
| **Fonte oficial** | https://opencode.ai · GitHub: https://github.com/anomalyco/opencode/releases |

---

## AionUi

| | |
|---|---|
| **Para quê** | Interface gráfica completa para configurar e usar múltiplos provedores de IA (nuvem, local, combos) num só app. |
| **O que faz** | App Windows com gerenciador de provedores, rotação multi-chave, suporte a MCP servers, agendamento de tarefas, geração de imagens. Plataforma "Custom" para Ollama local. |
| **Versão** | 2.1.53 (GitHub release, ago/2026). Baixado de `static.aionui.com/releases/<ver>/AionUi-<ver>-win-x64.exe`. |
| **Config no KFAI** | Script `04-kfai-aionui-combos.ps1` adiciona o provider "KFAI Router" com os três combos e remove perfis pagos (Anthropic/OpenAI). |
| **Fonte oficial** | https://github.com/iOfficeAI/AionUi · Wiki: https://github.com/iOfficeAI/AionUi/wiki/LLM-Configuration · Site: https://aionui.com |

---

## Router KFAI (router.py)

| | |
|---|---|
| **Para quê** | O "cérebro" que decide para onde mandar cada requisição: nuvem (9Router) primeiro, local (Ollama) como reserva. |
| **O que faz** | Proxy Python compatível com OpenAI. Lê `router.conf` (rotas e fallbacks). Se o 9Router falhar com qualquer erro (429, 403, 500, timeout), marca cooldown e cai para o próximo uplink (Ollama). Também faz cache, compressão de histórico (modo eco) e log. |
| **Porta** | 20129 (padrão). 9Router = 20128. Ollama = 11434. |
| **Config** | `router.conf` (1 uplink por linha, formato `rota\|modelo\|base_url\|variavel_chave\|modo`). Exemplo em `router.conf.example`. |
| **Segurança** | Recusa `Origin` externo (sites maliciosos não usam suas chaves). Token opcional (`KFAI_ROUTER_TOKEN`). |
| **Fonte** | `router.py` no próprio repositório KFAI. MIT. |

---

## Como as peças se conectam

```
Você (opencode CLI / AionUi / OpenCode Desktop)
    │
    │  request "kfai/cloud-plus-local"
    ▼
Router KFAI (porta 20129)  ←── router.py
    │
    ├─ 1º uplink: 9Router (porta 20128)  ←── suas chaves estão aqui
    │     │
    │     ├─ Gemini  ────┐
    │     ├─ OpenRouter ─┤  (provedores gratuitos, chaves no dashboard)
    │     └─ NVIDIA ─────┘
    │
    └─ 2º uplink (fallback): Ollama (porta 11434)  ←── IA local, sem internet
          │
          └─ qwen3:4b (ou o modelo que o instalador escolheu)
```

- **Combo full-cloud**: só o 1º uplink (9Router).
- **Combo cloud-plus-local**: 9Router primeiro; se falhar, Ollama.
- **Combo full-local**: só Ollama (nem toca o 9Router).

Cada combo é uma "rota" no `router.conf`. O router KFAI decide qual rota usar
pelo nome do modelo que o opencode/AionUi pede (`kfai/full-cloud`,
`kfai/cloud-plus-local`, `kfai/full-local`).

---

## Skills (ferramentas de otimização)

O KFAI também traz **skills** — scripts que dão ao agente de IA a capacidade de
otimizar seu PC:

| Skill | O que faz |
|---|---|
| `hardware-scan` | Lê seu hardware real (RAM, CPU, GPU, VRAM) e sugere melhorias |
| `windows-otimizacao` | Limpa disco, remove bloatware, otimiza inicialização |
| `rede` | Testa velocidade, ping, DNS e sugere melhorias de conexão |
| `bios-otimizacao` | Guia de configuração de BIOS por hardware |
| `android-debug` | Diagnóstico de dispositivo Android (com ou sem emulador) |
| `ia-gratis` | Lista de modelos e ferramentas de IA gratuitos |
| `tarefas` | Usa o agente para tarefas do dia a dia |

Cada skill tem um `SKILL.md` (manual) e scripts executáveis em `scripts/`.