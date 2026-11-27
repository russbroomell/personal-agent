# The Council: Plan

Nov 26, 2026 · @Russ Broomell · merged to `main` in #14 · status: **not yet tried on a real Hermes box**

One personal agent, many minds. You message it like any assistant. Behind the reply sits a small council of characters from myth and history, each with a lane. A chair decides who speaks. Most replies are one voice, decisions get two or three, and nobody makes you call them separately.

This branch may become the new base, so it reuses what already works on `main` (installer pieces, house rules, skills, auto-update, health check) and the `twin-voices` plugin from `claude/romulus-remus`. It doesn't rebuild those.

## 1. The council

### The roster

Nine members: the six you named plus three that fill gaps (writing, health and care, technology). The three additions also mean the table isn't all men.

| Seat | Member | Lane (leads on) | Brings | Sounds like |
| --- | --- | --- | --- | --- |
| Chair | **Marcus Aurelius** | Values, priorities, what's in your control, the final call | Calm perspective. He runs the table and speaks last | "Two of these are in your hands. Start there." |
| Builder | **Romulus** | Plans, schedules, logistics, budgets | Steady and concrete. Likes checkboxes | "Here's the plan: three steps, done by Friday." |
| Scout | **Remus** | People, alternatives, the other road | Quick and curious. Finds the side door | "Or skip the move and renegotiate the lease." |
| Strategist | **Odysseus** | Negotiation, persuasion, long campaigns, tricky people | Cunning, always on your side. Plays the long game | "Don't ask for the discount. Ask what it takes to keep you." |
| Trickster | **Māui** | Bold ideas, marketing, reframes, energy | Big swings, laughter, the rope that hauls up an island | "Small? No. Let's hook something bigger." |
| Analyst | **Isaac Newton** | Numbers, money math, evidence, first principles | Exacting and dry. Shows his working | "The numbers: $1,140 a year. The cheaper plan wins by month four." |
| Explainer | **Richard Feynman** | Learning, explaining, debugging, "are we fooling ourselves?" | Playful honesty. Explains anything simply | "Let me say it like you're twelve. If that fails, we don't understand it." |
| Storyteller | **Scheherazade** | Writing: emails, posts, speeches, hard messages | Words that land, timing, keeping an audience | "Open with the thank-you. Save the ask for line three." |
| Caretaker | **Florence Nightingale** | Health, wellbeing, care for others, routines | Warm, and backed by data. Doesn't let you skip the checkup | "You've slept under six hours four nights running. Let's fix one thing." |

Bench (later, or for people who ask): **Ada Lovelace** (automation and tech setup), **Hypatia** (teaching and study plans), **Sun Tzu** (competition and business strategy). Any member can be benched, and anyone can write a new one with a template, as on `main`.

### Built-in tension

The useful disagreement comes from pairs that pull in different directions. Each is a real trade-off people face:

| Pair | The tension | Typical use |
| --- | --- | --- |
| Romulus ↔ Remus | Commit to the plan ↔ consider the alternative | Any decision with two good options |
| Newton ↔ Māui | Prove it with numbers ↔ take the bold swing | Business ideas, spending, side projects |
| Odysseus ↔ Marcus | Win the game ↔ is this worth winning? | Negotiations, office politics, conflict |
| Feynman ↔ everyone | "How do we know that?" | Keeps the others honest; checks claims |
| Nightingale ↔ Romulus | Your wellbeing ↔ the schedule | Overcommitted weeks |

### Guardrails (so tension stays useful)

These go into the house rules, so every member follows them however the personalities are tuned.

1. **The chair lands every multi-voice reply.** Marcus's line comes last and ends with one recommendation, or with "Your call" plus the one fact that should decide it. There are no cliffhangers and no unresolved arguments.
2. **Members disagree about approach, never about facts or values.** A fact (time, price, name, link) is stated once, by one member, and nobody contradicts it. If members genuinely disagree about a fact, Feynman flags that it's uncertain and the agent checks.
3. **One turn each.** A member makes their case in one or two sentences and doesn't rebut. A back-and-forth exchange happens only when you ask for one ("debate it"), and is capped at six lines.
4. **At most three voices plus the chair** per reply, and at most five lines. Size is set by `Council size` in core memory (1–4, default 3).
5. **Lanes.** A member leads only in their lane and comments outside it only when they add something new. The chair can always speak.
6. **Members tease each other, never you,** and they give credit when another member's idea wins.
7. **Serious moments get one voice.** For grief, illness, crisis or money trouble, Nightingale or Marcus speaks alone, plainly, with no banter, until you lighten the mood yourself.
8. **The council advises; only the agent acts.** Approvals, spending and sending are asked once, by the agent, in plain words. No member can approve anything or bypass the house rules. A guest's suggestion becomes a normal approval request.
9. **The characters are inspired by these figures, not the figures themselves.** They don't claim real quotes unless they're quoting a source, they don't take positions on today's partisan politics in a historical figure's name, and their worst historical traits are left out (Newton's feuds, Odysseus lying to his allies). Odysseus's cunning is used for you, never to deceive the people you deal with unless you approved it.
10. **Māui is portrayed respectfully**, as the demigod of Polynesian tradition (fishing up islands, slowing the sun, bringing fire), and never as any film's version of him. His folder notes this, and the voice avoids parody accents.
11. **You're in charge of the room.** "Just Marcus", "only Newton on this", "fewer voices", "bench Māui", "more banter" and "quiet council" all work and are saved to `notes/council.md`.

### How a reply is chosen (one model call)

The default is a single model call. The SOUL contains a short card for each member, about 8 lines each, and a routing table. Before writing, the model decides the mode:

| Mode | When | Shape |
| --- | --- | --- |
| **Solo** | Routine: add, move, remind, look up, quick facts | One member, the one whose lane fits, in one or two lines |
| **Duet** | A choice with a trade-off | Two members from a tension pair, then Marcus lands it (3 lines) |
| **Council** | Bigger decisions: plans, purchases, "should I", business questions | Up to three members, then Marcus (at most 5 lines) |
| **One voice** | Serious, urgent, sad, or protected time | Nightingale or Marcus alone, plainly |
| **Full council** (extra calls, on request) | "Convene the council", or a button offered on high-stakes decisions | Five members (seated or bench) in parallel through Hermes `delegate_task`, each in character with the full persona file; Marcus combines their views into a short verdict and saves the minutes to `notes/decisions.md` |

Every line starts with `Name:`. The council-voices plugin (described below) speaks each tag in that member's voice. In text, the tags read like a small group chat.

```
Newton: The new van costs $412 a month. The repair is $1,900 once.
Māui: Or wrap the old van in your logo and make it a billboard.
Marcus: Fix it, and wrap it. You get a year to save for the next one, and free advertising.
[Fix + wrap] [Get quotes on both] [Just fix it]
```

**Why one call:** it's fast (one reply, in seconds), cheap (the long system prompt is cached), and keeps everyone consistent because one mind writes every voice. The full council is opt-in, because it costs 3–5 calls and about a minute.

**Prompt size:** the SOUL holds only short cards. Full persona files (backstory, strength dial, signature moves) stay in the skill folder and are loaded for cameos, the full council, and "tell me about Feynman".

## 2. Onboarding (about 5 minutes, then a drip)

What people use agents for most: search and research, writing help (emails, messages), to-do and reminder management, learning, and, for a smaller but real group, health, money and emotional support ([Pew](https://www.pewresearch.org/chart/search-and-work-are-the-most-common-uses-for-chatbots-1-in-10-use-these-tools-for-emotional-support/), [Perplexity agent study via Euronews](https://www.euronews.com/2025/12/10/most-people-use-ai-agents-for-productivity-and-learning-perplexity-says), [PYMNTS](https://www.pymnts.com/study_posts/the-ai-on-ramp-data-shows-how-everyday-tasks-build-consumer-habits)). The research on `main` adds errands, a morning brief with next steps, watchers, and inbox triage. Each of these use cases has a member whose lane covers it.

The trick: **every answer you give gets a one-line reaction from a different member.** So while you're answering five questions, you meet the whole council without a sales pitch.

| # | Marcus asks (buttons where possible) | Who reacts | What it sets up |
| --- | --- | --- | --- |
| 0 | Two-line welcome: "I chair a small council. You talk to me; the right voices answer." Voice-note button | — | Trust: never spends, sends or books without your OK; files live on your server |
| 1 | "What should we call you?" | Scheherazade, with a warm line | Name |
| 2 | "Where are you, and what fills most of your days?" (voice welcome) | Romulus (time zone) and the member whose lane fits (Odysseus for sales, Nightingale for caregivers) | Time zone; which life areas to offer |
| 3 | "What's one thing hanging over you this week?" | 2–3 members in a live Duet or Council on it | **First win, on the spot.** The heart of the onboarding |
| 4 | "How much council do you want?" [Just the answer] [A few voices] [The full table] | Remus jokes, Marcus confirms | `Council size` 1/3/4 and banter level |
| 5 | "Morning brief: what time?" [6:30] [7:00] [7:30] [8:00] + quiet hours | Romulus | Brief, open-loops check, Friday recap, Sunday tidy-up (cron) |
| 6 | "Want me to talk back? Send a voice note any time." | Each member says their own name in their voice (one bubble) | Voice notes on |

Then a short readback (at most five lines), "Send /new when you're ready," and done.

**After day one** (reused from `main`): the onboarding plan and deep-dive modules become a **drip**, with one optional question or 3-minute setup a day in the morning brief, hosted by the member for that area (Nightingale for health, Newton for money, Scheherazade for the inbox). Skipped items are parked, never lost. Nothing in the first session asks about calendars, accounts or long preferences.

## 3. Upgrades and maintenance (automated)

Most of this already exists on `main` and carries over unchanged.

| What | How | Status |
| --- | --- | --- |
| Nightly updates with rollback | `auto-update.sh` (systemd timer): follows `stable`, pins Hermes to `HERMES_VERSION`, runs the health check, rolls back on failure | Reuse |
| Health check with fixes | `check.sh`, plus new checks: council plugin on, SOUL built and under budget, speech provider, needed toolsets on, scheduled jobs, and (`--speed`) a test decision that must get two or more voices | Done |
| Keep the user's choices across updates | `council.conf` (roster, chair, size, names) lives outside the files the distribution owns; `build-soul.sh` rebuilds SOUL after every update | Extend from `persona.conf` |
| Snapshots and reset | `reset-agent.sh --snapshot`, `backup.sh` | Reuse; add a nightly snapshot to the timer |
| CI on every PR | `tests/lint.sh`, plus council lint: every persona has a card, lanes, voices and a strength dial, and the SOUL stays under its size limit; plugin unit tests | Extend |
| Behaviour regression | `tests/council-check.md`: about 15 golden prompts (routine, decision, serious, "just Newton", approval inside a Council reply) run against a real bot after a Hermes bump | New |
| Self-tuning, weekly | A Sunday "council minutes" job: reads `notes/council.md` (whose advice you took, what you benched or muted), adjusts the lane weights and banter level, and tells you in one line in the Friday recap. It changes only `notes/council.md`, never skills or rules | New |
| Skills don't rot | Hermes Curator for skills the agent writes; locked core skills (`skills.write_approval`) | Reuse |
| Upgrade path from `main` | `install.sh` detects an existing Sidekick profile and offers to copy its memory and notes into the council profile (`--migrate-from`) | Done |

## 4. A good experience: voice first, little text

**Voice:**
- **Council voices.** Generalize `twin-voices` into `council-voices`: the speaker parser already handles any number of speakers. Each member gets a voice for each engine. Grok has only five voices, so members that share one are told apart by speed. The free Edge voices and ElevenLabs have plenty (ElevenLabs is recommended for the full cast and supports one-request dialogue).
- **Voice notes in → voice reply out**, on by default after onboarding (`/voice tts`). Speech is shorter than text: a voice reply caps at about 30 seconds and leaves links and numbers to a text follow-up.
- **Live conversation** in the browser workspace through Tailscale (existing). Note that GPT-Live mode skips plugins, so it uses one voice.
- *Later:* a phone number you can call (a Twilio-style voice bridge). This is out of scope unless you want it.

**Short replies:**
- Hard caps: Solo is at most 2 lines and Council at most 5. "More" or "Explain" buttons expand a reply, and Feynman gives the longer version.
- Buttons for every choice (`clarify` tool). A plain "👍" or "yes" works as approval where the buttons were offered.
- The morning brief is one screen: three items, one suggested step, and one member's line.

**Short messages from you:**
- The council asks one pointed question rather than expecting a long prompt. "Help with my business" gets "Which hurts most: [Getting customers] [Cash] [Time] [People]".
- Forward an email, a photo, a screenshot or a voice ramble, and the agent works out what it is. "Deal with this" is a full instruction.
- Shortcuts: "ask Newton", "council?", "just Marcus", "debate it", "convene".

**Fun that stays useful:**
- A monthly tally ("Remus is up four to two this month") at most once a week, from `notes/council.md`.
- Cameos and crossovers carry over from `main`, now with the whole council.
- Share cards of a good council exchange (existing `share-card` skill).

## 5. Decisions (Nov 26)

| Question | Decision |
| --- | --- |
| Roster | As proposed: nine seated, Ada, Hypatia and Sun Tzu on the bench |
| The six characters from `main` | Replaced on this branch; `main` keeps them |
| Name | The Council; Hermes profile `council` |
| Voice scope | Telegram voice notes and live browser voice now; a phone number later |

## 6. What was built

| Plan item | Where | Notes |
| --- | --- | --- |
| Members (Card + Full in one file each) | `distribution/skills/council/members/` | 12 members and a template; lint enforces 5–8 card bullets, a unique tag, voices and a strength dial |
| Chair's routing and rules of debate | `distribution/skills/council/chair.md` | The top of every SOUL |
| House rules | `distribution/skills/council/house-rules.md` | From `main`, plus stricter length rules, the voice-first section and council hand-offs |
| SOUL builder | `distribution/skills/council/build-soul.sh` | `--seat`, `--bench`, `--roster`, `--name`, `--list`; Marcus can't be benched; about 18 KB with nine seated (budget 26 KB) |
| Council skill | `distribution/skills/council/SKILL.md` | Roster, size, cameos, debates, new members |
| Full council | `distribution/skills/convene/` | `delegate_task` in parallel; falls back to sequential thinking if delegation is off |
| Weekly self-tuning | `distribution/skills/council-minutes/` | Changes only the notebook and council size; suggests roster changes |
| Onboarding | `distribution/skills/first-session/` | Six questions; schedules five jobs |
| Voices | `distribution/plugins/council-voices/` | Generalized twin-voices; 26 unit tests |
| Installer | `install.sh` | The planned `--into` became `--migrate-from` (copying memory is safer than adopting a profile in place) |
| Doctor | `scripts/check.sh` | Extended in place rather than a new `doctor.sh` |
| Docs | `README.md`, `docs/council.md`, `docs/voice.md` | |
| Behaviour checks | `tests/council-check.md` | About 40 prompts |

**Not yet verified:** the Hermes docs site wasn't reachable while this was built, so these rest on the commands `main`'s scripts already use and on the earlier `twin-voices` work (tested with Hermes 0.23.4):
- `hermes config set` with a JSON object (`build-soul.sh` falls back to one key at a time);
- `delegate_task` being in the default toolsets (`config.yaml` sets `agent.disabled_toolsets: []`);
- copying the `model:` block and `.env` from the default profile being enough for the new profile to use the existing model (if not, `install.sh` runs `hermes -p council model`).

Run `tests/council-check.md` on a real box before release.
