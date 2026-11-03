# Talking to Sidekick

Nov 3, 2026 · @Russ Broomell

There are two ways to talk to the assistant and hear it answer, and both are built into Hermes. Each personality has its own voice.

| Way | Where | Feels like | Needs |
| --- | --- | --- | --- |
| **Voice notes** | Telegram, on your phone | Walkie-talkie: hold to talk, a voice bubble comes back | Nothing extra beyond `voice-setup.sh` |
| **Live conversation** | The workspace in a browser (laptop or phone) | A phone call: talk naturally, it answers out loud, interrupt it any time | The Tailscale HTTPS address ([setup guide](setup-guide-ovh.md), Step 6, Route A), because browsers only allow the microphone over HTTPS |

## Turn it on (2 minutes)

On the server, as `agent`:

```bash
bash ~/personal-agent/scripts/voice-setup.sh grok
```

This uses **Grok voices**: expressive, and every personality gets its own voice. Hermes adds delivery cues like `[laughs]` and `[pause]` automatically. Listening and speaking both go through your xAI sign-in, the same one as the chat model.

```bash
bash ~/personal-agent/scripts/voice-setup.sh free
```

Use this instead if Grok's voice isn't available on your plan. It uses **free voices** (Microsoft Edge voices, no account), and listening runs on the server itself with Whisper. That costs about 300 MB of memory while in use, which is fine on 4 GB.

Switching personality switches the voice too.

| Persona | Grok voice | Free voice | Delivery |
| --- | --- | --- | --- |
| Sam | sal | en-US-Guy | Measured, low-key, dry half-beat before the punchline |
| Pip | ara (a bit faster) | en-US-Aria | Upbeat, smiling, the occasional laugh |
| Mortimer | leo (a bit slower) | en-GB-Ryan (British) | Slow, precise, one raised eyebrow per sentence |
| Rex | rex (a bit faster) | en-US-Davis | Crisp, energetic, excited only for wins |
| Nova | eve | en-US-Jenny | Calm, clipped, like a radio channel |
| Vic | rex (slow) | en-US-Christopher | Low, slow, world-weary, with a wink |

Change a voice in `distribution/skills/persona-switch/personas/voices.conf`, then run `bash ~/personal-agent/scripts/update.sh`.

## Voice notes in Telegram

- Hold the microphone in your bot's chat, talk, and let go. It transcribes, does the work, and replies with a voice bubble plus the text.
- Send `/voice on` once. It then speaks back whenever *you* send a voice note. `/voice tts` speaks every reply, which is good in the car. `/voice off` means text only.
- Links, addresses and long numbers come as text, not read aloud. The house rules say so.

## A live conversation in the browser

1. Open your workspace at the `https://…ts.net` address (on your laptop, or your phone with the Tailscale app on).
2. In the chat box, the **microphone** is dictation. The button **to its right starts a full voice conversation**. Allow the microphone when the browser asks.
3. Talk normally. It detects when you stop, answers out loud sentence by sentence as it thinks, and **you can interrupt it mid-sentence** (it knows it was interrupted). Say **"stop"** to end.
4. Everything still works: errands, the browser screen, approvals. Approvals still need a tap or a clear "yes".

**Laptop tips:** use headphones or a headset in a demo room, because speaker echo can trigger interruptions. If it keeps cutting itself off, run `hermes -p sidekick config set voice.barge_in_threshold_multiplier 4`. If it's hard to interrupt, use `2`.

**Faster replies when talking:** spoken turns use the main model with reasoning turned off, so they're quicker than typed ones. To use a faster model just for voice, set `auxiliary.voice_chat` (see the Hermes voice docs).

## Not used here (and why)

- **GPT-Live full-duplex voice** (in the Hermes desktop app): the most natural conversation, but it needs an OpenAI key and costs $0.05 a minute.
- **Discord voice channels:** work well, but we use Telegram as the front door.
- **Wake word ("hey Sidekick")**: works in the desktop app and the CLI. A nice later touch for a home PC.

## If something goes wrong

| What you hear or see | Try |
| --- | --- |
| No voice bubble, just an audio file | Install ffmpeg: `sudo apt-get install -y ffmpeg`, then `hermes -p default gateway restart` |
| Grok voice errors, or `403` | Your xAI plan may not include voice: `bash ~/personal-agent/scripts/voice-setup.sh free` |
| Voice conversation button missing or greyed out | You're on plain `http://`. Use the `https://…ts.net` address |
| It transcribes the wrong words | Speak a little closer; set `stt.language` to your language; with `free`, try a bigger model: `hermes -p sidekick config set stt.local.model small` (more memory) |
| Voice doesn't match the personality | Run `bash ~/personal-agent/scripts/set-persona.sh <persona>` again, then `/new` |

Sources: [Hermes voice mode](https://hermes-agent.nousresearch.com/docs/user-guide/features/voice-mode) · [Hermes voice and TTS](https://hermes-agent.nousresearch.com/docs/user-guide/features/tts) · [Desktop workspace in a browser](https://hermes-agent.nousresearch.com/docs/user-guide/desktop) · [xAI text to speech](https://docs.x.ai//developers/model-capabilities/audio/text-to-speech)
