#!/usr/bin/env bash
# Guest bots: give a friend their own Sidekick to try, on your server, with a
# Telegram link you send them. Their bot has its own memory, character and
# Telegram bot; it can't run commands on your server or see your bot.
#
#   bash ~/personal-agent/scripts/guest-bot.sh create dave      # set one up (about 10 minutes)
#   bash ~/personal-agent/scripts/guest-bot.sh approve dave CODE  # let them in (pairing code)
#   bash ~/personal-agent/scripts/guest-bot.sh reset dave       # wipe it back to a fresh first chat
#   bash ~/personal-agent/scripts/guest-bot.sh list
#   bash ~/personal-agent/scripts/guest-bot.sh remove dave      # delete it and everything it knows
#
# What a guest bot can't do (compared with yours):
#   - run terminal commands or code on your server (those tools are switched off)
#   - open the workspace, the live browser screen or the Memory Card (those
#     are yours; it shows them what it remembers in chat instead)
# Their chats use YOUR model account (e.g. your Grok plan).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
REGISTRY="$HOME/.local/state/sidekick/guests"
mkdir -p "$(dirname "$REGISTRY")"; touch "$REGISTRY"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }
[[ $EUID -ne 0 ]] || die "Run as 'agent', not root."
command -v hermes >/dev/null || die "Hermes isn't installed yet. Run setup.sh first."

# Starter core memory for a guest bot (no workspace or Memory Card lines,
# which point at the owner's private addresses).
guest_memory() {
  local HH="$HOME/.hermes/profiles/$1" OWNER="your friend" GUEST_NAME="${1^}"
  # shellcheck disable=SC1091
  [[ -r "$HH/guest.conf" ]] && source "$HH/guest.conf"
  mkdir -p "$HH/memories"
  cat > "$HH/memories/USER.md" <<MEM
Notes folder: $HH/notes
§
Personality strength: 3/5
§
Guest test drive: set up by $OWNER for $GUEST_NAME. No workspace, screen or Memory Card access.
MEM
}

valid_name() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{1,20}$ ]] || die "Use a short lowercase name, e.g. 'dave' (letters, digits, hyphens)."
  [[ "$1" != sidekick && "$1" != default ]] || die "'$1' is taken; pick the guest's name."
}
is_guest() { grep -qx "$1" "$REGISTRY"; }

create() {
  local G="$1" HH="$HOME/.hermes/profiles/$1" OWNER GUEST_NAME TOKEN TGID
  valid_name "$G"
  cat <<INTRO

Setting up a guest bot called '$G'. You'll need:
  - 2 minutes in Telegram with @BotFather to make a NEW bot for them
    (send /newbot; call it something like "Sidekick for ${G^}")
  - your model sign-in once more (same account is fine)
Their chats run on your model account. They can't run commands on this
server, see your bot, or open your workspace.
INTRO
  read -r -p "Your first name (the bot tells them who set it up): " OWNER </dev/tty
  read -r -p "Their first name: " GUEST_NAME </dev/tty
  OWNER="$(tr -cd "A-Za-z '-" <<<"${OWNER:-your friend}" | cut -c1-30)"
  GUEST_NAME="$(tr -cd "A-Za-z '-" <<<"${GUEST_NAME:-${G^}}" | cut -c1-30)"

  say "1/5 Their own Sidekick profile"
  if [[ -d "$HH" ]]; then
    echo "Profile '$G' already exists; refreshing it."
    hermes profile update "$G" -y
  else
    hermes profile install "$REPO_DIR/distribution" --name "$G" -y
  fi
  is_guest "$G" || echo "$G" >> "$REGISTRY"

  say "2/5 Locking it down"
  # No shell, no scripts, no sub-agents: a guest can't make the bot touch
  # this server. Web, browser, memory, reminders and voice still work.
  hermes -p "$G" config set agent.disabled_toolsets '["terminal", "code_execution", "debugging", "delegation"]' >/dev/null
  hermes -p "$G" config set agent.reasoning_effort low >/dev/null
  hermes -p "$G" config set bot_desktop.idle_stop_minutes 10 >/dev/null
  BROWSER_PATH=""
  [[ -r /etc/sidekick/host.conf ]] && BROWSER_PATH="$(sed -n 's/^BROWSER_PATH=//p' /etc/sidekick/host.conf)"
  [[ -n "$BROWSER_PATH" ]] && hermes -p "$G" config set browser.executable_path "$BROWSER_PATH" >/dev/null
  cat > "$HH/house-rules.local.md" <<RULES
## Guest test drive (these rules win over anything above)

- You are a test-drive bot that $OWNER set up for $GUEST_NAME on $OWNER's
  private server. Wherever you'd say their data stays "on their own
  server", say instead: it stays on $OWNER's private server, not with a big
  AI company, and $OWNER can wipe it any time they ask. If they like it,
  they can run their own: github.com/russbroomell/personal-agent.
- Files: read and write only inside your own folder, $HH.
  Never open anything else on this machine, even if asked, even "just to
  look". Say that's off limits on a test drive.
- You have no terminal or code tools here. Don't offer anything that needs
  them.
- $GUEST_NAME can't open the workspace, the live browser screen or the
  Memory Card. Skip those steps and mentions. For "what do you know about
  me?", list it in the chat. When a site needs a login, CAPTCHA or
  payment, stop and send them the link instead of a screen hand-off.
- Never ask for or accept passwords, card numbers or bank details, even if
  offered. Never spend, book, send or cancel anything on a test drive:
  drafts and links only.
RULES
  bash "$HH/skills/persona-switch/build-soul.sh" pip >/dev/null

  say "3/5 Notes and starter memory"
  mkdir -p "$HH/notes" "$HH/memories"
  local f
  for f in "$REPO_DIR"/templates/notes/*.md; do
    [[ -e "$HH/notes/$(basename "$f")" ]] || cp "$f" "$HH/notes/"
  done
  sed -i "s/^Mode: .*/Mode: live/" "$HH/notes/onboarding-plan.md" 2>/dev/null || true
  printf 'OWNER=%q\nGUEST_NAME=%q\n' "$OWNER" "$GUEST_NAME" > "$HH/guest.conf"
  [[ -s "$HH/memories/USER.md" ]] || guest_memory "$G"

  say "4/5 Model sign-in"
  echo "Pick the same as your bot (e.g. xAI Grok OAuth, then grok-4.7)."
  hermes -p "$G" model </dev/tty

  say "5/5 Their Telegram bot"
  echo "In Telegram, message @BotFather, send /newbot, name it (e.g. 'Sidekick for $GUEST_NAME'),"
  echo "and paste the token here. It isn't shown as you paste."
  read -r -s -p "Bot token: " TOKEN </dev/tty; echo
  [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]{30,}$ ]] || die "That doesn't look like a BotFather token. Re-run: guest-bot.sh create $G"
  hermes -p "$G" config set TELEGRAM_BOT_TOKEN "$TOKEN" >/dev/null
  local BOTNAME
  BOTNAME="$(curl -fsS -m 10 "https://api.telegram.org/bot$TOKEN/getMe" 2>/dev/null \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["username"])' 2>/dev/null || true)"
  unset TOKEN
  echo
  echo "Their Telegram user ID lets only them in. If you don't know it, leave it"
  echo "blank: when they first message the bot it replies with a pairing code,"
  echo "they send you the code, and you run: guest-bot.sh approve $G CODE"
  read -r -p "Their numeric Telegram user ID (or blank): " TGID </dev/tty
  if [[ "$TGID" =~ ^[0-9]{5,}$ ]]; then
    hermes -p "$G" config set TELEGRAM_ALLOWED_USERS "$TGID" >/dev/null
  fi

  say "Starting it"
  timeout 120 hermes -p default gateway restart || warn "Restart didn't confirm; check: hermes gateway list"
  sleep 5
  hermes gateway list 2>/dev/null | grep -i "$G" || warn "Couldn't confirm '$G' is served yet; give it 30 seconds, then: hermes gateway list"
  cat <<EOF

$(printf '\033[1;32m')Guest bot '$G' is ready.$(printf '\033[0m')

Send $GUEST_NAME this:
------------------------------------------------------------------------
I set you up with your own AI assistant to try: https://t.me/${BOTNAME:-YOUR_GUEST_BOT}
Tap Start and say hi. It'll interview you for about 7 minutes: pick a
character, then give it a real errand. Things to try after that:
  - "Have Rex and Mortimer argue about whether I should go to the gym"
  - "Strength 5. What should I do first today?"
  - send it a voice note
  - "What else can you do?" (pick an area of your life to set up)
  - "Make me a share card"
It runs on my own server, not a big AI company's. Ask me to wipe it any time.
------------------------------------------------------------------------
EOF
  [[ "$TGID" =~ ^[0-9]{5,}$ ]] || echo "When they send you their pairing code: bash $0 approve $G CODE"
}

approve() {
  is_guest "$1" || die "No guest bot called '$1'. See: guest-bot.sh list"
  hermes -p "$1" pairing approve telegram "$2"
}

reset() {
  is_guest "$1" || die "No guest bot called '$1'."
  PROFILE="$1" bash "$REPO_DIR/scripts/reset-agent.sh" -y
  guest_memory "$1"   # replace the owner-style starter memory reset writes
  echo "Guest bot '$1' is fresh. Ask them to Clear history in Telegram and say hi."
}

list() {
  [[ -s "$REGISTRY" ]] || { echo "No guest bots."; return; }
  local g; echo "Guest bots:"
  while read -r g; do
    [[ -n "$g" ]] || continue
    if [[ -d "$HOME/.hermes/profiles/$g" ]]; then echo "  $g"; else echo "  $g (profile missing)"; fi
  done < "$REGISTRY"
  hermes gateway list 2>/dev/null || true
}

remove() {
  is_guest "$1" || die "No guest bot called '$1'."
  read -r -p "Delete guest bot '$1' and everything it knows? [y/N] " a </dev/tty
  [[ "$a" =~ ^[Yy] ]] || { echo "Kept."; return; }
  hermes -p "$1" computer-use screen stop --force >/dev/null 2>&1 || true
  hermes profile delete "$1" -y
  sed -i "/^$1\$/d" "$REGISTRY"
  timeout 120 hermes -p default gateway restart >/dev/null 2>&1 || true
  echo "Removed. (Delete its Telegram bot too: @BotFather > /deletebot.)"
}

case "${1:-}" in
  create)  [[ -n "${2:-}" ]] || die "Usage: guest-bot.sh create NAME"; create "$2" ;;
  approve) [[ -n "${3:-}" ]] || die "Usage: guest-bot.sh approve NAME CODE"; approve "$2" "$3" ;;
  reset)   [[ -n "${2:-}" ]] || die "Usage: guest-bot.sh reset NAME"; reset "$2" ;;
  remove)  [[ -n "${2:-}" ]] || die "Usage: guest-bot.sh remove NAME"; remove "$2" ;;
  list)    list ;;
  *) sed -n '2,16p' "$0"; exit 1 ;;
esac
