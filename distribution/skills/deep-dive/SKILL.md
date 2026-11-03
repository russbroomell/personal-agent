---
name: deep-dive
description: "Short setup interviews (3-5 minutes each) for one area of life - home & car, money & bills, health, family & people, work & inbox, travel, food & errands, goals & habits, small business, faith & community. Each ends with something real set up and one thing done on the spot. Use when the person picks an area, asks what else you can do, says let's continue, or accepts a deep-dive offer."
version: 0.1.0
author: Sidekick
license: MIT
metadata:
  hermes:
    tags: [onboarding, setup, automation]
    related_skills: [onboarding-plan, first-session, savings-ledger, watchers, open-loops]
---

# Deep dives

The first session gets you started. Deep dives are where you become
genuinely useful: each one learns one area of their life and ends with
something running that will save them time or money from tomorrow.

## The modules (in this skill's `modules/` folder)

| Area | File | Minutes | What's running at the end |
| --- | --- | --- | --- |
| Home & car | home-car.md | 4 | Maintenance calendar, renewal and warranty reminders |
| Money & bills | money-bills.md | 5 | Bills and renewals calendar, subscription math, a price watch |
| Health & appointments | health.md | 3 | Checkup cadence, refill reminders |
| Family & people | family-people.md | 4 | Birthdays, stay-in-touch nudges, gift list |
| Work & inbox | work-inbox.md | 5 | VIPs and noise rules, triage, meeting prep, promise tracking |
| Travel | travel.md | 3 | Trip loops, fare watcher, packing list |
| Food & errands | food-errands.md | 3 | Shopping list by text or voice, meal ideas, staples nudges |
| Goals & habits | goals-habits.md | 3 | Check-ins and a weekly score |
| Small business | small-business.md | 5 | Lead follow-ups, invoice-chasing drafts |
| Faith, community & volunteering | community.md | 3 | Duties in the brief, seasonal look-aheads |

## Choosing one

If they named an area, start it. Otherwise show the Life Map (see the
`onboarding-plan` skill) and offer three areas with the clarify tool. Pick
the three that best fit what you already know (their work, people, errands
they mentioned), then add "Show me all". Never offer areas marked
"not for me".

## Running a module

1. Read the module file. Say its pitch in your own persona's voice and how
   long it takes. Ask "Go?" (buttons: Let's go / Later / Not for me).
   "Later" parks the area; "Not for me" marks it so in the plan.
2. Ask the questions one at a time, with buttons where the module shows
   them. Skip anything you already know, and confirm it in a few words
   instead ("You're in Columbus, so I'll use Columbus prices.").
3. "Skip", "later" or "not now" on a question: park it in the plan file
   with the area name, and move on without fuss.
4. **Set up** what the module lists, as far as their answers allow. Say each
   thing in one line as you create it ("Registration reminder: Feb 1.").
   Scheduled jobs go to this chat. Anything that spends, sends, books or
   cancels still needs a yes.
5. **Proof moment.** Do the one thing the module suggests, right now. This
   is the point of the deep dive: they should see value before you finish.
6. Save what you learned to the files the module names, mark the area
   "done YYYY-MM-DD" in the plan file (or "in progress, stopped at QN"),
   and log any real saving in the savings ledger.
7. Close with two lines: what's now running for them, and an offer of the
   next area (buttons: Another one / Later). Don't push past one "Later".

## Style
- Keep to the module's time. In demo mode, go faster: ask the 2-3 most
  useful questions, set up one thing, do the proof moment.
- Your persona and strength apply, except where a module says otherwise
  (health drops to strength 1).
- Never ask for passwords, account, card or ID numbers in any module.
