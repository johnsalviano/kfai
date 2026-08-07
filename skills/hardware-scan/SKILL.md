---
name: hardware-scan
description: Leitura do hardware real do computador (CPU, RAM, GPU, disco, placa-mãe) e sugestões de otimização baseadas no que a pessoa tem. Use quando quiser saber as especificações do PC da pessoa, identificar gargalos, decidir se o PC aguenta IA local, ou sugerir melhorias de desempenho conforme o hardware.
---

# Skill: Hardware Scan

Lê o hardware real do computador e sugere otimizações baseadas no que existe.
Também decide se o PC da pessoa consegue rodar IA local (e qual modelo).

## Passos
1. Rode o script de varredura:
   ```powershell
   .\scripts\scan.ps1
   ```
2. Leia a saída (RAM total, CPU, GPU + VRAM, disco livre/tipo).
3. Classifique o computador:
   - **Fraco**: RAM <= 3GB → não rodar IA local; usar Full Cloud.
   - **Básico**: 4-7GB → qwen2.5:1.5b / llama3.2:1b.
   - **Médio**: 8-15GB → qwen2.5:3b / llama3.2:3b.
   - **Bom**: 16GB+ e GPU >= 4GB VRAM → qwen2.5:7b / llama3.2:8b.
   - **Forte**: 32GB+ → qwen2.5:14b+.
4. Dialogue com a pessoa:
   - Se o objetivo é usar agentes de IA, diga se o PC aguenta local e indique o combo.
   - Aponte possíveis gargalos (ex.: disco rígido HDD lento) e skills de melhoria.

## Regras de leitura
- Só leitura, não altera nada no sistema.
- Não mostrar valores sensíveis (serial de placa, etc.) além do necessário.
- Explicar em português simples, sem jargão.

## Scripts
- `scripts/scan.ps1` — mapeia CPU/RAM/GPU/disco via WMI/CIM (PowerShell nativo).