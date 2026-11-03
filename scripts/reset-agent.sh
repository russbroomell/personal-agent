#!/usr/bin/env bash
# Sidekick: the reset button, plus snapshots for demos.
#
#   bash ~/personal-agent/scripts/reset-agent.sh                 # factory reset (asks first)
#   bash ~/personal-agent/scripts/reset-agent.sh -y --persona vic --strength 5
#   bash ~/personal-agent/scripts/reset-agent.sh --snapshot lived-in   # save the current state
#   bash ~/personal-agent/scripts/reset-agent.sh --restore lived-in    # go back to it
#   bash ~/personal-agent/scripts/reset-agent.sh --list
#   bash ~/personal-agent/scripts/reset-agent.sh -y --demo           # fresh, in demo mode
#
# Demo -> test drive: carry what a prospect told the demo agent onto their
# own bot (another profile), without the demo's chats or schedules:
#   bash ~/personal-agent/scripts/reset-agent.sh --snapshot demo-jane
#   PROFILE=jane bash ~/personal-agent/scripts/reset-agent.sh --restore demo-jane --carry-over
#
# A factory reset ERASES: core memory, topic notes, savings ledger, all chats,
# scheduled jobs (brief, recap, watchers...), the bot browser's logins and
# cookies, and files the agent made. The next "hi" starts the first-session
# interview from scratch.
#
# It KEEPS: the model sign-in, Telegram bot and allowlist, voice settings,
# remote access (Tailscale + workspace password), config and skills.
#
# Every reset and restore first saves an automatic snapshot, so it can be
# undone with --restore. Snapshots live in ~/sidekick-snapshots (private;
# they contain your chats and memory, but no keys or tokens).
#
# Modes (written to notes/onboarding-plan.md): live (default), demo (fast
# onboarding, skipped things parked, no nagging), test-drive (set by
# --carry-over; the agent welcomes them back and resumes what was parked).
#
# Runs from SSH or from the terminal inside the workspace.
set -euo pipefail

PROFILE="${PROFILE:-sidekick}"
MC_PORT="${MC_PORT:-8765}"
WEBAPP_PORT="${WEBAPP_PORT:-9120}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HH="$HOME/.hermes/profiles/$PROFILE"
SNAPS="$HOME/sidekick-snapshots"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

ACTION="reset"; NAME=""; YES=""; PERSONA="pip"; BOT_NAME=""; STRENGTH="3"; KEEP_BROWSER=""; MODE="live"; CARRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --snapshot) ACTION="snapshot"; NAME="${2:?name}"; shift 2 ;;
    --restore)  ACTION="restore";  NAME="${2:?name}"; shift 2 ;;
    --list)     ACTION="list"; shift ;;
    --persona)  PERSONA="$2"; shift 2 ;;
    --name)     BOT_NAME="$2"; shift 2 ;;
    --strength) STRENGTH="$2"; shift 2 ;;
    --keep-browser) KEEP_BROWSER=1; shift ;;
    --demo)     MODE="demo"; shift ;;
    --carry-over) CARRY=1; shift ;;
    -y|--yes)   YES=1; shift ;;
    -h|--help)  sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
done

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 || -n "${SIDEKICK_ALLOW_ROOT:-}" ]] || die "Run as your normal user (e.g. 'agent'), not root."
[[ -d "$HH" ]] || die "Profile $PROFILE isn't installed."
[[ "$STRENGTH" =~ ^[1-5]$ ]] || die "--strength must be 1 to 5."
[[ -z "$NAME" || "$NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "Snapshot names: letters, numbers, dot, dash, underscore."

# Everything that is "what the agent knows and did", relative to $HH.
# (Not here, on purpose: .env, auth.json, config.yaml, skills/, webapp/,
# gateway_voice_mode.json, memory-card.token, distribution.yaml.)
STATE_PATHS=(memories notes state.db state.db-wal state.db-shm sessions
             cron/jobs.json cron/output persona.conf SOUL.md)
SCRATCH_PATHS=(workspace plans checkpoints logs image_cache audio_cache
               document_cache browser_screenshots SOUL.md.bak)
BROWSER_PATH_REL="bot-desktop/browser-profile"

gateway_stop() {
  hermes -p "$PROFILE" computer-use screen stop --force >/dev/null 2>&1 || true
  hermes -p "$PROFILE" gateway stop >/dev/null 2>&1 || true
  sleep 2
}
gateway_start() {
  hermes -p "$PROFILE" gateway start >/dev/null 2>&1 || hermes -p "$PROFILE" gateway restart >/dev/null 2>&1 || true
}

snapshot() {   # snapshot <name>
  local name="$1" out list=() p
  mkdir -p "$SNAPS"; chmod 700 "$SNAPS"
  out="$SNAPS/$name.tar.gz"
  for p in "${STATE_PATHS[@]}"; do [[ -e "$HH/$p" ]] && list+=("$p"); done
  [[ -e "$HH/$BROWSER_PATH_REL" ]] && list+=("$BROWSER_PATH_REL")
  if [[ ${#list[@]} -eq 0 ]]; then echo "Nothing to snapshot yet."; return 0; fi
  tar -czf "$out" -C "$HH" "${list[@]}"
  chmod 600 "$out"
  echo "Snapshot saved: $out ($(du -h "$out" | cut -f1))"
}

wipe_state() {
  local p
  for p in "${STATE_PATHS[@]}" "${SCRATCH_PATHS[@]}"; do rm -rf "${HH:?}/$p"; done
  [[ -n "$KEEP_BROWSER" ]] || rm -rf "${HH:?}/$BROWSER_PATH_REL"
}

case "$ACTION" in
  list)
    ls -lh "$SNAPS"/*.tar.gz 2>/dev/null || echo "No snapshots yet in $SNAPS."
    ;;

  snapshot)
    say "Saving snapshot '$NAME' (pausing the agent for a moment)"
    gateway_stop
    snapshot "$NAME"
    gateway_start
    ;;

  restore)
    [[ -f "$SNAPS/$NAME.tar.gz" ]] || die "No snapshot '$NAME'. See --list."
    say "Restoring '$NAME'"
    gateway_stop
    snapshot "auto-before-restore-$(date +%Y%m%d-%H%M%S)"
    KEEP_BROWSER=""; wipe_state
    # shellcheck source=lib/starter.sh
    source "$REPO_DIR/scripts/lib/starter.sh"
    if [[ -n "$CARRY" ]]; then
      # Only what the person told the agent: memory, notes, personality.
      # Not the demo bot's chats, schedules or browser logins.
      tar -xzf "$SNAPS/$NAME.tar.gz" -C "$HH" --wildcards \
        'memories*' 'notes*' 'persona.conf' 2>/dev/null || true
      fix_notes_path
      seed_notes
      set_mode test-drive
    else
      tar -xzf "$SNAPS/$NAME.tar.gz" -C "$HH"
      fix_notes_path
    fi
    bash "$HH/skills/persona-switch/build-soul.sh" >/dev/null
    gateway_start
    if [[ -n "$CARRY" ]]; then
      echo "Carried '$NAME' over to $PROFILE as a test drive. When they message"
      echo "this bot, it welcomes them back, recreates the brief and other"
      echo "schedules, and picks up what was parked."
    else
      echo "Restored '$NAME'. Send /new in Telegram to pick it up cleanly."
    fi
    ;;

  reset)
    if [[ -z "$YES" ]]; then
      if [[ -n "$KEEP_BROWSER" ]]; then what="schedules (browser logins kept)"; else what="schedules and the bot browser's logins"; fi
      cat <<EOF
This erases everything $PROFILE knows and did: memory, notes, chats,
$what.
Sign-ins, Telegram, voice and remote access are kept, and an automatic
snapshot is saved first so you can undo it.
EOF
      read -r -p "Type RESET to continue: " ans </dev/tty
      [[ "$ans" == "RESET" ]] || die "Cancelled."
    fi
    say "Pausing the agent"
    gateway_stop
    say "Safety snapshot"
    snapshot "auto-before-reset-$(date +%Y%m%d-%H%M%S)"
    say "Erasing memory, notes, chats and schedules"
    wipe_state
    say "Fresh start: $PERSONA at strength $STRENGTH ($MODE mode)"
    # shellcheck source=lib/starter.sh
    source "$REPO_DIR/scripts/lib/starter.sh"
    seed_notes
    seed_user_memory
    bash "$HH/skills/persona-switch/build-soul.sh" "$PERSONA" "$BOT_NAME"
    gateway_start
    cat <<EOF

$(printf '\033[1;32m')Reset done.$(printf '\033[0m') The agent remembers nothing.

For a clean-looking demo:
  1. In Telegram, open the bot chat > menu (three dots) > Clear history.
     (Your phone keeps old messages; the agent doesn't.)
  2. Send /start and say hi. The first-session interview begins.
     (If the morning brief never arrives later, send /sethome once.)
  3. If voice replies were on, they still are (send /voice off to stop).

Undo: bash $0 --restore <the auto-before-reset snapshot above>
EOF
    ;;
esac
