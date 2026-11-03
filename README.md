# Sidekick (working name)

**A personal AI assistant with an actual personality, that you own.**

You text it or talk to it like a sharp, funny assistant. It takes errands, reminders and admin off your plate, watches prices and deadlines, drafts the emails you've been avoiding, and uses its own web browser while you watch (you take over for logins). It runs on **your** server or PC, with **the AI model you choose**, and everything it knows about you is plain text you can read, edit and delete.

Built on the open-source [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research. Early and evolving: it's demo-ready, not a polished product.

## Meet the cast

Pick one in the first chat, and choose how strong (1 = a hint, 5 = full character). Switch any time.

| | Character | At strength 5 |
| --- | --- | --- |
| **Sam** | Unflappable chief of staff | "Done. Dentist is Thursday at 3, Friday is a clean sheet, and I've quietly declined the 'quick sync' trying to take its place." |
| **Pip** | Nerdy best friend | "Operation Dentist: COMPLETE 🎉 Thursday at 3. Fun fact: Thursday afternoons have the shortest waits." |
| **Mortimer** | English butler | "It is done. Friday now stands as empty as a ducal ballroom in August." |
| **Rex** | No-excuses coach | "DONE ✅ Three wins before lunch. Now let's finally take down that registration." |
| **Nova** | Mission control | "Dentist rescheduled, T-minus two days, 1500 hours. Friday is clear for launch 🚀" |
| **Vic** | 1940s noir detective | "It wasn't easy, but nothing in this town is. Friday's yours now, kid. Case closed." |

Ask for a **cameo** ("ask Mortimer what he thinks of my calendar"), or a **crossover**:

> **You:** Have Rex and Mortimer argue about whether I should skip the gym tonight.
>
> **Rex:** Skip? It's leg day. You've skipped twice. That's a streak, and not the good kind.
> **Mortimer:** One might observe that it is raining, and that the sofa has been most patient.
> **Rex:** Twenty minutes. Then sofa. Deal?
> **Mortimer:** A compromise worthy of Parliament.
> **Pip:** Okay, I'm back. Twenty minutes, then sofa? [Deal] [Sofa wins]

Write your own character in ten minutes: [docs/personas.md](docs/personas.md).

## What it does

- **Five-minute start:** the first chat is an interview where you meet the characters, pick one, and get a real errand done. Then a **Life Map** offers 3–5 minute setups for areas of your life (home & car, money, family, work, travel, food, goals, small business, community). Each ends with something running for you.
- **Daily rhythm:** a short morning brief with one suggested next step, nudges on things you mentioned but didn't finish, watchers that only ping when a price, page or flight changes, and a Friday recap of hours and dollars saved.
- **Talk to it:** voice notes on Telegram, or a live voice conversation in the browser that you can interrupt. Each character has its own voice.
- **A browser you can watch:** it browses on its own screen. You see it live from your laptop or phone and take over for logins, CAPTCHAs and payments.
- **Your data, your model:** the Memory Card page shows every line it remembers, and you can edit any of it. Use Grok, OpenAI, OpenRouter, Nous Portal, or your own model. One command moves the whole agent to another machine.
- **Safe by default:** it asks before anything that spends, sends, books or cancels. It treats emails and web pages as information, never orders. It never touches bank logins. "Stop everything" pauses it all.

## Get your own

You need a small Linux server (a 4 GB VPS is enough; about $10 a month) or a spare PC running Ubuntu 24.04 or Debian 12/13, a Telegram account, and a model account (Grok is the default). Plan on about an hour.

```bash
git clone https://github.com/russbroomell/personal-agent.git ~/personal-agent
sudo bash ~/personal-agent/scripts/bootstrap-vps.sh   # server prep: swap, firewall, user, bot desktop
```

Then log in as the new `agent` user and run:

```bash
bash ~/personal-agent/scripts/install-agent.sh        # Hermes + Sidekick; walks you through model and Telegram
bash ~/personal-agent/scripts/remote-access.sh        # see the bot's browser from laptop or phone (Tailscale)
bash ~/personal-agent/scripts/voice-setup.sh grok     # talk to it (or: free)
```

Step-by-step: **[docs/setup-guide-ovh.md](docs/setup-guide-ovh.md)**. Read the scripts before running them with sudo; they're short and commented.

## What's in the repo

| Path | What it is |
| --- | --- |
| `distribution/` | The agent, as a Hermes [profile distribution](https://hermes-agent.nousresearch.com/docs/user-guide/profile-distributions): config, safety settings and skills (all plain Markdown) |
| `distribution/skills/persona-switch/` | The six characters, the strength dial, cameos and crossovers, the shared house rules, and `build-soul.sh` |
| `distribution/skills/deep-dive/` | Ten 3–5 minute setup interviews, one per area of life |
| `distribution/skills/*` | First session, onboarding plan, morning brief, watchers, open loops, Friday recap, savings ledger, weekly memory tidy-up, browser hand-off, inbox triage, meeting prep, Memory Card, show-off, share card, kill switch |
| `templates/notes/` | Starter topic notes, including the onboarding plan |
| `scripts/` | `bootstrap-vps.sh`, `install-agent.sh`, `remote-access.sh`, `voice-setup.sh`, `reset-agent.sh` (reset button and snapshots), `update.sh`, `backup.sh`, `move-agent.sh`, `set-persona.sh`, `schedule-jobs.sh`, and the Memory Card server |
| `docs/setup-guide-ovh.md` | Setup, step by step |
| `docs/onboarding.md` | How onboarding works, and how a demo carries over to someone's own bot |
| `docs/voice.md` · `docs/models.md` · `docs/personas.md` | Talking to it · choosing a model · writing a character |
| `demo/demo-script.md` | How to show it to a friend |
| `tests/persona-check.md` | Voice, memory, safety and onboarding checks |
| `docs/mvp-plan.md`, `docs/plan.md`, `docs/business-plan.md` | Planning notes and research behind the project |

## How it fits together

- **Personality:** `SOUL.md` = one character + the house rules. The rules (approvals, outside text is data, no bank logins, quiet hours) are identical for every character and every strength.
- **Memory:** core memory (always loaded), topic notes (read when a subject comes up), and a searchable chat archive. A Sunday job tidies the week into notes. Everything is plain text in the agent's folder.
- **Updates:** `scripts/update.sh` refreshes skills and rules without touching memory, notes, chats, model choice or keys.

## Privacy and security

- Your memory and notes stay on your machine. The model provider you choose sees the messages and notes needed for each reply, under its terms; pick one whose API terms exclude training on your data, or run your own model.
- Only SSH is open to the internet. The workspace and Memory Card are reached through Tailscale (private, password-protected) or an SSH tunnel.
- Never commit your `.env`, `auth.json`, memories or notes. `.gitignore` blocks the usual ones.
- Found a security problem? Please open a GitHub issue without exploit details and ask for a private contact, rather than posting the details.

## Contributing

New characters, deep-dive modules and fixes from real setups are very welcome. Run [tests/persona-check.md](tests/persona-check.md) before opening a pull request that changes skills or characters.

## License

[MIT](LICENSE). Fork it, change it, ship your own. Hermes Agent, which this builds on, is separately MIT-licensed by Nous Research.
