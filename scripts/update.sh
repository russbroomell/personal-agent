#!/usr/bin/env bash
# Update Sidekick: pull this repo, refresh skills and house rules, update
# Hermes itself, and rebuild SOUL.md with the personality you chose.
# Memories, notes, chats, model choice and credentials are kept.
set -euo pipefail
PROFILE="${PROFILE:-sidekick}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
git -C "$REPO_DIR" pull --ff-only
hermes update || echo "hermes update reported a problem; carrying on." >&2
hermes profile update "$PROFILE" -y
bash "$HOME/.hermes/profiles/$PROFILE/skills/persona-switch/build-soul.sh"
systemctl --user restart "sidekick-memory-card-$PROFILE.service" 2>/dev/null || true
hermes -p "$PROFILE" gateway restart
echo "Updated. Send /new to the bot to pick up any personality or rule changes."
