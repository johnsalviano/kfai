# AGENTS.md — KFAI (Kit de Ferramentas de Agente de IA)

Notas para agentes de IA que trabalham neste repositório.

## Regras de segurança (IMPORTANTE - não quebrar)
- **NUNCA** incluir, ler ou exportar chaves, tokens, API keys, cookies, e-mails
  ou dados pessoais. Nem do autor, nem de usuários.
- Tudo que é credencial nasce como placeholder `SUA_CHAVE_AQUI` ou variável de
  ambiente `{env:...}`. Manter esse padrão.
- Combos copiados de uma instalação real do 9Router = **só a estrutura**
  (nomes de combos e IDs de modelo), nunca as colunas `data`/`apiKeys`/`email`.

## Estrutura
Executáveis na ordem de uso (o número é a sequência):
- `01-install.ps1` — instalador guiado (pt-BR), detecta hardware, escolhe modelo local.
  Com `-Atualizar` sobe de versão no lugar (Ollama/opencode/9Router/AionUi), nunca duplica.
  Com `-Limpo` remove a config antiga do KFAI e configura do zero (mantém chaves e modelos).
  (versão compilada: `KFAI-Instalador.exe`, gerado por `build/build-instalador.ps1`).
- `02-kfai-config-chaves.ps1` — assistente de chaves gratuitas (salva direto no 9Router).
- `03-kfai-config-provider-nodes.ps1` — provedores fora do catálogo do 9Router (opcional).
- `04-kfai-aionui-combos.ps1` — aplica os combos no AionUi (opcional).
- `05-kfai-start.ps1` — liga/desliga roteador + 9Router + Ollama (ou `-Register` no login).
- `06-kfai-launch.ps1` — abre o agente (opencode/aionui/hermes) com os serviços certos.
- `07-KFAI-Abrir-Opencode.vbs` e `08-KFAI-Abrir-AionUi.vbs` — atalhos de dois cliques.
- `09-kfai-desinstalar.ps1` — desinstalador guiado: para serviços, tira autostart,
  restaura a config do opencode e oferece desinstalar cada app (`-SoKfai` só config,
  `-Tudo` desinstala tudo, `-Limpo` apaga também backups, temporários, 9router-src,
  modelos do Ollama, dados do AionUi e a própria pasta).

Outros:
- `config/opencode/` — 3 combos: `full-cloud.json`, `cloud-plus-local.json`, `full-local.json`.
- `skills/<nome>/SKILL.md` — cada skill tem um manual + scripts.
- `docs/` — CREDITOS, O-QUE-E-KFAI, GUIA-CONFIGURACAO, GUIA-CHAVES-GRATIS,
  PROMPT-RODAR-TUDO-OPENCODE.

## Tom
- Português brasileiro, simples e acolhedor. Explicar conceito antes do termo técnico.
- KFAI é curador; as ferramentas (Ollama/9Router/Opencode/AionUi) são de terceiros.

## Verificação
- Sintaxe de scripts PowerShell: usar `[System.Management.Automation.PSParser]::Tokenize`.
- Sem testes de framework; cada skill deixa ao menos um check executável.