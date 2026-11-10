# Security

Sidekick runs on your own server with access to a web browser, your
messages and whatever you tell it. Security problems matter, so please
report them privately.

## Reporting a vulnerability

Use **[GitHub's private vulnerability reporting](https://github.com/russbroomell/personal-agent/security/advisories/new)**
(the repo's **Security** tab, then **Report a vulnerability**). Only the
maintainer sees the report. Please don't open a public issue for
anything that could be exploited.

Helpful to include: what an attacker could do, the steps to reproduce,
and the Sidekick release (`git -C ~/personal-agent log --oneline -1`)
and Hermes version (`hermes --version`).

You can expect a reply within a week. Fixes ship as a new release on
the `stable` branch, so servers on auto-update get them overnight.

## What counts

- Ways for someone other than the owner to make the bot act: message
  injection (emails or web pages that get obeyed), the Telegram
  allowlist or pairing, the workspace sign-in, the Memory Card link.
- A guest bot (`scripts/guest-bot.sh`) reaching the owner's files,
  commands or bot.
- Scripts that open ports, weaken the firewall or SSH, or leak secrets
  (bot tokens, `.env`, `auth.json`) into logs, snapshots or the repo.
- Auto-update pulling or running something other than the configured
  branch.

Problems in Hermes Agent itself (gateway, workspace, tools) should go to
[Hermes Agent](https://github.com/NousResearch/hermes-agent/security);
if you're unsure, report here and it will be forwarded.

## Design notes

- The bot asks before anything that spends, sends, books or cancels, and
  treats emails and web pages as information, never orders (house rules
  in `distribution/skills/persona-switch/house-rules.md`).
- Only SSH is open to the internet; the workspace and Memory Card are
  reached through Tailscale or an SSH tunnel.
- The workspace is a full shell on the server for anyone signed in.
  Treat its password like the server's.
