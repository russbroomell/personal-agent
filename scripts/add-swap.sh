#!/usr/bin/env bash
# Top swap up to 4 GB in total (or SWAP_GB). A 4 GB server needs it for the
# workspace build and the bot's browser screen. Safe to run again.
#
#   sudo bash ~/personal-agent/scripts/add-swap.sh
set -euo pipefail
SWAP_GB="${SWAP_GB:-4}"
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0" >&2; exit 1; }
HAVE_MB="$(free -m | awk '/^Swap:/{print $2}')"
WANT_MB=$((SWAP_GB*1024))
if [[ "${HAVE_MB:-0}" -ge $((WANT_MB - 64)) ]]; then
  echo "Swap is already ${HAVE_MB} MB."; swapon --show; exit 0
fi
ADD_MB=$((WANT_MB - ${HAVE_MB:-0}))
SWAPFILE=/swapfile; swapon --show=NAME --noheadings | grep -qx /swapfile && SWAPFILE=/swapfile-council
echo "Swap is ${HAVE_MB:-0} MB; adding ${ADD_MB} MB at $SWAPFILE"
fallocate -l "${ADD_MB}M" "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count="$ADD_MB"
chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE" >/dev/null
swapon "$SWAPFILE"
grep -q "^$SWAPFILE " /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
swapon --show
