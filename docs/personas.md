# Characters

Nov 3, 2026

Sidekick's personality is a character file plus a shared set of house rules. Characters change *how it talks*. The house rules decide *what it's allowed to do*, and they're identical for every character and every strength.

## The cast

| | Concept | Signature moves | Voice (Grok / free) |
| --- | --- | --- | --- |
| **Sam** | Unflappable chief of staff | Understatement ("slight wrinkle"), the quiet save, one-line pushback | sal / Guy |
| **Pip** | Nerdy best friend | Nicknames for errands, one fun fact after a win, "tiny victory" | ara / Aria |
| **Mortimer** | English butler | The diary and the post, one withering aside, bad news as a weather report | leo / Ryan (British) |
| **Rex** | No-excuses coach | Counts how often you've put something off, two-minute drills, the scoreboard | rex / Davis |
| **Nova** | Mission control | Go/no-go briefs, T-minus countdowns, mission names, "splashdown" | eve / Jenny |
| **Vic** | 1940s noir detective | Errands as cases, "call it a hunch", "case closed" | rex (slow) / Christopher |

The files are in `distribution/skills/persona-switch/personas/`.

## Strength (1–5)

Each character file shows the same reply at strengths 1, 3 and 5. The person chooses in the first chat and can say "tone it down", "turn it up" or "strength 4" any time. At every strength:

- facts come first, and a full-strength reply is never more than twice as long as a plain one;
- approval lines (anything involving money, health, safety or the law) stay plain and exact;
- serious moments drop to strength 1 automatically;
- messages drafted for other people are written in *your* voice, not the character's.

## Cameos and crossovers

- **Cameo:** "Ask Vic what he makes of my inbox." One message from another character, then back.
- **Crossover:** "Have Nova and Pip plan my Saturday." A 4–6 line exchange that ends in something useful, often a choice with buttons.

Guests never change memory or settings, and never act on their own. Anything they suggest still needs your yes.

## Write your own (about 10 minutes)

1. Copy the template:

   ```bash
   cd ~/personal-agent/distribution/skills/persona-switch/personas
   cp _template.md captain.md
   ```

2. Fill it in. Keep the first line in the form `You are Captain, a personal assistant who…`, because the name is taken from there. What makes a character work:
   - **A clear concept in one line** (a pirate quartermaster, a nature-documentary narrator, a hype-man DJ).
   - **Two or three signature moves** that repeat. Running bits are what make people laugh by day three.
   - **A strength dial**: write the dentist line at 1, 3 and 5. This is the most useful part of the file.
   - **A "never" list.** It keeps the joke from turning annoying or unkind.
   - **A serious mode.** Every character needs a way to drop the act.
3. Optional: give it a voice by adding a line to `voices.conf`, for example `captain  rex  0.95  en-GB-ThomasNeural`.
4. Install and switch:

   ```bash
   bash ~/personal-agent/scripts/update.sh
   bash ~/personal-agent/scripts/set-persona.sh captain
   ```

   Then send `/new` to your bot.
5. Run the voice section of [tests/persona-check.md](../tests/persona-check.md). If it holds up, open a pull request: good characters are welcome.

**Keep it kind.** Characters can tease the world, the calendar, the airline website and the weather. They never mock the person, comment on bodies or food, or play with fear, money worries or health.
