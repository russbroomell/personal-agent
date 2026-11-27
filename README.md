# The Council

[![Checks](https://github.com/russbroomell/personal-agent/actions/workflows/checks.yml/badge.svg)](https://github.com/russbroomell/personal-agent/actions/workflows/checks.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

**One personal assistant, many minds.** You message it like any assistant. Behind each reply sits a small council of characters from myth and history, each good at something. A chair decides who answers: one voice for routine things, two or three on a decision, and he always has the last word. You never pick who to ask.

> **You:** Van needs a $1,900 repair. Or I lease a new one for $412 a month?
>
> **Newton:** The repair pays for itself inside five months.
> **Māui:** Or keep it and wrap it in your logo. A billboard that parks outside your customers.
> **Marcus:** Fix it and wrap it. You get a year to save, and free advertising.
> `[Fix + wrap]` `[Get quotes on both]` `[Just fix it]`

Send that as a voice note and the answer comes back as one voice bubble, with each member in their own voice.

Built on [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research. The earlier six-character Sidekick is in the git history, and stays on the `stable` branch until the first Council release.

## The council

| | Seat | Leads on |
| --- | --- | --- |
| **Marcus Aurelius** | Chair | Priorities, values, what's in your control, the final call |
| **Romulus** & **Remus** | Builder & Scout | The plan, dates and budgets ↔ people and the other road |
| **Odysseus** | Strategist | Negotiation, persuasion, tricky people |
| **Māui** | Trickster | Bold ideas, marketing, energy |
| **Isaac Newton** | Analyst | Numbers, comparisons, evidence |
| **Richard Feynman** | Explainer | Learning, fixing things, "how do we know that?" |
| **Scheherazade** | Storyteller | Emails, posts, speeches, hard messages |
| **Florence Nightingale** | Caretaker | Health, rest, caring for others; serious moments |
| *Bench:* Ada Lovelace, Hypatia, Sun Tzu | Engineer, Teacher, General | Automation and tech · learning plans and homework · competitors and positioning. They join the full council when their lane fits, host their own setup areas, and can be seated with "seat Ada" |

They're built to pull against each other (Newton against Māui, Romulus against Remus, Odysseus against Marcus), with rules that keep that useful: the chair always lands it, members argue about approach and never about facts, each gets one turn, serious moments get one gentle voice, and only the agent acts, with your yes. Details: **[docs/council.md](docs/council.md)**.

## What it's like

- **Short by design.** Routine replies are one or two lines, and decisions five at most, with buttons for every choice. "More" expands only when you ask.
- **No long prompts from you.** Forward an email, a photo or a voice ramble with "deal with this". A vague ask gets one pointed question with buttons, not a questionnaire.
- **Voice first.** Voice notes in, a voice bubble out with a voice per member (free Edge voices, Grok, or ElevenLabs). Live conversation in the browser workspace, interruptible. See [docs/voice.md](docs/voice.md).
- **A 5-minute start.** Marcus asks six questions, and a different member reacts to each answer, so you meet the council while it does a real errand for you. Everything else drips in, one optional item a day in the morning brief.
- **A daily rhythm.** A morning brief with one suggested step, nudges on open loops, watchers that ping only on change, a Friday recap, and Sunday tidy-ups.
- **It tunes itself.** A weekly review notices whose advice you take and who you cut short, adjusts the council's notebook, and tells you in one line how to undo it.
- **The full council, on request.** "Convene the council" has five members (seated or from the bench) think separately, in parallel, then Marcus chairs: he weighs all five, gives a verdict, and files the minutes.
- **You run the room.** "Just Marcus", "fewer voices", "bench Māui", "turn it up", or "add Cleopatra to the council".
- **Careful with your stuff.** It asks before anything that spends, sends, books or cancels. It treats emails and web pages as information, never orders, and never uses bank logins. "Stop everything" pauses it all.

## Install (on a computer that already runs Hermes)

You need:
- Hermes Agent (0.23 or newer) installed, with a working model. Any provider is fine; a fast one feels best in chat.
- A Telegram account, for the council's own bot (the installer walks you through @BotFather).
- About 10 minutes. Debian or Ubuntu is assumed for package installs.

Log in as the user Hermes runs as (root is fine), then:

```bash
git clone -b main https://github.com/russbroomell/personal-agent.git ~/personal-agent
```

```bash
bash ~/personal-agent/install.sh
```

It asks yes/no before each optional step (Enter takes the recommended answer; `--yes` takes them all):

| Step | What happens | You're asked |
| --- | --- | --- |
| 1. Pre-flight | Checks Hermes, its version against `HERMES_VERSION`, your model, and `git`, `python3`, `curl`, `ffmpeg` | Update Hermes if it's older; install missing tools |
| 2. Profile | Installs the `council` profile from `distribution/`, reusing your existing model and keys (Telegram tokens stay where they are) | Reuse your model setup? Bring over memory from a Sidekick profile? |
| 3. Seating | Builds the personality file (chair's rules, nine member cards, house rules), member voices, notes and starter memory | Nothing |
| 4. Messaging | Telegram bot setup for the council | Your bot token and user id |
| 5. Services | The 24/7 gateway, the Memory Card page, and staying up after logout | Memory Card? Linger? |
| 6. Extras | Voices; the browser workspace (live voice, the bot's screen); nightly auto-update with backup and rollback; Tailscale remote access | `free` / `grok` / `elevenlabs` / `skip`, then yes/no for each |
| 7. Check | Health check with a `fix:` line for anything wrong, plus a test question that two council members must answer | Nothing |

Then open the council's bot in Telegram, tap **Start**, send `/sethome`, and say **hi**.

Options: `--profile NAME`, `--migrate-from PROFILE`, `--voice free|grok|elevenlabs|skip`, `--no-update`, `--no-check`. Run it again any time: it refreshes the profile and never touches memory, notes, chats or keys.

Starting from a bare server? Install Hermes first ([Hermes docs](https://hermes-agent.nousresearch.com/docs)), add swap on a 4 GB machine with `sudo bash ~/personal-agent/scripts/add-swap.sh`, then run `install.sh`.

## Looking after itself

| What | How |
| --- | --- |
| Nightly auto-update | `scripts/auto-update.sh enable`. It backs up the profile, fast-forwards this repo on the branch you installed from, updates Hermes only to the tested version in `HERMES_VERSION`, refreshes skills, rebuilds the personality with your seats, restarts, and rolls back if anything fails. `status` / `run` / `disable`. Cloned from `main`, it follows `main` and gets every change as it lands. Don't switch it to `--channel stable` until the first Council release: `stable` still holds the old Sidekick |
| Update by hand | `scripts/update.sh` |
| Health check | `scripts/check.sh` (`--speed` times a reply and asks the council a test decision) |
| Backups | `scripts/backup.sh`: nightly with auto-update, newest 14 kept in `~/council-backups` |
| Your choices survive updates | Seats and name live in `council.conf`; memory, notes and keys are user data that updates never touch |
| Checks on every change | `tests/lint.sh` (GitHub runs it on each pull request): shell, skills, config, every member's card, tag, voices and strength dial, the personality budget and guardrails, plugin unit tests |
| Behaviour checks | [tests/council-check.md](tests/council-check.md): about 40 real prompts to run after a Hermes update |

Handy commands:

```bash
hermes -p council                                                # chat in the terminal
bash ~/.hermes/profiles/council/skills/council/build-soul.sh --list   # seated and bench
bash ~/personal-agent/scripts/voice-setup.sh elevenlabs           # change the voice engine
```

## Privacy

Your memory, notes and chats live as plain files on your own server, and you can read and edit them on the Memory Card. This version doesn't try to keep data away from model or tool providers: use whichever model and services work best. Only SSH needs to be open to the internet; the workspace and Memory Card are reached through an SSH tunnel or Tailscale.

## What's in the repo

| Path | What it is |
| --- | --- |
| `install.sh` | The installer for a Hermes computer |
| `distribution/` | The agent, as a Hermes profile distribution: config, skills, plugin |
| `distribution/skills/council/` | Members (`members/*.md`, `voices.conf`), the chair's rules (`chair.md`), house rules, `build-soul.sh`, and the skill for changing the council |
| `distribution/skills/convene/`, `council-minutes/`, `first-session/` | Full council · weekly self-tuning · 5-minute onboarding |
| `distribution/skills/*` | Morning brief, open loops, watchers, Friday recap, weekly distill, deep dives (ten life areas), inbox triage, meeting prep, browser hand-off, Memory Card, savings ledger, show-off, share card, kill switch |
| `distribution/plugins/council-voices/` | Speaks each member's lines in their own voice |
| `scripts/` | `check.sh`, `update.sh`, `auto-update.sh`, `voice-setup.sh`, `backup.sh`, `remote-access.sh`, `add-swap.sh`, `release.sh`, the Memory Card server |
| `docs/council.md` · `docs/voice.md` · `docs/models.md` | How it works · talking to it · choosing a model |
| `docs/council-plan.md` | The plan behind this version |
| `docs/archive/` | Planning and research from the earlier version |
| `tests/` | `lint.sh`, plugin unit tests, `council-check.md` |

## Contributing

A new council member is one Markdown file plus one line of voices; see [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/council.md](docs/council.md#add-a-member). Security problems: see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Hermes Agent is separately MIT-licensed by Nous Research. The council's characters are inspired by historical and mythological figures and are not endorsed by anyone.
