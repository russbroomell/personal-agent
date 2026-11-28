# shellcheck shell=bash
# Helpers for the workspace port (sourced by remote-access.sh and check.sh).
#
# The host gateway can only serve the workspace if nothing else holds its
# port. Leftovers from earlier attempts (an old profile-only gateway, a
# `hermes webapp`/`hermes dashboard` run by hand) keep the port, answer
# requests themselves, and the real gateway logs
# "Webapp unavailable: could not listen on 127.0.0.1:9120 (Address already in use)".

# PID of the running host gateway service, or empty.
gateway_main_pid() {
  local pid
  pid="$(systemctl --user show -p MainPID --value hermes-gateway.service 2>/dev/null)"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] && echo "$pid"
}

# PIDs listening on TCP port $1 (only this user's processes are visible).
port_pids() {
  if command -v ss >/dev/null; then
    ss -Hltnp "sport = :$1" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u
    return
  fi
  # No ss: map the listening socket's inode to a PID through /proc.
  python3 - "$1" <<'PY2'
import os, sys
port = int(sys.argv[1]); inodes = set()
for f in ("/proc/net/tcp", "/proc/net/tcp6"):
    try:
        for line in open(f).read().splitlines()[1:]:
            p = line.split()
            if p[3] == "0A" and int(p[1].rsplit(":", 1)[1], 16) == port:
                inodes.add(p[9])
    except OSError:
        pass
pids = set()
for pid in filter(str.isdigit, os.listdir("/proc")):
    try:
        for fd in os.listdir(f"/proc/{pid}/fd"):
            l = os.readlink(f"/proc/{pid}/fd/{fd}")
            if l.startswith("socket:[") and l[8:-1] in inodes:
                pids.add(pid)
    except OSError:
        pass
print("\n".join(sorted(pids)))
PY2
}

# True when $1 is the gateway itself or one of its descendants.
is_gateway_pid() {
  local pid="$1" main; main="$(gateway_main_pid)"
  [[ -n "$main" ]] || return 1
  while [[ -n "$pid" && "$pid" != 1 && "$pid" != 0 ]]; do
    [[ "$pid" == "$main" ]] && return 0
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
  return 1
}

# Print "PID command" for every process on port $1 that isn't the gateway.
port_strays() {
  local pid
  for pid in $(port_pids "$1"); do
    is_gateway_pid "$pid" && continue
    printf '%s %s\n' "$pid" "$(ps -o args= -p "$pid" 2>/dev/null | cut -c1-100)"
  done
}

# Stop Hermes leftovers holding port $1 (systemd units are stopped, not just
# killed, so they don't respawn). Non-Hermes holders are reported, not touched.
# Returns 1 if something that isn't Hermes still holds the port.
free_port() {
  local port="$1" line pid args unit rc=0
  while read -r line; do
    [[ -n "$line" ]] || continue
    pid="${line%% *}"; args="${line#* }"
    if [[ "$args" == *hermes* ]]; then
      unit="$(ps -o unit= -p "$pid" 2>/dev/null | tr -d ' ')"
      if [[ "$unit" == hermes-gateway-*.service ]]; then
        echo "Stopping leftover service $unit (it holds port $port)."
        systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
      else
        echo "Stopping leftover Hermes process $pid on port $port: $args"
      fi
      kill "$pid" 2>/dev/null || true
    else
      echo "Port $port is used by something else, not Hermes: PID $pid $args"
      rc=1
    fi
  done < <(port_strays "$port")
  sleep 2
  return $rc
}

# ------------------------------------------------------------- leftovers
# Things from an earlier install that keep running after a reinstall, and
# that the gateway can't see or stop: another user's Hermes, and services
# whose profile folder is gone.

# True when anything listens on TCP port $1, whoever owns it (ss without -p
# shows other users' sockets too, just not their PIDs).
port_listening() {
  if command -v ss >/dev/null; then
    [[ -n "$(ss -Hltn "sport = :$1" 2>/dev/null)" ]]; return
  fi
  python3 - "$1" <<'PY3'
import sys
port = int(sys.argv[1])
for f in ("/proc/net/tcp", "/proc/net/tcp6"):
    try:
        for line in open(f).read().splitlines()[1:]:
            p = line.split()
            if p[3] == "0A" and int(p[1].rsplit(":", 1)[1], 16) == port:
                sys.exit(0)
    except OSError:
        pass
sys.exit(1)
PY3
}

# True when port $1 is held by a process this user can't see (another user's).
port_held_by_other_user() {
  port_listening "$1" && [[ -z "$(port_pids "$1")" ]]
}

# "user pid hermes-home" for every Hermes gateway run by another user.
other_user_gateways() {
  local me; me="$(id -un)"
  ps -eo user=,pid=,args= 2>/dev/null | while read -r user pid args; do
    [[ "$pid" =~ ^[0-9]+$ && "$user" != "$me" ]] || continue
    # The process itself is Python running Hermes (not a shell that mentions it).
    [[ "${args%% *}" == *python* && "$args" == *hermes* && "$args" == *"gateway run"* ]] || continue
    home="$(grep -oE '/[^ ]*/\.hermes' <<<"$args" | head -1)"
    printf '%s %s %s\n' "$user" "$pid" "${home:-unknown}"
  done
}

# "unit reason" for this user's council/sidekick services that point at a
# profile folder that no longer exists, or that an older version left behind.
stale_council_units() {  # stale_council_units <current profile home>
  local current="$1" dir="$HOME/.config/systemd/user" f unit home
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*memory-card*.service; do
    [[ -f "$f" ]] || continue
    unit="$(basename "$f")"
    home="$(cat "$f" "$f.d"/*.conf 2>/dev/null | grep -oE -- '--home [^ ]+' | tail -1 | cut -d' ' -f2)"
    if [[ -n "$home" && ! -d "$home" ]]; then
      echo "$unit its profile folder $home is gone"
    elif [[ -n "$home" && "$(realpath -m "$home")" != "$(realpath -m "$current")" ]]; then
      echo "$unit it serves $home, not the council's profile"
    fi
  done
  for unit in sidekick-update.timer sidekick-update.service; do
    [[ -f "$dir/$unit" ]] && echo "$unit Sidekick's old nightly updater (the council uses council-update)"
  done
  return 0
}

# "pid home" for Memory Card pages running for a profile folder that's gone.
orphan_memory_cards() {
  ps -eo pid=,user=,args= 2>/dev/null | while read -r pid user args; do
    [[ "$pid" =~ ^[0-9]+$ && "$user" == "$(id -un)" ]] || continue
    [[ "${args%% *}" == *python* && "$args" == *memory-card/server.py* ]] || continue
    home="$(grep -oE -- '--home [^ ]+' <<<"$args" | cut -d' ' -f2)"
    [[ -n "$home" && ! -d "$home" ]] && printf '%s %s\n' "$pid" "$home"
  done
  return 0
}
