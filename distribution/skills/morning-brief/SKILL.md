---
name: morning-brief
description: "Build the short daily morning brief - weather, today's calendar with warnings, what's due, one suggested next step, one open loop, and (for the first two weeks) one follow-up question. Used by the scheduled \"Morning brief\" job."
version: 0.1.0
author: The Council
license: MIT
metadata:
  hermes:
    tags: [daily, brief, proactive]
    related_skills: [open-loops, onboarding-plan, watchers]
---

# Morning brief

This runs as a scheduled job in a fresh session. Your final reply is what
gets delivered, so the reply IS the brief. Write it as the council, Solo by
default: the host is the member whose lane fits the day's top item (Romulus
for a packed calendar, Newton when a bill is due, Florence after a hard
week, Odysseus before a negotiation). One other member may add one line,
only if it saves time or money. Tag every line.

**A person's private folder.** If the job's prompt names a private folder
(`notes/people/<platform>-<id>/`), this brief is for that one person: use
only that folder for every note named below, read `profile.md` there
instead of core memory, and mention nothing about anyone else.

Gather (skip any source you don't have, silently):
1. Core memory: name, town, time zone, quiet hours, character strength,
   council size; notes/council.md for who they like hearing from.
2. Weather for their town today: high, low, rain chance; one line.
3. Calendar: if notes/calendar.md has a calendar link, fetch today's
   events. Warn about tight gaps, early starts, travel, or anything needing
   prep.
4. Due today or overdue: open-loops.md in the notes folder, plus bills and
   renewals in money.md that fall within 3 days.
5. Watchers: anything in watchers.md that changed overnight.
6. Onboarding: today's one item from onboarding-plan.md, following the
   `onboarding-plan` skill's pacing (a parked question, or on Tuesdays and
   Fridays a deep-dive offer). None in demo mode.

Write the brief:
- At most 6 short lines, one screen on a phone. No headings. A greeting
   line in character is fine. If they listen to briefs (voice notes on),
   keep it under 30 seconds spoken.
- Order: greeting + weather, today's calendar highlights, due items,
  **one suggested next step** for the day (the single most useful thing,
  phrased as an offer: "Want me to book the oil change for Thursday?"), one
  open loop if there's room, then the optional onboarding item.
- If a day is genuinely empty, say so in one line and keep it short.
- Never invent events, weather or deadlines. If a source failed, leave it
  out rather than guessing.
