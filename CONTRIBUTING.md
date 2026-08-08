# Contribuindo — KFAI (Kit de Ferramentas de Agente de IA)

Obrigado por querer ajudar! O KFAI é um projeto **open source, gratuito e feito
no tempo livre** — toda contribuição conta. Este guia mostra as formas de
ajudar e as regras para manter tudo organizado.

---

## 🛡️ Regra de ouro: nunca versionar dados sensíveis

**NÃO commite** chaves/API keys, tokens, senhas, certificados, e-mails,
telefones, documentos com dados pessoais, machine-id ou histórico de uso com
identificação. Nem em texto de commit.

- Chaves vão para variáveis de ambiente ou `router.conf` (que está no
  `.gitignore`). Em arquivos compartilhados, use `SUA_CHAVE_AQUI`.
- Se algo com segredo aparecer no `git status`, **não** commite.

## 🐛 Reportando bugs

1. Pesquise nas [issues](https://github.com/johnsalviano/kfai/issues) se já não
   existe (para não duplicar).
2. Abra a issue com:
   - **Passos** para reproduzir;
   - **O que esperava** vs. **o que aconteceu**;
   - **Ambiente** (Windows 10/11, RAM, GPU se houver);
   - Log do roteador, se aplicável (`logs/router.log`).

## 🚀 Propondo melhorias

Abra uma issue descrevendo a ideia antes de codar — assim alinhamos o rumo e
evitamos retrabalho. Issue de melhoria pronta é ótima; PR direto também é bem-vindo.

## 📝 Contribuindo com código

### Fluxo sugerido

1. **Fork** o repositório e clone localmente.
2. Crie um branch descritivo: `git checkout -b melhoria/descricao-curta`.
3. Faça as mudanças **com foco** (1 assunto por PR).
4. Teste o que alterou:
   - Scripts PowerShell: rode com `-WhatIf` quando possível; confira a sintaxe.
   - `router.py`: `py -3.14 -m py_compile router.py`.
5. Commit com mensagem clara em **pt-BR** descrevendo o **porquê**.
6. Abra o **Pull Request** para `main` explicando a mudança e como testou.

### Estilo

- Siga o estilo dos arquivos existentes (PowerShell/ Python simples e legível).
- **Sem comentários desnecessários** no código — prefira nomes claros.
- Não quebre a compatibilidade com os combos atuais (full-cloud / cloud-plus-local / full-local).

## 📚 Contribuindo com documentação

Erros de digitação, seções confusas ou falta de exemplos ajudam tanto quanto
código. Edite os `.md` direto (leia antes para manter o tom e o formato).

## 🌐 Traduções

Os READMEs são mantidos em **pt-BR** (principal) e **en** (`README.en.md`).
Para novos docs, comece em pt-BR; se quiser traduzir, crie `NOME.en.md` e linke
no `README.en.md`.

## 💬 Comunidade e divulgação

- Dê uma ⭐ no repositório;
- Responda dúvidas de quem está começando;
- Compartilhe o projeto com alguém que possa aproveitar.

---

O KFAI é **100% gratuito e sem anúncios**. Se quiser apoiar financeiramente,
veja a seção **Apoie o projeto** no [README](README.md).
