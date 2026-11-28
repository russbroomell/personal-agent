#!/usr/bin/env bash
# Council health check: one screen that says what's working, what isn't,
# and the exact command to fix each problem.
#
#   bash ~/personal-agent/scripts/check.sh          # quick (about 10 seconds)
#   bash ~/personal-agent/scripts/check.sh --speed  # also times one model reply
#
# Paste the output when asking for help: it contains no passwords or tokens.
set -uo pipefail

# shellcheck source=lib/profile.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/profile.sh"
PROFILE="${PROFILE:-$(saved_profile)}"
HOST_PROFILE="default"
WEBAPP_PORT="${WEBAPP_PORT:-9120}"
HH="$(profile_home "$PROFILE")"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
SPEED=0; [[ "${1:-}" == "--speed" ]] && SPEED=1

ok()   { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[1;31m✗\033[0m %s\n' "$*"; PROBLEMS=$((PROBLEMS+1)); }
meh()  { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
fix()  { printf '      fix: %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }
cfg()  { hermes -p "$1" config get "$2" 2>/dev/null | tail -1; }
PROBLEMS=0

head_ "Server"
read -r _ total _ _ _ _ avail < <(free -m | awk '/^Mem:/')
read -r _ swap_total swap_used _ < <(free -m | awk '/^Swap:/')
echo "  memory: ${avail} MB free of ${total} MB; swap used ${swap_used:-0} of ${swap_total:-0} MB; load $(cut -d' ' -f1-3 /proc/loadavg)"
if [[ "${swap_total:-0}" -ge 3900 ]]; then ok "swap is on (${swap_total} MB)"
else bad "swap is ${swap_total:-0} MB; a 4 GB server needs 4 GB (the workspace build and the screen get killed otherwise)"; fix "sudo bash ~/personal-agent/scripts/add-swap.sh"; fi
if [[ "${avail:-0}" -lt 500 ]]; then
  bad "under 500 MB free: everything will be slow"
  fix "close the bot's screen: hermes -p $PROFILE computer-use screen stop"
fi
if [[ "${swap_used:-0}" -gt 1000 ]]; then
  meh "over 1 GB in swap: the server is short of memory, replies will lag"
fi

head_ "Hermes"
if command -v hermes >/dev/null; then ok "hermes $(hermes --version 2>/dev/null | head -1)"; else bad "hermes not installed"; fix "bash ~/personal-agent/install.sh"; exit 1; fi
HAVE_V="$(hermes --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)"
TESTED_V="$(cat "$(dirname "${BASH_SOURCE[0]}")/../HERMES_VERSION" 2>/dev/null || true)"
if [[ -n "$HAVE_V" && -n "$TESTED_V" && "$HAVE_V" != "$TESTED_V" ]]; then
  if [[ "$(printf '%s\n%s\n' "$HAVE_V" "$TESTED_V" | sort -V | tail -1)" == "$HAVE_V" ]]; then
    meh "Hermes $HAVE_V is newer than this release was tested with ($TESTED_V). It usually works; if something breaks, report it"
  else
    meh "Hermes $HAVE_V is older than tested ($TESTED_V)"; fix "hermes update --yes && hermes -p default gateway restart"
  fi
fi
council_installed "$PROFILE" && ok "the council is installed in the '$PROFILE' profile ($HH)" || { bad "the council isn't installed in the '$PROFILE' profile"; fix "bash ~/personal-agent/install.sh"; }

head_ "Gateway (the 24/7 service)"
if systemctl --user cat "hermes-gateway-$PROFILE.service" >/dev/null 2>&1; then
  bad "an old $PROFILE-only service exists; it fights the main one and slows or blocks replies"
  fix "hermes -p $PROFILE gateway uninstall && hermes -p default gateway restart"
fi
if systemctl --user is-active --quiet hermes-gateway.service; then
  ok "main gateway service is running"
else
  bad "main gateway service isn't running"
  fix "hermes -p default gateway install --if-missing && hermes -p default gateway restart"
fi
LIST="$(timeout 20 hermes gateway list 2>/dev/null || true)"
if grep -qi "$PROFILE" <<<"$LIST"; then
  echo "$LIST" | grep -i "$PROFILE" | head -2 | sed 's/^/  /'
else
  meh "couldn't confirm '$PROFILE' is served (hermes gateway list didn't mention it)"
fi
CRASHES="$(journalctl --user -u hermes-gateway.service --since '-30 min' 2>/dev/null | grep -ciE 'traceback|exited|error' || true)"
[[ "${CRASHES:-0}" -gt 0 ]] && meh "$CRASHES error lines in the gateway log (last 30 min): journalctl --user -u hermes-gateway -n 60"

head_ "Model"
PROV="$(cfg "$PROFILE" model.provider)"; MODEL="$(cfg "$PROFILE" model.default)"
[[ -z "$MODEL" || "$MODEL" == "None" ]] && MODEL="$(cfg "$PROFILE" model.model)"
if [[ -n "$PROV" && "$PROV" != "None" ]]; then ok "provider: $PROV, model: ${MODEL:-?}"; else bad "no model set for $PROFILE"; fix "hermes -p $PROFILE model"; fi
EFFORT="$(cfg "$PROFILE" agent.reasoning_effort)"
if [[ "$EFFORT" == "low" || "$EFFORT" == "minimal" || "$EFFORT" == "none" ]]; then
  ok "thinking time: $EFFORT (fast replies)"
else
  meh "thinking time: ${EFFORT:-model default}. Chat feels faster on low"
  fix "hermes -p $PROFILE config set agent.reasoning_effort low && hermes -p $PROFILE gateway restart"
fi
if [[ $SPEED -eq 1 ]]; then
  echo "  timing one reply (should be under 15 seconds)..."
  t0=$(date +%s)
  REPLY="$(timeout 180 hermes -p "$PROFILE" -z "Reply with just the word ready." 2>&1 | tail -3)"
  dt=$(( $(date +%s) - t0 ))
  if [[ $dt -le 15 ]]; then ok "model replied in ${dt}s"
  elif [[ $dt -le 40 ]]; then meh "model replied in ${dt}s: slow; see docs/models.md for faster options"
  else bad "model took ${dt}s (or timed out): the model is the bottleneck, not Telegram"; fix "try another model: hermes -p $PROFILE model  (see docs/models.md)"; fi
  echo "  reply: $(tr '\n' ' ' <<<"$REPLY" | cut -c1-120)"
  echo "  asking the council a decision (two or more voices expected)..."
  DUET="$(timeout 180 hermes -p "$PROFILE" -z "Quick test, no tools: should I repair my old van for \$1,900 or buy a new one at \$412 a month? Answer as the council." 2>&1 | tail -12)"
  VOICES="$(grep -oE '(^|[.!?] )(Marcus|Romulus|Remus|Odysseus|Māui|Maui|Newton|Feynman|Scheherazade|Florence|Ada|Hypatia|Sun Tzu):' <<<"$DUET" | sed -E 's/^[.!?] //' | sort -u | wc -l)"
  if [[ "$VOICES" -ge 2 ]]; then ok "the council answered with $VOICES voices"
  else bad "a decision got $VOICES tagged voice(s); the SOUL may not be loaded"; fix "bash $HH/skills/council/build-soul.sh && hermes -p default gateway restart"; fi
  sed 's/^/    /' <<<"$DUET" | head -6
fi

head_ "Council"
if [[ -f "$HH/SOUL.md" ]] && grep -q '^# The council' "$HH/SOUL.md"; then
  SEATS="$(sed -n 's/^SEATED=//p' "$HH/council.conf" 2>/dev/null | tr -d "'\"\\\\")"
  ok "SOUL.md built: $(wc -c <"$HH/SOUL.md") bytes; seated: ${SEATS:-default nine}"
  [[ "$(wc -c <"$HH/SOUL.md")" -le 26000 ]] || meh "SOUL.md is large (slower, costlier replies). Bench a member: bash $HH/skills/council/build-soul.sh --bench <name>"
else
  bad "SOUL.md isn't the council's"
  fix "bash $HH/skills/council/build-soul.sh"
fi
[[ -f "$HH/notes/council.md" ]] && ok "council notebook (notes/council.md) exists" || { meh "no council notebook yet"; fix "bash $HH/skills/council/build-soul.sh"; }
DIS="$(cfg "$PROFILE" agent.disabled_toolsets)"
for t in clarify cronjob delegation memory; do
  grep -qw "$t" <<<"$DIS" && { bad "toolset '$t' is turned off; the council needs it"; fix "hermes -p $PROFILE config set agent.disabled_toolsets '[]'  (then restart)"; }
done
PLUG="$(timeout 20 hermes -p "$PROFILE" plugins list 2>/dev/null | grep -i council-voices || true)"
if [[ -z "$PLUG" ]]; then bad "council-voices plugin not found"; fix "bash ~/personal-agent/scripts/update.sh && hermes -p $PROFILE plugins enable council-voices"
elif grep -qiE 'disabled|off|no\b' <<<"$PLUG"; then bad "council-voices plugin is off"; fix "hermes -p $PROFILE plugins enable council-voices && hermes -p default gateway restart"
else ok "council-voices plugin: $(tr -s ' ' <<<"$PLUG" | cut -c1-80)"; fi
TTS="$(cfg "$PROFILE" tts.provider)"; ENGINE="$(cfg "$PROFILE" tts.council.engine)"
if [[ "$TTS" == "council" ]]; then ok "speech: a voice per member, ${ENGINE:-edge} engine"
else meh "speech provider is '${TTS:-none}', so every member sounds the same"; fix "bash ~/personal-agent/scripts/voice-setup.sh grok   (or free / elevenlabs)"; fi
if [[ "$ENGINE" == "elevenlabs" ]] && ! grep -qs '^ELEVENLABS_API_KEY=.' "$HH/.env"; then
  bad "ElevenLabs is the voice engine but no key is set"; fix "bash ~/personal-agent/scripts/voice-setup.sh elevenlabs"
fi
JOBS="$(timeout 20 hermes -p "$PROFILE" cron list 2>/dev/null || true)"
if grep -qi "morning brief" <<<"$JOBS"; then ok "scheduled jobs: $(grep -ciE 'brief|loops|recap|distill|minutes' <<<"$JOBS") council jobs"
else meh "no morning brief scheduled yet (the first chat sets it up: say hi to the bot)"; fi

if grep -qsE '^DISCORD_BOT_TOKEN=.' "$HH/.env"; then
  head_ "Discord"
  ok "bot token set"
  PRIV="$(timeout 20 hermes -p "$PROFILE" plugins list 2>/dev/null | grep -i council-privacy || true)"
  if [[ -z "$PRIV" ]] || grep -qiE 'disabled|off|no\b' <<<"$PRIV"; then
    bad "council-privacy plugin isn't on: DMs wouldn't be kept private from public channels"
    fix "hermes -p $PROFILE plugins enable council-privacy && hermes -p default gateway restart"
  else ok "council-privacy plugin on (each person's DM is private)"; fi
  RM="$(cfg "$PROFILE" discord.require_mention)"
  if grep -qsE '^DISCORD_REQUIRE_MENTION=(true|1|yes)' "$HH/.env" || [[ "$RM" =~ ^(True|true)$ ]]; then
    meh "public channels need an @mention (fine if you chose that)"
    fix "hermes -p $PROFILE config set discord.require_mention false  (and drop DISCORD_REQUIRE_MENTION from .env)"
  else ok "answers in public channels without an @mention"; fi
  if grep -qsE '^(DISCORD_ALLOW_ALL_USERS|GATEWAY_ALLOW_ALL_USERS)=(true|1|yes)' "$HH/.env"; then ok "access: everyone who can reach the bot"
  elif grep -qsE '^DISCORD_ALLOWED_(USERS|ROLES)=.' "$HH/.env"; then ok "access: allowlisted users or roles"
  else bad "nobody is allowlisted, so the bot answers no one"; fix "hermes -p $PROFILE gateway setup  (or set DISCORD_ALLOWED_USERS in $HH/.env)"; fi
  # Core memory is loaded in every chat, public ones included: keep people out of it.
  if [[ -f "$HH/memories/USER.md" ]] && grep -qvE '^(§|Notes folder:|Council size:|Character strength:|Memory Card:|Screen:|First session:|Assistant name:)|^$' "$HH/memories/USER.md"; then
    meh "core memory (USER.md) holds more than settings; on Discord every chat loads it, public channels too"
    fix "move personal lines into notes/people/discord-<your id>/profile.md (Memory Card), then trim USER.md"
  fi
  PEOPLE="$(find "$HH/notes/people" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
  echo "  private folders: $PEOPLE (one per person who has DMed it)"
fi

head_ "Leftovers from earlier installs"
# shellcheck source=lib/port.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/port.sh"
MC_PORT="${MC_PORT:-8765}"
LEFT=0
while read -r ouser opid ohome; do
  [[ -n "$ouser" ]] || continue
  LEFT=1
  bad "another Hermes is running as user '$ouser' (PID $opid, $ohome). It can hold the workspace port and answer your bot's messages too"
  fix "sudo systemctl --user -M $ouser@ disable --now hermes-gateway.service   (keeps its files; delete $ohome later if you don't need it)"
done < <(other_user_gateways)
while read -r unit reason; do
  [[ -n "$unit" ]] || continue
  LEFT=1
  bad "old service $unit: $reason"
  fix "systemctl --user disable --now $unit; rm -rf ~/.config/systemd/user/$unit ~/.config/systemd/user/$unit.d; systemctl --user daemon-reload"
done < <(stale_council_units "$HH")
while read -r opid ohome; do
  [[ -n "$opid" ]] || continue
  LEFT=1
  bad "a Memory Card page is still running for $ohome, which no longer exists (PID $opid); it holds its port"
  fix "kill $opid   (and remove its service above, if one is listed, so it doesn't come back at boot)"
done < <(orphan_memory_cards)
for port in "$WEBAPP_PORT" "$MC_PORT"; do
  if port_held_by_other_user "$port"; then
    LEFT=1
    bad "port $port is held by a process another user owns, so yours can't use it"
    fix "see which: sudo ss -ltnp 'sport = :$port'   (often another user's Hermes, listed above)"
  fi
done
if systemctl --user cat "council-memory-card-$PROFILE.service" >/dev/null 2>&1 \
   && ! systemctl --user is-active --quiet "council-memory-card-$PROFILE.service"; then
  LEFT=1
  bad "the council's Memory Card page isn't running"
  fix "systemctl --user restart council-memory-card-$PROFILE.service; journalctl --user -u council-memory-card-$PROFILE -n 20"
fi
[[ $LEFT -eq 0 ]] && ok "none found (no other user's Hermes, no old services, ports free for yours)"

head_ "Workspace (bot screen in a browser)"
[[ "$(cfg "$HOST_PROFILE" webapp.enabled)" == "True" || "$(cfg "$HOST_PROFILE" webapp.enabled)" == "true" ]] \
  && ok "turned on" || { meh "turned off (optional: needed for live voice and watching the bot's browser)"; fix "bash ~/personal-agent/install.sh  (answer yes to the workspace), or remote-access.sh"; }
PUB="$(cfg "$HOST_PROFILE" webapp.public_url)"
[[ "$PUB" == https://* ]] && ok "address: $PUB" || meh "no Tailscale address set (SSH tunnel only). For the browser without SSH: bash ~/personal-agent/scripts/remote-access.sh"
CODE="$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H "Host: ${PUB#https://}" "http://127.0.0.1:$WEBAPP_PORT/" 2>/dev/null || true)"
[[ "$PUB" != https://* ]] && CODE="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://127.0.0.1:$WEBAPP_PORT/" 2>/dev/null || true)"
case "$CODE" in
  2*|3*|401) ok "something answers on port $WEBAPP_PORT (HTTP $CODE)" ;;
  400) bad "rejects the address (Invalid Host header)"; fix "bash ~/personal-agent/scripts/remote-access.sh  (sets the address on the default profile and restarts)" ;;
  000|"") bad "nothing listening on port $WEBAPP_PORT"; fix "bash ~/personal-agent/scripts/remote-access.sh  (builds it safely, then restarts)" ;;
  *) bad "answers HTTP $CODE"; fix "hermes -p default webapp --status" ;;
esac
STATUS="$(timeout 15 hermes -p "$HOST_PROFILE" webapp --status 2>&1 | head -3)"
[[ -n "$STATUS" ]] && sed 's/^/  /' <<<"$STATUS"
STRAYS="$(port_strays "$WEBAPP_PORT")"
if grep -qi "unavailable\|address already in use" <<<"$STATUS" || [[ -n "$STRAYS" ]]; then
  bad "something other than the gateway holds port $WEBAPP_PORT, so the real workspace can't start"
  [[ -n "$STRAYS" ]] && sed 's/^/      holding it: /' <<<"$STRAYS"
  if [[ -z "$STRAYS" ]] && port_held_by_other_user "$WEBAPP_PORT"; then
    fix "another user's process holds it: see 'Leftovers' above, then: hermes gateway restart"
  else
    fix "bash ~/personal-agent/scripts/remote-access.sh  (stops the leftover and restarts)"
  fi
fi
if command -v tailscale >/dev/null; then
  tailscale serve status 2>/dev/null | grep -q "$WEBAPP_PORT" && ok "Tailscale forwards https to port $WEBAPP_PORT" \
    || meh "Tailscale isn't forwarding to the workspace; run remote-access.sh"
fi

head_ "Updates"
echo "  running: $(git -C "$(dirname "${BASH_SOURCE[0]}")/.." log --oneline -1 2>/dev/null || echo unknown) ($(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --abbrev-ref HEAD 2>/dev/null))"
if systemctl --user is-enabled --quiet council-update.timer 2>/dev/null; then
  ok "auto-update is on"
  [[ -r "$HOME/.local/state/council/last-update" ]] && echo "  last run: $(cat "$HOME/.local/state/council/last-update")"
  grep -q "FAILED" "$HOME/.local/state/council/last-update" 2>/dev/null && { bad "last auto-update failed and rolled back"; fix "tail -60 ~/.local/state/council/update.log"; }
else
  meh "auto-update is off. Turn on: bash ~/personal-agent/scripts/auto-update.sh enable"
fi

head_ "Summary"
if [[ $PROBLEMS -eq 0 ]]; then echo "  All good."; else echo "  $PROBLEMS problem(s). Run the 'fix:' lines above, top to bottom."; fi
[[ $SPEED -eq 0 ]] && echo "  Replies slow? Run: bash ~/personal-agent/scripts/check.sh --speed"
