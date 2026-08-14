# KFAI — Passo a passo (instalar e usar)

Kit **v0.2.0** · Guia simples começando do zero. Tudo grátis.

## Parte 1 — Instalar

1. **Extraia a pasta** do arquivo baixado para qualquer lugar (ex.: `C:\KFAI`).
2. **Dê dois cliques em `KFAI-Instalador.exe`**.
3. Se pedir confirmação da origem (`johnsalviano/kfai`), responda **s**.
4. Aguarde. O instalador baixa e instala tudo sozinho **na versão mais recente**:
   Node.js, Ollama, a linha de comando do opencode, o 9Router, o OpenCode
   Desktop e o AionUi.
5. Terminou quando a tela mostrar **Integridade (SHA-256)**.

> Quer ver tudo que será executado antes? Rode o script no PowerShell em vez do
> `.exe`: `.\01-install.ps1` (abaixo). O resultado é o mesmo.

> Atalho oficial: `ollama launch opencode` já configura o opencode com o Ollama
> local sozinho, sem mexer na sua config. Veja os docs em
> https://docs.ollama.com/integrations/opencode.

## Parte 2 — Adicionar suas chaves gratuitas

Os combos de nuvem (Full Cloud) precisam de pelo menos uma chave gratuita.

1. Abra o **PowerShell** na pasta extraída.
2. Rode o assistente de chaves:

   ```powershell
   .\02-kfai-config-chaves.ps1
   ```

3. Ele mostra **quais chaves faltam** e abre o site de cada fornecedor. Gere a
   chave de graça e rode o fluxo automático para salvá-la:

   ```powershell
   .\02-kfai-config-chaves.ps1 -Adicionar
   ```

   (alternativa manual: colar a chave no 9Router, painel em
   `http://localhost:20128/dashboard` → conexões).
4. Volte ao assistente e confirme; ele só sai quando estiver tudo certo.

> O 9Router guarda as suas chaves num banco local. O KFAI não copia nem
> envia nada — ele só pede ao 9Router para responder com as suas chaves.

## Parte 3 — Usar os agentes

Escolha o **combo** (modo de uso) na primeira conversa com o agente:

| Você quer | Combo |
|---|---|
| IAs gratuitas na nuvem (PCs sem suporte local) | `kfai/full-cloud` |
| Nuvem primeiro, seu PC como reserva (padrão) | `kfai/cloud-plus-local` |
| 100% offline (requer PC capaz) | `kfai/full-local` |

### No terminal (Opencode)

1. Abra um terminal na pasta e rode:

   ```powershell
   .\06-kfai-launch.ps1
   ```

2. Quando o agente perguntar qual modelo, escolha um dos combos acima.

### No aplicativo gráfico (AionUi)

1. No app, abra o terminal interno e rode:

   ```powershell
   .\04-kfai-aionui-combos.ps1
   ```

2. Esse script adiciona o provider **KFAI Router** com os três combos e remove
   os perfis pagos. Escolha o combo ao iniciar.

## Dicas

- PC **básico** (menos de 3 GB de RAM): use `full-cloud`, não force IA local.
- **Atualizar tudo** que já estiver instalado sem duplicar: `.\01-install.ps1 -Atualizar`.
- **Config quebrada**: `.\01-install.ps1 -Limpo` (configura do zero, mantém chaves e modelos).
- **Desinstalar**: `.\09-kfai-desinstalar.ps1` (pergunta antes de cada coisa);
  `.\09-kfai-desinstalar.ps1 -Limpo` para remoção **limpa** (apaga tudo, até a pasta).
- Suas chaves ficam **só na sua máquina**. Não compartilhe e não envie arquivos
  de configuração para ninguém.
- Guias detalhados: `docs\GUIA-CHAVES-GRATIS.md` (todas as chaves grátis) e
  `docs\GUIA-CONFIGURACAO.md` (ajuste fino).