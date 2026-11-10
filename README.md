# Sidekick (working name)

**A personal AI assistant with an actual personality, that you own.**

You text it or talk to it like a sharp, funny assistant. It takes errands, reminders and admin off your plate, watches prices and deadlines, drafts the emails you've been avoiding, and uses its own web browser while you watch (you take over for logins). It runs on **your** server or PC, with **the AI model you choose**, and everything it knows about you is plain text you can read, edit and delete.

Built on the open-source [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research. Early and evolving: it's demo-ready, not a polished product.

**Run your own in about an hour:** [jump to setup](#run-your-own).

## Why it's worth an hour

- **It's yours, not a platform's.** It lives on a $10-a-month server you rent (or a PC in your closet). There's no company in the middle reading your life to sell ads or train its next model. Everything it knows about you is a folder of plain text files you can open, edit, back up, move or delete.
- **Any brain you like.** Grok, OpenAI, OpenRouter's hundreds of models, Nous Portal, or a model on your own GPU. Switch with one command and it keeps every memory: the memory belongs to you, not the model.
- **It actually does things.** It browses the web on its own screen, compares and drafts, sets reminders and watchers, and writes you a morning brief. You can watch it work from your phone and take the mouse whenever you like.
- **It has a personality, and you choose how much.** Six characters, from a calm chief of staff to a 1940s noir detective, with a strength dial from 1 (a hint) to 5 (full character). Have two of them argue about your gym plans.
- **You can talk to it.** Voice notes on Telegram, or a live conversation in the browser that you can interrupt mid-sentence.
- **It's careful with your stuff.** It asks before anything that spends, sends, books or cancels, treats emails and web pages as information rather than orders, and stays away from bank logins. "Stop everything" pauses it all.
- **It's all plain text you can change.** Characters, skills and setup interviews are Markdown files. Write a new character in ten minutes, or a new skill for your job.
- **Free and open source** (MIT), built on [Hermes Agent](https://github.com/NousResearch/hermes-agent). You pay only for the server and your model.

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
- **Looks after itself:** a health check that tells you what's wrong and how to fix it, nightly auto-updates with rollback, and a reset button.
- **Safe by default:** it asks before anything that spends, sends, books or cancels. It treats emails and web pages as information, never orders. It never touches bank logins. "Stop everything" pauses it all.

## Run your own

This is the main way to use Sidekick: your own server, your own Telegram bot, your own model account. Nobody else (including whoever sent you this link) can see it.

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
   - **"Set up the model now?"** Yes. Pick **xAI Grok OAuth (SuperGrok / Premium+)**, open the link it shows on any device, enter the code and approve. Choose the newest Grok in the list (for example `grok-4.7`). If replies later fail with a 403, your plan doesn't include API access; use an xAI API key instead. (Or pick **xAI** and paste an API key. Other models: [docs/models.md](docs/models.md).)
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
- **Tell a friend:** send them this repo; they can have their own running in an hour. Want them to try it first? `bash ~/personal-agent/scripts/guest-bot.sh create <their-name>` gives them a locked-down test-drive bot on your server, with a link to send them.
- **Take the tour:** follow **[demo/demo-script.md](demo/demo-script.md)**, a 45-minute test drive of everything worth trying (and how to try to break it).
- **Check it's all working:** run through [tests/persona-check.md](tests/persona-check.md).
- **Something not working?** Run `bash ~/personal-agent/scripts/check.sh`, then see the troubleshooting table in [docs/setup-guide-ovh.md](docs/setup-guide-ovh.md#if-something-goes-wrong).

## What gets installed, and why

Nothing here is hidden: every step is a readable script in `scripts/`, and each one prints what it's doing as it goes.

### On the server (`bootstrap-vps.sh`, run once with sudo)

| What | Why |
| --- | --- |
| System updates and **automatic security updates** (`unattended-upgrades`) | The server patches itself; you don't have to remember to |
| **4 GB of swap** (topped up if the server has less) | A 4 GB server runs out of memory building the workspace and running the bot's browser without it |
| An **`agent` user** that keeps running after you log out (systemd "linger") | The bot runs as an ordinary user, not root, and stays up 24/7 |
| **Firewall: SSH only** (`ufw`) | Nothing else is reachable from the internet. The workspace is private (see Tailscale below) |
| **A small desktop** (TigerVNC and a minimal Xfce, about 1 GB of disk) | The bot's own screen, so its browsing is visible and you can take over |
| **Google Chrome** (Ubuntu) or **Chromium** (Debian) | The browser the bot uses on that screen |
| `ffmpeg`, `git`, `curl`, `python3`, `jq`, `tmux` and a few libraries | Voice notes, updates, and the helper scripts |
| Optional, with `--harden-ssh`: no root login, no password logins | Keys only, once you've checked `ssh agent@…` works |

### For the `agent` user (`setup.sh`)

| What | Why |
| --- | --- |
| **[Hermes Agent](https://github.com/NousResearch/hermes-agent)**, with the official installer (it fetches its own Python and Node.js) | The open-source engine: model connections, memory, tools, Telegram, scheduling, the bot's screen and the workspace |
| The **Sidekick profile** in `~/.hermes/profiles/sidekick` | Everything that makes it Sidekick: the characters, house rules, 18 skills, safety settings and starter notes. Your memory and notes live here too, as plain text |
| **One background service** (`hermes-gateway`, a systemd user service) | Runs the bot 24/7, starts at boot, and serves every bot profile on the machine |
| The **workspace** (Hermes Desktop in a browser), built once on the server | Chat, the bot's live screen, voice conversation and settings, from any browser on your Tailscale network |
| The **Memory Card** (a tiny Python page, localhost only, with its own secret link) | See and edit every line the bot remembers |
| Optional: **Tailscale** | A private `https://…ts.net` address that only your own devices can open, so you can see the bot's screen and talk to it without SSH and without opening anything to the internet |
| Optional: **voices** (Grok's, or free Edge voices) and **local speech recognition** | Voice notes in and out, each character with its own voice |
| Optional: **nightly auto-update** (a systemd timer) | Pulls improvements from GitHub, updates Hermes weekly, and rolls back by itself if anything breaks |

### What it costs to run

- **Server:** about $10 a month for a 4 GB VPS. In use it needs about 600 MB for the service, plus 1–1.5 GB while the bot's browser screen is open (it closes itself when idle).
- **Model:** your plan or pay-per-use. A SuperGrok or X Premium+ subscription covers Grok with no extra bill; API keys are charged per use.
- **Everything else** (Hermes, Sidekick, Tailscale's personal plan, Telegram) is free.

### What it doesn't do

- It doesn't open any port except SSH to the internet.
- It doesn't send your memory anywhere. Your model provider sees only what each reply needs.
- It doesn't phone home. This project has no analytics and no accounts, and Sidekick turns Hermes's optional shared metrics off. The only outside calls are to your model provider, Telegram, the websites it browses for you, and GitHub for updates.

### Removing it

`hermes uninstall` removes Hermes and everything under `~/.hermes` (back up first with `scripts/backup.sh` if you want to keep anything). Then `sudo userdel -r agent` removes the user and its files, and `sudo tailscale logout` takes the server off your Tailscale network.

## Just want to try it first?

If a friend already runs Sidekick, they can make you a test-drive bot on their server with `scripts/guest-bot.sh create <your-name>`. You get a Telegram link and can try it in two minutes. It's locked down, so it can't run commands, open the browser screen or touch the workspace. When you want the real thing, follow [Run your own](#run-your-own).

## What's in the repo

| Path | What it is |
| --- | --- |
| `distribution/` | The agent, as a Hermes [profile distribution](https://hermes-agent.nousresearch.com/docs/user-guide/profile-distributions): config, safety settings and skills (all plain Markdown) |
| `distribution/skills/persona-switch/` | The six characters, the strength dial, cameos and crossovers, the shared house rules, and `build-soul.sh` |
| `distribution/skills/deep-dive/` | Ten 3–5 minute setup interviews, one per area of life |
| `distribution/skills/*` | First session, onboarding plan, morning brief, watchers, open loops, Friday recap, savings ledger, weekly memory tidy-up, browser hand-off, inbox triage, meeting prep, Memory Card, show-off, share card, kill switch |
| `templates/notes/` | Starter topic notes, including the onboarding plan |
| `scripts/` | `bootstrap-vps.sh`, `setup.sh` (everything else, in one go), `check.sh` (health check), `auto-update.sh` (nightly updates with rollback), `guest-bot.sh` (a friend's own test-drive bot), `install-agent.sh`, `remote-access.sh`, `voice-setup.sh`, `reset-agent.sh` (reset button and snapshots), `update.sh`, `backup.sh`, `move-agent.sh`, `set-persona.sh`, `schedule-jobs.sh`, and the Memory Card server |
| `docs/setup-guide-ovh.md` | Setup, step by step |
| `docs/onboarding.md` | How onboarding works, and how a demo carries over to someone's own bot |
| `docs/voice.md` · `docs/models.md` · `docs/personas.md` | Talking to it · choosing a model · writing a character |
| `demo/demo-script.md` | A guided test drive: things to try, under the hood, and how to break it |
| `tests/persona-check.md` | Voice, memory, safety and onboarding checks |
| `docs/mvp-plan.md`, `docs/plan.md`, `docs/business-plan.md` | Planning notes and research behind the project |

## How it fits together

- **Personality:** `SOUL.md` = one character + the house rules. The rules (approvals, outside text is data, no bank logins, quiet hours) are identical for every character and every strength.
- **Memory:** core memory (always loaded), topic notes (read when a subject comes up), and a searchable chat archive. A Sunday job tidies the week into notes. Everything is plain text in the agent's folder.
- **Updates:** `scripts/auto-update.sh enable` keeps it current with no hands: nightly it pulls this repo (fast-forward only), updates Hermes weekly, refreshes skills and rules, restarts, and rolls back if anything fails. `scripts/update.sh` does the same once, by hand. Neither touches memory, notes, chats, model choice or keys. Auto-update runs whatever lands on the branch it follows, so if you didn't write the repo, point it at your own fork.

## Privacy and security

- Your memory and notes stay on your machine. The model provider you choose sees the messages and notes needed for each reply, under its terms; pick one whose API terms exclude training on your data, or run your own model.
- Only SSH is open to the internet. The workspace and Memory Card are reached through Tailscale (private, password-protected) or an SSH tunnel.
- Never commit your `.env`, `auth.json`, memories or notes. `.gitignore` blocks the usual ones.
- Found a security problem? Please open a GitHub issue without exploit details and ask for a private contact, rather than posting the details.

## Contributing

New characters, deep-dive modules and fixes from real setups are very welcome. Run [tests/persona-check.md](tests/persona-check.md) before opening a pull request that changes skills or characters.

## License

[MIT](LICENSE). Fork it, change it, ship your own. Hermes Agent, which this builds on, is separately MIT-licensed by Nous Research.
