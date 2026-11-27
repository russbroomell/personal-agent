# shellcheck shell=bash
# Used by install.sh. Source it; don't run it.
# Needs: HH (profile home), REPO_DIR, PROFILE, MC_PORT, WEBAPP_PORT.
# Optional: STRENGTH (1-5, default 3), COUNCIL_SIZE (1-4, default 3).

# Copy the note templates into the notes folder (never overwrites).
# MODE (live | demo | test-drive) goes into onboarding-plan.md.
seed_notes() {
  local notes="$HH/notes" f
  mkdir -p "$notes"
  for f in "$REPO_DIR"/templates/notes/*.md; do
    [[ -e "$notes/$(basename "$f")" ]] || cp "$f" "$notes/"
  done
  set_mode "${MODE:-live}"
}

# Set the onboarding mode line in onboarding-plan.md.
set_mode() {
  local plan="$HH/notes/onboarding-plan.md"
  [[ -f "$plan" ]] || cp "$REPO_DIR/templates/notes/onboarding-plan.md" "$plan"
  sed -i "s/^Mode: .*/Mode: $1/" "$plan"
}

# After restoring someone's notes into a different profile, point the
# notes path in core memory at this profile.
fix_notes_path() {
  local user_md="$HH/memories/USER.md"
  [[ -f "$user_md" ]] && sed -i "s|^Notes folder: .*|Notes folder: $HH/notes|" "$user_md"
  return 0
}

# Write the starter core memory if USER.md is empty or missing; otherwise
# make sure the lines the skills rely on are present.
seed_user_memory() {
  local notes="$HH/notes" user_md="$HH/memories/USER.md" public mc_addr ws_addr
  mkdir -p "$HH/memories"
  public="$(hermes -p default config get webapp.public_url 2>/dev/null || true)"
  if [[ "$public" == https://* ]]; then
    ws_addr="$public (your Tailscale address)"
    mc_addr="${public%/}:8443 (your Tailscale address)"
  else
    ws_addr="http://127.0.0.1:$WEBAPP_PORT (through the SSH tunnel)"
    mc_addr="http://127.0.0.1:$MC_PORT (through the SSH tunnel)"
  fi
  if [[ ! -s "$user_md" ]]; then
    # Hermes separates memory entries with a line holding only "§".
    cat > "$user_md" <<MEM
Notes folder: $notes
§
Council size: ${COUNCIL_SIZE:-3}
§
Character strength: ${STRENGTH:-3}/5
§
Memory Card: $mc_addr
§
Screen: Hermes workspace at $ws_addr; open the bot's Screen, tap Take over, then Hand back.
MEM
  else
    grep -q '^Notes folder:' "$user_md" || printf '§\nNotes folder: %s\n' "$notes" >> "$user_md"
    # Older installs said "Personality strength"; the council calls it character strength.
    sed -i 's/^Personality strength:/Character strength:/' "$user_md"
    grep -q '^Character strength:' "$user_md" || printf '§\nCharacter strength: %s/5\n' "${STRENGTH:-3}" >> "$user_md"
    grep -q '^Council size:' "$user_md" || printf '§\nCouncil size: %s\n' "${COUNCIL_SIZE:-3}" >> "$user_md"
  fi
}
