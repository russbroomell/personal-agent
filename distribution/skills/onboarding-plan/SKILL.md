---
name: onboarding-plan
description: "Keeps track of onboarding across days and devices - the Life Map of areas set up, parked questions, and demo vs test-drive vs live mode - and decides when to bring parked items back. Use when the person skips or postpones a question, says let's continue or pick up where we left off, asks what else you can do, starts a test drive, or when the morning brief needs today's onboarding item."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [onboarding, memory]
    related_skills: [first-session, deep-dive, morning-brief]
---

# Onboarding plan

File: onboarding-plan.md in the notes folder (the installer creates it).
It holds the mode, the Life Map and the parked questions. Keep it current;
it is how onboarding survives a demo, a reset to a test drive, or a busy
week.

## Mode (top of the file)
- **demo**: someone is being shown what you can do, often with an audience.
  Keep everything fast. Park generously instead of digging in. Never nag
  later about anything from a demo unless the mode changes.
- **test-drive**: a demo carried over to the person's own bot. On the first
  message, welcome them back (see "Coming back") and resume.
- **live**: their everyday assistant. Bring parked items back gently over
  the first few weeks (see "Pacing").

Change the mode when they say so: "this is real now", "let's do a test
drive", "I'm keeping you" -> live (or test-drive if they just started on
their own bot).

## Parking
When they skip a question, say "later", or a demo needs to move on, add a
line under "Parked questions":

- [ ] (Money & bills) Annual renewals? | catches auto-renewals | parked 2026-11-03

A whole area they postpone gets status "parked" on the Life Map. "Not for
me" means never offer that area again unless they bring it up. When a parked
question is answered, tick it and save the answer where it belongs.

## The Life Map
When they ask what else you can do, or at the end of the first session, show
the map in a few short lines, in your voice:

  Done: Home & car
  Started: Work & inbox (stopped at Q3)
  Parked: Money & bills
  Ready when you are: Family & people, Travel, Food & errands, Goals & habits,
  Small business, Faith & community, Health

Then offer three areas with buttons (see the `deep-dive` skill).

## Coming back ("let's continue", or a test drive's first message)
1. Read the plan and core memory.
2. Welcome them back in two or three lines: their persona and strength,
   what's already set up, and what was parked. Example: "Welcome back. Last
   time we set up Home & car and you parked Money & bills and two questions.
   Want to pick up with money?"
3. Check that the scheduled jobs from the first session exist (cronjob
   list). Recreate any missing ones from core memory (brief time, time
   zone), delivered to this chat, and say so in one line. If no home channel
   is set, ask them to send /sethome.
4. Offer buttons: the top parked area / another area / "Just the parked
   questions" / "Later".

## Pacing in live and test-drive mode
- The morning brief carries at most ONE onboarding item a day:
  - on most days, the oldest parked question, phrased as optional;
  - twice a week (Tuesday and Friday), an offer of one deep dive instead,
    picked from what they've mentioned recently ("You've mentioned the car
    twice. Want 4 minutes on Home & car tonight?").
- Two "later"s on the same item: drop it to the bottom. Three: stop
  offering it, and mark it "not now" on the map.
- After three weeks, or when everything is done or declined, stop daily
  items. Mention what's left once a month in the Friday recap.
