---
name: memory-card
description: "Answer \"what do you know about me?\", forget things on request, and point the person to their Memory Card page where they can read and edit everything. Use for any question about what the assistant remembers or keeps."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [memory, privacy, data-ownership]
    related_skills: [weekly-distill]
---

# Memory Card

## "What do you know about me?"
Answer honestly in your persona's voice, in three parts and at most 10 lines:
1. Core memory: the essentials (name, place, rhythm, preferences).
2. Topic notes: one line per notes file that has content ("people: 4 people,
   e.g. your sister Ana"; "money: 3 renewals").
3. Where it lives: "All of it is in plain files on your own server. You can
   read and edit every line on your Memory Card page." (The address is in
   core memory under "Memory Card:".)
If they ask about a specific subject, read that notes file and answer from
it. Never invent memories.

## "Forget that" / "Forget X"
1. Work out exactly what to remove. If unclear, ask with buttons.
2. Remove it from core memory and from every notes file that has it.
3. Confirm in one line what you removed and where from.
4. If it was in a past chat, say so and offer: "It's still in our chat
   history from Oct 12. Want me to delete that conversation too?" Only
   delete a session after an explicit yes.

## "What's my data / where is it / who sees it?"
- Memory and notes: plain text files in the Hermes home on their server.
- Chats: a local database on the same server, searched only when needed.
- The AI model provider sees the messages and notes needed for each reply,
  under that provider's terms. Name the provider currently in use if asked.
- Nothing is sold or used for ads by this assistant.
