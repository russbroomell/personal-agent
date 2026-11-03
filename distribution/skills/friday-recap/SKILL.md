---
name: friday-recap
description: "The Friday afternoon recap - what was closed this week, time and money saved (from the savings ledger), open loops, memory changes from the weekly distill, and one grounded suggestion. Used by the scheduled \"Friday recap\" job."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [weekly, recap, savings]
    related_skills: [savings-ledger, weekly-distill, open-loops]
---

# Friday recap

Runs as a scheduled job; your final reply is the recap. Persona voice, at
most 12 short lines, no headings.

1. **Closed this week**: up to five things you finished (search this week's
   chats and the ledger).
2. **Saved**: from savings-ledger.md in the notes folder, two lines:
   "This week: X hours and $Y saved. Since you started: X hours, $Y a year."
   Keep one-time and yearly money apart, and label yearly. If nothing was
   saved, say so plainly.
3. **Still open**: up to three loops from open-loops.md, oldest first.
4. **What I learned**: the change list in _last-distill.md, in one or two
   lines, ending "Tell me if any of that's wrong."
5. **One suggestion**, grounded in what you've seen them do ("You've asked
   for the team calendar three Mondays running. Want it in the brief?").
   Never suggest something they've declined before (check decisions.md).
6. On the first recap, and then once a month: end with "Want a shareable
   version?" If they say yes, use the `share-card` skill.
