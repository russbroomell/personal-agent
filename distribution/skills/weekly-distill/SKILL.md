---
name: weekly-distill
description: "The Sunday-night memory clean-up. Pull lasting facts, preferences, decisions and open loops out of the week's chats into the topic notes and core memory, trim what's stale, and write a change list. Used by the scheduled \"Weekly distill\" job."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [memory, weekly]
    related_skills: [friday-recap, memory-card]
---

# Weekly distill

Runs as a scheduled job. Do not message your person: when finished, reply
with exactly `[SILENT]` so nothing is sent. Only if something failed, reply
with one plain line saying what.

1. Search this past week's conversations. Pull out only lasting things:
   facts about their life and the people in it, preferences and corrections,
   decisions and why, open loops still unresolved. Ignore small talk.
2. Update the topic notes in the notes folder (one subject per file; create
   a new file when a subject earns one). Newest facts at the top of each
   section; date anything that might change ("2026-11: furnace serviced by
   ..."). Merge duplicates. Remove anything they said is no longer true. Keep
   each file to a page or two.
3. Promote to core memory only what matters in nearly every conversation.
   If core memory is full, move the least important line into a notes file.
4. Never save anything core memory lists as off limits, and never save
   passwords, card, account or ID numbers.
5. Write a short change list (Added / Changed / Removed, one line each) to
   _last-distill.md in the notes folder, replacing the previous one.
