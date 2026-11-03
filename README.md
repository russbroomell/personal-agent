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

**You need:**
- A small Linux server or spare PC running **Ubuntu 24.04 or Debian 12/13**. A 4 GB VPS is enough (about $10 a month).
- **Telegram** on your phone.
- A **Grok** account (SuperGrok or X Premium+), or an xAI API key. Other models work too: see [docs/models.md](docs/models.md).
- For seeing the bot's browser and for live voice: a free **[Tailscale](https://tailscale.com/download)** account, with the app on your laptop and phone.

Plan on about an hour, mostly waiting for installs. Each step below says what it does and what you'll be asked. The full guide, with troubleshooting, is **[docs/setup-guide-ovh.md](docs/setup-guide-ovh.md)**.

### Step 1: Prepare the server (about 10 minutes)

Log in to your server as its default user (`ubuntu` on Ubuntu, `debian` on Debian):

```bash
git clone https://github.com/russbroomell/personal-agent.git ~/personal-agent
sudo bash ~/personal-agent/scripts/bootstrap-vps.sh
```

This updates the system and adds 4 GB of swap. It creates an `agent` user (copying your SSH key) and sets the firewall to SSH only. It also installs a small desktop and browser for the bot. **You'll be asked** to choose a password for `agent`, which is needed rarely, for `sudo`.

### Step 2: Log in as `agent`

From your computer, in a new terminal:

```bash
ssh agent@YOUR_SERVER_IP
```

Everything from here runs as `agent`. (Optional hardening, back in the first window: `sudo bash ~/personal-agent/scripts/bootstrap-vps.sh --harden-ssh` turns off password and root logins.)

### Step 3: Run setup (about 20–30 minutes, mostly waiting)

```bash
bash ~/personal-agent/scripts/setup.sh
```

One script does the rest, in five labelled steps. You can run it again any time: finished steps are skipped and nothing the bot knows is touched.

1. **Install Hermes and Sidekick.** You'll be asked:
   - **"Set up the model now?"** Yes. Pick **xAI Grok OAuth (SuperGrok / Premium+)**, open the link it shows on any device, enter the code and approve. Choose `grok-4.6`. (Or pick **xAI** and paste an API key. Other models: [docs/models.md](docs/models.md).)
   - **"Run the Telegram wizard?"** Yes. In Telegram, message [@BotFather](https://t.me/BotFather), send `/newbot`, and paste the token it gives you. Get your numeric user ID from [@userinfobot](https://t.me/userinfobot) and paste that too.
2. **Tune for speed:** short thinking time on chat replies, so answers come back in seconds.
3. **The bot's browser on your laptop or phone (optional, recommended).** Install the [Tailscale](https://tailscale.com/download) app on your laptop first. You'll be asked to open a login link and approve the server, possibly to click **Enable** on a second link (HTTPS), and to choose a workspace password (username `agent`). Nothing is opened to the public internet.
4. **Voice:** type `grok` (Grok's voices), `free`, or `skip`.
5. **Health check:** a list of ✓ and ✗, with a `fix:` command under anything that's wrong, and a timed test reply from the model.

How it runs: Hermes has one background service, started from its built-in `default` profile, that serves every profile on the machine. Sidekick's personality, memory, skills and Telegram bot live in the `sidekick` profile; the service and the workspace are set on `default`. You never start anything by hand: it runs 24/7 and survives reboots.

### Step 4: Say hi

In Telegram, open your new bot and:

1. Tap **Start**.
2. Send `/sethome`, so morning briefs and recaps know where to go.
3. Say **hi**. The first-session interview starts: pick a character and strength, a few quick questions, and a first errand done for you.

Replies should take seconds. If they take a minute, run `bash ~/personal-agent/scripts/check.sh --speed`: it shows whether the model or the server is the slow part.

### Step 5: Use it from your laptop, and talk to it

On a laptop or phone with Tailscale on, open the address setup printed: `https://sidekick-vps.<your-tailnet>.ts.net`.

- **Watch its browser:** sign in, then **Bots → sidekick → Screen**. **Take over** gives you the mouse and keyboard; **Hand back** returns them.
- **Talk live:** press the **voice conversation button** just right of the microphone in the chat box, allow the microphone, and talk. You can interrupt it mid-sentence; say "stop" to end. Use headphones (speaker echo makes it interrupt itself). Only works on the `https://` address.
- **Voice notes:** on your phone, send `/voice on` to the bot once, then send a voice note; it replies with one.
- **Memory Card:** the `…:8443/?token=…` link setup printed. Everything the bot remembers, editable.

Handy commands on the server:

```bash
bash ~/personal-agent/scripts/check.sh   # what works, what doesn't, how to fix it
hermes -p sidekick                       # chat in the terminal instead of Telegram
```

### Next step

You're set up. Now:

- **Play:** text it "show off" for a menu of party tricks, or try "Have Rex and Mortimer argue about whether I should go to the gym."
- **Set up an area of your life:** text "what else can you do?" to see the Life Map, and pick one (3–5 minutes each).
- **Show a friend:** follow **[demo/demo-script.md](demo/demo-script.md)**.
- **Check it's all working:** run through [tests/persona-check.md](tests/persona-check.md).
- **Something not working?** Run `bash ~/personal-agent/scripts/check.sh`, then see the troubleshooting table in [docs/setup-guide-ovh.md](docs/setup-guide-ovh.md#if-something-goes-wrong).

## What's in the repo

| Path | What it is |
| --- | --- |
| `distribution/` | The agent, as a Hermes [profile distribution](https://hermes-agent.nousresearch.com/docs/user-guide/profile-distributions): config, safety settings and skills (all plain Markdown) |
| `distribution/skills/persona-switch/` | The six characters, the strength dial, cameos and crossovers, the shared house rules, and `build-soul.sh` |
| `distribution/skills/deep-dive/` | Ten 3–5 minute setup interviews, one per area of life |
| `distribution/skills/*` | First session, onboarding plan, morning brief, watchers, open loops, Friday recap, savings ledger, weekly memory tidy-up, browser hand-off, inbox triage, meeting prep, Memory Card, show-off, share card, kill switch |
| `templates/notes/` | Starter topic notes, including the onboarding plan |
| `scripts/` | `bootstrap-vps.sh`, `setup.sh` (everything else, in one go), `check.sh` (health check), `install-agent.sh`, `remote-access.sh`, `voice-setup.sh`, `reset-agent.sh` (reset button and snapshots), `update.sh`, `backup.sh`, `move-agent.sh`, `set-persona.sh`, `schedule-jobs.sh`, and the Memory Card server |
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
