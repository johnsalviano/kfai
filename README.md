# KFAI — Kit de Ferramentas de Agente de IA

**🇧🇷 Português · [🇺🇸 English](README.en.md)**

[![Licença](https://img.shields.io/github/license/johnsalviano/kfai)](LICENSE)
[![Versão](https://img.shields.io/github/v/release/johnsalviano/kfai)](https://github.com/johnsalviano/kfai/releases)
[![Último commit](https://img.shields.io/github/last-commit/johnsalviano/kfai)](https://github.com/johnsalviano/kfai)
[![Estrelas](https://img.shields.io/github/stars/johnsalviano/kfai?style=social&label=Estrelas)](https://github.com/johnsalviano/kfai)
[![Forks](https://img.shields.io/github/forks/johnsalviano/kfai?style=social&label=Forks)](https://github.com/johnsalviano/kfai/fork)

![Plataforma](https://img.shields.io/badge/Plataforma-Windows%2010%2F11-lightgrey)
![Linguagem](https://img.shields.io/badge/Linguagem-PowerShell%20%2B%20Python-purple)
![IA](https://img.shields.io/badge/IA-Ollama%20%2B%209Router%20%2B%20Opencode-green)
![Status](https://img.shields.io/badge/Status-Ativo-brightgreen)

O KFAI reúne, configura e explica como usar ferramentas de IA **gratuitas**
(Ollama, 9Router, Opencode, AionUi) para realizar tarefas do dia a dia — e ainda
te ajuda a otimizar seu próprio computador para aproveitá-las melhor.

- ✅ **100% gratuito** — só ferramentas de código aberto
- 🖥️ **Roda em PC fraco** — se sua máquina não aguentar IA local, você usa a nuvem
- 🔐 **Sem chaves de ninguém** — você gera as suas, de graça, e elas ficam na sua máquina

## 📖 Índice

- [Como instalar](#-como-instalar)
- [Combos disponíveis](#-combos-disponíveis)
- [Como o KFAI funciona](#-como-o-kfai-funciona)
- [IA local com contexto que funciona](#-ia-local-com-contexto-que-funciona)
- [Ligar só quando usar](#-ligar-só-quando-usar-sem-processo-sempre-rodando)
- [Documentação](#-documentação)
- [FAQ](#-faq--dúvidas-frequentes)
- [Apoie o projeto](#-apoie-o-projeto)
- [Segurança](#-segurança)
- [Material para aprender mais](#-material-para-aprender-mais)

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

O instalador do KFAI já deixa os combos prontos: adiciona o **provider `kfai`**
no seu `opencode.json` (Full Cloud, Cloud + Local, Full Local) e, se você usa
AionUi, o `kfai-aionui-combos.ps1` adiciona o mesmo no app e remove perfis pagos.

Também há arquivos prontos para configurar à mão na pasta `config/opencode/`:

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

## 🧠 Como o KFAI funciona

Uma única rota com **vários provedores em ordem de prioridade** (uplinks): o
router KFAI tenta o primeiro; se ele falhar, a chamada segue para o próximo.

```
Você (Opencode CLI / OpenCode Desktop / AionUi)
        │  pede um combo (ex.: kfai/cloud-plus-local)
        ▼
Router KFAI (porta 20129 — router.py)
        │
        ├── 1º uplink: 9Router (porta 20128) ←── suas chaves gratuitas ficam aqui
        │        ├─ OpenRouter  ·  Gemini  ·  NVIDIA NIM  ·  Cloudflare …
        │        └─ falhou? (429/5xx/qualquer erro do 9Router) → desce
        │
        └── 2º uplink: Ollama local (porta 11434) ←── IA 100% offline
                 └─ qwen3:4b (ou o modelo que o instalador escolheu p/ seu PC)
```

- **`kfai/full-cloud`** → só o 9Router (nuvem gratuita).
- **`kfai/cloud-plus-local`** → nuvem primeiro; se falhar, cai para o Ollama local.
- **`kfai/full-local`** → só o Ollama (funciona até sem internet).

Cada combo é uma rota do `router.conf`; o modelo que o agente pede decide a rota.
Mais detalhes técnicos em [docs/FERRAMENTAS.md](docs/FERRAMENTAS.md).

## IA local com contexto que funciona (não quebra o agente)

O Ollama usa contexto **4.096 tokens por padrão** e **trunca silenciosamente**
o que passar disso — isso faz o agente local "esquecer" o meio da tarefa e as
**tool calls falharem**. O KFAI resolve isso em três pontos:

1. **`kfai-start.ps1`** define `OLLAMA_KEEP_ALIVE=30m` (o modelo fica na RAM,
   sem cold start de 3–10s a cada request) e `OLLAMA_NUM_PARALLEL=2`.
2. **Router próprio**: quando um uplink é o Ollama local, o router injeta
   `options.num_ctx` no request (`KFAI_NUM_CTX`, padrão **65536**).
3. **Modelo derivado `-64k`**: o instalador cria um modelo com `num_ctx 65536`
   gravado nele (ex.: `qwen3-64k`). Use esse nome no config do opencode
   (`config/opencode/full-local.json`, campo `KFAI_LOCAL_MODEL`).

> Contexto de **64k+** é a recomendação oficial do Ollama para agentes com tool
> calling (https://docs.ollama.com/integrations/opencode). O instalador já cria
> o modelo `-64k` automaticamente; para outro tamanho, monte um `Modelfile`
> (`FROM <modelo>` + `PARAMETER num_ctx <N>`) e rode
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
.\kfai-launch.ps1 -App "C:\caminho\app.exe"   # qualquer executável
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

## 📚 Documentação

- [O que é o KFAI](docs/O-QUE-E-KFAI.md)
- [Guia de configuração](docs/GUIA-CONFIGURACAO.md)
- [Guia de chaves gratuitas](docs/GUIA-CHAVES-GRATIS.md) — como gerar sua API key grátis de cada provedor
- `kfai-config-chaves.ps1` — assistente que mostra quais chaves faltam, abre o site de cada provedor e, com `-Adicionar`, salva a chave direto no 9Router
- [Modelos por hardware](docs/MODELOS-POR-HARDWARE.md) — qual modelo local baixar no seu PC
- [Créditos](docs/CREDITOS.md) — quem fez cada ferramenta

## ❓ FAQ / Dúvidas frequentes

**O PowerShell bloqueia o `install.ps1` ("não pode ser carregado")?**
Política de execução restrita. Solução rápida: baixe o `KFAI-Instalador.exe`
(dá dois cliques, sem depender da política) **ou** rode `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` e abra o PowerShell de novo.

**Recebo erro 401/403 (não autorizado) ao usar o roteador?**
Isso é problema de configuração, não de limite — o roteador **não** faz fallback
para 400/401/403/404 de propósito. Confira sua chave no `router.conf` (a
`SUA_CHAVE_AQUI` foi preenchida?), o provedor e o modelo no config do opencode.

**Recebo 429 (rate limit) e a resposta trava?**
O 429 é o caso normal de fallback: o roteador espera o `KFAI_COOLDOWN_SEC`
(60s) e tenta o próximo uplink da lista. Se **todos** estiverem em 429, aguarde
ou troque de combo (ex.: `cloud-plus-local` para cair no Ollama local).

**Meu PC é fraco, dá para usar?**
Sim — use o combo **Full Cloud** (só nuvem gratuita, sem IA local). O instalador
detecta o hardware e o launcher só tenta subir o Ollama se a máquina aguentar.

**O agente local "esquece" o meio da tarefa / tool call falha?**
Contexto curto. O KFAI já configura `num_ctx 65536` (modelo `-64k`). Veja a seção
"IA local com contexto que funciona" acima.

**Como deixo tudo sempre ligado?** `.\kfai-start.ps1 -Register` (reverter: `-Unregister`).

**Nada funciona e não sei por onde começar?** Rode `.\kfai-start.ps1 -Status`
— mostra as portas, caminhos encontrados e se o PC é compatível com IA local.

**Tenho outra dúvida?** Abra uma [issue](https://github.com/johnsalviano/kfai/issues)
— ajudamos e o FAQ cresce com você.

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

### 📜 Regras da doação (proteção contra golpes)

Para a segurança de todos, leia antes de doar:

- **A doação é voluntária e irrevogável.** Ela **não** é uma compra: você não
  recebe produto nem serviço em troca, então **não existe "reembolso por
  arrependimento"** — é o mesmo entendimento do Banco Central para doações via
  Pix. Antes de confirmar, reflita: **só doe se for de verdade mesmo.**
- **Devolução só em caso de fraude ou falha operacional**, e **sempre pelo
  caminho oficial**: abrindo o **MED (Mecanismo Especial de Devolução)** no
  **seu banco**, em até 80 dias da transação. Não peça devolução diretamente ao
  projeto e nem o projeto devolve direto — quem decide é o circuito bancário
  oficial, com análise e provas.
- **Golpe do "Pix por engano":** alguns golpistas enviam um Pix, depois
  procuram o dono da chave pedindo devolução para **outra** conta/chave e ainda
  acionam o MED, tentando receber duas vezes. **Nunca devolva dinheiro por fora
  de um Pix que você não conhece** — qualquer devolução deve seguir o fluxo do
  seu banco, para a **mesma** chave de origem.
- **O projeto nunca pede seus dados nem cobra nada** além da doação voluntária.
  Desconfie de qualquer "suporte" ou "falso doador" pedindo confirmação,
  senha ou um "Pix de garantia" — isso é golpe, ignore e denuncie.

## 🔐 Segurança

O KFAI **não inclui, lê nem compartilha** chaves, tokens ou dados pessoais de
ninguém. Toda credencial nasce como `SUA_CHAVE_AQUI` para você preencher — e os
valores reais ficam apenas na sua máquina, nunca neste repositório.

O instalador se autoprotege contra cópias adulteradas:

- só executa se vier do repositório oficial (`github.com/johnsalviano/kfai`);
- se o remote não for o oficial, **para** imediatamente (sinal de cópia adulterada);
- se **não houver remote** (ZIP, executável ou cópia repassada por terceiros),
  **avisa e pede confirmação** antes de continuar — você confirma que baixou do
  repositório oficial e confere o hash abaixo;
- no final, mostra o **SHA-256 do próprio instalador** para você conferir contra o
  valor publicado abaixo (mantido atualizado a cada versão);
- **verifica a integridade de cada download**: o Node.js é conferido contra o
  `SHASUMS256.txt` oficial da nodejs.org e o OpenCode Desktop contra o digest
  publicado pelo próprio GitHub; se o hash não conferir, a instalação é abortada.

O roteador próprio também se protege contra abuso:

- recusa requests com `Origin` de sites externos (uma página maliciosa que você
  visite **não** consegue usar as suas chaves de IA pelo navegador);
- opcionalmente exige `KFAI_ROUTER_TOKEN` para bloquear qualquer processo local
  que não conheça o token.

> **Hash do `install.ps1` atual (confira antes de rodar):**<br>
> `138BDA47546FE389E98887A5B44885EA70B62ABE4C3C495BDD647BF00B1BDCEA`<br>
> *(o próprio script imprime o mesmo valor no final da instalação — se divergir,
> o arquivo pode ter sido adulterado e **não** deve ser executado)*

> **Hash do `KFAI-Instalador.exe` atual (confira antes de rodar):**<br>
> `3C0142A100547FFF4A80DD910B00385C9B3BD0304E10A7E0E8958F4D01FD7A2C`<br>
> *(se você baixou o executável, confira **este** valor — o executável imprime o
> hash do `.exe` no final, não o do script)*

## 📺 Material para aprender mais

Documentação oficial das ferramentas (sempre confira nelas antes de qualquer
tutorial de terceiros — evita phishing):

| Ferramenta | Documentação oficial |
|---|---|
| Ollama (IA local) | https://docs.ollama.com · integração com opencode: https://docs.ollama.com/integrations/opencode |
| Opencode (agente no terminal) | https://opencode.ai/docs |
| AionUi (app gráfico) | https://github.com/iOfficeAI/AionUi/wiki |
| 9Router (gateway de nuvem) | https://github.com/decolua/9router |

Vídeos citados nos próprios READMEs oficiais (fonte verificável, baixo risco):

- Julian Goldie SEO — *"Hermes + Aion UI is Insane (FREE!)"*: https://www.youtube.com/watch?v=vWxE6VO9TKo
- WorldofAI — review do AionUi: https://www.youtube.com/watch?v=yUU5E-U5B3M
- CodeVerse Soban — *"Claude CLI Free Setup with 9Router"*: https://www.youtube.com/@CodeVerseSoban

> ⚠️ **Phishing:** gere chaves de IA **sempre** nos sites oficiais dos provedores
> e cole-as você mesmo no painel do 9Router (`http://localhost:20128/dashboard`).
> Nenhum site "agregador de API grátis" ou tutorial que peça suas chaves é
> confiável.

## Licença

Veja [docs/CREDITOS.md](docs/CREDITOS.md) para atribuição das ferramentas. O kit
em si (documentação, skills, scripts, configuração) é distribuído sob MIT.

---

**Quer ajudar?** Veja o [CONTRIBUTING.md](CONTRIBUTING.md) — tem como contribuir
sem saber programar.