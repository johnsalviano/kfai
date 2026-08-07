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
  a chamada segue para o próximo da lista.
- **Cooldown (circuit breaker)**: um uplink que falhou (429, 401, 5xx, timeout)
  fica em quarentena e é pulado nas próximas chamadas (`KFAI_COOLDOWN_SEC`, padrão 60s).
- **Modo `auto`**: heurística determinística (sem custo de LLM) para escolher
  `full` vs `eco` por request — complexidade do prompt, presença de tools e tamanho.
- **Compressão de saída de ferramentas**: saídas longas de `tool` (logs, git, etc.)
  são colapsadas (linhas repetidas omitidas) e truncadas para caber no contexto.
- **Cache em memória**: chamadas repetidas idênticas (non-stream) respondem
  instantaneamente sem reprocessar (`KFAI_CACHE_SEC` 300s, até `KFAI_CACHE_MAX` 200).
- **Log JSONL**: cada request registrado em `logs/router.log` (rota, uplink, modo,
  cache, bytes, tempo). Variáveis: `KFAI_LOG_FILE`, `KFAI_ROUTER_PORT`.

## Ligar só quando usar (sem processo sempre rodando)

Por padrão, nada fica rodando ocioso. O launcher liga router + Ollama **quando
você abre o agente** e desliga quando você o fecha:

```powershell
.\kfai-launch.ps1 -App aionui      # abre o AionUi
.\kfai-launch.ps1 -App opencode    # abre o opencode no terminal
.\kfai-launch.ps1 -App hermes      # abre o Hermes
.\kfai-launch.ps1 -App "C:\caminho\app.exe"   # qualquer executavel
```

**Usa o 9Router (porta 20128)?** Adicione `-With9Router` para ele subir junto
somente enquanto o agente estiver aberto — em vez de ficar rodando o dia todo:

```powershell
.\kfai-launch.ps1 -App aionui -With9Router   # abre AionUi + router + ollama + 9Router
.\kfai-launch.ps1 -App opencode -With9Router
```

O 9Router sobe **sem bandeja e sem janela** (via `cli.js -n`), e o `-Stop`
mata a árvore inteira (CLI + servidor Next). Sem a flag, o launcher não mexe
no 9Router — ideal para quem prefere deixá-lo sempre ligado no login (o
`9router.vbs` na pasta Inicializar). O status mostra as 3 portas
(`kfai-start.ps1 -Status`).

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