---
name: rede
description: Teste e melhoria de rede - velocidade de internet, latencia/ping, configuracao de DNS, e dicas para melhor conexao. Use quando a pessoa reclamar de internet lenta, cair conexao, lag em jogos/video ou quiser descobrir o melhor servidor/DNS.
---

# Skill: Rede

Diagnostica e melhora a rede/internet do computador. So leitura e sugestoes
seguras; mudancas de DNS sao opcionais e explicadas.

## Passos
1. **Teste de velocidade** — indique a pessoa usar o site de teste do proprio
   provedor ou https://fast.com (gratis, sem app).
2. **Ping/estabilidade** — script `scripts/testar-ping.ps1` verifica ping e
   perda de pacotes para dois servidores (nacional e internacional).
3. **DNS** — `scripts/testar-dns.ps1` compara tempo de resposta de DNS comum
   (Google 8.8.8.8, Cloudflare 1.1.1.1, e o do provedor). Mudar o DNS e
   **opcional** e so com o acordo do usuario. Explicar: DNS rapido pode
   acelerar o "abrir pagina".
4. **Eicos simples**:
   - testar cabo vs WiFi (cabo mais estavel);
   - aproximar o roteador / evitar barreiras;
   - usar banda de 5GHz quando possivel;
   - reiniciar modem roteador 30s (desligar, esperar, religar) resolve muitos casos.
5. **Contexto do jogo** (ex.: Ragnarok/discord): manter ping baixo e sem
   "jitter". Mostrar cabos e DNS no que ajuda.

## Regras
- Nao mexer em configuracao de roteador sem instrucao explicita e com cuidado.
- Explicar termos (ping = tempo de ida e volta; latencia = demora).
- Nunca prometer velocidade maior do que o plano contratado.

## Scripts
- `scripts/teste-ping.ps1` — ping + perda p/ Google e Cloudflare.
- `scripts/testar-dns.ps1` — tempo de resposta de DNS conhecidos.