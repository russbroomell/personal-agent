# Talking to the Council

Nov 26, 2026 · @Russ Broomell

The council is meant to be heard. Send a voice note with a decision and you get one voice bubble back, with Newton, Māui and Marcus each in their own voice. The `council-voices` plugin does this: it splits a reply at each `Name:` tag and speaks every line with that member's voice.

Commands here assume the Council is in Hermes's default profile (what `install.sh` does unless you pass `--profile`). If you installed it into a named profile, add `-p NAME` after `hermes`, and use `~/.hermes/profiles/NAME/` instead of `~/.hermes/`.

| Way | Where | Feels like | Needs |
| --- | --- | --- | --- |
| **Voice notes** | Telegram, on your phone | Walkie-talkie: hold to talk, one voice bubble with every member who answers | `voice-setup.sh` |
| **Live conversation** | The workspace in a browser (laptop or phone) | A phone call with the council: talk naturally, interrupt any time | The workspace, on an `https://` address (Tailscale) or `http://127.0.0.1` through an SSH tunnel |

## Turn it on (2 minutes)

On the server, as the user Hermes runs as:

```bash
bash ~/personal-agent/scripts/voice-setup.sh free
```

Pick the engine that fits:

| Engine | Command | Cast | Notes |
| --- | --- | --- | --- |
| **Free** (Edge voices) | `voice-setup.sh free` | A distinct voice for every member, including Māui's New Zealand voice and Newton's English one | No account. Listening runs on the server (Whisper, about 300 MB while in use) |
| **Grok** | `voice-setup.sh grok` | Five Grok voices, shared at different speeds (Marcus slower, Remus quicker) | The same xAI sign-in as the chat model. Expressive tags like `[laughs]` |
| **ElevenLabs** | `voice-setup.sh elevenlabs` | The best cast: a stock voice per member, sent as one dialogue so hand-offs sound natural | Paid API key (asked once, saved in the profile's `.env`) |

Then, in Telegram, send `/voice on` once. It speaks back whenever *you* send a voice note. `/voice tts` speaks every reply (good in the car), and `/voice off` means text only.

## How the voices work

- Every line of a reply starts with a member's tag, like `Newton:`. The plugin speaks that line in Newton's voice and drops the tag.
- Untagged text, and `All:` lines, are spoken by the chair (Marcus).
- A name in the middle of a sentence ("I asked Newton: twice") isn't treated as a tag.
- In a live conversation, Hermes speaks sentence by sentence as the model writes, and an untagged sentence keeps the last speaker's voice for 8 seconds (`tts.council.sticky_seconds`).
- Links, addresses and long numbers are sent as text, not read aloud. The house rules say so, and keep a spoken reply under 30 seconds.

## Change a member's voice

For good, so it survives updates: edit their line in `distribution/skills/council/members/voices.conf` (columns: slug, Grok voice, Grok speed, Edge voice, Edge speed, ElevenLabs voice id), then run:

```bash
bash ~/personal-agent/scripts/update.sh
```

For now, on this server only:

```bash
hermes config set tts.council.voices.newton.edge en-GB-RyanNeural
hermes config set tts.council.engine elevenlabs   # which engine speaks
```

| Setting under `tts.council` | Default | What it does |
| --- | --- | --- |
| `engine` | the engine `voice-setup.sh` chose | `xai`, `edge` or `elevenlabs` |
| `speakers` | the seated members | Who can speak |
| `voices.<member>.<engine>` | from `voices.conf` | The voice, plus `xai_speed` and `edge_speed` |
| `lead` | `marcus` | Speaks untagged and `All:` lines; members with no voice use his |
| `labels` | `māui → maui`, etc. | Extra tag spellings |
| `elevenlabs_dialogue` | `true` | One dialogue request instead of one per line |

`build-soul.sh` rewrites these from `voices.conf` whenever it runs (after every update, and whenever a member is seated or benched).

## A live conversation in the browser

1. Open the workspace: your `https://…ts.net` address (`scripts/remote-access.sh`), or `http://127.0.0.1:9120` through the SSH tunnel that `install.sh` printed.
2. In the chat box, the **microphone** is dictation. The button **to its right starts a full voice conversation**. Allow the microphone when the browser asks.
3. Talk normally. It answers out loud, each member in their voice, and **you can interrupt it mid-sentence**. Say **"stop"** to end.
4. Approvals still need a tap or a clear "yes".

**Tips:** use headphones, because speaker echo can trigger interruptions. If it keeps cutting itself off, run `hermes config set voice.barge_in_threshold_multiplier 4`. If it's hard to interrupt, use `2`.

**Not with GPT-Live** (the desktop app's full-duplex mode): it uses one OpenAI voice and skips plugins, so the whole council sounds the same.

## If something goes wrong

| What you hear or see | Try |
| --- | --- |
| One voice for everyone | `hermes config get tts.provider` should say `council`, and `hermes plugins list` should show `council-voices` enabled. Fix: `bash ~/.hermes/skills/council/build-soul.sh`, then `hermes -p default gateway restart` |
| "Voice engine ... isn't ready" in the logs | The engine under `tts.council.engine` isn't set up. Run `voice-setup.sh` with `free`, `grok` or `elevenlabs` |
| It reads a name aloud ("Newton colon") | A tag landed mid-sentence. Say "start every line with the name"; if it keeps happening, send `/new` |
| An audio file instead of a voice bubble | Install ffmpeg (`sudo apt-get install -y ffmpeg`), then `hermes -p default gateway restart` |
| Grok voice errors, or `403` | Your xAI plan may not include voice: `voice-setup.sh free` |
| It transcribes the wrong words | Set `stt.language`; with `free`, try a bigger model: `hermes config set stt.local.model small` (more memory) |

## For developers

The plugin is `distribution/plugins/council-voices/`, shipped with the profile. It registers a Hermes text-to-speech provider named `council`, splits replies with `speakers.py`, and speaks each line with Hermes's own engine (`engines.py`), so it reuses Hermes's keys and sign-ins. Parts are joined with ffmpeg into one Opus file. Tests: `python3 tests/council_voices/test_council_voices.py`, which is part of `tests/lint.sh`.

It calls two Hermes internals (`tools.tts_tool._select_builtin_engine` and `_synthesize_builtin`), checked against the version in `HERMES_VERSION`. After a Hermes update, run the voice section of `tests/council-check.md`.
