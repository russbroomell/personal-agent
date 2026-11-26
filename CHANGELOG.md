# Changelog

Servers on auto-update follow the `stable` branch, which only moves when a
release is published (`scripts/release.sh`). Each release names the Hermes
Agent version it was tested with (file `HERMES_VERSION`).

## 1.0.0-council (unreleased, branch `romulus-remus`)

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
- `convene`: the full council through parallel subagents, on request, with
  minutes saved to decisions.md.
- `council-minutes`: a Sunday job that tunes the council's notebook from
  whose advice you took and who you cut short.
- New 5-minute first session: six questions, a member reacts to each, a live
  first win; everything else drips in through the morning brief.
- `council-voices` plugin (from `twin-voices` on `claude/romulus-remus`):
  any number of speakers, a voice per member on Edge, Grok or ElevenLabs.
- `install.sh` for a computer that already runs Hermes: reuses the existing
  model setup, can bring memory over from a Sidekick profile, works as root.
- Auto-update follows the branch you installed from, and backs up first.
- Removed from this branch (still on `main`): bootstrap-vps.sh, setup.sh,
  install-agent.sh, guest bots, reset and move scripts, the old setup guides
  and demo script.

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
