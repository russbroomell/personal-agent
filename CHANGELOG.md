# Changelog

Servers on auto-update follow the `stable` branch, which only moves when a
release is published (`scripts/release.sh`). Each release names the Hermes
Agent version it was tested with (file `HERMES_VERSION`).

## Unreleased

- Health check: a new "Leftovers from earlier installs" section. It flags
  a Hermes gateway run by another user (for example an old install under
  `ubuntu`, which can hold the workspace port and answer the same bot),
  ports held by another user's process, old Sidekick services (a Memory
  Card page for a deleted profile, the old nightly updater), Memory Card
  pages still running for a folder that's gone, and the council's own
  Memory Card page not running. Each comes with the command to fix it.

## 1.0.0 (2026-11-28)

The Council: a new version that replaces the six-character Sidekick.
Tested with Hermes Agent 0.23.4: lint, unit tests for both plugins,
simulated installs, and an install on a real 4 GB OVH VPS (Ubuntu). The
full behaviour checklist (`tests/council-check.md`) is still to be run on
a live bot.

**Upgrading a Sidekick server:** it won't switch by itself. Its old
updater tries this release, can't rebuild the old characters, and rolls
back. Run the upgrade once, by hand (README, "Upgrading from Sidekick"):
`install.sh --replace sidekick`.

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
- **Discord first, with a private council for each person.** New
  `council-privacy` plugin: every Discord user who DMs the bot gets their
  own first chat and private folder (`notes/people/discord-<id>/`), and
  nothing from a DM appears in a public channel unless that person asks
  to share their own information there. Enforced in code too: tool calls
  that would read another person's folder, search everyone's notes or
  chats, write shared core memory, or read the session database are
  blocked on Discord. Public channels answer without an @mention. The
  installer leads with Discord, asks who may use it, and `--replace`
  moves Discord bots too; the health check has a Discord section.
- Simple questions about the bot itself get Marcus alone.
- `install.sh` puts the council in Hermes's **default profile** by default,
  using the model and Telegram bot already set up there. It backs the
  profile up first, keeps any earlier personality as
  `SOUL.md.before-council`, adds the skills and plugin (tracked in
  `council-files.txt`, so updates can remove dropped ones), and applies
  settings one at a time instead of replacing `config.yaml`. `--profile
  NAME` still gives a separate profile; every script remembers which one
  was used (`scripts/lib/profile.sh`).
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
