#!/usr/bin/env bash
# Sidekick: prepare a fresh VPS (tested target: OVH VPS, 4 GB RAM,
# Ubuntu 24.04 or Debian 12/13). Run ONCE with sudo:
#
#   git clone -b stable https://github.com/russbroomell/personal-agent.git ~/personal-agent
#   sudo bash ~/personal-agent/scripts/bootstrap-vps.sh
#
# It gives the new "agent" user its own copy of the repo, so it can pull
# updates. (Using a private fork? Put a read-only deploy key at
# ~/.ssh/sidekick_deploy first and it is copied across too.)
#
# What it does:
#   1. Updates packages, turns on automatic security updates
#   2. Adds 4 GB of swap (a 4 GB server needs it for the browser screen)
#   3. Creates the "agent" user with your SSH key and sudo
#   4. Firewall: only SSH in. Nothing else is exposed; you reach the
#      workspace and Memory Card through an SSH tunnel.
#   5. Installs the bot's desktop (TigerVNC + Xfce) and a headed browser
#      for Bot Screen (watch and take over the agent's browser)
#
# It asks yes/no before each optional part (Enter takes the recommended
# answer). --yes takes every recommended answer without asking.
#
# SSH hardening (no root login, no passwords) is a separate, explicit step:
#   sudo bash bootstrap-vps.sh --harden-ssh
# Run it only after you've confirmed `ssh agent@YOUR_SERVER` works.
set -euo pipefail

AGENT_USER="${AGENT_USER:-agent}"
SWAP_GB="${SWAP_GB:-4}"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mxx %s\033[0m\n' "$*" >&2; exit 1; }
# shellcheck source=lib/ask.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/ask.sh"

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"
[[ -r /etc/os-release ]] || die "Can't read /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) die "This script supports Ubuntu and Debian (found: ${ID:-unknown})." ;;
esac

harden_ssh() {
  say "Hardening SSH: no root login, no passwords"
  local home_keys="/home/$AGENT_USER/.ssh/authorized_keys"
  [[ -s "$home_keys" ]] || die "$home_keys is empty. Fix that first or you'll lock yourself out."
  printf 'PermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' \
    > /etc/ssh/sshd_config.d/99-sidekick-hardening.conf
  sshd -t || die "sshd config test failed; nothing restarted."
  systemctl restart ssh 2>/dev/null || systemctl restart sshd
  say "Done. Keep this window open and test 'ssh $AGENT_USER@<server>' in a new one."
}

[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && export SIDEKICK_YES=1
if [[ "${1:-}" == "--harden-ssh" ]]; then
  harden_ssh
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

cat <<'INTRO'

Preparing this server for Sidekick. It asks yes/no before each optional
part; press Enter for the recommended answer (shown as the capital letter).

INTRO

say "Packages"
apt-get update -y
if ask "Upgrade the installed system packages now? (recommended on a new server)" Y; then
  apt-get -y -o Dpkg::Options::=--force-confold upgrade
fi
echo "Installing the basics Sidekick needs (git, curl, python3, ffmpeg, ...)"
apt-get install -y ca-certificates curl git ufw unattended-upgrades python3 \
  xz-utils unzip jq tmux libatomic1 ffmpeg

say "Automatic security updates"
if ask "Let the server install security updates by itself?" Y; then
  dpkg-reconfigure -f noninteractive unattended-upgrades || true
else
  echo "Skipped. Remember to run 'sudo apt-get upgrade' now and then."
fi

say "Swap (at least ${SWAP_GB} GB in total)"
# Building the workspace and running the bot's screen both need more than
# 4 GB of RAM at peak. Some VPS images ship a small swap file (or none), so
# top up to SWAP_GB total rather than skipping when any swap exists.
HAVE_MB="$(free -m | awk '/^Swap:/{print $2}')"
WANT_MB=$((SWAP_GB*1024))
if [[ "${HAVE_MB:-0}" -ge $((WANT_MB - 64)) ]]; then
  echo "Swap already ${HAVE_MB} MB:"; swapon --show
elif ! ask "Swap is ${HAVE_MB:-0} MB. Add more, up to ${SWAP_GB} GB? (needed on a 4 GB server; skip only with 8 GB+ RAM)" Y; then
  warn "Skipped swap. On a 4 GB server the workspace build and the bot's screen may be killed for lack of memory."
else
  ADD_MB=$((WANT_MB - ${HAVE_MB:-0}))
  SWAPFILE=/swapfile; swapon --show=NAME --noheadings | grep -qx /swapfile && SWAPFILE=/swapfile-sidekick
  echo "Swap is ${HAVE_MB:-0} MB; adding ${ADD_MB} MB at $SWAPFILE"
  fallocate -l "${ADD_MB}M" "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count="$ADD_MB"
  chmod 600 "$SWAPFILE"
  mkswap "$SWAPFILE"
  swapon "$SWAPFILE"
  grep -q "^$SWAPFILE " /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
  swapon --show
fi
sysctl -q -w vm.swappiness=20
echo 'vm.swappiness=20' > /etc/sysctl.d/90-sidekick-swap.conf

say "User '$AGENT_USER'"
if ! id "$AGENT_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "Sidekick agent" "$AGENT_USER"
fi
usermod -aG sudo "$AGENT_USER"
# Passwordless sudo is NOT granted. Set a password for sudo use:
if ! passwd -S "$AGENT_USER" 2>/dev/null | grep -q ' P '; then
  warn "Set a sudo password for '$AGENT_USER' now (you'll need it rarely):"
  passwd "$AGENT_USER" || warn "No password set; run 'sudo passwd $AGENT_USER' later."
fi
install -d -m 700 -o "$AGENT_USER" -g "$AGENT_USER" "/home/$AGENT_USER/.ssh"
keys="/home/$AGENT_USER/.ssh/authorized_keys"
touch "$keys"
for src in /root/.ssh/authorized_keys "/home/${SUDO_USER:-none}/.ssh/authorized_keys" \
           /home/ubuntu/.ssh/authorized_keys /home/debian/.ssh/authorized_keys; do
  [[ -s "$src" ]] && cat "$src" >> "$keys"
done
sort -u "$keys" -o "$keys"
chown "$AGENT_USER:$AGENT_USER" "$keys"; chmod 600 "$keys"
[[ -s "$keys" ]] || warn "No SSH keys found to copy. Add yours to $keys before logging in as $AGENT_USER."
# Let the agent's services keep running when nobody is logged in.
loginctl enable-linger "$AGENT_USER"

say "Repo and GitHub deploy key for '$AGENT_USER'"
REPO_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DST="/home/$AGENT_USER/personal-agent"
REPO_URL="${REPO_URL:-https://github.com/russbroomell/personal-agent.git}"
if [[ ! -d "$REPO_DST/.git" ]]; then
  if [[ -d "$REPO_SRC/.git" && -d "$REPO_SRC/distribution" ]]; then
    cp -a "$REPO_SRC" "$REPO_DST"
    echo "Copied repo to $REPO_DST"
  else
    sudo -u "$AGENT_USER" git clone -b stable "$REPO_URL" "$REPO_DST" 2>/dev/null \
      || sudo -u "$AGENT_USER" git clone "$REPO_URL" "$REPO_DST"
    echo "Cloned $REPO_URL to $REPO_DST"
  fi
  chown -R "$AGENT_USER:$AGENT_USER" "$REPO_DST"
fi
SRC_HOME="$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)"
if [[ -f "$SRC_HOME/.ssh/sidekick_deploy" ]]; then
  install -m 600 -o "$AGENT_USER" -g "$AGENT_USER" "$SRC_HOME/.ssh/sidekick_deploy" "/home/$AGENT_USER/.ssh/sidekick_deploy"
  install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$SRC_HOME/.ssh/sidekick_deploy.pub" "/home/$AGENT_USER/.ssh/sidekick_deploy.pub" 2>/dev/null || true
  [[ -f "$SRC_HOME/.ssh/known_hosts" ]] && install -m 644 -o "$AGENT_USER" -g "$AGENT_USER" "$SRC_HOME/.ssh/known_hosts" "/home/$AGENT_USER/.ssh/known_hosts"
  cfg="/home/$AGENT_USER/.ssh/config"
  if ! grep -q sidekick_deploy "$cfg" 2>/dev/null; then
    printf 'Host github.com\n  IdentityFile ~/.ssh/sidekick_deploy\n  IdentitiesOnly yes\n' >> "$cfg"
    chown "$AGENT_USER:$AGENT_USER" "$cfg"; chmod 600 "$cfg"
  fi
  echo "Deploy key installed for $AGENT_USER"
fi

say "Firewall"
if ask "Turn on the firewall, allowing only SSH in? (recommended; Sidekick needs no other open ports)" Y; then
  ufw allow OpenSSH >/dev/null
  ufw --force enable
  ufw status | head -5
else
  warn "Firewall left as it was."
fi

say "The bot's screen"
cat <<'SCREEN'
A small desktop and a real browser for the bot, so you can watch it browse
and take over for logins (about 1 GB of disk; 1-1.5 GB of memory while it's
open). Without it, the bot still browses the web, you just can't watch.
SCREEN
SCREEN=1
ask "Install the bot's screen?" Y || SCREEN=0
BROWSER_PATH=""
if [[ $SCREEN -eq 1 ]]; then
apt-get install -y tigervnc-standalone-server xfce4-panel xfwm4 xfdesktop4 \
  xfce4-settings xfce4-terminal dbus-x11 x11-xserver-utils x11-utils xauth \
  fonts-dejavu-core at-spi2-core

echo "Installing the browser for the bot's screen"
if [[ "$ID" == "debian" ]]; then
  apt-get install -y chromium
  BROWSER_PATH=/usr/bin/chromium
else
  # Ubuntu's chromium is a snap, which doesn't run well headless. Google
  # Chrome's .deb ships an AppArmor profile that works with Ubuntu 24.04's
  # user-namespace restriction.
  if [[ "$(dpkg --print-architecture)" == "amd64" ]]; then
    tmpdeb="$(mktemp --suffix=.deb)"
    curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$tmpdeb"
    apt-get install -y "$tmpdeb"
    rm -f "$tmpdeb"
    BROWSER_PATH=/usr/bin/google-chrome-stable
  else
    warn "Not amd64: skipping Chrome. Hermes will try its own Chromium."
  fi
fi
fi   # SCREEN
install -d -m 755 /etc/sidekick
printf 'BROWSER_PATH=%s\nSCREEN=%s\n' "$BROWSER_PATH" "$SCREEN" > /etc/sidekick/host.conf

say "All set"
cat <<EOF

Server is ready. Next:

  1. From your computer, in a NEW terminal, check you can log in:
       ssh $AGENT_USER@$(hostname -I 2>/dev/null | awk '{print $1}')
  2. Then (optional but recommended), back here:
       sudo bash $0 --harden-ssh
  3. Log in as $AGENT_USER and set up the agent:
       bash ~/personal-agent/scripts/setup.sh

Memory: $(free -h | awk '/Mem:/{print $2" RAM"}'), $(free -h | awk '/Swap:/{print $2" swap"}').
EOF
