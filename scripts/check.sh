#!/usr/bin/env bash
# Sidekick health check: one screen that says what's working, what isn't,
# and the exact command to fix each problem.
#
#   bash ~/personal-agent/scripts/check.sh          # quick (about 10 seconds)
#   bash ~/personal-agent/scripts/check.sh --speed  # also times one model reply
#
# Paste the output when asking for help: it contains no passwords or tokens.
set -uo pipefail

PROFILE="${PROFILE:-sidekick}"
HOST_PROFILE="default"
WEBAPP_PORT="${WEBAPP_PORT:-9120}"
HH="$HOME/.hermes/profiles/$PROFILE"
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
else bad "swap is ${swap_total:-0} MB; a 4 GB server needs 4 GB (the workspace build and the screen get killed otherwise)"; fix "sudo bash ~/personal-agent/scripts/bootstrap-vps.sh  (tops swap up to 4 GB)"; fi
if [[ "${avail:-0}" -lt 500 ]]; then
  bad "under 500 MB free: everything will be slow"
  fix "close the bot's screen: hermes -p $PROFILE computer-use screen stop"
fi
if [[ "${swap_used:-0}" -gt 1000 ]]; then
  meh "over 1 GB in swap: the server is short of memory, replies will lag"
fi

head_ "Hermes"
if command -v hermes >/dev/null; then ok "hermes $(hermes --version 2>/dev/null | head -1)"; else bad "hermes not installed"; fix "bash ~/personal-agent/scripts/setup.sh"; exit 1; fi
HAVE_V="$(hermes --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d v)"
TESTED_V="$(cat "$(dirname "${BASH_SOURCE[0]}")/../HERMES_VERSION" 2>/dev/null || true)"
if [[ -n "$HAVE_V" && -n "$TESTED_V" && "$HAVE_V" != "$TESTED_V" ]]; then
  if [[ "$(printf '%s\n%s\n' "$HAVE_V" "$TESTED_V" | sort -V | tail -1)" == "$HAVE_V" ]]; then
    meh "Hermes $HAVE_V is newer than this release was tested with ($TESTED_V). It usually works; if something breaks, report it"
  else
    meh "Hermes $HAVE_V is older than tested ($TESTED_V)"; fix "hermes update --yes && hermes -p default gateway restart"
  fi
fi
[[ -d "$HH" ]] && ok "profile '$PROFILE' installed" || { bad "profile '$PROFILE' missing"; fix "bash ~/personal-agent/scripts/setup.sh"; }

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
fi

head_ "Workspace (bot screen in a browser)"
[[ "$(cfg "$HOST_PROFILE" webapp.enabled)" == "True" || "$(cfg "$HOST_PROFILE" webapp.enabled)" == "true" ]] \
  && ok "turned on" || { bad "turned off on the default profile"; fix "bash ~/personal-agent/scripts/remote-access.sh"; }
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
# shellcheck source=lib/port.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/port.sh"
STRAYS="$(port_strays "$WEBAPP_PORT")"
if grep -qi "unavailable\|address already in use" <<<"$STATUS" || [[ -n "$STRAYS" ]]; then
  bad "something other than the gateway holds port $WEBAPP_PORT, so the real workspace can't start"
  [[ -n "$STRAYS" ]] && sed 's/^/      holding it: /' <<<"$STRAYS"
  fix "bash ~/personal-agent/scripts/remote-access.sh  (stops the leftover and restarts)"
fi
if command -v tailscale >/dev/null; then
  tailscale serve status 2>/dev/null | grep -q "$WEBAPP_PORT" && ok "Tailscale forwards https to port $WEBAPP_PORT" \
    || meh "Tailscale isn't forwarding to the workspace; run remote-access.sh"
fi

head_ "Updates"
echo "  running: $(git -C "$HOME/personal-agent" log --oneline -1 2>/dev/null || echo unknown)"
if systemctl --user is-enabled --quiet sidekick-update.timer 2>/dev/null; then
  ok "auto-update is on"
  [[ -r "$HOME/.local/state/sidekick/last-update" ]] && echo "  last run: $(cat "$HOME/.local/state/sidekick/last-update")"
  grep -q "FAILED" "$HOME/.local/state/sidekick/last-update" 2>/dev/null && { bad "last auto-update failed and rolled back"; fix "tail -60 ~/.local/state/sidekick/update.log"; }
else
  meh "auto-update is off. Turn on: bash ~/personal-agent/scripts/auto-update.sh enable"
fi

head_ "Summary"
if [[ $PROBLEMS -eq 0 ]]; then echo "  All good."; else echo "  $PROBLEMS problem(s). Run the 'fix:' lines above, top to bottom."; fi
[[ $SPEED -eq 0 ]] && echo "  Replies slow? Run: bash ~/personal-agent/scripts/check.sh --speed"
