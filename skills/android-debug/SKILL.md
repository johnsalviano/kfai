---
name: android-debug
description: Depuracao e otimizacao de sistemas Android (celular ou via emulador). Usa ADB para limpar apps pesados, ver uso de bateria, desativar coisas desnecessarias e diagnosticar lentidao. Use quando a pessoa quiser deixar o celular Android mais rapido, saber o que esta travando/consumindo bateria, ou configurar um emulador/iPhone sem baixar emulador.
---

# Skill: Android Debug (depuracao)

Otimiza e diagnostica dispositivos Android usando ADB (Android Debug Bridge).
Funciona em celular real, emulador (se ja instalado) e tambem pode ajudar em
outros sistemas que usem ADB. **Este kit nao baixa emulador** - se a pessoa tem,
usamos; se nao tem, nao instalamos.

## Requisitos
- `adb` instalado (parte do Android Platform-Tools). Se faltar, o script avisa.
- No celular real: ativar "Depuracao USB" em Opcoes do desenvolvedor e conectar por USB.

## Passos
1. Confira se o aparelho esta conectado: `adb devices` (deve aparecer um serial "device").
2. Rode `scripts/diagnostico.ps1` — le a lista de apps, uso de bateria e
   processos (so leitura).
3. Sugira otimizacoes seguras:
   - desinstalar apps desconhecidos/que o usuario nao usa;
   - limpar cache de apps (dados do app, NAO apagar dados pessoais sem avisar);
   - desativar apps do sistema desnecessarios (bloatware) - apenas os seguros, com
     confirmacao, e mostrando como reativar.
4. Se for para bateria: ver Analise de bateria > usar melhor.

## Regras
- Nao desativar apps criticos do Android (telefone, SMS, configuracoes, Google
  Services). Explicar o risco de desativar bloat.
- Nunca apagar dados pessoais do usuario sem permissao clara.
- A ação é sempre do usuário; você guia. Nada de desbloqueio de bootloader/root
  sugerido à toa.

## Scripts
- `scripts/diagnostico.ps1` — relatorio (so leitura) de dispositivos, apps e uso.