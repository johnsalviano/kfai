# KFAI — Kit de Ferramentas de Agente de IA

**Agentes de IA gratuitos para quem não desiste.**

O KFAI reúne, configura e explica como usar ferramentas de IA **gratuitas**
(Ollama, 9Router, Opencode, AionUi) para realizar tarefas do dia a dia — e ainda
te ajuda a otimizar seu próprio computador para aproveitá-las melhor.

- 100% gratuito (ferramentas de código aberto)
- Roda em PC fraco: se sua máquina não aguentar IA local, você usa a nuvem
- Sem chaves de ninguém: você gera as suas, gratuitamente

## Como instalar

1. Baixe e instale [Ollama](https://ollama.com/download/windows) (opcional, só se quiser IA local).
2. Instale o [9Router](https://9router.com) e o [Opencode](https://opencode.ai).
3. Rode o instalador:

```powershell
.\install.ps1
```

Ele detecta o seu hardware (RAM, CPU, GPU), escolhe o modelo local certo e mostra
o caminho passo a passo.

## Combos disponíveis

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

O atalho do AionUi no menu Iniciar já aponta para o launcher (backup em
`backup-AionUi.lnk`). Para abrir um agente SEM launcher e mesmo assim ter os
serviços, ligue manualmente com `.\kfai-start.ps1`.

**Modo "sempre ligado" (opcional):** se preferir que tudo suba no login sem
abrir agente, rode `.\kfai-start.ps1 -Register` (e `-Unregister` para reverter).

## Documentação

- [O que é o KFAI](docs/O-QUE-E-KFAI.md)
- [Guia de configuração](docs/GUIA-CONFIGURACAO.md)
- [Guia de chaves gratuitas](docs/GUIA-CHAVES-GRATIS.md) — como gerar sua API key grátis de cada provedor
- [Créditos](docs/CREDITOS.md) — quem fez cada ferramenta

## Segurança

O KFAI não inclui, lê nem compartilha chaves, tokens ou dados pessoais de
ninguém. Toda credencial nasce como `SUA_CHAVE_AQUI` para você preencher.

O instalador se autoprotege contra cópias adulteradas:

- só executa se vier do repositório oficial (`github.com/johnsalviano/kfai`);
- no final, mostra o SHA-256 do próprio script para você conferir contra o
  valor publicado na página oficial do repositório.

## Licença

Veja [docs/CREDITOS.md](docs/CREDITOS.md) para atribuição das ferramentas. O kit
em si (documentação, skills, scripts, configuração) é distribuído sob MIT.