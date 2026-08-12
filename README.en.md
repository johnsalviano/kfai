# KFAI — AI Agent Toolkit

**[🇧🇷 Português](README.md) · 🇺🇸 English**

[![License](https://img.shields.io/github/license/johnsalviano/kfai)](LICENSE)
[![Release](https://img.shields.io/github/v/release/johnsalviano/kfai)](https://github.com/johnsalviano/kfai/releases)
[![Last commit](https://img.shields.io/github/last-commit/johnsalviano/kfai)](https://github.com/johnsalviano/kfai)
[![Stars](https://img.shields.io/github/stars/johnsalviano/kfai?style=social&label=Stars)](https://github.com/johnsalviano/kfai)
[![Forks](https://img.shields.io/github/forks/johnsalviano/kfai?style=social&label=Forks)](https://github.com/johnsalviano/kfai/fork)

![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey)
![Language](https://img.shields.io/badge/Language-PowerShell%20%2B%20Python-purple)
![AI](https://img.shields.io/badge/AI-Ollama%20%2B%209Router%20%2B%20Opencode-green)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

KFAI gathers, sets up and explains how to use **free** AI tools (Ollama,
9Router, Opencode, AionUi) to handle everyday tasks — and also helps you
tune up your own computer to get the most out of them.

- ✅ **100% free** — open-source tools only
- 🖥️ **Runs on modest PCs** — if your machine can't handle local AI, you use the cloud
- 🔐 **No one else's keys** — you generate your own, for free, and they stay on your machine

## 📖 Table of contents

- [How to install](#-how-to-install)
- [Available combos](#-available-combos)
- [How KFAI works](#-how-kfai-works)
- [Local AI with context that works](#local-ai-with-context-that-actually-works-doesnt-break-the-agent)
- [Run only when you use it](#run-only-when-you-use-it-no-process-always-running)
- [Documentation](#documentation)
- [FAQ](#-faq--troubleshooting)
- [Support the project](#-support-the-project)
- [Security](#-security)
- [Learn more](#-learn-more)

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

The KFAI installer already sets the combos up: it adds the **`kfai`** provider
to your `opencode.json` (Full Cloud, Cloud + Local, Full Local) and, if you use
AionUi, `kfai-aionui-combos.ps1` adds the same inside the app and removes paid
profiles.

There are also ready-made files for manual setup in `config/opencode/`:

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

## 🧠 How KFAI works

A single route with **several providers in priority order** (uplinks): the KFAI
router tries the first one; if it fails, the call moves to the next.

```
You (Opencode CLI / OpenCode Desktop / AionUi)
        │  requests a combo (e.g.: kfai/cloud-plus-local)
        ▼
KFAI Router (port 20129 — router.py)
        │
        ├── 1st uplink: 9Router (port 20128) ←── your free keys live here
        │        ├─ OpenRouter  ·  Gemini  ·  NVIDIA NIM  ·  Cloudflare …
        │        └─ failed? (429/5xx/any 9Router error) → goes down
        │
        └── 2nd uplink: local Ollama (port 11434) ←── 100% offline AI
                 └─ qwen3:4b (or the model the installer chose for your PC)
```

- **`kfai/full-cloud`** → only 9Router (free cloud).
- **`kfai/cloud-plus-local`** → cloud first; if it fails, falls back to local Ollama.
- **`kfai/full-local`** → only Ollama (works even offline).

Each combo is a route in `router.conf`; the model the agent asks for picks the
route. More technical details in [docs/FERRAMENTAS.md](docs/FERRAMENTAS.md).

## Local AI with context that actually works (doesn't break the agent)

Ollama uses a **4,096-token context by default** and **silently truncates**
anything beyond that — which makes the local agent "forget" the middle of the
task and **tool calls fail**. KFAI solves this in three places:

1. **`kfai-start.ps1`** sets `OLLAMA_KEEP_ALIVE=30m` (the model stays in RAM,
   no 3–10s cold start per request) and `OLLAMA_NUM_PARALLEL=2`.
2. **Own router**: when an uplink is local Ollama, the router injects
   `options.num_ctx` into the request (`KFAI_NUM_CTX`, default **65536**).
3. **`-64k` derived model**: the installer creates a model with `num_ctx 65536`
   baked in (e.g. `qwen3-64k`). Use that name in the opencode config
   (`config/opencode/full-local.json`, field `KFAI_LOCAL_MODEL`).

> Context of **64k+** is the official Ollama recommendation for agents with tool
> calling (https://docs.ollama.com/integrations/opencode). The installer creates
> the `-64k` model automatically; for another size, build a `Modelfile`
> (`FROM <model>` + `PARAMETER num_ctx <N>`) and run
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
- `kfai-config-chaves.ps1` — helper that shows which keys are missing and opens each provider's site
- [Models by hardware](docs/MODELOS-POR-HARDWARE.md) *(in Portuguese)* — which local model to download on your PC
- [Credits](docs/CREDITOS.md) *(in Portuguese)* — who made each tool

## ❓ FAQ / Troubleshooting

**PowerShell blocks `install.ps1` ("cannot be loaded")?**
Restricted execution policy. Quick fix: download `KFAI-Instalador.exe` (double-click, no policy needed) **or** run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` and reopen PowerShell.

**Getting 401/403 (unauthorized) errors from the router?**
That's a config problem, not a limit — the router **intentionally does not**
fallback on 400/401/403/404. Check your key in `router.conf` (did you replace
`SUA_CHAVE_AQUI`?), the provider and the model in the opencode config.

**Getting 429 (rate limit) and responses stall?**
429 is the normal fallback case: the router waits `KFAI_COOLDOWN_SEC` (60s) and
tries the next uplink in the list. If **all** are on 429, wait or switch combos
(e.g. `cloud-plus-local` to fall back to local Ollama).

**My PC is weak, can I use it?**
Yes — use the **Full Cloud** combo (cloud free tiers only, no local AI). The
installer detects hardware and the launcher only tries Ollama if the machine
can handle it.

**The local agent "forgets" mid-task / tool calls fail?**
Short context. KFAI already sets `num_ctx 65536` (`-64k` model). See the
"Local AI with context that actually works" section above.

**How do I keep everything always on?** `.\kfai-start.ps1 -Register` (revert: `-Unregister`).

**Nothing works and I don't know where to start?** Run `.\kfai-start.ps1 -Status`
— it shows the ports, found paths and whether your PC supports local AI.

**Another question?** Open an [issue](https://github.com/johnsalviano/kfai/issues)
— we'll help and the FAQ grows with you.

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

### 📜 Donation rules (scam protection)

For everyone's safety, please read before donating:

- **Donations are voluntary and irrevocable.** This is **not** a purchase: you
  receive no product or service in return, so there is **no "buyer's remorse"
  refund** — this matches Brazil's Central Bank stance on Pix donations.
  Before confirming, think it through: **only donate if you really mean it.**
- **Refunds only for fraud or operational failure**, and **always through the
  official channel**: open the **MED (Special Refund Mechanism)** at **your
  bank**, within 80 days of the transaction. Don't ask the project to refund you
  directly, and the project never refunds directly — the official banking
  process decides, with analysis and evidence.
- **The "mistaken Pix" scam:** some scammers send a Pix, then contact the
  account owner asking for a refund to a **different** account/key and also
  trigger the MED, trying to get paid twice. **Never refund money outside the
  banking system for a Pix you don't recognize** — any refund must follow your
  bank's flow, back to the **same** original key.
- **The project never asks for your data or charges anything** beyond the
  voluntary donation. Be wary of any "support" or "fake donor" asking for
  confirmation, passwords or a "guarantee Pix" — that's a scam; ignore and
  report it.

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
> `466065D0CD68C91944A5D4D7D0EBE89472654CE03513A72F1A7B25E43AF6ABBA`<br>
> *(the script itself prints the same value at the end of the install — if it
> diverges, the file may have been tampered with and **must not** be run)*

> **Current `KFAI-Instalador.exe` hash (check before running):**<br>
> `DC8BBC8A9C8967FBCF86E47D23DDBFD93117AD0F4F7134FE9117E93DF3863027`<br>
> *(if you downloaded the executable, check **this** value — the executable
> prints the `.exe` hash at the end, not the script's)*

## 📺 Learn more

Official tool documentation (always trust it over any third-party tutorial —
avoids phishing):

| Tool | Official docs |
|---|---|
| Ollama (local AI) | https://docs.ollama.com · opencode integration: https://docs.ollama.com/integrations/opencode |
| Opencode (terminal agent) | https://opencode.ai/docs |
| AionUi (GUI app) | https://github.com/iOfficeAI/AionUi/wiki |
| 9Router (cloud gateway) | https://github.com/decolua/9router |

Videos referenced in the projects' own official READMEs (verifiable, low risk):

- Julian Goldie SEO — *"Hermes + Aion UI is Insane (FREE!)"*: https://www.youtube.com/watch?v=vWxE6VO9TKo
- WorldofAI — AionUi review: https://www.youtube.com/watch?v=yUU5E-U5B3M
- CodeVerse Soban — *"Claude CLI Free Setup with 9Router"*: https://www.youtube.com/@CodeVerseSoban

> ⚠️ **Phishing:** generate AI keys **always** on the providers' official sites
> and paste them yourself into the 9Router panel (`http://localhost:20128/dashboard`).
> No "free API aggregator" site or tutorial asking for your keys is trustworthy.

## License

See [docs/CREDITOS.md](docs/CREDITOS.md) for tool attribution. The kit itself
(documentation, skills, scripts, configuration) is distributed under MIT.

---

**Want to help?** See [CONTRIBUTING.md](CONTRIBUTING.md) — there are ways to
contribute even without coding.
