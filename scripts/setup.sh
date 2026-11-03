#!/usr/bin/env bash
# Sidekick: everything after the server is prepared, in one command.
# Run as the 'agent' user (after bootstrap-vps.sh):
#
#   bash ~/personal-agent/scripts/setup.sh
#
# Safe to run again at any time: finished steps are skipped or refreshed,
# nothing you've told the bot is touched. It does, in order:
#   1. install Hermes and the Sidekick profile (model + Telegram questions)
#   2. tune for speed (short thinking time on chat replies)
#   3. the bot's browser from your laptop/phone via Tailscale (optional)
#   4. two-way voice (optional)
#   5. a health check that says what works and how to fix what doesn't
set -euo pipefail

PROFILE="${PROFILE:-sidekick}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HH="$HOME/.hermes/profiles/$PROFILE"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ask() { local a; read -r -p "$1 [Y/n] " a </dev/tty || a=""; [[ ! "$a" =~ ^[Nn] ]]; }
[[ $EUID -ne 0 ]] || { echo "Run as 'agent', not root (log in with: ssh agent@YOUR_SERVER_IP)." >&2; exit 1; }

# Make 'hermes' work in every new terminal, not just inside these scripts.
grep -qs 'HOME/.local/bin' "$HOME/.bashrc" || \
  printf '\n# Hermes\nexport PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"\n' >> "$HOME/.bashrc"

cat <<'INTRO'

Sidekick setup. About 20-30 minutes, mostly waiting. You'll be asked:
  - to sign in to your AI model (Grok: open a link, enter a code)
  - for your Telegram bot token (from @BotFather) and your user ID
  - optionally: to approve this server in Tailscale and pick a password
  - optionally: which voices to use
Every step can be re-run later; nothing is lost if you stop with Ctrl+C.
INTRO

# ------------------------------------------------------------- 1. install
if command -v hermes >/dev/null && [[ -d "$HH" ]] && hermes -p "$PROFILE" config get model.provider 2>/dev/null | grep -qv '^None$\|^$'; then
  say "Step 1 of 5: already installed; refreshing skills and settings"
  hermes profile update "$PROFILE" -y || true
  bash "$HH/skills/persona-switch/build-soul.sh" >/dev/null || true
  # Older installs made a sidekick-only gateway service that fights the main
  # one (slow or missing replies, restarts that hang). One host service only.
  if systemctl --user cat "hermes-gateway-$PROFILE.service" >/dev/null 2>&1; then
    echo "Removing the old $PROFILE-only gateway service..."
    timeout 60 hermes -p "$PROFILE" gateway uninstall || true
  fi
  hermes -p default gateway install --if-missing || true
else
  say "Step 1 of 5: installing Hermes and Sidekick"
  SIDEKICK_SETUP=1 bash "$REPO_DIR/scripts/install-agent.sh" "$@"
fi

# --------------------------------------------------------------- 2. speed
say "Step 2 of 5: tuning for quick replies"
# Chat turns don't need long deliberation; this is the biggest speed lever
# with reasoning models like Grok. Say "think hard about…" for the odd tough one.
hermes -p "$PROFILE" config set agent.reasoning_effort low >/dev/null
echo "Thinking time on chat replies: low."

# ------------------------------------------------------------ 3. browser
say "Step 3 of 5: see the bot's browser from your laptop or phone"
echo "Uses Tailscale (free): a private https address only your devices can open."
if ask "Set it up now? (needs the Tailscale app on your laptop/phone)"; then
  bash "$REPO_DIR/scripts/remote-access.sh" || echo "Remote access didn't finish; re-run: bash $REPO_DIR/scripts/remote-access.sh"
else
  echo "Skipped. Later: bash $REPO_DIR/scripts/remote-access.sh"
fi

# -------------------------------------------------------------- 4. voice
say "Step 4 of 5: talk to it"
echo "  grok = Grok's voices (needs an xAI plan with voice)   free = free voices   skip"
read -r -p "Which? [grok/free/skip] " V </dev/tty || V=skip
case "${V:-skip}" in
  grok|free) bash "$REPO_DIR/scripts/voice-setup.sh" "$V" || echo "Voice setup didn't finish; re-run: bash $REPO_DIR/scripts/voice-setup.sh $V" ;;
  *) echo "Skipped. Later: bash $REPO_DIR/scripts/voice-setup.sh grok" ;;
esac

# -------------------------------------------------------- auto-update
say "Keeping it up to date"
echo "Nightly at 04:30 (server time) it can pull improvements from GitHub, update"
echo "Hermes weekly, restart, and roll back by itself if anything fails."
if ask "Turn on automatic updates?"; then
  bash "$REPO_DIR/scripts/auto-update.sh" enable || echo "Couldn't turn it on; later: bash $REPO_DIR/scripts/auto-update.sh enable"
else
  echo "Skipped. Later: bash $REPO_DIR/scripts/auto-update.sh enable  (or update by hand: update.sh)"
fi

# ------------------------------------------------------- restart + check
say "Restarting the agent with everything applied"
timeout 120 hermes -p default gateway restart || echo "Restart didn't confirm; the check below will say more."
sleep 5

say "Step 5 of 5: health check"
bash "$REPO_DIR/scripts/check.sh" --speed || true

cat <<EOF

$(printf '\033[1;32m')Done.$(printf '\033[0m') Next: open your bot in Telegram, tap Start, send /sethome, and say hi.
Anything red above? Run its 'fix:' line, or run this script again.
Health check any time: bash $REPO_DIR/scripts/check.sh
EOF
