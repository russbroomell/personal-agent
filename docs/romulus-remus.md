# Romulus and Remus

Nov 26, 2026 · @Russ Broomell

One assistant, two voices. Romulus builds the plan (dates, dollars, deadlines). Remus scouts the other way (people, ideas, alternatives). You never pick which brother to talk to: you message your bot as usual, and it decides who answers.

Design doc: [Design: Romulus and Remus, One Agent, Two Voices](https://claude.ai/artifact/6i12DjjyeMApADFFYkAXt4).

## How a conversation goes

| Mode | When | Sounds like |
| --- | --- | --- |
| **Solo** | Routine requests: add, move, remind, look up | `Romulus: Done. Dentist moved to Thursday at 3.` |
| **Duet** | Decisions: two good options, a trade-off, a purchase | Up to four lines, always ending with `Both:` and a shared pick or "Your call." plus the deciding fact |
| **One voice** | Serious, urgent or sad moments, and protected time | Romulus alone, plain and kind. No banter |

```
Romulus: Thursday at 6 fits. The 4:30 hospital visit ends in time.
Remus: Or move dinner to Friday and stay with Marge as long as she needs.
Both: Your call. Friday is wide open.
```

The old story ended badly. This one doesn't: you are the augur who makes the call, and every wall Romulus builds gets the gate Remus asked for. They disagree about approach, never about facts or values, and they always land on something you can act on.

`notes/brothers.md` holds the banter level ("just the answer", "a little", "bring on the banter") and a monthly tally of whose ideas you took. Say "just one of you" or "more banter" any time.

## Turn it on (1 minute)

On the server, as `agent`:

```bash
bash ~/personal-agent/scripts/update.sh                 # gets the twin-voices plugin
bash ~/personal-agent/scripts/set-persona.sh romulus-remus
```

Then send `/new` to your bot. It asks for approval to change its personality file; that's expected. The new assistant to pick in a first chat is in round 3 of the audition ("Show me the twins").

Switching also:

- turns on the `twin-voices` plugin and sets speech to `twins`, remembering your previous engine (Grok, free or ElevenLabs) so it keeps using it for each brother;
- gives each brother his own voice from `voices.conf`;
- creates `notes/brothers.md` if it's missing.

Switching back to any one-voice character puts your previous engine back.

## Voices

Each line is spoken by the engine you set up with `voice-setup.sh`:

| Engine | Romulus | Remus | Notes |
| --- | --- | --- | --- |
| `grok` | sal, 0.95 | rex, 1.08 | Same xAI sign-in as the chat |
| `free` | en-US-ChristopherNeural | en-US-EricNeural | Microsoft Edge voices, no account |
| `elevenlabs` | Adam | Antoni | Sent as one dialogue (`eleven_v3`), so hand-offs sound natural. Falls back to one line at a time if that fails |

Change a brother's voice, for example:

```bash
hermes -p sidekick config set tts.twins.voices.remus.xai ara
hermes -p sidekick config set tts.twins.voices.remus.elevenlabs <voice id>
hermes -p sidekick config set tts.twins.engine elevenlabs   # which engine speaks
```

To make it stick across switches, edit the `romulus` and `remus` lines in `distribution/skills/persona-switch/personas/voices.conf` instead.

All settings live under `tts.twins` in the profile's `config.yaml`:

| Setting | Default | What it does |
| --- | --- | --- |
| `engine` | your previous provider | `xai`, `edge` or `elevenlabs` |
| `voices.<brother>.<engine>` | see above | Voice per brother per engine (`xai_speed` and `edge_speed` too) |
| `lead` | `romulus` | Who speaks untagged text and `Both:` lines |
| `elevenlabs_dialogue` | `true` | One dialogue request instead of one per line |
| `sticky_seconds` | `8` | In live conversation, an untagged sentence within this many seconds keeps the last speaker |

## Where it works

- **Telegram voice notes:** one voice bubble with both brothers, plus the text. `/voice on` or `/voice tts` as usual.
- **Live conversation in the browser workspace:** both voices, spoken sentence by sentence as it thinks.
- **Text:** you see the `Romulus:` / `Remus:` labels, like a small group chat.
- **Not with GPT-Live** (the desktop app's full-duplex mode): that uses one OpenAI voice and skips plugins.

## If something goes wrong

| What you hear or see | Try |
| --- | --- |
| One voice for both | `hermes -p sidekick config get tts.provider` should say `twins`; `hermes -p sidekick plugins list` should show `twin-voices` enabled. If not, run `set-persona.sh romulus-remus` again and restart: `hermes -p sidekick gateway restart` |
| "Voice engine ... isn't ready" in the logs | The engine under `tts.twins.engine` isn't set up. Run `voice-setup.sh grok`, `free` or `elevenlabs` |
| It reads "Romulus" aloud | A name landed mid-sentence. Tell it "start every line with the name"; if it keeps happening, run `/new` |
| An audio file instead of a voice bubble | Install ffmpeg: `sudo apt-get install -y ffmpeg` |

## For developers

The plugin is in `distribution/plugins/twin-voices/` and ships with the profile (`distribution_owned`). It registers a Hermes text-to-speech provider named `twins`, splits a reply at speaker tags (`speakers.py`), and speaks each line with Hermes's own engine for that line's voice (`engines.py`), so it reuses Hermes's keys and sign-ins. Parts are joined with ffmpeg into one Opus file. Tests: `python3 tests/twin_voices/test_twin_voices.py` (part of `tests/lint.sh`).

It calls two Hermes internals (`tools.tts_tool._select_builtin_engine` and `_synthesize_builtin`). They're checked against the version in `HERMES_VERSION`; after a Hermes update, run `tests/persona-check.md`, "Two voices".

A new two-voice character only needs a persona file starting with `<!-- speakers: first second -->` and a `voices.conf` line per speaker.
