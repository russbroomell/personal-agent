#!/usr/bin/env bash
# Sidekick auto-update: keep the bot current from GitHub with no hands.
#
#   bash ~/personal-agent/scripts/auto-update.sh enable    # nightly at 04:30 (server time)
#   bash ~/personal-agent/scripts/auto-update.sh enable --time 03:15 --tz America/Chicago
#   bash ~/personal-agent/scripts/auto-update.sh enable --hermes daily   # or weekly (default) / never
#   bash ~/personal-agent/scripts/auto-update.sh status    # schedule + last result
#   bash ~/personal-agent/scripts/auto-update.sh run       # do one update now
#   bash ~/personal-agent/scripts/auto-update.sh disable
#
# Each night it:
#   1. fetches this repo; fast-forwards only (never merges, never discards
#      local changes: if it can't fast-forward it skips and says why)
#   2. updates Hermes itself (weekly by default, Sundays)
#   3. if anything changed: refreshes the profile (skills, house rules),
#      rebuilds SOUL.md with your chosen character, restarts the agent
#   4. runs the health check; if the refresh or restart failed, it rolls the
#      repo back to the version that worked and restarts again
# Memory, notes, chats, model sign-in and settings are never touched.
#
# Trust: this runs whatever lands on the branch it follows. If you didn't
# write the repo yourself, point it at your own fork (git remote set-url).
set -uo pipefail

PROFILE="${PROFILE:-sidekick}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HH="$HOME/.hermes/profiles/$PROFILE"
STATE="$HOME/.local/state/sidekick"
LOG="$STATE/update.log"
LAST="$STATE/last-update"
CONF="$STATE/auto-update.conf"
UNIT="sidekick-update"
UDIR="$HOME/.config/systemd/user"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
mkdir -p "$STATE"

say() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
die() { echo "$*" >&2; exit 1; }
[[ $EUID -ne 0 || -n "${SIDEKICK_ALLOW_ROOT:-}" ]] || die "Run as 'agent', not root."

HERMES_EVERY="weekly"
[[ -r "$CONF" ]] && source "$CONF"

enable() {
  local time="04:30" tz="" hermes="$HERMES_EVERY"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --time) time="$2"; shift 2 ;;
      --tz) tz="$2"; shift 2 ;;
      --hermes) hermes="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  [[ "$time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]] || die "--time must look like 04:30"
  [[ "$hermes" =~ ^(daily|weekly|never)$ ]] || die "--hermes must be daily, weekly or never"
  echo "HERMES_EVERY=$hermes" > "$CONF"
  mkdir -p "$UDIR"
  cat > "$UDIR/$UNIT.service" <<EOF
[Unit]
Description=Sidekick auto-update (repo + Hermes)
After=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $REPO_DIR/scripts/auto-update.sh run
TimeoutStartSec=45min
Nice=10
EOF
  cat > "$UDIR/$UNIT.timer" <<EOF
[Unit]
Description=Nightly Sidekick auto-update

[Timer]
OnCalendar=*-*-* $time:00${tz:+ $tz}
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now "$UNIT.timer"
  echo "Auto-update is on: nightly at $time${tz:+ ($tz)}, Hermes itself $hermes."
  systemctl --user list-timers "$UNIT.timer" --no-pager | head -3
  echo "Log: $LOG    Check any time: bash $REPO_DIR/scripts/auto-update.sh status"
}

disable() {
  systemctl --user disable --now "$UNIT.timer" 2>/dev/null || true
  rm -f "$UDIR/$UNIT.timer" "$UDIR/$UNIT.service"
  systemctl --user daemon-reload
  echo "Auto-update is off. Update by hand with: bash $REPO_DIR/scripts/update.sh"
}

status() {
  if systemctl --user is-enabled --quiet "$UNIT.timer" 2>/dev/null; then
    echo "Auto-update: on (Hermes itself: $HERMES_EVERY)"
    systemctl --user list-timers "$UNIT.timer" --no-pager | head -2
  else
    echo "Auto-update: off. Turn on: bash $REPO_DIR/scripts/auto-update.sh enable"
  fi
  [[ -r "$LAST" ]] && echo "Last run: $(cat "$LAST")"
  echo "Running version: $(git -C "$REPO_DIR" log --oneline -1)"
}

restart_agent() {
  systemctl --user restart "sidekick-memory-card-$PROFILE.service" 2>/dev/null || true
  timeout 120 hermes -p default gateway restart
}

apply_profile() {
  hermes profile update "$PROFILE" -y && bash "$HH/skills/persona-switch/build-soul.sh" >/dev/null || return 1
  # Guest bots (guest-bot.sh) get the same skills and rules.
  local g
  while read -r g; do
    [[ -n "$g" && -d "$HOME/.hermes/profiles/$g" ]] || continue
    hermes profile update "$g" -y && bash "$HOME/.hermes/profiles/$g/skills/persona-switch/build-soul.sh" >/dev/null || true
  done < <(cat "$STATE/guests" 2>/dev/null)
}

run() {
  exec 9>"$STATE/update.lock"
  flock -n 9 || { say "Another update is running; skipping."; return 0; }
  say "---- auto-update start"
  local before after changed=0 result="no changes"

  # 1. This repo: fast-forward only.
  before="$(git -C "$REPO_DIR" rev-parse HEAD)"
  if ! git -C "$REPO_DIR" fetch -q origin 2>>"$LOG"; then
    say "Couldn't reach GitHub; will try again tomorrow."
  elif [[ -n "$(git -C "$REPO_DIR" status --porcelain --untracked-files=no)" ]]; then
    say "Repo has local edits; skipped the repo update (run update.sh by hand)."
    result="skipped: local edits in the repo"
  elif git -C "$REPO_DIR" merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
    git -C "$REPO_DIR" merge -q --ff-only '@{u}' 2>>"$LOG"
    after="$(git -C "$REPO_DIR" rev-parse HEAD)"
    if [[ "$before" != "$after" ]]; then
      changed=1
      say "Repo: $(git -C "$REPO_DIR" log --oneline "$before..$after" | wc -l) new commit(s), now $(git -C "$REPO_DIR" log --oneline -1)"
    fi
  else
    say "Repo can't fast-forward (its history differs from GitHub); skipped. Fix: git -C $REPO_DIR reset --hard @{u}"
    result="skipped: repo history differs from GitHub"
  fi

  # 2. Hermes itself.
  local do_hermes=0
  case "$HERMES_EVERY" in
    daily) do_hermes=1 ;;
    weekly) [[ "$(date +%u)" == 7 ]] && do_hermes=1 ;;
  esac
  if [[ $do_hermes -eq 1 ]] && hermes update --check >>"$LOG" 2>&1; then
    say "Updating Hermes..."
    if hermes update --yes >>"$LOG" 2>&1; then
      changed=1; say "Hermes updated: $(hermes --version 2>/dev/null | head -1)"
    else
      say "Hermes update reported a problem (see log); it keeps its own backup and rollback."
      result="Hermes update had a problem"
    fi
  fi

  # 3. Apply and restart, with rollback of the repo on failure.
  if [[ $changed -eq 1 ]]; then
    if apply_profile >>"$LOG" 2>&1 && restart_agent >>"$LOG" 2>&1; then
      result="updated to $(git -C "$REPO_DIR" log --oneline -1)"
    else
      say "Applying the update failed; rolling the repo back to $before."
      git -C "$REPO_DIR" reset -q --hard "$before"
      apply_profile >>"$LOG" 2>&1; restart_agent >>"$LOG" 2>&1
      result="FAILED, rolled back to $(git -C "$REPO_DIR" log --oneline -1)"
    fi
  fi

  # 4. Health check, for the log.
  sleep 5
  bash "$REPO_DIR/scripts/check.sh" >>"$LOG" 2>&1 || true
  echo "$(date '+%F %T') $result" > "$LAST"
  say "---- done: $result"
  # Keep the log small.
  tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

case "${1:-}" in
  enable) shift; enable "$@" ;;
  disable) disable ;;
  status) status ;;
  run) run ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
