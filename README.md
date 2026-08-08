# KFAI — Kit de Ferramentas de Agente de IA

**🇧🇷 Português · [🇺🇸 English](README.en.md)**

![Licença](https://img.shields.io/badge/Licen%C3%A7a-MIT-blue)
![Plataforma](https://img.shields.io/badge/Plataforma-Windows%2010%2F11-lightgrey)
![Linguagem](https://img.shields.io/badge/Linguagem-PowerShell%20%2B%20Python-purple)
![IA](https://img.shields.io/badge/IA-Ollama%20%2B%209Router%20%2B%20Opencode-green)
![Status](https://img.shields.io/badge/Status-Aberto%20para%20todos-brightgreen)
[![Release](https://img.shields.io/github/v/release/johnsalviano/kfai)](https://github.com/johnsalviano/kfai/releases)

> **Agentes de IA gratuitos para quem não desiste.**

O KFAI reúne, configura e explica como usar ferramentas de IA **gratuitas**
(Ollama, 9Router, Opencode, AionUi) para realizar tarefas do dia a dia — e ainda
te ajuda a otimizar seu próprio computador para aproveitá-las melhor.

- ✅ **100% gratuito** — só ferramentas de código aberto
- 🖥️ **Roda em PC fraco** — se sua máquina não aguentar IA local, você usa a nuvem
- 🔐 **Sem chaves de ninguém** — você gera as suas, de graça, e elas ficam na sua máquina

---

## 🚀 Como instalar

Você pode rodar o instalador de **duas formas** — escolha a que preferir:

| Prefere | Faça |
|---|---|
| Script (transparente, dá para ler tudo) | `.\install.ps1` no PowerShell |
| Executável (não depende da Execution Policy) | baixe o `KFAI-Instalador.exe` na página de [releases](https://github.com/johnsalviano/kfai/releases) e dê dois cliques |

> O executável é apenas o instalador compilado — o kit em si continua sendo
> scripts abertos (você pode ler tudo antes de usar). O `.exe` existe para quem
> tem o PowerShell com políticas de execução que bloqueiam scripts.

Antes, instale as dependências:

1. [Ollama](https://ollama.com/download/windows) *(opcional, só se quiser IA local)*.
2. [9Router](https://9router.com) e [Opencode](https://opencode.ai).

O instalador **detecta o seu hardware** (RAM, CPU, GPU), escolhe o modelo local
certo para a sua máquina e mostra o caminho passo a passo — sem pedir
administrador e sem baixar nada duas vezes.

---

## 🧩 Combos disponíveis

| Combo | O que é | Quando usar |
|---|---|---|
| **Full Cloud** | só IAs gratuitas na nuvem (Gemini, OpenRouter :free, NVIDIA NIM…) | PC fraco, quer usar a IA da nuvem |
| **Cloud + Local** | nuvem primeiro; se o limite acabar, usa IA local | equilíbrio, quase sempre |
| **Full Local** | 100% offline (Ollama) | sem internet ou por privacidade; só se seu PC aguentar |

Ambos os caminhos (9Router e o roteador próprio do KFAI): a pasta `config/opencode/`
tem arquivos para os dois. Copie o que preferir:

| Prefere | Arquivos |
|---|---|
| Roteador próprio (sem 9Router ligado) | `router-full-cloud.json`, `router-cloud-plus-local.json`, `router-full-local.json` |
| 9Router | `full-cloud.json`, `cloud-plus-local.json`, `full-local.json` |

**Roteador próprio:** rode `python router.py`, preencha `router.conf` (copie o
`.example`), escolha por rota `full` (texto intacto), `eco` (resume histórico
antigo para economizar tokens) ou `auto` (o roteador decide por heurística: tema
complexo → `full`, pergunta simples → `eco`). O 9Router fica só para quem preferir ele.

Os **3 combos padrão** já vêm prontos no `router.conf.example`. Cada linha é um
"uplink" (provedor); linhas com a mesma rota formam a lista de fallback:

- **`full-cloud`** — só nuvem gratuita (Gemini, Groq, Cerebras, OpenRouter `:free`,
  Mistral, NVIDIA NIM). Para PC fraco que não roda IA local, use **só** este.
- **`cloud-plus-local`** — nuvem primeiro; quando os tokens acabam (429), cai
  automaticamente para o Ollama local (últimos uplinks da lista).
- **`full-local`** — somente Ollama local (100% offline).

Recursos que o roteador próprio tem de fábrica:

- **Fallback automático**: cada rota aceita vários uplinks; se um cair ou falhar,
  a chamada segue para o próximo da lista. **Só erros recuperáveis** (429 de
  rate limit, 5xx, timeout) disparam fallback/cooldown — erros de configuração
  (400, 401, 403, 404) não caem para outro provedor, pois são problema do pedido.
- **Cooldown (circuit breaker)**: um uplink que falhou de forma recuperável fica
  em quarentena e é pulado nas próximas chamadas (`KFAI_COOLDOWN_SEC`, padrão 60s).
- **Modo `auto`**: heurística determinística (sem custo de LLM) para escolher
  `full` vs `eco` por request — complexidade do prompt, presença de tools e tamanho.
- **Compressão de saída de ferramentas**: saídas longas de `tool` (logs, git, etc.)
  são colapsadas (linhas repetidas omitidas) e truncadas para caber no contexto.
- **Cache em memória**: chamadas repetidas idênticas (non-stream) respondem
  instantaneamente sem reprocessar (`KFAI_CACHE_SEC` 300s, até `KFAI_CACHE_MAX` 200).
- **Log JSONL**: cada request registrado em `logs/router.log` (rota, uplink, modo,
  cache, bytes, tempo). Variáveis: `KFAI_LOG_FILE`, `KFAI_ROUTER_PORT`.
- **Proteção contra abuso local**: o roteador recusa requests com `Origin` de sites
  externos (evita que uma página maliciosa que você visite use as suas chaves via
  navegador) e pode exigir um token — defina `KFAI_ROUTER_TOKEN` para que só quem
  conhece o token use o roteador (proteção extra contra malware local).

## IA local com contexto que funciona (não quebra o agente)

O Ollama usa contexto **4.096 tokens por padrão** e **trunca silenciosamente**
o que passar disso — isso faz o agente local "esquecer" o meio da tarefa e as
**tool calls falharem**. O KFAI resolve isso em dois pontos:

1. **`kfai-start.ps1`** define `OLLAMA_KEEP_ALIVE=30m` (o modelo fica na RAM,
   sem cold start de 3–10s a cada request) e `OLLAMA_NUM_PARALLEL=2`.
2. **Router próprio**: quando um uplink é o Ollama local, o router injeta
   `options.num_ctx` no request (`KFAI_NUM_CTX`, padrão **32768**). Config de
   falha/erro só para 429/5xx/timeout.
3. **Modelo derivado `-32k`**: o instalador cria um modelo com `num_ctx 32768`
   gravado nele (ex.: `qwen2.5-coder-32k`). Use esse nome no config do opencode
   (`config/opencode/full-local.json`, campo `KFAI_LOCAL_MODEL`).

> Recomendação oficial do Ollama para agentes com tool calling: contexto **≥64k**.
> Se seu PC aguentar (VRAM livre), pode criar `-64k` com o mesmo método:
> `FROM <modelo>` + `PARAMETER num_ctx 65536` num Modelfile, depois
> `ollama create <modelo>-64k -f Modelfile`.

O instalador também aproveita o comando **`ollama launch opencode`** (Ollama 0.15+):
configura o opencode com o modelo local automaticamente, sem JSON manual.

## Ligar só quando usar (sem processo sempre rodando)

Por padrão, nada fica rodando ocioso. O launcher liga router + Ollama **quando
você abre o agente** e desliga quando você o fecha:

```powershell
.\kfai-launch.ps1 -App aionui      # abre o AionUi
.\kfai-launch.ps1 -App opencode    # abre o opencode no terminal
.\kfai-launch.ps1 -App hermes      # abre o Hermes
.\kfai-launch.ps1 -App "C:\caminho\app.exe"   # qualquer executavel
```

**Usa o 9Router (porta 20128)?** Adicione `-With9Router` para preferir a IA
**local** e usar o 9Router só como reserva. Os dois **nunca** ficam ligados ao
mesmo tempo:

```powershell
.\kfai-launch.ps1 -App aionui -With9Router   # prefere local; cai pro 9Router se falhar
.\kfai-launch.ps1 -App opencode -With9Router
```

**Verificação automática no início** (o launcher decide sozinho):

1. **O PC aguenta IA local?** checa RAM (≥ 8 GB), VRAM da GPU (via `nvidia-smi`)
   e CPU. Sem isso, o Ollama não roda — o launcher **usa o 9Router como padrão**
   e nem tenta subir o local.
2. **Qual comando existe na máquina?** os caminhos do Ollama (`ollama.exe serve`
   ou `ollama app.exe`) e do 9Router (`cli.js` do npm global ou build standalone
   `server.js`) são descobertos em tempo real, pois mudam de PC para PC.
3. Se o PC suporta: sobe o Ollama, testa se responde e tem modelo (`/api/tags`).
   OK → usa o local. Falhou → derruba o local e sobe o 9Router.

`kfai-start.ps1 -Status` mostra as 3 portas **e o resultado da verificação**
(compatível ou não, com os caminhos encontrados). Para forçar só nuvem mesmo em
PC capaz, defina `KFAI_FORCE_NO_LOCAL=1`.

Se você fechar um agente mas **outro ainda estiver aberto** (ex.: AionUi aberto
e você fecha o opencode), os serviços continuam — só desligam quando o último
agente fecha. Use `-KeepOn` para manter os serviços após fechar o agente.

O atalho do AionUi no menu Iniciar já aponta para o launcher. Para abrir um
agente SEM launcher e mesmo assim ter os serviços, ligue manualmente com
`.\kfai-start.ps1`.

**Modo "sempre ligado" (opcional):** se preferir que tudo suba no login sem
abrir agente, rode `.\kfai-start.ps1 -Register` (e `-Unregister` para reverter).

## Documentação

- [O que é o KFAI](docs/O-QUE-E-KFAI.md)
- [Guia de configuração](docs/GUIA-CONFIGURACAO.md)
- [Guia de chaves gratuitas](docs/GUIA-CHAVES-GRATIS.md) — como gerar sua API key grátis de cada provedor
- [Créditos](docs/CREDITOS.md) — quem fez cada ferramenta

## ❤️ Apoie o projeto

O KFAI é **100% gratuito e sem anúncios** — feito no tempo livre, com carinho.
Se o projeto te ajudou e você quiser retribuir, qualquer valor é bem-vindo e
**faz diferença real** para continuar mantendo, corrigindo e melhorando:

> **PIX:** `edb2e588-8dc5-4991-ab61-62f113a066c6` *(chave aleatória — criada só
> para doações, sem expor dados pessoais)*
>
> 📱 **QR Code:** [pagamento via Nubank](https://nubank.com.br/cobrar/1bq05j/6a7686af-8d68-4c76-bde7-5ae91eabd152)

Se preferir não doar, tudo bem também! Você já ajuda muito ao:
- ⭐ dar uma estrela no repositório;
- 🐛 reportar bugs em [issues](https://github.com/johnsalviano/kfai/issues);
- 📣 divulgar o projeto para alguém que possa aproveitar.

## 🔐 SegurançaO KFAI **não inclui, lê nem compartilha** chaves, tokens ou dados pessoais de
ninguém. Toda credencial nasce como `SUA_CHAVE_AQUI` para você preencher — e os
valores reais ficam apenas na sua máquina, nunca neste repositório.

O instalador se autoprotege contra cópias adulteradas:

- só executa se vier do repositório oficial (`github.com/johnsalviano/kfai`);
- se o remote não for o oficial, **para** imediatamente (sinal de cópia adulterada);
- se **não houver remote** (ZIP, executável ou cópia repassada por terceiros),
  **avisa e pede confirmação** antes de continuar — você confirma que baixou do
  repositório oficial e confere o hash abaixo;
- no final, mostra o **SHA-256 do próprio instalador** para você conferir contra o
  valor publicado abaixo (mantido atualizado a cada versão).

O roteador próprio também se protege contra abuso:

- recusa requests com `Origin` de sites externos (uma página maliciosa que você
  visite **não** consegue usar as suas chaves de IA pelo navegador);
- opcionalmente exige `KFAI_ROUTER_TOKEN` para bloquear qualquer processo local
  que não conheça o token.

> **Hash do `install.ps1` atual (confira antes de rodar):**<br>
> `AA850FD54D15E3A2239C4212930D24CB436EE0DB3A030779D6E575CF60094936`<br>
> *(o próprio script imprime o mesmo valor no final da instalação — se divergir,
> o arquivo pode ter sido adulterado e **não** deve ser executado)*

> **Hash do `KFAI-Instalador.exe` atual (confira antes de rodar):**<br>
> `5E22AFB7CC87491C4F801A0C8B7CE0BC365E8A7226F51725E397697B25B7C10F`<br>
> *(se você baixou o executável, confira **este** valor — o executável imprime o
> hash do `.exe` no final, não o do script)*

## Licença

Veja [docs/CREDITOS.md](docs/CREDITOS.md) para atribuição das ferramentas. O kit
em si (documentação, skills, scripts, configuração) é distribuído sob MIT.