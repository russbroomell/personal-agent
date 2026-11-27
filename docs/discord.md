# The Council on Discord

Nov 27, 2026 · @Russ Broomell

Discord is the recommended way in. Everyone who DMs the bot gets their own private council: a 5-minute first chat, their own morning brief, and a private notebook that nobody else can see. In your server's public channels, the council chats with whoever is there, without needing an @mention, and never brings up anything from anyone's DMs.

Commands here assume the Council is in Hermes's default profile (what `install.sh` does unless you pass `--profile`). If you installed it into a named profile, add `-p NAME` after `hermes`, and use `~/.hermes/profiles/NAME/` instead of `~/.hermes/`.

## Set it up

If Hermes already has a Discord bot, `install.sh` uses it. Otherwise it offers Discord first and runs Hermes's setup wizard:

1. At [discord.com/developers/applications](https://discord.com/developers/applications), go to **New Application**, then **Bot**, then **Reset Token**, and copy the token.
2. On the Bot page, turn on **Message Content Intent** and **Server Members Intent**.
3. In the wizard, pick **Discord** and paste the token. It checks the token and the intents, prints the invite link for your server, and allowlists you as the owner.

The installer then asks who may talk to the council:

| Choice | How | When |
| --- | --- | --- |
| Only people on the allowlist (default) | `DISCORD_ALLOWED_USERS=<id>,<id>` in `~/.hermes/.env` | Family, a small team |
| Everyone with a role | `DISCORD_ALLOWED_ROLES=<role id>` | A community where moderators decide |
| Everyone who can reach the bot | `DISCORD_ALLOW_ALL_USERS=true` | A server you trust; every person still gets a private DM, but model use goes up |

Restart after changing `.env`: `hermes gateway restart`.

## How it behaves

| Where | What happens |
| --- | --- |
| **A DM, the first time** | Marcus runs the 5-minute first chat for that person. Their answers go in their private folder, `~/.hermes/notes/people/discord-<user id>/profile.md` |
| **A DM after that** | Their profile comes with every message, so the council knows them. Their brief, open loops and Friday recap arrive in their DM |
| **A public channel** | The council answers without an @mention (`discord.require_mention: false`). It stays quiet when a message @mentions only other people. Each person's session stays separate (`group_sessions_per_user: true`). It keeps replies useful to the room, and offers a DM for anything personal |
| **Choices** | Buttons, as on Telegram, plus an "Other" button for typing an answer |

To answer only in some channels: `hermes config set discord.require_mention true`, then list those channel ids under `discord.free_response_channels`.

## What stays private, and how

A DM is a personal, confidential space. In a public channel, nothing from anyone's DM is said unless that person asks, in that message, to share their own information there. It is never shared about anyone else.

This is enforced in two layers by the `council-privacy` plugin (`distribution/plugins/council-privacy/`):

1. **What the council is told, every turn.** In a DM: "this is a private DM with user X", their folder, and their profile, or the first-chat instruction. In a public channel: the public-room rules above. Where a message comes from (DM or not, which user) is read from Hermes's own session records. Anything that can't be identified is treated as public.
2. **What its tools can do, enforced in code.** On Discord, these are blocked whatever the model decides:
   - reading, writing or searching **another person's private folder**, including through `../` paths and symlinks;
   - **searching across everyone's notes**;
   - **chat-history search**, which would reach other people's DM transcripts;
   - **writes to core memory** (`USER.md` and `MEMORY.md`), which every conversation loads, public ones included;
   - reading **Hermes's session database**, directly or with a shell command;
   - shell commands that reach into `people/` outside the person's own folder.

   Subagents (the full council) get the same limits as the chat that started them.

Telegram, the terminal and the workspace are unchanged: there, the council works for its one owner, and none of this applies.

### Limits, honestly

- **Core memory is shared.** On Discord, core memory is off for writes, but whatever is already in `USER.md` and `MEMORY.md` is loaded into every chat, public channels included. Keep it to settings (the health check warns otherwise). If you used the council before, move your personal lines into your own folder (`notes/people/discord-<your id>/profile.md`) with the Memory Card.
- **Shared notes are shared.** The top-level notes folder (`notes/*.md`) is visible to every conversation. On Discord, personal things belong in each person's folder, and the rules say so.
- **Scheduled jobs run outside the DM.** A person's brief runs as a background job. Its instructions name only their folder, and the brief, open-loops and recap skills use only that folder, but the code-level blocks above apply to chats, not to those background jobs.
- **The model is still a model.** The first layer is instructions. The second layer stops the tool calls that would cross people, but nothing can stop a model repeating something a person typed into the same public channel.
- **The server owner can read everything.** All of it is plain files on your server: the Memory Card, the notes folders and the chat database. That's by design, and worth telling people who use your bot.

## Voice on Discord

Voice messages you send are transcribed as usual. The council's reply audio is made by the `council-voices` plugin, with every member in their own voice. On Discord it may arrive as an audio file rather than a voice bubble, and in Discord voice channels Hermes may use a single voice. Check it with the voice rows in `tests/council-check.md`.

## Troubleshooting

| What you see | Try |
| --- | --- |
| It ignores messages in a channel | Check `bash ~/personal-agent/scripts/check.sh`. Remove `DISCORD_REQUIRE_MENTION=true` from `.env` (it overrides config), and check the channel isn't in `discord.ignored_channels` |
| It ignores a person entirely | They're not allowlisted: add their id to `DISCORD_ALLOWED_USERS`, or a role they have to `DISCORD_ALLOWED_ROLES`, then restart |
| It replies "Chat search is off on Discord" or "That's another person's private folder" | The privacy plugin doing its job. Nothing to fix |
| A DM keeps getting the public-room rules | The session wasn't identified as a DM. Restart the gateway; if it persists, report it with `journalctl --user -u hermes-gateway -n 80` (no tokens in it) |
| Someone wants their private data removed | In their DM: "forget everything about me". Or delete their folder `~/.hermes/notes/people/discord-<id>/` |
