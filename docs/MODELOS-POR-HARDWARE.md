# Modelos por hardware — KFAI

Guia rápido para escolher o modelo local certo para a sua máquina. O instalador
**detecta o hardware e escolhe sozinho**, mas se você quiser trocar ou escolher
na mão, use esta tabela.

> Regra de bolso: o que pesa é a **RAM** para o modelo e a **VRAM da GPU** para
> rodar com qualidade. Mais VRAM = modelo maior = resposta melhor (e mais lenta).

## 🖥️ Seleção rápida

| Hardware | Modelo recomendado | Exemplo de comando | Observação |
|---|---|---|---|
| **PC fraco** (4–8 GB RAM, sem GPU) | não rode IA local | — | Use o combo **Full Cloud** |
| **8–16 GB RAM** (sem GPU ou integrada) | qwen3 4B | `ollama run qwen3:4b` | 2.5 GB, tools, 256K ctx |
| **16–32 GB RAM** | qwen3 8B | `ollama run qwen3:8b` | Bom equilíbrio (5.2 GB) |
| **GPU 6–8 GB VRAM** | qwen3 4B | `ollama run qwen3:4b` | Cabe folgado; 8B pode ficar apertado |
| **GPU 8–12 GB VRAM** | qwen3 8B | `ollama run qwen3:8b` | Fluido e boa qualidade |
| **GPU 12–16 GB VRAM** | qwen3 14B | `ollama run qwen3:14b` | Alta qualidade |
| **GPU 24+ GB VRAM** | qwen3 30B | `ollama run qwen3:30b` | Qualidade máxima |

## 🧠 Modelos recomendados por tarefa

| Tarefa | Modelo | Por quê |
|---|---|---|
| **Código** | `qwen3` / `qwen2.5-coder` (4b/8b/14b) | Tools + tool calling confiável |
| **Chat/geral** | `qwen3` (4b/8b/14b) | Equilibrado em conversa e raciocínio |
| **IA mais forte p/ raciocínio** | `qwen3` 30B / `deepseek-r1` (se a VRAM aguentar) | Raciocínio avançado, pesado |
| **Textos longos** | `qwen3:4b` (256K ctx nativo) | Não "esquece" o meio da tarefa |
| **Português** | modelos qwen/llama recentes | Boa fluência em pt-BR |

## ⚙️ Como trocar o modelo

1. Baixe o modelo: `ollama pull qwen3:8b`
2. No `router.conf`, aponte a rota local para o novo modelo (campo `model`).
3. Se for usar com o opencode, crie o derivado `-64k` (contexto estendido —
   os docs do opencode exigem 64k+):
   ```dockerfile
   FROM qwen3:8b
   PARAMETER num_ctx 65536
   ```
   ```powershell
   ollama create qwen3-8b-64k -f Modelfile
   ```
   e use o nome `qwen3-8b-64k` no `config/opencode/full-local.json`
   (campo `KFAI_LOCAL_MODEL`).

## 📉 Reduzindo o uso de memória

- Use modelos **menores** (qwen3:4b em vez de qwen3:8b);
- Use **quantizações** mais leves (ex.: `q4_K_M` já é padrão em muitos);
- Feche outros programas pesados (navegador com dezenas de abas);
- O `05-kfai-start.ps1` define `OLLAMA_KEEP_ALIVE=30m` para o modelo não ficar
  preso na RAM para sempre, `OLLAMA_NUM_PARALLEL=2` e
  `OLLAMA_KV_CACHE_TYPE=q8_0` (corta ~50% da memória do cache de contexto).

> Dica: rode `nvidia-smi` (se tiver GPU NVIDIA) para ver a VRAM livre antes de
> escolher o modelo. Se a VRAM for insuficiente, o Ollama usa a RAM (mais lento,
> mas funciona).
