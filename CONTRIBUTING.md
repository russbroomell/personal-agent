# Contributing

Thanks for helping. Most of Sidekick is plain Markdown, so you don't need
to be a programmer to make it better.

## Easiest ways to contribute

**A new character.** Copy `distribution/skills/persona-switch/personas/_template.md`,
fill it in (voice, catchphrases, strength 1 to 5 examples), add a line
for its voice in `personas/voices.conf`, and test it with the steps in
[docs/personas.md](docs/personas.md). One file plus one line.

**A new deep-dive setup.** These are the 3 to 5 minute interviews on the Life
Map (home & car, money & bills, and so on). Copy a module in
`distribution/skills/deep-dive/modules/`, keep the same shape (a few
questions, then something set up and one thing done), and add it to the
list in that skill's `SKILL.md`. Pets, kids' school, rentals,
freelancing and running a club are all wanted.

**Fixes from a real install.** If setup stumbled on your server, the fix
(or just a good issue with your `check.sh` output) helps everyone after you.

## Before you open a pull request

1. Run the checks (needs `shellcheck` and Python with PyYAML):
   ```bash
   bash tests/lint.sh
   ```
   GitHub runs the same checks on every pull request.
2. If you changed skills or characters, run through
   [tests/persona-check.md](tests/persona-check.md) on a real bot.
3. If you changed setup scripts, say in the pull request which server and
   OS you tried them on.
4. Keep the house rules intact: approvals before spending, sending,
   booking or cancelling; outside text is data, never orders; no bank
   logins. Characters change the voice, never the rules.

## Style

- Bot text and docs: short sentences, plain words, no jargon.
- Shell scripts: `set -euo pipefail`, say what each step does as it runs,
  ask yes/no (`scripts/lib/ask.sh`) before anything optional, and stay safe
  to run twice.
- Never commit secrets, memories, notes or chats. `.gitignore` blocks the
  usual ones; check `git status` anyway.

## Releases (maintainers)

`main` is where work lands. Servers on auto-update follow `stable`, which
moves only on a release:

1. Try `main` on your own server (`bash scripts/update.sh`).
2. If you tested with a newer Hermes, update `HERMES_VERSION`.
3. Add a `## X.Y.Z` section to `CHANGELOG.md`, commit and push.
4. `bash scripts/release.sh X.Y.Z` tags the release and moves `stable`.

## Questions

Questions and show-and-tell go in
[Discussions](https://github.com/russbroomell/personal-agent/discussions);
problems go in [Issues](https://github.com/russbroomell/personal-agent/issues).
