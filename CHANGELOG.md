# Changelog

Servers on auto-update follow the `stable` branch, which only moves when a
release is published (`scripts/release.sh`). Each release names the Hermes
Agent version it was tested with (file `HERMES_VERSION`).

## Unreleased

Tested with Hermes Agent 0.23.4.

- New character: **Romulus and Remus**, one assistant with two voices.
  Solo replies for errands, a four-line Duet on decisions that always ends
  with "Both:" and a pick or "Your call.", and one plain voice for serious
  moments. Banter level and a tally of whose ideas you took live in
  `notes/brothers.md`. Third audition round in the first session.
- New plugin `twin-voices` (ships with the profile, on only for two-voice
  characters): speaks each "Name:" line in that speaker's voice with Grok,
  free Edge or ElevenLabs voices and sends one Telegram voice bubble; with
  ElevenLabs, lines go out as one natural dialogue.
- `voice-setup.sh elevenlabs`: ElevenLabs speech both ways (asks for the
  key once, stored in the profile's `.env`).
- `build-soul.sh` restores the previous voice engine when switching from a
  two-voice character back to a one-voice one.

## 0.1.0 (2026-11-10)

First public release. Tested with Hermes Agent 0.22.6 on a 4 GB OVH VPS
(Ubuntu 24.04).

- Six characters with a strength dial, cameos and crossovers; write your own
  in Markdown.
- First-session interview, Life Map and ten deep-dive setups; skipped
  questions are parked, not lost.
- Morning brief, open loops, watchers, Friday recap with time saved,
  weekly memory tidy-up, inbox triage, meeting prep, share card, kill switch.
- The bot's own browser screen, watchable and take-over-able from a laptop
  or phone over Tailscale; live voice conversation and Telegram voice notes.
- Memory Card: every remembered line, editable.
- One-command setup with yes/no at each optional step, a health check with
  fixes, nightly auto-update with rollback, a reset button with snapshots,
  and guest test-drive bots.
