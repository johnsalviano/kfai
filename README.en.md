# KFAI — AI Agent Toolkit

**[🇧🇷 Português](README.md) · 🇺🇸 English**

![License](https://img.shields.io/badge/License-MIT-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey)
![Language](https://img.shields.io/badge/Language-PowerShell%20%2B%20Python-purple)
![AI](https://img.shields.io/badge/AI-Ollama%20%2B%209Router%20%2B%20Opencode-green)
![Status](https://img.shields.io/badge/Status-Open%20to%20everyone-brightgreen)
[![Release](https://img.shields.io/github/v/release/johnsalviano/kfai)](https://github.com/johnsalviano/kfai/releases)

> **Free AI agents for people who don't give up.**

KFAI gathers, sets up and explains how to use **free** AI tools (Ollama,
9Router, Opencode, AionUi) to handle everyday tasks — and also helps you
tune up your own computer to get the most out of them.

- ✅ **100% free** — open-source tools only
- 🖥️ **Runs on modest PCs** — if your machine can't handle local AI, you use the cloud
- 🔐 **No one else's keys** — you generate your own, for free, and they stay on your machine

---

## 🚀 How to install

You can run the installer in **two ways** — pick whichever you prefer:

| Prefer | Do this |
|---|---|
| Script (transparent, you can read everything) | `.\install.ps1` in PowerShell |
| Executable (doesn't depend on Execution Policy) | download `KFAI-Instalador.exe` from the [releases](https://github.com/johnsalviano/kfai/releases) page and double-click it |

> The executable is just the installer compiled — the kit itself remains
> open scripts (you can read everything before using it). The `.exe` exists
> for people whose PowerShell has execution policies that block scripts.

First, install the dependencies:

1. [Ollama](https://ollama.com/download/windows) *(optional, only if you want local AI)*.
2. [9Router](https://9router.com) and [Opencode](https://opencode.ai).

The installer **detects your hardware** (RAM, CPU, GPU), picks the right local
model for your machine and walks you through step by step — no administrator
required, and nothing is downloaded twice.

---

## 🧩 Available combos

| Combo | What it is | When to use it |
|---|---|---|
| **Full Cloud** | free cloud AIs only (Gemini, OpenRouter :free, NVIDIA NIM…) | modest PC, you want cloud AI |
| **Cloud + Local** | cloud first; if the limit runs out, uses local AI | balance, almost always |
| **Full Local** | 100% offline (Ollama) | no internet or for privacy; only if your PC can handle it |

Both paths (9Router and KFAI's own router): the `config/opencode/` folder has
files for both. Copy whichever you prefer:

| Prefer | Files |
|---|---|
| Own router (no 9Router running) | `router-full-cloud.json`, `router-cloud-plus-local.json`, `router-full-local.json` |
| 9Router | `full-cloud.json`, `cloud-plus-local.json`, `full-local.json` |

**Own router:** run `python router.py`, fill in `router.conf` (copy the
`.example`), choose by route `full` (text kept intact), `eco` (summarizes old
history to save tokens) or `auto` (the router decides by heuristics: complex
topic → `full`, simple question → `eco`). 9Router stays for those who prefer it.

The **3 default combos** already come ready in `router.conf.example`. Each line
is an "uplink" (provider); lines with the same route form the fallback list:

- **`full-cloud`** — free cloud only (Gemini, Groq, Cerebras, OpenRouter `:free`,
  Mistral, NVIDIA NIM). For modest PCs that can't run local AI, use **only** this one.
- **`cloud-plus-local`** — cloud first; when tokens run out (429), it falls back
  automatically to local Ollama (last uplinks in the list).
- **`full-local`** — local Ollama only (100% offline).

Built-in features of the own router:

- **Automatic fallback**: each route accepts several uplinks; if one goes down or
  fails, the call moves to the next in the list. **Only recoverable errors** (429
  rate limit, 5xx, timeout) trigger fallback/cooldown — configuration errors
  (400, 401, 403, 404) don't switch providers, since the request itself is at fault.
- **Cooldown (circuit breaker)**: an uplink that failed recoverably goes into
  quarantine and is skipped on the next calls (`KFAI_COOLDOWN_SEC`, default 60s).
- **`auto` mode**: deterministic heuristics (no LLM cost) to choose `full` vs `eco`
  per request — prompt complexity, presence of tools and size.
- **Tool output compression**: long `tool` outputs (logs, git, etc.) are collapsed
  (repeated lines omitted) and truncated to fit the context.
- **In-memory cache**: repeated identical calls (non-stream) answer instantly
  without reprocessing (`KFAI_CACHE_SEC` 300s, up to `KFAI_CACHE_MAX` 200).
- **JSONL log**: each request recorded in `logs/router.log` (route, uplink, mode,
  cache, bytes, time). Variables: `KFAI_LOG_FILE`, `KFAI_ROUTER_PORT`.
- **Local abuse protection**: the router refuses requests with `Origin` from
  external sites (prevents a malicious page you visit from using your keys via
  the browser) and can require a token — set `KFAI_ROUTER_TOKEN` so that only
  those who know the token can use the router (extra protection against local malware).

## Local AI with context that actually works (doesn't break the agent)

Ollama uses a **4,096-token context by default** and **silently truncates**
anything beyond that — which makes the local agent "forget" the middle of the
task and **tool calls fail**. KFAI solves this in three places:

1. **`kfai-start.ps1`** sets `OLLAMA_KEEP_ALIVE=30m` (the model stays in RAM,
   no 3–10s cold start per request) and `OLLAMA_NUM_PARALLEL=2`.
2. **Own router**: when an uplink is local Ollama, the router injects
   `options.num_ctx` into the request (`KFAI_NUM_CTX`, default **32768**).
   Failover/error config only for 429/5xx/timeout.
3. **`-32k` derived model**: the installer creates a model with `num_ctx 32768`
   baked in (e.g. `qwen2.5-coder-32k`). Use that name in the opencode config
   (`config/opencode/full-local.json`, field `KFAI_LOCAL_MODEL`).

> Official Ollama recommendation for agents with tool calling: context **≥64k**.
> If your PC can handle it (free VRAM), you can create `-64k` the same way:
> `FROM <model>` + `PARAMETER num_ctx 65536` in a Modelfile, then
> `ollama create <model>-64k -f Modelfile`.

The installer also takes advantage of the **`ollama launch opencode`** command
(Ollama 0.15+): it configures opencode with the local model automatically,
no manual JSON.

## Run only when you use it (no process always running)

By default, nothing sits idle. The launcher starts router + Ollama **when you
open the agent** and stops them when you close it:

```powershell
.\kfai-launch.ps1 -App aionui      # opens AionUi
.\kfai-launch.ps1 -App opencode    # opens opencode in the terminal
.\kfai-launch.ps1 -App hermes      # opens Hermes
.\kfai-launch.ps1 -App "C:\path\app.exe"   # any executable
```

**Using 9Router (port 20128)?** Add `-With9Router` to prefer **local** AI and
use 9Router only as backup. The two are **never** running at the same time:

```powershell
.\kfai-launch.ps1 -App aionui -With9Router   # prefers local; falls back to 9Router on failure
.\kfai-launch.ps1 -App opencode -With9Router
```

**Automatic check at startup** (the launcher decides on its own):

1. **Can this PC handle local AI?** checks RAM (≥ 8 GB), GPU VRAM (via `nvidia-smi`)
   and CPU. Without that, Ollama doesn't run — the launcher **uses 9Router by
   default** and doesn't even try to start local.
2. **Which command exists on this machine?** the Ollama paths (`ollama.exe serve`
   or `ollama app.exe`) and 9Router paths (`cli.js` from global npm or the
   standalone `server.js` build) are discovered in real time, since they vary
   from PC to PC.
3. If the PC supports it: starts Ollama, tests whether it responds and has a
   model (`/api/tags`). OK → uses local. Failed → stops local and starts 9Router.

`kfai-start.ps1 -Status` shows the 3 ports **and the check result** (supported or
not, with the paths found). To force cloud only even on a capable PC, set
`KFAI_FORCE_NO_LOCAL=1`.

If you close one agent but **another is still open** (e.g. AionUi open and you
close opencode), the services keep running — they only stop when the last agent
closes. Use `-KeepOn` to keep the services running after closing the agent.

The AionUi shortcut in the Start menu already points to the launcher. To open an
agent WITHOUT the launcher and still have the services, start them manually with
`.\kfai-start.ps1`.

**"Always on" mode (optional):** if you prefer everything to start at login
without opening an agent, run `.\kfai-start.ps1 -Register` (and `-Unregister` to
revert).

## Documentation

- [What is KFAI](docs/O-QUE-E-KFAI.md) *(in Portuguese)*
- [Setup guide](docs/GUIA-CONFIGURACAO.md) *(in Portuguese)*
- [Free API keys guide](docs/GUIA-CHAVES-GRATIS.md) *(in Portuguese)* — how to get a free API key from each provider
- [Credits](docs/CREDITOS.md) *(in Portuguese)* — who made each tool

## ❤️ Support the project

KFAI is **100% free and ad-free** — built in spare time, with care.
If the project helped you and you'd like to give back, any amount is welcome and
**makes a real difference** in keeping it maintained, fixed and improved:

> **PIX:** `edb2e588-8dc5-4991-ab61-62f113a066c6` *(random key — created only for
> donations, without exposing personal data)*
>
> 📱 **QR Code:** [pay via Nubank](https://nubank.com.br/cobrar/1bq05j/6a7686af-8d68-4c76-bde7-5ae91eabd152)

If you'd rather not donate, that's fine too! You already help a lot by:
- ⭐ starring the repository;
- 🐛 reporting bugs in [issues](https://github.com/johnsalviano/kfai/issues);
- 📣 sharing the project with someone who might benefit from it.

## 🔐 Security

KFAI **does not include, read or share** anyone's keys, tokens or personal data.
Every credential starts as `YOUR_KEY_HERE` for you to fill in — and the real
values stay only on your machine, never in this repository.

The installer protects itself against tampered copies:

- it only runs if it comes from the official repository (`github.com/johnsalviano/kfai`);
- if the remote isn't the official one, it **stops** immediately (sign of a tampered copy);
- if there's **no remote** (ZIP, executable or a copy passed along by others),
  it **warns and asks for confirmation** before continuing — you confirm you
  downloaded it from the official repository and check the hash below;
- at the end, it shows the **SHA-256 of the installer itself** for you to compare
  against the value published below (kept up to date with every release).

The own router also protects against abuse:

- it refuses requests with `Origin` from external sites (a malicious page you
  visit **can't** use your AI keys through the browser);
- optionally requires `KFAI_ROUTER_TOKEN` to block any local process that
  doesn't know the token.

> **Current `install.ps1` hash (check before running):**<br>
> `AA850FD54D15E3A2239C4212930D24CB436EE0DB3A030779D6E575CF60094936`<br>
> *(the script itself prints the same value at the end of the install — if it
> differs, the file may have been tampered with and **must not** be run)*

> **Current `KFAI-Instalador.exe` hash (check before running):**<br>
> `5E22AFB7CC87491C4F801A0C8B7CE0BC365E8A7226F51725E397697B25B7C10F`<br>
> *(if you downloaded the executable, check **this** value — the executable
> prints the `.exe` hash at the end, not the script's)*

## License

See [docs/CREDITOS.md](docs/CREDITOS.md) for tool attribution. The kit itself
(documentation, skills, scripts, configuration) is distributed under MIT.
