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
| **8–16 GB RAM** (sem GPU ou integrada) | 7B | `ollama run qwen2.5:7b` | Usa a RAM, roda em CPU |
| **16–32 GB RAM** | 7B–14B | `ollama run qwen2.5-coder:14b` | Bom equilíbrio |
| **GPU 6–8 GB VRAM** | 7B (quantizado) | `ollama run qwen2.5-coder:7b` | 14B pode ficar lento |
| **GPU 8–12 GB VRAM** | 7B–14B | `ollama run qwen2.5-coder:14b` | Fluido e boa qualidade |
| **GPU 12–16 GB VRAM** | 14B–32B | `ollama run qwen2.5-coder:32b` | Alta qualidade |
| **GPU 24+ GB VRAM** | 32B+ | `ollama run qwen3:32b` | Qualidade máxima |

## 🧠 Modelos recomendados por tarefa

| Tarefa | Modelo | Por quê |
|---|---|---|
| **Código** | `qwen2.5-coder` (7b/14b/32b) | Melhor custo-benefício para programação |
| **Chat/geral** | `qwen2.5` (7b/14b/32b) | Equilibrado em conversa e raciocínio |
| **IA mais forte p/ raciocínio** | `qwen3` / `deepseek-r1` (se a VRAM aguentar) | Raciocínio avançado, pesado |
| **Textos longos** | modelos com contexto 32k+ | Não "esquece" o meio da tarefa |
| **Português** | modelos qwen/llama recentes | Boa fluência em pt-BR |

## ⚙️ Como trocar o modelo

1. Baixe o modelo: `ollama pull qwen2.5-coder:14b`
2. No `router.conf`, aponte a rota local para o novo modelo (campo `model`).
3. Se for usar com o opencode, crie o derivado `-32k` (contexto estendido):
   ```dockerfile
   FROM qwen2.5-coder:14b
   PARAMETER num_ctx 32768
   ```
   ```powershell
   ollama create qwen2.5-coder-14b-32k -f Modelfile
   ```
   e use o nome `qwen2.5-coder-14b-32k` no `config/opencode/full-local.json`
   (campo `KFAI_LOCAL_MODEL`).

## 📉 Reduzindo o uso de memória

- Use modelos **menores** (7B em vez de 14B);
- Use **quantizações** mais leves (ex.: `q4_K_M` já é padrão em muitos);
- Feche outros programas pesados (navegador com dezenas de abas);
- O `kfai-start.ps1` define `OLLAMA_KEEP_ALIVE=30m` para o modelo não ficar
  preso na RAM para sempre e `OLLAMA_NUM_PARALLEL=2`.

> Dica: rode `nvidia-smi` (se tiver GPU NVIDIA) para ver a VRAM livre antes de
> escolher o modelo. Se a VRAM for insuficiente, o Ollama usa a RAM (mais lento,
> mas funciona).
