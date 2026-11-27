#!/usr/bin/env bash
# Back up the whole Council profile (memory, notes, chats, config, keys)
# to ~/council-backups, keeping the newest 14. The zip contains your API
# keys and bot token: keep it private. Optional: copy it off the server with
#   scp agent@YOUR_SERVER:council-backups/<file>.zip .
# Schedule nightly at 03:15 with:
#   (crontab -l 2>/dev/null; echo "15 3 * * * bash $HOME/personal-agent/scripts/backup.sh >/dev/null 2>&1") | crontab -
set -euo pipefail
# shellcheck source=lib/profile.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/profile.sh"
PROFILE="${PROFILE:-$(saved_profile)}"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
OUT="$HOME/council-backups"
mkdir -p "$OUT"; chmod 700 "$OUT"
hermes -p "$PROFILE" backup -o "$OUT/hermes-backup-$PROFILE-$(date +%Y%m%d-%H%M%S).zip" -k 14
chmod 600 "$OUT"/*.zip
ls -lh "$OUT" | tail -3
