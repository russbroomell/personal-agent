# shellcheck shell=bash
# Yes/no questions for the setup scripts.
#
#   ask "Question?" Y   -> Enter means yes   [Y/n]
#   ask "Question?" N   -> Enter means no    [y/N]
#
# With SIDEKICK_YES=1 (scripts' --yes flag) or no terminal to ask on, the
# default answer is taken and printed, so unattended runs still work.
ask() {
  local q="$1" def="${2:-Y}" hint a
  [[ "$def" == Y ]] && hint="[Y/n]" || hint="[y/N]"
  if [[ -n "${SIDEKICK_YES:-}" ]] || ! { : </dev/tty; } 2>/dev/null; then
    printf '%s %s %s (default)\n' "$q" "$hint" "$def"
    [[ "$def" == Y ]]; return
  fi
  read -r -p "$q $hint " a </dev/tty || a=""
  [[ -z "$a" ]] && a="$def"
  [[ "$a" =~ ^[Yy] ]]
}
