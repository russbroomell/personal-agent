#!/usr/bin/env bash
# Sidekick: see the bot's browser, the workspace and the Memory Card from
# any of your devices (laptop or phone), with no SSH tunnel.
#
#   bash ~/personal-agent/scripts/remote-access.sh
#
# How: Tailscale puts the VPS on your private network (your "tailnet") and
# gives it an HTTPS address like https://sidekick-vps.tail1234.ts.net that
# only devices signed in to YOUR Tailscale account can open. Nothing is
# opened to the public internet. The workspace also asks for a username
# and password.
#
# You need: a free Tailscale account (tailscale.com), and the Tailscale app
# on each device you'll view from (laptop, phone), signed in to that account.
set -euo pipefail

PROFILE="${PROFILE:-sidekick}"
# Hermes runs one gateway per machine from its default profile (the "host"),
# serving every profile. The workspace, its address and its password are read
# from the host's settings, so they are set on the default profile.
HOST_PROFILE="default"
WEBAPP_PORT="${WEBAPP_PORT:-9120}"
MC_PORT="${MC_PORT:-8765}"
WEB_USER="${WEB_USER:-$(id -un)}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HH="$HOME/.hermes/profiles/$PROFILE"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as your normal user (e.g. 'agent'); it uses sudo where needed."
[[ -d "$HH" ]] || die "Profile $PROFILE isn't installed. Run scripts/install-agent.sh first."
command -v hermes >/dev/null || die "hermes not on PATH."

cat <<'INTRO'

Remote access: see the workspace, the bot's browser screen and the Memory
Card from your laptop or phone, with no SSH. Four things will happen:

  1. Tailscale installs, then prints a LOGIN LINK. Open it in any browser,
     sign in to your Tailscale account, and approve this server.
  2. Tailscale may print a second link to ENABLE HTTPS for your account.
     Open it and click Enable; the script carries on by itself.
  3. You choose a workspace password (your username is shown).
  4. It prints your private https:// addresses. Open them on a laptop or
     phone that has the Tailscale app installed and signed in.

Haven't installed the Tailscale app on your laptop/phone yet? Do that now
(tailscale.com/download), signed in to the same account.
INTRO
read -r -p "Press Enter to start (Ctrl+C to stop)... " _ </dev/tty || true

# --------------------------------------------------------------- Tailscale
if ! command -v tailscale >/dev/null 2>&1; then
  say "Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! tailscale status >/dev/null 2>&1; then
  say "Step 1 of 4: connect this server to your Tailscale account"
  echo "A login link will appear below. Open it on any device, sign in, and"
  echo "approve this server. The script waits here until you do."
  sudo tailscale up --operator="$(id -un)" --hostname="${TS_HOSTNAME:-sidekick-vps}"
else
  sudo tailscale set --operator="$(id -un)" >/dev/null 2>&1 || true
fi

TS_NAME="$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"
[[ -n "$TS_NAME" ]] || die "Couldn't read this machine's Tailscale name. Is MagicDNS on? (Tailscale admin > DNS)"
echo "Tailscale name: $TS_NAME"

say "Firewall: allow traffic that arrives over Tailscale only"
sudo ufw allow in on tailscale0 >/dev/null
sudo ufw status | grep -i tailscale0 | head -2 || true

say "Step 2 of 4: private HTTPS addresses"
echo "If Tailscale prints a link saying Serve or HTTPS isn't enabled, open it,"
echo "click Enable, and come back: it continues on its own once enabled."
tailscale serve --bg --https=443 "http://127.0.0.1:$WEBAPP_PORT"
tailscale serve --bg --https=8443 "http://127.0.0.1:$MC_PORT"
tailscale serve status

# ------------------------------------------------ Workspace sign-in
say "Step 3 of 4: workspace sign-in (username + password)"
CFG_USER="$(hermes -p "$HOST_PROFILE" config get dashboard.basic_auth.username 2>/dev/null || true)"
if [[ -n "$CFG_USER" && "$CFG_USER" != "None" && "${RESET_PASSWORD:-}" != "1" ]]; then
  echo "A workspace login already exists for '$CFG_USER'. (RESET_PASSWORD=1 to change it.)"
  WEB_USER="$CFG_USER"
else
  while :; do
    read -r -s -p "Choose a workspace password for '$WEB_USER' (12+ characters): " PW </dev/tty; echo
    read -r -s -p "Type it again: " PW2 </dev/tty; echo
    [[ "$PW" == "$PW2" ]] || { warn "They didn't match."; continue; }
    [[ ${#PW} -ge 12 ]] || { warn "Use at least 12 characters."; continue; }
    break
  done
  # Same scrypt format Hermes's username/password provider verifies.
  HASH="$(PW="$PW" python3 - <<'PY'
import base64, hashlib, os, secrets
salt = secrets.token_bytes(16)
dk = hashlib.scrypt(os.environ["PW"].encode(), salt=salt, n=2**14, r=8, p=1, dklen=32, maxmem=0)
print(f"scrypt$16384$8$1${base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}")
PY
)"
  unset PW PW2
  SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
  hermes -p "$HOST_PROFILE" config set dashboard.basic_auth.username "$WEB_USER" >/dev/null
  hermes -p "$HOST_PROFILE" config set dashboard.basic_auth.password_hash "$HASH" >/dev/null
  hermes -p "$HOST_PROFILE" config set dashboard.basic_auth.secret "$SECRET" >/dev/null
  chmod 600 "$HH/config.yaml" 2>/dev/null || true
fi

say "Step 4 of 4: turning the workspace on at its Tailscale address"
# Three things must all be true, or the address fails:
#   webapp.enabled  - otherwise the gateway says "The Webapp is off"
#   a built bundle  - otherwise it says "The Webapp is not built"
#   webapp.public_url = this exact https name - otherwise every request gets
#                     "Invalid Host header" (Hermes only answers to names it was told about)
# all on the DEFAULT profile (set on sidekick they're silently ignored), and
# the host gateway must restart afterwards to pick them up.
hermes -p "$HOST_PROFILE" config set webapp.enabled true >/dev/null
hermes -p "$HOST_PROFILE" config set webapp.host 127.0.0.1 >/dev/null
hermes -p "$HOST_PROFILE" config set webapp.port "$WEBAPP_PORT" >/dev/null
hermes -p "$HOST_PROFILE" config set webapp.public_url "https://$TS_NAME" >/dev/null
echo "Checking the workspace is built (first time: a few minutes)..."
# shellcheck source=lib/build.sh
source "$REPO_DIR/scripts/lib/build.sh"
build_workspace "$HOST_PROFILE" "$PROFILE" || die "Workspace build failed (see above). Fix it, then re-run this script."
# Older installs created a sidekick-only gateway service; it fights the host
# gateway for the same bot and port. Remove it if present.
if systemctl --user cat "hermes-gateway-$PROFILE.service" >/dev/null 2>&1; then
  echo "Removing the old $PROFILE-only gateway service (the host gateway runs $PROFILE now)..."
  timeout 60 hermes -p "$PROFILE" gateway uninstall || warn "Couldn't remove hermes-gateway-$PROFILE.service."
fi
hermes -p "$HOST_PROFILE" gateway install --if-missing >/dev/null || true
# Anything else already on the workspace port blocks it (the gateway logs
# "Address already in use" and a leftover answers in its place).
# shellcheck source=lib/port.sh
source "$REPO_DIR/scripts/lib/port.sh"
free_port "$WEBAPP_PORT" || die "Free port $WEBAPP_PORT (or set WEBAPP_PORT=another port), then re-run this script."
echo "Restarting the agent so it picks up the new settings (up to 2 minutes)..."
timeout 120 hermes -p "$HOST_PROFILE" gateway restart || warn "Gateway restart failed; run: hermes -p $HOST_PROFILE gateway restart"

# Prove it: ask the workspace for its page the way Tailscale will, with the
# https name as the Host. 400 = wrong name; nothing = not listening yet.
CODE=""
for _ in $(seq 1 30); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $TS_NAME" "http://127.0.0.1:$WEBAPP_PORT/" || true)"
  [[ "$CODE" =~ ^(2|3|401) ]] && break
  sleep 2
done
WSTATUS="$(hermes -p "$HOST_PROFILE" webapp --status 2>&1 || true)"
echo "$WSTATUS"
if grep -qi "unavailable\|address already in use" <<<"$WSTATUS"; then
  warn "The gateway couldn't open the workspace port; something else answered instead."
  port_strays "$WEBAPP_PORT" | sed 's/^/  holding the port: /'
  CODE="blocked"
fi
if [[ "$CODE" =~ ^(2|3|401) ]]; then
  echo "Workspace answers at https://$TS_NAME (HTTP $CODE)."
else
  warn "The workspace isn't answering correctly yet (HTTP ${CODE:-none})."
  echo "  webapp.enabled    = $(hermes -p "$HOST_PROFILE" config get webapp.enabled 2>/dev/null)"
  echo "  webapp.public_url = $(hermes -p "$HOST_PROFILE" config get webapp.public_url 2>/dev/null)  (should be https://$TS_NAME)"
  echo "  Try: hermes -p $HOST_PROFILE gateway restart, wait 20 seconds, then re-run this script."
  echo "  Still stuck? hermes -p $HOST_PROFILE gateway status and hermes -p $HOST_PROFILE doctor"
fi

# ------------------------------------------------ Memory Card over Tailscale
say "Memory Card over Tailscale"
UNIT="sidekick-memory-card-$PROFILE.service"
DROPIN="$HOME/.config/systemd/user/$UNIT.d"
mkdir -p "$DROPIN"
cat > "$DROPIN/tailscale.conf" <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/python3 $REPO_DIR/scripts/memory-card/server.py --home $HH --port $MC_PORT --allow-host $TS_NAME
EOF
systemctl --user daemon-reload
systemctl --user restart "$UNIT"
MC_URL="$(python3 "$REPO_DIR/scripts/memory-card/server.py" --home "$HH" --port "$MC_PORT" --print-url --public-url "https://$TS_NAME:8443")"

cat <<EOF

$(printf '\033[1;32m')Remote access is on.$(printf '\033[0m')

On any device signed in to your Tailscale account (install the Tailscale app
on your laptop and phone first):

  Workspace + bot screen:  https://$TS_NAME
                           sign in as '$WEB_USER' with the password you chose
  Memory Card:             $MC_URL

Bot screen: in the workspace open Bots > $PROFILE > Screen, then Take over / Hand back.
Next: turn on voice with  bash $REPO_DIR/scripts/voice-setup.sh grok
      then press the voice conversation button in the workspace and talk.

Not reachable from the public internet. To turn it off:
  tailscale serve reset && hermes -p $HOST_PROFILE config unset webapp.public_url && hermes -p $HOST_PROFILE gateway restart
EOF
