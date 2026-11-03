#!/usr/bin/env bash
# Back up the whole Sidekick profile (memory, notes, chats, config, keys)
# to ~/sidekick-backups, keeping the newest 14. The zip contains your API
# keys and bot token: keep it private. Optional: copy it off the server with
#   scp agent@YOUR_SERVER:sidekick-backups/<file>.zip .
# Schedule nightly at 03:15 with:
#   (crontab -l 2>/dev/null; echo "15 3 * * * bash $HOME/personal-agent/scripts/backup.sh >/dev/null 2>&1") | crontab -
set -euo pipefail
PROFILE="${PROFILE:-sidekick}"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
OUT="$HOME/sidekick-backups"
mkdir -p "$OUT"; chmod 700 "$OUT"
hermes -p "$PROFILE" backup -o "$OUT/hermes-backup-$PROFILE-$(date +%Y%m%d-%H%M%S).zip" -k 14
chmod 600 "$OUT"/*.zip
ls -lh "$OUT" | tail -3
