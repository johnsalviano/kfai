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
- `install.ps1` — instalador guiado (pt-BR), detecta hardware, escolhe modelo local.
- `config/opencode/` — 3 combos: `full-cloud.json`, `cloud-plus-local.json`, `full-local.json`.
- `skills/<nome>/SKILL.md` — cada skill tem um manual + scripts.
- `docs/` — CREDITOS, O-QUE-E-KFAI, GUIA-CONFIGURACAO, GUIA-CHAVES-GRATIS.

## Tom
- Português brasileiro, simples e acolhedor. Explicar conceito antes do termo técnico.
- KFAI é curador; as ferramentas (Ollama/9Router/Opencode/AionUi) são de terceiros.

## Verificação
- Sintaxe de scripts PowerShell: usar `[System.Management.Automation.PSParser]::Tokenize`.
- Sem testes de framework; cada skill deixa ao menos um check executável.