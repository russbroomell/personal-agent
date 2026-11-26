#!/usr/bin/env bash
# The Council: install on a computer that already runs Hermes Agent.
#
#   git clone -b romulus-remus https://github.com/russbroomell/personal-agent.git ~/personal-agent
#   bash ~/personal-agent/install.sh
#
# Assumes Hermes is installed and has a working model (LLM). Run it as the
# user Hermes runs as (root is fine). Safe to run again: it refreshes what's
# there and never touches memory, notes, chats or keys.
#
# It asks yes/no before each optional step (Enter = recommended answer).
# Options:
#   --yes                     take every recommended answer, no questions
#   --profile NAME            profile to install as (default: council)
#   --migrate-from NAME       copy memory and notes from another profile (e.g. sidekick)
#   --voice grok|free|elevenlabs|skip
#   --no-update               don't turn on nightly auto-update
#   --no-check                skip the final health check
#
# Steps:
#   1. Pre-flight: Hermes, its version, a model, and a few system tools
#   2. Install (or update) the council profile and its model settings
#   3. Build the council's SOUL, voices, notes and starter memory
#   4. Messaging: a Telegram bot for the council (or later, in the workspace)
#   5. Background services: the 24/7 gateway and the Memory Card page
#   6. Voice, auto-update, and (optionally) remote access with Tailscale
#   7. Health check, including a test question to the council
set -euo pipefail

PROFILE="${PROFILE:-council}"
MIGRATE=""; VOICE=""; UPDATE=1; CHECK=1
MC_PORT="${MC_PORT:-8765}"
WEBAPP_PORT="${WEBAPP_PORT:-9120}"
HOST_PROFILE="default"   # Hermes runs one gateway per machine, from its default profile
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_ROOT="${HERMES_HOME:-$HOME/.hermes}"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) export COUNCIL_YES=1; shift ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --migrate-from) MIGRATE="$2"; shift 2 ;;
    --voice) VOICE="$2"; shift 2 ;;
    --no-update) UPDATE=0; shift ;;
    --no-check) CHECK=0; shift ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 1 ;;
  esac
done
[[ "$PROFILE" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "--profile: lower-case letters, digits, - and _ only." >&2; exit 1; }
HH="$HERMES_ROOT/profiles/$PROFILE"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }
# shellcheck source=scripts/lib/ask.sh
source "$REPO_DIR/scripts/lib/ask.sh"
SUDO="sudo"; [[ $EUID -eq 0 ]] && SUDO=""
tty_ok() { [[ -z "${COUNCIL_YES:-}" ]] && { : </dev/tty; } 2>/dev/null; }

cat <<'INTRO'

The Council: one personal assistant, many voices.
About 5-10 minutes. You'll be asked a few yes/no questions, and optionally
for a Telegram bot token and a voice choice. Ctrl+C is safe at any point;
run this again to carry on.
INTRO

# --------------------------------------------------------- 1. pre-flight
say "Step 1 of 7: pre-flight"
if ! command -v hermes >/dev/null 2>&1; then
  warn "Hermes Agent isn't on PATH for $(id -un)."
  if ask "Install Hermes now with the official installer? (No = stop here)" N; then
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
    hash -r
  fi
  command -v hermes >/dev/null 2>&1 || die "Install Hermes first (or log in as the user it runs as), then re-run: bash $0"
fi
HAVE_V="$(hermes --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
TESTED_V="$(cat "$REPO_DIR/HERMES_VERSION")"
ok "Hermes ${HAVE_V:-unknown version} (tested with $TESTED_V)"
if [[ -n "$HAVE_V" && "$HAVE_V" != "$TESTED_V" ]]; then
  if [[ "$(printf '%s\n%s\n' "$HAVE_V" "$TESTED_V" | sort -V | head -1)" == "$HAVE_V" ]]; then
    warn "Hermes $HAVE_V is older than $TESTED_V; voices and buttons may not work."
    if ask "Update Hermes now (hermes update)?" Y; then hermes update --yes || warn "hermes update reported a problem; carrying on."; fi
  else
    echo "  Newer than tested. It usually works; the health check at the end will tell."
  fi
fi
[[ $EUID -ne 0 ]] || echo "  Running as root: fine, the council will run as root's Hermes."

missing=()
for t in git python3 curl ffmpeg; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "  Missing: ${missing[*]} (ffmpeg makes voice bubbles; the rest run the scripts)."
  if command -v apt-get >/dev/null 2>&1 && ask "Install them with apt-get?" Y; then
    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq "${missing[@]}" >/dev/null && ok "installed ${missing[*]}"
  else
    warn "Install ${missing[*]} yourself; voice notes need ffmpeg."
  fi
else
  ok "git, python3, curl, ffmpeg"
fi

# Where the existing model setup lives: the default profile, unless the
# council profile already has one.
model_of() { hermes -p "$1" config get model.provider 2>/dev/null | tail -1; }
SRC_MODEL="$(model_of "$HOST_PROFILE" || true)"
if [[ -n "$SRC_MODEL" && "$SRC_MODEL" != "None" ]]; then ok "existing model setup: $SRC_MODEL (default profile)"
else echo "  No model on the default profile; you'll pick one in step 2."; fi

# ---------------------------------------------------------- 2. profile
say "Step 2 of 7: the '$PROFILE' profile"
if [[ -f "$HH/distribution.yaml" ]]; then
  echo "Updating it (memory, notes, chats, model and keys are kept)..."
  hermes profile update "$PROFILE" -y
else
  hermes profile install "$REPO_DIR/distribution" --name "$PROFILE" --alias -y
fi
[[ -d "$HH" ]] || die "Profile folder $HH wasn't created; see the output above."

# The model: reuse the one already set up, so there's nothing to re-enter.
if [[ "$(model_of "$PROFILE" || true)" =~ ^(|None)$ ]]; then
  if [[ -n "$SRC_MODEL" && "$SRC_MODEL" != "None" ]] && ask "Use your existing model setup ($SRC_MODEL) for the council?" Y; then
    # Copy the model block of config.yaml plus the sign-in files, never overwriting.
    python3 - "$HERMES_ROOT/config.yaml" "$HH/config.yaml" <<'PY'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
def block(text, key):
    m = re.search(rf"^{key}:.*?(?=^\S|\Z)", text, re.M | re.S)
    return m.group(0) if m else ""
s = open(src, encoding="utf-8").read()
d = open(dst, encoding="utf-8").read() if __import__("os").path.exists(dst) else ""
model = block(s, "model")
if model and not block(d, "model"):
    with open(dst, "a", encoding="utf-8") as f:
        f.write("\n" + model.rstrip() + "\n")
PY
    for f in .env auth.json; do
      if [[ -f "$HERMES_ROOT/$f" && ! -s "$HH/$f" ]]; then
        # Model keys only; a Telegram token stays with its own bot (step 4).
        if [[ "$f" == .env ]]; then grep -vE '^(TELEGRAM_|DISCORD_|SLACK_|WHATSAPP_|SIGNAL_)' "$HERMES_ROOT/$f" > "$HH/$f" || true
        else cp "$HERMES_ROOT/$f" "$HH/$f"; fi
        chmod 600 "$HH/$f"
      fi
    done
  fi
  if [[ "$(model_of "$PROFILE" || true)" =~ ^(|None)$ ]]; then
    echo "Pick the council's model (any provider works; a fast one feels best in chat)."
    if tty_ok; then hermes -p "$PROFILE" model </dev/tty || warn "Model setup didn't finish; later: hermes -p $PROFILE model"
    else warn "No terminal to ask on; later: hermes -p $PROFILE model"; fi
  fi
fi
M="$(model_of "$PROFILE" || true)"; [[ -n "$M" && "$M" != "None" ]] && ok "model: $M $(hermes -p "$PROFILE" config get model.default 2>/dev/null | tail -1)"
hermes -p "$PROFILE" config set agent.reasoning_effort low >/dev/null || true
hermes -p "$PROFILE" config set agent.disabled_toolsets '[]' >/dev/null || true

# Optional: bring memory and notes over from another profile.
if [[ -z "$MIGRATE" && -d "$HERMES_ROOT/profiles/sidekick/memories" && "$PROFILE" != sidekick && ! -s "$HH/memories/USER.md" ]]; then
  ask "Found a Sidekick profile. Bring its memory and notes to the council?" Y && MIGRATE=sidekick
fi
if [[ -n "$MIGRATE" ]]; then
  SRC="$HERMES_ROOT/profiles/$MIGRATE"; [[ "$MIGRATE" == default ]] && SRC="$HERMES_ROOT"
  [[ -d "$SRC" ]] || die "--migrate-from: no profile at $SRC"
  mkdir -p "$HH/memories" "$HH/notes"
  [[ -s "$HH/memories/USER.md" ]] && cp -a "$HH/memories" "$HH/memories.before-migrate.$(date +%s)"
  cp -an "$SRC/memories/." "$HH/memories/" 2>/dev/null || true
  cp -an "$SRC/notes/." "$HH/notes/" 2>/dev/null || true
  sed -i "s|^Notes folder: .*|Notes folder: $HH/notes|" "$HH/memories/USER.md" 2>/dev/null || true
  ok "copied memory and notes from '$MIGRATE' (its own copy is untouched)"
fi

# -------------------------------------------------- 3. council and memory
say "Step 3 of 7: seating the council"
bash "$HH/skills/council/build-soul.sh"
# shellcheck source=scripts/lib/starter.sh
source "$REPO_DIR/scripts/lib/starter.sh"
seed_notes
seed_user_memory
ok "notes folder and starter memory in $HH"
for b in google-chrome google-chrome-stable chromium chromium-browser; do
  if BP="$(command -v "$b" 2>/dev/null)"; then
    hermes -p "$PROFILE" config set browser.executable_path "$BP" >/dev/null && ok "browser for errands: $BP"; break
  fi
done

# -------------------------------------------------------- 4. messaging
say "Step 4 of 7: messaging"
if grep -qsE '^TELEGRAM_BOT_TOKEN=.' "$HH/.env"; then
  ok "the council already has a Telegram bot"
else
  echo "The council needs its own Telegram bot (two profiles can't share one)."
  echo "In Telegram: message @BotFather, send /newbot, and copy the token. Your"
  echo "numeric user id comes from @userinfobot."
  if tty_ok && ask "Set up the council's Telegram bot now?" Y; then
    hermes -p "$PROFILE" gateway setup </dev/tty || warn "Wizard exited; later: hermes -p $PROFILE gateway setup"
  else
    echo "  Later: hermes -p $PROFILE gateway setup   (or the workspace: Messaging > Telegram > Create with QR)"
  fi
fi

# ----------------------------------------------- 5. background services
say "Step 5 of 7: background services"
if command -v loginctl >/dev/null 2>&1 && [[ "$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null)" != yes ]]; then
  if ask "Keep the council running after you log out (systemd linger)?" Y; then
    $SUDO loginctl enable-linger "$(id -un)" && ok "linger on"
  fi
fi
hermes -p "$HOST_PROFILE" gateway install --if-missing || warn "Gateway service install failed; see: hermes -p $HOST_PROFILE gateway status"
if ask "Run the Memory Card page (see and edit everything the council remembers; localhost only)?" Y; then
  UDIR="$HOME/.config/systemd/user"; mkdir -p "$UDIR"
  cat > "$UDIR/council-memory-card-$PROFILE.service" <<EOF
[Unit]
Description=Council Memory Card for $PROFILE (localhost only)
After=network.target

[Service]
ExecStart=/usr/bin/env python3 $REPO_DIR/scripts/memory-card/server.py --home $HH --port $MC_PORT
Restart=on-failure

[Install]
WantedBy=default.target
EOF
  if systemctl --user daemon-reload 2>/dev/null; then
    systemctl --user enable --now "council-memory-card-$PROFILE.service" >/dev/null 2>&1 || true
    systemctl --user restart "council-memory-card-$PROFILE.service" || warn "Memory Card didn't start; see: journalctl --user -u council-memory-card-$PROFILE"
    ok "Memory Card: $(python3 "$REPO_DIR/scripts/memory-card/server.py" --home "$HH" --port "$MC_PORT" --print-url)"
  else
    warn "No systemd user session; start it by hand: python3 $REPO_DIR/scripts/memory-card/server.py --home $HH &"
  fi
fi

# --------------------------------------- 6. voice, updates, remote access
say "Step 6 of 7: voice, updates and remote access"
if [[ -z "$VOICE" ]]; then
  echo "Voices: each council member speaks in their own voice."
  echo "  grok = Grok's voices (xAI sign-in)  free = free Edge voices + local listening"
  echo "  elevenlabs = the best cast (paid key)  skip = text only for now"
  if tty_ok; then read -r -p "Which? [grok/free/elevenlabs/skip] (free) " VOICE </dev/tty || VOICE=free; fi
  VOICE="${VOICE:-free}"
fi
case "$VOICE" in
  grok|free|elevenlabs) PROFILE="$PROFILE" bash "$REPO_DIR/scripts/voice-setup.sh" "$VOICE" \
                          || warn "Voice setup didn't finish; re-run: bash $REPO_DIR/scripts/voice-setup.sh $VOICE" ;;
  *) echo "  Skipped. Later: bash $REPO_DIR/scripts/voice-setup.sh free" ;;
esac

if [[ $UPDATE -eq 1 ]] && ask "Turn on nightly auto-update (backs up first, rolls back if anything fails)?" Y; then
  PROFILE="$PROFILE" bash "$REPO_DIR/scripts/auto-update.sh" enable || warn "Couldn't turn it on; later: bash $REPO_DIR/scripts/auto-update.sh enable"
else
  echo "  Auto-update off. Update by hand: bash $REPO_DIR/scripts/update.sh"
fi

echo "The workspace is Hermes in a browser: chat, live voice conversation (talk and"
echo "interrupt), and the bot's own browser screen. It's built once (a few minutes,"
echo "about 3 GB of memory at peak, so add swap on a 4 GB server first)."
if [[ "$(hermes -p "$HOST_PROFILE" config get webapp.enabled 2>/dev/null | tail -1)" =~ ^(True|true)$ ]]; then
  ok "workspace already on"
elif ask "Turn on the workspace now?" Y; then
  hermes -p "$HOST_PROFILE" config set webapp.enabled true >/dev/null
  hermes -p "$HOST_PROFILE" config set webapp.host 127.0.0.1 >/dev/null
  hermes -p "$HOST_PROFILE" config set webapp.port "$WEBAPP_PORT" >/dev/null
  # shellcheck source=scripts/lib/build.sh
  source "$REPO_DIR/scripts/lib/build.sh"
  build_workspace "$HOST_PROFILE" "$PROFILE" || warn "Workspace build failed; retry: bash $REPO_DIR/scripts/remote-access.sh"
fi

echo "Remote access gives the workspace (live voice, the bot's browser screen) a"
echo "private https address on your devices, via Tailscale. Without it, use an SSH tunnel."
if ask "Set up Tailscale remote access now?" N; then
  PROFILE="$PROFILE" bash "$REPO_DIR/scripts/remote-access.sh" || warn "Remote access didn't finish; re-run: bash $REPO_DIR/scripts/remote-access.sh"
fi

say "Restarting with everything applied"
timeout 120 hermes -p "$HOST_PROFILE" gateway restart || timeout 60 hermes -p "$HOST_PROFILE" gateway start || warn "Restart didn't confirm; the check below will say more."
sleep 5

# ----------------------------------------------------------- 7. check
if [[ $CHECK -eq 1 ]]; then
  say "Step 7 of 7: health check"
  PROFILE="$PROFILE" bash "$REPO_DIR/scripts/check.sh" --speed || true
fi

cat <<EOF

$(printf '\033[1;32m')The council is seated.$(printf '\033[0m')

Next, in Telegram: open the council's bot, tap Start, send /sethome, then say hi.
Marcus runs a 5-minute first chat: six quick questions and one real thing done.

Handy:
  Chat in the terminal:            hermes -p $PROFILE
  Health check, with fixes:        bash $REPO_DIR/scripts/check.sh
  Who's seated, who's on the bench: bash $HH/skills/council/build-soul.sh --list
  Workspace and Memory Card from your laptop (leave it running):
    ssh -N -L $WEBAPP_PORT:127.0.0.1:$WEBAPP_PORT -L $MC_PORT:127.0.0.1:$MC_PORT $(id -un)@<this server>
    then open http://127.0.0.1:$WEBAPP_PORT
EOF
