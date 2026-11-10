# shellcheck shell=bash
# Build the workspace (Hermes Desktop in a browser) without running out of
# memory. Sourced by install-agent.sh and remote-access.sh.
#
# The build (Node) can need several GB at peak. On a 4 GB server with the bot's
# screen and Chrome running, the kernel kills it partway through. So: free
# what we can first, check RAM + swap, and retry once if it still dies.

mem_headroom_mb() {   # free RAM + free swap, in MB
  awk '/^MemAvailable:/{a=$2} /^SwapFree:/{s=$2} END{print int((a+s)/1024)}' /proc/meminfo
}

build_workspace() {   # build_workspace <host-profile> <bot-profile>
  local host="$1" bot="$2" head
  # The screen (Xfce + Chrome) holds 1-1.5 GB; it restarts on its own the
  # next time the bot browses.
  hermes -p "$bot" computer-use screen stop --force >/dev/null 2>&1 || true
  sync
  head="$(mem_headroom_mb)"
  echo "Memory available for the build: ${head} MB (RAM + swap)."
  if [[ "$head" -lt 3000 ]]; then
    echo "!! That's tight; the build may be killed. Add swap with:"
    echo "     sudo bash ~/personal-agent/scripts/bootstrap-vps.sh   (tops swap up to 4 GB)"
  fi
  if hermes -p "$host" webapp --build-only; then
    return 0
  fi
  echo "Build failed; trying once more (a killed build is usually memory)..."
  sleep 5
  hermes -p "$host" webapp --build-only && return 0
  echo "!! Workspace build failed twice. Free memory now: $(mem_headroom_mb) MB (RAM + swap)."
  echo "   If that's under 3000, add swap (sudo bash ~/personal-agent/scripts/bootstrap-vps.sh), then re-run."
  return 1
}
