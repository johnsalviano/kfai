---
name: tarefas
description: Guia para usar o agente de IA em tarefas do dia a dia - escrita, planilhas, estudos, organizacao, respostas. Mostra como pedir bem (prompt), escolher o combo certo e onde encontrar modelos prontos. Use quando a pessoa quiser usar a IA para achar/trabalhar em algo concreto do cotidiano e nao souber por onde comecar.
---

# Skill: Tarefas do dia a dia com o agente

Este kit entrega um agente de IA que ja esta funcionando; esta skill ensina a
tirar proveito dele para tarefas reais, do jeito simples.

## Como usar o agente
- Abra o **Opencode** (terminal) ou **AionUi** (interface grafica) no projeto/pasta certa.
- Fale em **portugues simples** o que quer. Exemplos:
  - "Escreva um texto de 200 palavras sobre X."
  - "Monte uma planilha com a lista de despesas que tiver aqui."
  - "Faça um resumo deste arquivo."

## Dicas de pergunta boa (prompt)
1. Seja claro: diga o **resultado** que quer ("uma tabela", "um texto", "um roteiro").
2. Diga o **publico/tom** ("simples, para iniciantes", "formal").
3. Para tarefas maiores, **quebre em passos**: comece pedindo o "esboco" do que
   depois detalhar.
4. Se der resposta confusa, reformule ou peca "em outras palavras".

## Escolhendo o combo
| Tipo de tarefa | Combo sugerido |
|---|---|
| rapida, resposta de texto | Full Cloud (mais velocidade na nuvem) |
| trabalho longo continuo | Cloud + Local (reserva pro PC quando nuvem acaba) |
| privacidade / sem internet | Full Local |

## Modelos prontos / inspiração
- Veja a lista de modelos gratis em `skills/ia-gratis/scripts/modelos-gratis.ps1`.
- Para gerar documentos Office (Word/Excel/PowerPoint), o kit usa as skills
  `officecli-*` (se presentes) — veja `docs/GUIA-CONFIGURACAO.md`.

## Regras
- Nao inventar que o agente faz algo que nao faz (ex.: sem internet, nao busca
  "ao vivo" - so com chave e config). Ser honesto sobre limite.
- A decisão é sempre do usuário; a IA apoia e revisa.