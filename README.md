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