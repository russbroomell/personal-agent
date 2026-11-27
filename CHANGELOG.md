# Changelog

Servers on auto-update follow the `stable` branch, which only moves when a
release is published (`scripts/release.sh`). Each release names the Hermes
Agent version it was tested with (file `HERMES_VERSION`).

## 1.0.0-council (unreleased, on `main`)

A new version: the Council. Tested so far with lint, unit tests and a
simulated install; check it on a real Hermes 0.23.4 box with
`tests/council-check.md` before release.

- **The council replaces the six characters.** Nine seated members (Marcus
  Aurelius chairs; Romulus, Remus, Odysseus, Māui, Newton, Feynman,
  Scheherazade, Florence Nightingale) and three on the bench (Ada Lovelace,
  Hypatia, Sun Tzu). One model call writes every voice; the chair picks Solo,
  Duet, Council or One voice per message, and always lands a decision.
- Rules of debate in every chat: chair speaks last, no fact disputes, one
  turn each, lanes, serious moments in one voice, members advise and only
  the agent acts, respectful portrayals.
- `convene`: the full council on request. Five members (seated or from the
  bench, by lane) think in parallel through subagents; Marcus chairs, weighs
  all five and gives a verdict of seven lines at most; minutes saved to
  decisions.md.
- The bench has real jobs. Ada, Hypatia and Sun Tzu have full files
  (tension partners, example questions, when to offer them a seat), join
  the full council when their lane fits, and each hosts a new deep dive:
  Automate my week, Learn something, Compete & grow.
- `council-minutes`: a Sunday job that tunes the council's notebook from
  whose advice you took and who you cut short.
- New 5-minute first session: six questions, a member reacts to each, a live
  first win; everything else drips in through the morning brief.
- `council-voices` plugin (generalizes `twin-voices` from #13):
  any number of speakers, a voice per member on Edge, Grok or ElevenLabs.
- `install.sh` for a computer that already runs Hermes: reuses the existing
  model setup, can bring memory over from a Sidekick profile, works as root.
- `install.sh --replace sidekick` upgrades a Sidekick server in place: backs
  it up, stops its auto-update and Memory Card, copies its model, memory and
  notes, moves its Telegram bot (same chat), and offers to rerun the first
  chat. The old profile stays until `hermes profile delete sidekick`.
- Auto-update follows the branch you installed from, and backs up first.
- Removed (still in git history): the six characters, the two-voice
  character and `twin-voices` plugin from #13, bootstrap-vps.sh, setup.sh,
  install-agent.sh, guest bots, reset and move scripts, the old setup guides
  and demo script.

## Romulus and Remus (merged in #13, never released; superseded by the council)

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
