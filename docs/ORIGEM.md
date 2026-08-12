# Como nasceu o KFAI

## A motivação

Em 2024-2025, usar agentes de IA no dia a dia exigia escolher um lado:

| Se você queria... | O caminho era... |
|---|---|
| IA **local** (privacidade, offline, sem custo por token) | Instalar Ollama, baixar modelo certo pro seu hardware, configurar `num_ctx`, criar `Modelfile`, editar `opencode.json` à mão, torcer pra não truncar contexto em 4096. |
| IA **na nuvem** (modelos maiores, mais rápido) | Criar conta em 5 provedores diferentes (OpenRouter, Gemini, NVIDIA, Cloudflare, Poolside...), gerar chave em cada site, guardar tudo num gerenciador de senhas, configurar variáveis de ambiente, e ainda lidar com cotas que acabam no meio da tarefa. |
| **As duas** juntas (nuvem primeiro, local de reserva) | Quase ninguém fazia. Era "ou um ou outro". |

O resultado: **a maioria desiste na configuração**. Não por falta de interesse, mas porque o caminho até "funcionar" tem 15 passos manuais, documentação espalhada em 6 sites, e nenhum instalador que faça tudo junto.

## O estalo

> "E se existisse **um único arquivo** que você baixa, clica, e 5 minutos depois tem: Node.js, Ollama, opencode, 9Router, OpenCode Desktop, AionUi, router local com fallback automático, combos prontos (nuvem / local / nuvem+local), e um assistente que te mostra **exatamente quais chaves faltam e abre o site de cada uma**?"

Foi isso que virou o KFAI.

## Princípios que guiaram (e ainda guiam)

1. **Zero chave no repositório** — suas chaves ficam no seu 9Router (banco local SQLite), nunca no git, nunca no instalador, nunca em log.
2. **Sempre versão mais recente oficial** — o instalador baixa Node.js, Ollama, opencode, AionUi direto dos sites/ GitHub oficiais no momento da execução. Nada empacotado velho.
3. **Detecta seu hardware e decide** — RAM, VRAM, CPU → escolhe o modelo local certo (hoje `qwen3:4b` pra 6GB VRAM, `qwen3:0.6b` pra PC fraco). Não precisa saber o que é "quantização" nem "context window".
4. **Fallback real** — o router KFAI (porta 20129) tenta o 9Router (nuvem, porta 20128); se der **qualquer erro** (429, 403, 500, timeout), cai pro Ollama local automaticamente. Não é "configure dois providers", é "uma rota, dois uplinks, ordem de prioridade".
5. **Tudo em pt-BR** — mensagens, docs, assistente de chaves, erros. A barreira do inglês atrapalha mais que a técnica.
6. **Instalador auditável** — é um `.ps1` (PowerShell) que você pode ler inteiro antes de rodar. O `.exe` é só conveniência pra quem tem `ExecutionPolicy` bloqueada; ele **é** o script compilado (ps2exe), sem ofuscação.
7. **Hash no final** — ao terminar, o instalador imprime o SHA-256 de si mesmo. Você confere com o publicado no GitHub. Se divergir, não rode.

## O que o KFAI **não** é

- Não é um "modelo de IA". É um **kit de ferramentas** que instala e configura as peças para você.
- Não hospeda nada. Tudo roda no **seu PC** (Ollama, router Python, 9Router) ou nos **seus provedores** (chaves que você gerou).
- Não cobra nada. MIT license. As ferramentas que ele instala são open source / free tier.

## Evolução rápida

| Versão | O que mudou |
|---|---|
| 0.1.0 | Primeira versão estável: instalador básico, combos, assistente de chaves, router Python. |
| 0.2.0 | Modelo padrão `qwen3` (tools + contexto 256K nativo), contexto 64k+ exigido pelo opencode, `KV_CACHE_TYPE=q8_0`, fallback 9Router→local em **qualquer** erro, versão visível no banner, docs oficiais + vídeos atestados, aviso anti-phishing. |

---

**Em resumo:** o KFAI nasceu da frustração de ver gente capaz desistir de usar IA local/nuvem porque a configuração era um labirinto. O objetivo é **tirar o labirinto** — você baixa, roda, escolhe o combo, cola as chaves que o assistente te mostra, e usa.