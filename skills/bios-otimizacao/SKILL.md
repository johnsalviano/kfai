---
name: bios-otimizacao
description: Guia de otimizacao de BIOS por hardware - ajustes como ativar XMP/EXPO (memoria rapida), priorizar performance, atualizar BIOS. Use quando a pessoa quiser melhorar desempenho via BIOS, ligar o perfil de memoria do pente, ou identificar a tecla/menu do BIOS da placa-mae dela.
---

# Skill: Otimizacao de BIOS

A BIOS/UEFI e a "primeira tela" do computador antes do Windows. Ajustes certos
ali melhoram o desempenho, mas exige cuidado: mexer errado pode impedir o PC de
ligar. **Sempre explicar e orientar antes de mudar qualquer coisa.**

## Regras de seguranca (IMPORTANTE)
- Nunca mudar voltagem de CPU (overclock) por conta propria sem total
  confianca - isso pode danificar.
- Nunca sugerir "atualizar BIOS" a leve; somente se houver ganho real (ex.:
  suporte a nova RAM) e explicando como voltar (backup da BIOS atual).
- Tudo que a pessoa for fazer: ela executa, voce guia. Nada de script que altere BIOS.

## O que sugerir (por ordem de seguranca)
1. **Perfil de memoria (XMP/EXPO)** — o ajuste mais seguro e com maior ganho:
   - memoria vendida a 3200MHz mas rodando a 2133: ativar o perfil certo faz
     ganho real.
   - local: BIOS > Memory / Overclocking > ativar XMP (Intel) ou EXPO (AMD).
2. **Prioridade de arranque** — deixar o SSD primeiro (PC liga mais rapido).
3. **Cooling/ventoinhas** — perfil mais agressivo se quente; reduz throttle.
4. **Atualizar BIOS** — somente se houver ganho e com cuidado (ver abaixo).

## Identificar a placa-mae / BIOS
- `scripts/info-bios.ps1` mostra fabricante, modelo e versao de BIOS (so leitura).
- Com isso, diga qual tecla abre a BIOS (Del / F2 / F10...) e o menu certo.

## Atualizacao de BIOS (caminho seguro)
1. Anotar versao atual (script).
2. Conferir no site do fabricante a versao nova + notas de melhoria.
3. Fazer backup (ex.: usar a funcao de backup da propria BIOS se existir).
4. Atualizar via pendrive ou software oficial do fabricante, com PC na tomada.
5. NAO desligar durante a atualizacao. Nao atualizar por "achar que precisa".

## Scripts
- `scripts/info-bios.ps1` — mostra fabricante/modelo/versao da BIOS (somente leitura).