# Prompt: rodar o KFAI inteiro de dentro do opencode

Copie e cole o bloco abaixo em qualquer conversa do opencode dentro da pasta do
projeto (`C:\Users\johns\projetos\kfai` — ou o caminho onde o repositório foi
extraído na máquina do usuário).

---

Você está na raiz do repositório **KFAI** (`johnsalviano/kfai`). Este pacote
instala e configura um kit completo de IA local + nuvem (Ollama, opencode,
AionUi, roteador KFAI e o 9Router) em um PC Windows.

Execute **todos** os passos abaixo, **na ordem**, a partir desta pasta
(`.\<nome-do-script>`), usando PowerShell.

**Regras de segurança (obrigatórias):**
- NUNCA mostre, grave em arquivo, nem commit chaves de API. A chave digitada
  pelo usuário vai direto para o 9Router pela API local (`localhost:20128`).
- Se algo falhar, PARE, mostre o erro e pergunte ao usuário como seguir. Não
  continue pulando etapas.
- Não altere arquivos fora do repositório além do que os próprios scripts
  fazem (instalação de programas, registro do Windows etc. é esperado).

**Passo 1 — Instalar o kit:**
```
.\01-install.ps1
```
- Rode e aguarde terminar. Ele detecta o hardware, escolhe o modelo certo e
  baixa as ferramentas.
- Se o usuário já tiver o Ollama instalado e não quiser reinstalar, use:
```
.\01-install.ps1 -SkipOllama
```

**Passo 2 — Configurar as chaves grátis (pedir ao usuário):**
```
.\02-kfai-config-chaves.ps1 -Adicionar
```
- Antes de rodar, pergunte ao usuário se ele já tem as chaves dos provedores
  que o kit usa (ex.: OpenRouter, Google/Gemini, Groq, Cerebras, etc.).
- As chaves são coladas pelo usuário no terminal, uma por vez. NUNCA colha,
  mostre ou salve essas chaves você mesmo.
- Se ele não tiver nenhuma, rode apenas:
```
.\02-kfai-config-chaves.ps1
```
  para ver o estado, e pergunte se quer abrir os sites de cadastro
  (`. -Open`).

**Passo 3 — (Opcional) Provedores personalizados:**
- Só faça este passo se o usuário tiver URLs/endpoints de provedores
  personalizados (ex.: empresas, servidores próprios).
- Caso contrário, pule.
```
.\03-kfai-config-provider-nodes.ps1
```

**Passo 4 — (Opcional) Combos para o AionUi:**
- Só faça se o usuário usar o **AionUi** (app gráfico). Pergunte antes.
```
.\04-kfai-aionui-combos.ps1
```

**Passo 5 — Ligar os serviços:**
```
.\05-kfai-start.ps1
```
- Confirme no final que o roteador (porta 20033), o 9Router (20128) e o
  Ollama (11434) estão de pé.
- Pergunte ao usuário se ele quer que tudo ligue sozinho ao iniciar o Windows;
  se sim:
```
.\05-kfai-start.ps1 -Register
```

**Passo 6 — Abrir o agente:**
```
.\06-kfai-launch.ps1 -App opencode
```
- Pode também abrir o AionUi (`-App aionui`), se ele preferir.

**Ao final, resuma em tópicos curtos o que foi instalado/configurado**, o que
ficou opcional/pulado, e diga os próximos passos (onde fica a documentação e
como usar os atalhos `07-KFAI-Abrir-Opencode.vbs` / `08-KFAI-Abrir-AionUi.vbs`).
