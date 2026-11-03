# Choosing the AI Model

Nov 3, 2026 · @Russ Broomell

Sidekick runs on whatever model the person chooses, and they can change it any time without losing memory: send `/model` in Telegram, or run `hermes -p sidekick model` on the server. Everything the agent knows lives in files on the server, not with the model provider.

## The options

| Option | How to sign in | Good for | Watch out for |
| --- | --- | --- | --- |
| **Grok (xAI) via OAuth** | **xAI Grok OAuth (SuperGrok / Premium+)**, or `hermes -p sidekick auth add xai-oauth --no-browser` (device code, no tunnel) | People with SuperGrok or X Premium+ | xAI limits OAuth API access by tier: a successful login can still return `HTTP 403`. If so, use an API key |
| **Grok via API key** | xAI → `XAI_API_KEY` | Grok without the tier question | Pay-per-use |
| **OpenAI (ChatGPT/Codex) via OAuth** | **ChatGPT or Codex Subscription** (device code) | People with a ChatGPT plan | Plan quotas for Hermes use aren't documented |
| **OpenRouter** | `hermes -p sidekick auth add openrouter --type oauth` or API key | Trying many models with one account | Pay-per-use; pick a model with strong tool calling |
| **Nous Portal** | `hermes -p sidekick model` → Nous Portal (device code) | One subscription for 300+ models plus web search, browser and TTS tools | Turn on Privacy Mode in the Portal before using it for personal data |
| **Your own model** (Ollama, vLLM, LM Studio, llama.cpp server, any OpenAI-compatible endpoint) | **Custom endpoint**: base URL, optional key, model name | Maximum privacy: prompts never leave hardware you control | Needs a model strong enough for tool calling (see below), and the server must be able to reach it |

**Default: Grok (`grok-4.6`).** Claude is not an option for this build. Agent work (multi-step errands, browser, scheduling) needs strong tool calling. Hermes's docs warn that small local models (roughly under 30B parameters) often *say* they saved or did something without actually doing it.

## Having more than one ready

Sign in to as many as you like; `/model` in Telegram then shows a button menu of providers and models. That's a good demo moment: switch from Grok to another model mid-conversation, and the agent still remembers everything.

```bash
hermes -p sidekick auth add xai-oauth --no-browser       # Grok (SuperGrok / Premium+)
hermes -p sidekick auth add openrouter --type oauth      # a second option, many models
```

**Scheduled jobs** (brief, recap, distill) follow the main model unless you pin them. To keep them on a cheaper model regardless of what you chat with, set one for the whole set of jobs:

```bash
hermes -p sidekick config set cron.model <model-name>
```

## When the prospect brings their own LLM

Three ways, from simplest to most private.

**1. Their API key, on a demo agent.** Good for "try it with your model". Ask them to make a **temporary key with a small spend cap**, and enter it on the server with `hermes -p sidekick model`, never in Telegram. Delete it afterwards with `hermes -p sidekick auth remove <provider>` (see `hermes auth --help`). The cleaner version: they run their own agent, which is the whole point of the product.

**2. Their hosted endpoint.** Any OpenAI-compatible URL (a company vLLM server, Azure, Bedrock and so on). Pick **Custom endpoint** and enter the base URL, key and model name. The server must be able to reach it over the internet or a VPN.

**3. A model running on their own computer** (Ollama or LM Studio on a laptop or workstation). The VPS can't reach their laptop directly, so open a reverse tunnel **from the machine running the model**:

```bash
# On the machine running Ollama (port 11434); keep it open:
ssh -N -R 11434:127.0.0.1:11434 agent@YOUR_SERVER_IP
```

Then on the server: `hermes -p sidekick model` → **Custom endpoint** → `http://127.0.0.1:11434/v1`, no key, and the model name (for example `qwen3:32b`). The agent now thinks with a model on their desk while its memory stays on the server. This makes a great privacy demo, but it only works while their machine is on and the tunnel is up. For daily use, Tailscale between the two machines is sturdier.

**Running the model on the VPS itself isn't realistic at 4 GB.** Even the smallest useful local models need more memory than is left once the gateway and the bot's browser are running. For an all-local setup, the right home is a mini PC or a Mac with 32–64 GB of memory: install Hermes there, then use Hermes's one-click local models (llama.cpp) and move the agent over with `scripts/move-agent.sh`.

## What the model provider sees

Every model provider (except your own hardware) receives the conversation and the notes needed for each reply, under its own terms. What it never gets is the archive as a whole: memory, notes and chat history stay on the server, and the agent sends only what a given reply needs. Choose providers whose API terms exclude training on your data, and use your own model for the most private topics.

Sources: [Hermes providers](https://hermes-agent.nousresearch.com/docs/integrations/providers) · [xAI Grok OAuth guide](https://hermes-agent.nousresearch.com/docs/guides/xai-grok-oauth) · [OAuth over SSH](https://hermes-agent.nousresearch.com/docs/guides/oauth-over-ssh) · [Hermes memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory) · [Cron model selection](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron)
