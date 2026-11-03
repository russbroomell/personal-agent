#!/usr/bin/env bash
# Sidekick: install the agent for the current user (run as "agent", not root).
#
#   bash ~/personal-agent/scripts/install-agent.sh [--persona pip|sam|mortimer|rex|nova|vic] [--name NAME] [--strength 1-5]
#
# Safe to re-run: it updates what's there and never touches memories,
# notes, chats or credentials.
#
# Steps:
#   1. Install Hermes Agent (official installer) if it isn't installed
#   2. Install the Sidekick profile from ./distribution
#   3. Build its personality (SOUL.md), notes folder and starter core memory
#   4. Point the bot's screen at the host browser
#   5. Start the Memory Card page (private, localhost only)
#   6. Walk you through: AI model, Telegram, then start the 24/7 gateway
set -euo pipefail

PROFILE="${PROFILE:-sidekick}"
PERSONA="pip"
BOT_NAME=""
STRENGTH="3"
MC_PORT="${MC_PORT:-8765}"
WEBAPP_PORT="${WEBAPP_PORT:-9120}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --persona) PERSONA="$2"; shift 2 ;;
    --name) BOT_NAME="$2"; shift 2 ;;
    --strength) STRENGTH="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }
ask()  { local a; read -r -p "$1 [Y/n] " a </dev/tty || true; [[ -z "$a" || "$a" =~ ^[Yy] ]]; }

[[ $EUID -ne 0 ]] || die "Run this as your normal user (e.g. 'agent'), not root."
[[ "$STRENGTH" =~ ^[1-5]$ ]] || die "--strength must be 1 to 5."

# ---------------------------------------------------------------- 1. Hermes
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
if ! command -v hermes >/dev/null 2>&1; then
  say "Installing Hermes Agent (official installer, a few minutes)"
  # --skip-setup: we configure our own profile below instead of the default one.
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
  hash -r
fi
command -v hermes >/dev/null 2>&1 || die "hermes not found after install. Open a new SSH session and re-run this script."
say "Hermes: $(hermes --version 2>/dev/null | head -1)"

# --------------------------------------------------------------- 2. Profile
HH="$HOME/.hermes/profiles/$PROFILE"
if [[ -f "$HH/distribution.yaml" ]]; then
  say "Updating the $PROFILE profile (your model, memory and chats are kept)"
  hermes profile update "$PROFILE" -y
else
  say "Installing the $PROFILE profile"
  hermes profile install "$REPO_DIR/distribution" --name "$PROFILE" --alias -y
fi
[[ -d "$HH" ]] || die "Profile folder $HH wasn't created. Check the output above."
hermes profile use "$PROFILE" >/dev/null 2>&1 || true

# ------------------------------------------- 3. Personality, notes, memory
say "Personality"
if [[ -f "$HH/persona.conf" && -z "$BOT_NAME" && "$PERSONA" == "pip" ]]; then
  bash "$HH/skills/persona-switch/build-soul.sh"          # keep the saved choice
else
  bash "$HH/skills/persona-switch/build-soul.sh" "$PERSONA" "$BOT_NAME"
fi

say "Notes folder and starter core memory"
# shellcheck source=lib/starter.sh
source "$REPO_DIR/scripts/lib/starter.sh"
seed_notes
seed_user_memory

# ------------------------------------------------------ 4. Browser screen
say "Bot Screen browser"
BROWSER_PATH=""
[[ -r /etc/sidekick/host.conf ]] && BROWSER_PATH="$(sed -n 's/^BROWSER_PATH=//p' /etc/sidekick/host.conf)"
if [[ -n "$BROWSER_PATH" && -x "$BROWSER_PATH" ]]; then
  hermes -p "$PROFILE" config set browser.executable_path "$BROWSER_PATH"
  echo "Browser: $BROWSER_PATH"
else
  warn "No host browser recorded (run bootstrap-vps.sh first). Hermes will use its own Chromium."
fi
hermes -p "$PROFILE" config set webapp.port "$WEBAPP_PORT" >/dev/null
hermes -p "$PROFILE" computer-use status 2>/dev/null | head -5 || \
  warn "Computer Use driver not ready; run: hermes -p $PROFILE computer-use install"
hermes -p "$PROFILE" computer-use screen status 2>/dev/null | head -8 || true

# --------------------------------------------------------- 5. Memory Card
say "Memory Card page (localhost only)"
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/sidekick-memory-card-$PROFILE.service" <<EOF
[Unit]
Description=Sidekick Memory Card for $PROFILE (localhost only)
After=network.target

[Service]
ExecStart=/usr/bin/python3 $REPO_DIR/scripts/memory-card/server.py --home $HH --port $MC_PORT
Restart=on-failure

[Install]
WantedBy=default.target
EOF
if systemctl --user daemon-reload 2>/dev/null; then
  systemctl --user enable --now sidekick-memory-card-$PROFILE.service
  systemctl --user restart sidekick-memory-card-$PROFILE.service
else
  warn "systemd user session not available; start it by hand: python3 $REPO_DIR/scripts/memory-card/server.py --home $HH &"
fi

# ---------------------------------------- 6. Model, Telegram, gateway
say "AI model"
echo "Pick the model this agent uses. Default: Grok (pick 'xAI Grok OAuth' for"
echo "SuperGrok / X Premium+, or 'xAI' with an API key). Also available: OpenAI,"
echo "OpenRouter, Nous Portal, or your own OpenAI-compatible endpoint (Ollama,"
echo "vLLM, LM Studio)."
echo "See docs/models.md for which to pick."
if ask "Set up the model now?"; then
  hermes -p "$PROFILE" model </dev/tty
fi

say "Telegram"
echo "Easiest: open the workspace (see below), go to Messaging > Telegram,"
echo "and use 'Create with QR'. Or run the text wizard now."
if ask "Run the Telegram wizard in this terminal now?"; then
  hermes -p "$PROFILE" gateway setup </dev/tty || warn "Wizard exited; you can use the QR route later."
fi

say "Starting the 24/7 gateway (runs at boot, survives logout)"
hermes -p "$PROFILE" gateway install || warn "Gateway service install failed; see 'hermes -p $PROFILE gateway status'."
hermes -p "$PROFILE" gateway restart 2>/dev/null || hermes -p "$PROFILE" gateway start || true
sleep 3
hermes -p "$PROFILE" gateway status 2>/dev/null | head -10 || true

IP="$(curl -fsS -4 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
MC_URL="$(python3 "$REPO_DIR/scripts/memory-card/server.py" --home "$HH" --port "$MC_PORT" --print-url)"
cat <<EOF

$(printf '\033[1;32m')Sidekick is installed.$(printf '\033[0m')

From your computer, open the private tunnel (leave it running):

    ssh -N -L $WEBAPP_PORT:127.0.0.1:$WEBAPP_PORT -L $MC_PORT:127.0.0.1:$MC_PORT $USER@$IP

Then:
  Workspace + bot screen:  run  'hermes -p $PROFILE webapp --no-open'  here and open the link it prints
  Memory Card:             $MC_URL
  Health check:            hermes -p $PROFILE doctor

Say hi to your bot on Telegram. It will run the 5-minute first session.
Next: bash $REPO_DIR/scripts/remote-access.sh   (see the bot's browser, no SSH)
      bash $REPO_DIR/scripts/voice-setup.sh grok (talk to it; or 'free')
EOF
