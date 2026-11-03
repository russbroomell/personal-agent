#!/usr/bin/env bash
# Switch Sidekick's personality or name from the server.
#   bash scripts/set-persona.sh <sam|pip|mortimer|rex|nova|vic> ["Name"]
# (Strength 1-5 is set by chatting: "strength 4", "tone it down", "turn it up".)
# Then send /new to the bot so the next chat uses it.
set -euo pipefail
PROFILE="${PROFILE:-sidekick}"
HH="$HOME/.hermes/profiles/$PROFILE"
[[ -x "$HH/skills/persona-switch/build-soul.sh" || -f "$HH/skills/persona-switch/build-soul.sh" ]] \
  || { echo "Profile $PROFILE not installed. Run scripts/install-agent.sh first." >&2; exit 1; }
bash "$HH/skills/persona-switch/build-soul.sh" "$@"
echo "Send /new to your bot to start a chat with the new personality."
