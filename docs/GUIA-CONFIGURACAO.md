# Guia de Configuração — KFAI

Passo a passo em português simples para deixar seu kit de agentes de IA funcionando.

## O que você vai precisar (tudo grátis)

| Ferramenta | Para quê | Onde baixar |
|---|---|---|
| **Ollama** | rodar IA localmente (opcional) | https://ollama.com/download/windows |
| **9Router** | combinar IAs gratuitas da nuvem | https://9router.com |
| **Opencode** | o agente de IA no terminal | https://opencode.ai |
| **AionUi** | (opcional) interface gráfica dos agentes | https://aionui.com |

## Passo 1 — Instalar as ferramentas

1. Instale o **9Router**. Abra ele (fica rodando em segundo plano).
2. Instale o **Opencode** (pode usar via terminal).
3. (Opcional) Instale o **Ollama** se você quiser IA local.
4. (Opcional) Instale o **AionUi** para usar pelo navegador.

## Passo 2 — Rode o instalador do KFAI

Abra o PowerShell na pasta do KFAI e rode:

```powershell
.\install.ps1
```

O script:
- detecta seu hardware (RAM, CPU, VRAM);
- decide se seu PC aguenta IA local;
- se aguenta, escolhe o modelo certo e baixa (via `ollama pull`);
- se não aguenta, avisa que deve usar **Full Cloud**.

## Passo 3 — Escolher o combo

O instalador do KFAI já adiciona o **provider `kfai`** (router local) ao seu
`opencode.json` automaticamente. Para escolher o combo, basta trocar o modelo
no opencode:

| Você quer | Modelo no opencode |
|---|---|
| só internet, IA da nuvem | `kfai/full-cloud` |
| nuvem + seu PC de reserva | `kfai/cloud-plus-local` |
| tudo offline (200%) | `kfai/full-local` |

Se preferir configurar à mão, também existem presets completos em
`config/opencode/` (`full-cloud.json`, `cloud-plus-local.json`,
`full-local.json`) para copiar para o seu `opencode.json`.

No **Full Local**, se preciso, troque o nome do modelo no arquivo
(`KFAI_LOCAL_MODEL`) pelo que o instalador baixou.

### Aplicar combos no AionUi (interface gráfica)

Se você usa o **AionUi**, abra o app e rode (no PowerShell do próprio AionUi):

```powershell
.\kfai-aionui-combos.ps1
```

Esse script adiciona o provider **KFAI Router** com os três combos e remove os
perfis pagos (Anthropic e OpenAI).

## Passo 4 — Gerar suas chaves gratuitas

Siga o [Guia de Chaves Gratuitas](GUIA-CHAVES-GRATIS.md) para gerar as chaves de
OpenRouter, Gemini, NVIDIA e Cloudflare (todas grátis). O 9Router funciona mesmo
sem chave, mas com mais chaves você tem mais IAs no combo.

## Passo 5 — Usar as skills (otimizar seu PC)

Os skills na pasta `skills/` dão à IA a tarefa de otimizar sua máquina:
- `hardware-scan` — lê seu hardware real e sugere melhorias
- `windows-otimizacao` — debloat, deixar o Windows mais leve
- `rede` — testar velocidade/ping/DNS e melhorar
- `bios-otimizacao` — guia de configuração de BIOS por hardware
- `android-debug` — otimizar sistema Android/celular (com ou sem emulador)
- `ia-gratis` — como usar cada ferramenta de IA gratuita
- `tarefas` — usar o agente para tarefas do dia a dia

Cada skill tem um `SKILL.md` (o "manual") e scripts para executar em baixo.

## Dicas

- Prefira **Cloud + Local** na maioria dos casos: usa a nuvem de grava e só usa
  seu PC se a nuvem estiver sem cota.
- Se seu PC for bem básico (menos de 3GB de RAM), o instalador não força IA
  local — use **Full Cloud**.
- Guarde suas chaves só em variável de ambiente (`KFAI_NINEROUTER_KEY`), nunca
  em arquivo que você vá compartilhar.

Pronto! Seu kit de agentes de IA está no ar. 🎉