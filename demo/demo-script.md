# Demo Script: Showing It to a Friend (about 20 minutes)

Nov 3, 2026

This is written for showing Sidekick to someone who already uses bots and AI tools. They've seen chatbots, so a feature list won't impress them. What will: a character they like, something useful done for *their* life in minutes, a peek under the hood, and the realisation that they could run (and tweak) their own.

**Three rules:**
- **Hand them the phone.** They drive; you narrate. People remember what they did, not what they watched.
- **Make it about their life.** Every errand, setup and crossover should use their real stuff: their town, their car, their gym excuses.
- **Leave them with something to share:** a crossover screenshot, their share card, the repo link.

## The night before

1. **Use it yourself for a bit** (an hour is enough): run the first session, two or three errands, a price watcher, "write my morning brief now", and one crossover. Then save that state:

   ```bash
   bash ~/personal-agent/scripts/reset-agent.sh --snapshot lived-in
   ```

2. **Polish the bot** in BotFather: picture, description and about text ([setup guide](../docs/setup-guide-ovh.md), Step 7½).
3. **Run the checklist** in [tests/persona-check.md](../tests/persona-check.md), at least the Onboarding and Voice sections.
4. **Just before he arrives**, wipe it into demo mode, then **Clear history** in the Telegram chat:

   ```bash
   bash ~/personal-agent/scripts/reset-agent.sh -y --demo
   ```

## Set up (10 minutes before)

- [ ] **Phone:** Telegram open on the bot, Do Not Disturb on, Tailscale on.
- [ ] **Laptop:** Tailscale on. Three tabs at your `https://…ts.net` address: **workspace** (signed in, with the workspace **terminal** handy), **bot Screen** (opened once so it's warm), **Memory Card**.
- [ ] **Voice** on (`voice-setup.sh`); one test voice note answered; headphones or a headset nearby.
- [ ] `/model` shows Grok plus a second model, if you have one.
- [ ] `hermes -p sidekick doctor` clean; `free -h` shows swap.

## 1. Cold open (30 seconds)

No pitch. Hand him the phone:

> "I've been building my own assistant. Say hi to it. It's going to interview you. Be honest, or be difficult; it can take it."

## 2. The interview (about 7 minutes, plus a 4-minute deep dive)

Let him drive the first session. Narrate only at these moments:

- **The audition.** "Six characters. Pick the one you'd actually want texting you every morning." (Bot people almost always pick Vic or Nova. Let them.)
- **The strength preview.** "Same sentence at 1 and 5. Most assistants have one setting: 'eager intern'." Push him toward 4 or 5 for the demo.
- **The first win.** It offers three errands and does one. If it browses, turn the laptop toward him and show the **Screen** tab: "That's its own computer, on my server. Watch."
- **The Life Map.** "That was the warm-up." He picks an area. Steer him toward one with an obvious payoff for him: **home & car** (registration and maintenance), **money & bills** (the subscription tally gets a reaction), or **work & inbox** (forward a real messy email). The deep dive ends with something set up and one thing done, in about 4 minutes.
- **The wrap-up:** "Everything you skipped is parked. If you want your own, it picks up exactly here."

Then send `/new` so his character fully loads.

## 3. Party tricks (3 minutes): the shareable bit

- **Crossover:** let him write it.

  > Have Rex and Mortimer argue about whether I should go to the gym tonight.

  Screenshot-worthy. Tell him to screenshot it.
- **Strength dial:** "Strength 1. What's on my plate?" then "Strength 5. Same question."
- **Talk to it:** put the headset on him. In the workspace tab, press the voice conversation button and let him talk:

  > What should I do first this afternoon?

  Have him **interrupt it** mid-sentence. That's the moment it stops feeling like a chatbot.

## 4. Watch it work (3 minutes): the browser

Give it something real for him:

> Find two places near [his town] that can do an oil change Saturday morning, compare reviews, and draft a booking message to the better one.

On the laptop, watch the **Screen**. Click **Take over**, scroll, then **Hand back**:

> "Grok's agent does this on xAI's computers. This is my box. Whatever I log in to here stays here."

The draft comes back with **Yes / Change it / No** buttons. Tap **Change it**, then show that it never sends on its own.

## 5. Under the hood (3 minutes): for the bot person

This is the part a bot-savvy friend will talk about later.

- **Memory Card tab:** "Everything it knows about you, as plain files." Find his answers from the interview. Edit one live, then ask the bot about it. Then say "forget that" and refresh.
- **It's just Markdown:** open a character file and a deep-dive module on GitHub (`distribution/skills/persona-switch/personas/vic.md`, `distribution/skills/deep-dive/modules/money-bills.md`). "Skills are plain text. You could write a new character in ten minutes." Show `docs/personas.md`.
- **Swap the brain:** `/model`, switch models with the buttons, then "What do you know about me?" Same memory, different model. "Grok, OpenAI, anything on OpenRouter, or a model running on your own GPU."
- **Lived-in in 10 seconds** (optional): first save his demo with `--snapshot demo-<name>` if he might test drive it. Then, in the workspace terminal, run `bash ~/personal-agent/scripts/reset-agent.sh --restore lived-in`, send `/new`, and show this morning's brief, a watcher and the Friday recap with time saved. "That's what week two looks like."

## 6. Hand-off (1 minute)

> "Make me a share card."

It writes a short, privacy-scrubbed brag of what it did, in character, with the repo link. Then:

> "It's open source: github.com/russbroomell/personal-agent. You can run your own on a $10 server, or I can set you up with a test-drive bot tonight that remembers everything you just told it."

Ask him what he'd want it to take off his plate first, and note it in `friction-log.md`. That's your next deep-dive module.

## If he wants a test drive

```bash
bash ~/personal-agent/scripts/reset-agent.sh --snapshot demo-<name>
```

Skip this if you already saved it in step 5. Then follow [docs/onboarding.md, "Demo → test drive"](../docs/onboarding.md#demo--test-drive-step-by-step): his own bot, his answers carried over, and it greets him with "Welcome back".

## Fallbacks

| If… | Do this |
| --- | --- |
| A site blocks the agent mid-errand | "It stops instead of fighting the site, and sends me the link." That's a feature; move on |
| The model is slow | Do a crossover or open the Memory Card while it thinks; or switch models with `/model` |
| Grok returns 403 | Switch to the xAI API key or your second model; mention xAI limits OAuth by tier |
| The screen won't start (memory) | Show a screenshot it sent; mention it's a 4 GB box |
| The interview goes sideways | Say "skip" (it parks it), or wipe it and start again from the workspace terminal: `reset-agent.sh -y --demo` (15 seconds) |
| Voice echoes or cuts itself off | Headset on, or use Telegram voice notes instead |
| He tries to break it ("ignore your rules…") | Let him. Then point out that it flagged the attempt and didn't act. Bot people love this |
