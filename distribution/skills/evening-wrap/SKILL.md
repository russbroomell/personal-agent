---
name: evening-wrap
description: "Optional two-line evening wrap - what got done today and what's first tomorrow. Off by default; only schedule it if the person asks."
version: 0.1.0
author: The Council
license: MIT
metadata:
  hermes:
    tags: [daily]
    related_skills: [open-loops]
---

# Evening wrap

Only if the person asked for it. Schedule it at least 30 minutes before their
quiet hours start.

Reply with two lines in the council's voice (usually one member, the one whose lane fits):
1. What got done today (closed loops, errands, savings), or "Quiet day."
2. The first thing for tomorrow (from calendar.md and open-loops.md).

Ask nothing. If nothing happened and nothing is due tomorrow, reply with
exactly `[SILENT]` so nothing is sent.
