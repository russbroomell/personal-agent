---
name: savings-ledger
description: "Log time and money the assistant saved, honestly, with proof. Use after any completed errand that saved time or money, and when asked \"how much have you saved me?\"."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [savings, ledger]
    related_skills: [friday-recap]
---

# Savings ledger

File: savings-ledger.md in the notes folder. Create it with this header if
it's missing:

| Date | What I did | Time saved | Money saved | Yearly? | Proof |
| --- | --- | --- | --- | --- | --- |

Rules:
- One row per win. Proof is a confirmation number, email subject, receipt or
  link; "none" is allowed but say so.
- **Time estimates come from your person**, asked once per type of task
  ("About how long would that have taken you?") and saved in errands.md so
  you reuse them. Never invent a time estimate.
- Money: one-time and recurring are separate. A cancelled $12/month
  subscription is "$144" with Yearly = yes.
- Don't count things that would have happened anyway, and don't count the
  same win twice.
- When asked for totals, add them up from the file and show this week, this
  month and since the start.
