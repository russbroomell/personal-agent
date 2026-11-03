#!/usr/bin/env bash
# Fallback: create Sidekick's scheduled jobs from the server, in case the
# first session didn't (it normally does this itself).
#   bash scripts/schedule-jobs.sh "America/New_York" "07:00"
# Jobs deliver to Telegram. Check them with: hermes -p sidekick cron list
set -euo pipefail
PROFILE="${PROFILE:-sidekick}"
TZ_NAME="${1:?time zone, e.g. America/New_York}"
BRIEF="${2:-07:00}"
H="${BRIEF%%:*}"; M="${BRIEF##*:}"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
mk() { hermes -p "$PROFILE" cron create "$1" "$2" --name "$3" --skill "$4" --timezone "$TZ_NAME" --deliver telegram; }
mk "$((10#$M)) $((10#$H)) * * *" "Write today's morning brief." "Morning brief" morning-brief
mk "30 12 * * *" "Run the daily open loops check." "Open loops check" open-loops
mk "0 16 * * 5" "Write this week's Friday recap." "Friday recap" friday-recap
mk "0 21 * * 0" "Run the weekly memory distill." "Weekly distill" weekly-distill
hermes -p "$PROFILE" cron list
