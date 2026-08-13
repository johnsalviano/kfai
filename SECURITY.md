# Segurança do KFAI

O KFAI leva a segurança a sério. Este documento explica como o projeto se
protege e como reportar problemas de segurança com responsabilidade.

## Como o KFAI protege você

- **Nenhuma chave é armazenada ou enviada pelo projeto.** Todo valor real de
  API key começa como `SUA_CHAVE_AQUI` / `YOUR_KEY_HERE` e fica apenas na sua
  máquina (no 9Router ou em variáveis de ambiente locais).
- **`.gitignore` bloqueia segredos**: `router.conf`, `*.db`, `*.log`, `*.lnk`,
  o instalador `.exe` e `backups/aionui-backend.db` nunca entram no repositório.
- **O roteador é local**: ouve apenas em `127.0.0.1` (porta 20129) e recusa
  requests com `Origin` de sites externos, impedindo que uma página maliciosa
  use suas chaves pelo navegador. Pode exigir um token (`KFAI_ROUTER_TOKEN`)
  contra malware local.
- **Downloads verificados por hash**: o instalador confere o SHA-256 de cada
  download oficial (Node via `SHASUMS256.txt`, OpenCode via digest do GitHub)
  e aborta a instalação se o hash não conferir.
- **O próprio instalador é verificado**: ele imprime o próprio SHA-256 no final
  para você conferir contra o valor publicado no release.

## Reportando problemas de segurança

Encontrou uma falha de segurança? **Não abra uma issue pública.**

1. Envie um e-mail para o mantenedor (veja o perfil em
   https://github.com/johnsalviano) ou abra um **security advisory privado**
   em https://github.com/johnsalviano/kfai/security/advisories/new.
2. Inclua: o que aconteceu, como reproduzir, versão afetada e o impacto
   estimado. Não inclua chaves reais ou dados pessoais.
3. Você terá resposta em até 72h. Divulgação pública após a correção.

## Área de superfície

| Componente | Confia em quê |
|---|---|
| `router.py` (porta 20129) | só localhost; valida `Origin`; opcionalmente exige `KFAI_ROUTER_TOKEN`; limite de corpo `KFAI_MAX_BODY_BYTES`; chave sanitizada no header |
| `9Router` (porta 20128) | chaves ficam no banco local do app |
| `Ollama` (porta 11434) | serviço local |
| `install.ps1` | verifica origem (remote oficial), verifica hash próprio e dos downloads |
| `kfai-config-chaves.ps1` | sem `-Adicionar`: leitura somente-leitura do banco do 9Router, sem expor segredos; com `-Adicionar`: envia a chave digitada apenas para a API local do 9Router (`localhost:20128`), nunca grava em arquivo |

## Suporte

Questões de uso → abra uma issue normal com o template de *bug report*.
