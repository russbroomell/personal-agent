#!/usr/bin/env bash
# Move Sidekick to another machine with its memory intact.
#
# On the OLD machine:
#   bash scripts/move-agent.sh export          -> ~/sidekick-export.tar.gz
# Copy the file across (scp), then on the NEW machine (Hermes installed):
#   bash scripts/move-agent.sh import ~/sidekick-export.tar.gz
#
# The export holds memory, notes, chats, skills, schedules and config, but
# NOT credentials: sign in to your model again (hermes -p sidekick model)
# and reconnect Telegram on the new machine. Stop the old gateway first so
# two copies never answer the same bot.
set -euo pipefail
PROFILE="${PROFILE:-sidekick}"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
case "${1:-}" in
  export)
    hermes -p "$PROFILE" gateway stop 2>/dev/null || true
    hermes profile export "$PROFILE" -o "$HOME/sidekick-export.tar.gz"
    echo "Exported to ~/sidekick-export.tar.gz (gateway stopped here)."
    ;;
  import)
    [[ -f "${2:-}" ]] || { echo "Usage: $0 import <file.tar.gz>" >&2; exit 1; }
    hermes profile import "$2" --name "$PROFILE"
    HH="$HOME/.hermes/profiles/$PROFILE"
    # The notes path in core memory points at the old machine's home; fix it.
    if [[ -f "$HH/memories/USER.md" ]]; then
      sed -i "s|^Notes folder: .*|Notes folder: $HH/notes|" "$HH/memories/USER.md"
    fi
    echo "Imported. Next: hermes -p $PROFILE model, then reconnect Telegram, then hermes -p $PROFILE gateway install"
    ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
