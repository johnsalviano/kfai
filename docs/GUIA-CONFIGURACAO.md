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
.\01-install.ps1
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
| tudo offline (100%) | `kfai/full-local` |

Se preferir configurar à mão, também existem presets completos em
`config/opencode/` (`full-cloud.json`, `cloud-plus-local.json`,
`full-local.json`) para copiar para o seu `opencode.json`.

No **Full Local**, se preciso, troque o nome do modelo no arquivo
(`KFAI_LOCAL_MODEL`) pelo que o instalador baixou.

### Aplicar combos no AionUi (interface gráfica)

Se você usa o **AionUi**, abra o app e rode (no PowerShell do próprio AionUi):

```powershell
.\04-kfai-aionui-combos.ps1
```

Esse script adiciona o provider **KFAI Router** com os três combos e remove os
perfis pagos (Anthropic e OpenAI).

## Passo 4 — Gerar suas chaves gratuitas

Rode o assistente de chaves para ver na tela **quais chaves faltam** e o **link
de cada uma**:

```powershell
.\02-kfai-config-chaves.ps1
```

Depois de gerar cada chave, salve-a no 9Router com o fluxo automático (ele
testa e adiciona os modelos ao combo `todas-free`):

```powershell
.\02-kfai-config-chaves.ps1 -Adicionar
```

Também pode seguir o [Guia de Chaves Gratuitas](GUIA-CHAVES-GRATIS.md) para
gerar as chaves de OpenRouter, Gemini, NVIDIA, Cloudflare, API.airforce,
Poolside e BytePlus (todas grátis). O 9Router fica rodando em
segundo plano e o router KFAI encaminha os combos de nuvem para ele — ou seja,
com as chaves dentro do 9Router, os combos **Full Cloud** e **Cloud + Local**
passam a funcionar sem precisar mexer em variáveis de ambiente.

> **Por que assim?** O 9Router guarda as chaves dele em um banco local seguro.
> O router KFAI não copia suas chaves: ele só pede ao 9Router para responder,
> e o 9Router usa as chaves que você já cadastrou.

## Passo 4.5 — Provedor que não está no catálogo (opcional)

O 9Router já conhece dezenas de provedores de graça. Mas se você usa algum
serviço de IA **que não está na lista** dele — desde que o serviço aceite o
formato de API da OpenAI (`.../v1/chat/completions`) ou da Anthropic
(`.../v1/messages`) — dá para conectar mesmo assim. O KFAI chama isso de
**provedor custom**:

```powershell
.\03-kfai-config-provider-nodes.ps1            # mostra os que você já cadastrou
.\03-kfai-config-provider-nodes.ps1 -Adicionar # conecta um novo (passo a passo)
.\03-kfai-config-provider-nodes.ps1 -Remover   # apaga um que não quer mais
```

O assistente pede apenas:

1. **Tipo** do endpoint (OpenAI-compatible ou Anthropic-compatible);
2. **Nome** (só para você reconhecer depois);
3. **Prefixo** curto — é o "nome" do provedor dentro do 9Router e nos combos
   (ex.: prefixo `meu-gw` + modelo `gpt-x` = `meu-gw/gpt-x`);
4. **Endereço base** da API (a "tomada" do serviço);
5. (recomendado) a **chave de API**, para testar antes e salvar direto no 9Router.

Depois de criado, o provedor custom aparece no dashboard do 9Router como
qualquer outro provedor: dá para testar, adicionar aos combos (perfil
`full-cloud` / `cloud-plus-local`) e usar nos agentes com o nome
`<prefixo>/<modelo>`.

> A chave vai do seu teclado direto para o 9Router (via API local), nunca é
> gravada em arquivo pelo KFAI — mesma garantia do assistente de chaves.

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

- Prefira **Cloud + Local** na maioria dos casos: usa a nuvem de graça e só usa
  seu PC se a nuvem estiver sem cota.
- Se seu PC for bem básico (menos de 3 GB de RAM), o instalador não força IA
  local — use **Full Cloud**.
- Suas chaves ficam **dentro do 9Router** (banco local seguro). Não compartilhe
  e não coloque em arquivo que você vá mandar para alguém.

Pronto! Seu kit de agentes de IA está no ar. 🎉