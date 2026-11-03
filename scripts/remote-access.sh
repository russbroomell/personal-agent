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

# --------------------------------------------------------------- Tailscale
if ! command -v tailscale >/dev/null 2>&1; then
  say "Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! tailscale status >/dev/null 2>&1; then
  say "Connect this server to your Tailscale account"
  echo "A login link will appear. Open it on any device and approve this server."
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

say "HTTPS addresses (private to your tailnet)"
echo "If Tailscale says HTTPS isn't enabled, open the link it prints, enable it, and re-run this script."
tailscale serve --bg --https=443 "http://127.0.0.1:$WEBAPP_PORT"
tailscale serve --bg --https=8443 "http://127.0.0.1:$MC_PORT"
tailscale serve status

# ------------------------------------------------ Workspace sign-in
say "Workspace sign-in (username + password)"
CFG_USER="$(hermes -p "$PROFILE" config get dashboard.basic_auth.username 2>/dev/null || true)"
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
  hermes -p "$PROFILE" config set dashboard.basic_auth.username "$WEB_USER" >/dev/null
  hermes -p "$PROFILE" config set dashboard.basic_auth.password_hash "$HASH" >/dev/null
  hermes -p "$PROFILE" config set dashboard.basic_auth.secret "$SECRET" >/dev/null
  chmod 600 "$HH/config.yaml" 2>/dev/null || true
fi

say "Pointing the workspace at its Tailscale address"
hermes -p "$PROFILE" config set webapp.public_url "https://$TS_NAME" >/dev/null
hermes -p "$PROFILE" gateway restart || warn "Gateway restart failed; run: hermes -p $PROFILE gateway restart"
sleep 3
hermes -p "$PROFILE" webapp --status 2>/dev/null || true

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
Not reachable from the public internet. To turn it off:
  tailscale serve reset && hermes -p $PROFILE config unset webapp.public_url && hermes -p $PROFILE gateway restart
EOF
