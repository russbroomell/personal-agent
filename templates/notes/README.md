# Topic notes

The middle layer of memory: one short file per subject, read only when that
subject comes up. Core facts live in core memory (USER.md and MEMORY.md); the
full chat archive is searched on demand. You can read and edit all of these on
the Memory Card page.

`scripts/install-agent.sh` copies these templates into the agent's notes
folder (`~/.hermes/profiles/sidekick/notes/`), never overwriting existing
files. Core memory holds the folder's path ("Notes folder: ...").

Rules for the assistant (also in the house rules):
- One subject per file, plain bullets, newest facts at the top of each section.
- Keep each file to a page or two. Merge and trim rather than append forever.
- Date anything that might change ("2026-10: furnace serviced by ...").
- Nothing here that core memory says never to keep.

Starter files: people.md, home.md, money.md, calendar.md, errands.md,
decisions.md. The skills add profile.md, open-loops.md, watchers.md,
savings-ledger.md and _last-distill.md as needed. onboarding-plan.md (mode,
Life Map and parked questions) is seeded on install and on every reset.
