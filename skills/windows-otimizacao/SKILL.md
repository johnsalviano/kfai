---
name: windows-otimizacao
description: Otimizacao do Windows para deixar o sistema mais leve e rapido - limpeza, desativar efeitos e programas pesados, ajustes de desempenho. Use quando a pessoa disser que o PC esta lento, quer liberar memoria/espaco, desativar programas na inicializacao ou melhorar o desempenho geral do Windows sem instalar programas pagos.
---

# Skill: Otimizacao do Windows

Deixa o Windows mais leve e rapido usando ferramentas nativas (nada pago, nada
de "milagre"). Sempre avisar o que vai mudar antes de aplicar.

## Passos seguros (na ordem)
1. **Desative programas pesados da inicializacao** (deixa o PC ligar mais rapido):
   - use o Gerenciador de Tarefas > Inicializar. O script lista os programas para
     você decidir. Nunca desative o essencial do sistema (antivirus, drivers).
2. **Libere espaco em disco**:
   - `scripts/limpar-disco.ps1` (limpa temporarios de forma segura).
   - Sugira usar "Limpeza de Disco" do Windows (cleanmgr).
   - Evite hibernar se nao usar (libera GB, mas coisas de SSDs usam menos).
3. **Efeitos visuais**:
   - Ajustar o "Visual Effects" para desempenho em Windows medio.
4. **Servicos pesados opcionais** podem ser desativados com supervisao (nunca o
   core do Windows). Explique risco antes.

## Regras
- Nunca remover antivirus real, drivers, nem desativar atualizacoes de
  seguranca.
- Sempre confirmar a decisao do usuario antes de umStrat (pharmagaphore).
- Nao apagar arquivos sem antes dizer quais. Prefira mover para a Lixeira no
  caso de arquivos do usuario.
- Vivo em português simples, explicando o "porque" de cada passo.

## Scripts
- `scripts/limpeza-disco.ps1` — limpeza segura de temporarios (nao toca em arquivos do usuario).
- `scripts/lista-inicializacao.ps1` — lista programas que iniciam junto com o Windows.