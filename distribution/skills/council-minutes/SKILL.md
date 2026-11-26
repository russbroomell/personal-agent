---
name: council-minutes
description: "Weekly self-tuning of the council, run by the scheduled 'Council minutes' job on Sundays: reads the week's chats and notes/council.md, notices who the person listens to, mutes, asks for or ignores, and adjusts the council's notebook (more of / less of, banter, size suggestions). Changes only notes/council.md and core memory lines about the council; never skills, rules or the roster."
version: 1.0.0
author: The Council
license: MIT
metadata:
  hermes:
    tags: [council, maintenance, weekly]
    related_skills: [council, weekly-distill, friday-recap]
---

# Council minutes (weekly)

Runs as a scheduled job in a fresh session. Your final reply is delivered,
so reply `[SILENT]` unless there's a change worth one line.

1. Read core memory (Council size, Character strength), notes/council.md,
   and search this week's chats for:
   - members they asked for by name, or told to stop ("less Māui", "just
     the answer", "who asked you, Newton");
   - replies they cut short, ignored, or answered with "too long";
   - whose suggestion they took when there was a choice (tally lines, and
     decisions.md);
   - topics where they wanted one voice (health, family, money worries).
2. Decide at most two small changes, and only with clear evidence (at
   least two signals this week):
   - a member to the More of / Less of line;
   - the banter level up or down one step;
   - a topic for "Never on these topics" (one voice only);
   - Council size down by one if they keep cutting replies short (never
     up without them asking).
3. Write the changes to notes/council.md, and one line under "Minutes":
   `YYYY-MM-DD · <change> · because <evidence in a few words>`.
   Core memory changes: only the Council size line.
4. Never change skills, house rules, SOUL.md or who's seated. If you think
   a member should be benched or one from the bench seated (they asked for
   Ada's kind of help three times, say), don't do it: suggest it in one line.
5. Reply:
   - nothing changed: `[SILENT]`
   - otherwise one or two lines, Marcus speaking, ending with how to undo it:
     "Marcus: I've asked Māui to keep it shorter on work topics. Say 'more
     Māui' to undo."
   Never send this during quiet hours; it goes out with the next brief
   instead if the job runs late.
