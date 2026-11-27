# shellcheck shell=bash
# Where the council lives, and how to install or refresh it there. Sourced by
# install.sh and the scripts in scripts/. Source it; don't run it.
#
# The council can live in Hermes's own default profile (~/.hermes, the usual
# choice on a machine that's already set up) or in a named profile
# (~/.hermes/profiles/<name>). install.sh records the choice, so updates,
# the health check and the other scripts all work on the same one.

HERMES_ROOT="${HERMES_HOME:-$HOME/.hermes}"
COUNCIL_STATE="$HOME/.local/state/council"

# The profile install.sh used (default if it hasn't run yet).
saved_profile() {
  local p
  p="$(cat "$COUNCIL_STATE/profile" 2>/dev/null || true)"
  [[ "$p" =~ ^[a-z0-9][a-z0-9_-]*$ ]] && echo "$p" || echo default
}

save_profile() { mkdir -p "$COUNCIL_STATE"; echo "$1" > "$COUNCIL_STATE/profile"; }

# The profile's home folder.
profile_home() {
  if [[ "$1" == default ]]; then echo "$HERMES_ROOT"; else echo "$HERMES_ROOT/profiles/$1"; fi
}

council_installed() { [[ -f "$(profile_home "$1")/skills/council/build-soul.sh" ]]; }

# Apply distribution/config.yaml one setting at a time (never replacing the
# file, so the model, keys and messaging settings stay as they are).
apply_council_config() {  # apply_council_config <profile> <repo_dir>
  local prof="$1" repo="$2" key value
  while IFS=$'\t' read -r key value; do
    [[ -n "$key" ]] || continue
    hermes -p "$prof" config set "$key" "$value" >/dev/null 2>&1 \
      || echo "!! couldn't set $key; set it later with: hermes -p $prof config set $key '$value'" >&2
  done < <(python3 - "$repo/distribution/config.yaml" <<'PY'
import re, sys
# A tiny reader for our own config.yaml: nested mappings of scalars and [].
stack = []
for raw in open(sys.argv[1], encoding="utf-8"):
    line = raw.split(" #", 1)[0].rstrip()
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    indent = len(line) - len(line.lstrip())
    m = re.match(r"\s*([A-Za-z0-9_.-]+):\s*(.*)$", line)
    if not m:
        continue
    key, value = m.groups()
    while stack and stack[-1][0] >= indent:
        stack.pop()
    if value == "":
        stack.append((indent, key))
        continue
    print(".".join([k for _, k in stack] + [key]) + "\t" + value.strip().strip("'\""))
PY
)
}

# Install or refresh the council's files in a profile.
sync_distribution() {  # sync_distribution <profile> <repo_dir>
  local prof="$1" repo="$2" home man rel d
  home="$(profile_home "$prof")"
  if [[ "$prof" != default ]]; then
    if [[ -f "$home/distribution.yaml" ]]; then hermes profile update "$prof" -y
    else hermes profile install "$repo/distribution" --name "$prof" --alias -y; fi
    return
  fi
  # The default profile isn't a distribution install, so copy the parts the
  # distribution owns (skills and plugins) and keep a list of them, so an
  # update can remove what a newer version no longer ships.
  man="$home/council-files.txt"
  mkdir -p "$home/skills" "$home/plugins"
  if [[ -f "$man" ]]; then
    while read -r rel; do
      [[ "$rel" =~ ^(skills|plugins)/[A-Za-z0-9_-]+$ && ! -e "$repo/distribution/$rel" ]] && rm -rf "${home:?}/$rel"
    done < "$man"
  fi
  : > "$man.new"
  for d in "$repo"/distribution/skills/*/ "$repo"/distribution/plugins/*/; do
    [[ -d "$d" ]] || continue
    rel="${d#"$repo/distribution/"}"; rel="${rel%/}"
    if [[ -e "$home/$rel" ]] && ! grep -qx "$rel" "$man" 2>/dev/null; then
      # Something of the same name that we didn't put there: keep it aside.
      mv "$home/$rel" "$home/$rel.before-council.$(date +%s)"
    fi
    rm -rf "${home:?}/$rel"
    cp -r "$d" "$home/$rel"
    echo "$rel" >> "$man.new"
  done
  mv "$man.new" "$man"
  apply_council_config "$prof" "$repo"
}
