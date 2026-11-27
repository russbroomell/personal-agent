#!/usr/bin/env bash
# Update the Council: pull this repo, refresh skills and house rules, update
# Hermes itself, and rebuild SOUL.md with the council seats you chose.
# Memories, notes, chats, model choice and credentials are kept.
set -euo pipefail
# shellcheck source=lib/profile.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/profile.sh"
PROFILE="${PROFILE:-$(saved_profile)}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
git -C "$REPO_DIR" pull --ff-only
hermes update || echo "hermes update reported a problem; carrying on." >&2
sync_distribution "$PROFILE" "$REPO_DIR"
bash "$(profile_home "$PROFILE")/skills/council/build-soul.sh"
systemctl --user restart "council-memory-card-$PROFILE.service" 2>/dev/null || true
# Restart the one host gateway (default profile), which serves $PROFILE too.
timeout 120 hermes -p default gateway restart || echo "Gateway restart didn't confirm; check: hermes gateway list" >&2
echo "Updated. Send /new to the bot to pick up any council or rule changes."
