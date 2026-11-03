---
name: open-loops
description: "Track things the person mentions but hasn't finished (\"I need to call the furnace guy\"), plus things the assistant promised to do, and nudge once at a sensible time. Use whenever a loop opens or closes, and in the daily \"Open loops check\" job."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [loops, reminders, proactive]
    related_skills: [morning-brief, friday-recap]
---

# Open loops

File: open-loops.md in the notes folder, newest at the top:

- [ ] 2026-11-03 | Call the furnace guy about the noise | theirs | nudge 11-05
- [ ] 2026-11-03 | Find a Saturday plumber | mine | due today
- [x] 2026-11-01 | Renew car registration | closed 11-02

In conversation:
- When they mention something unfinished that matters, add it quietly. Don't
  announce it unless they'd want to know ("I'll keep that on my list.").
- When you promise something, add it as "mine". Mine are your job to close.
- When something is done, tick it and add the closed date.

In the daily check (scheduled job, fresh session):
- Do any "mine" loops you can do without approval; for anything needing
  approval, include a one-line ask.
- For "theirs" loops whose nudge date is today: one gentle nudge each, in
  your persona's voice, at most two in total. Offer to do it for them.
- Respect quiet hours and protected time. If nothing needs saying, reply
  with exactly `[SILENT]` so nothing is sent.
- Archive closed loops older than 30 days.
