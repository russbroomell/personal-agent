#!/usr/bin/env bash
# Build SOUL.md for the Council: the chair's rules, a short card for every
# seated member, then the house rules. Also gives each seated member their
# own speaking voice (council-voices plugin).
#
#   build-soul.sh                    rebuild from the saved choice (council.conf)
#   build-soul.sh --list             who's seated, who's on the bench
#   build-soul.sh --seat ada         seat a member (from members/)
#   build-soul.sh --bench maui       bench a member (Marcus chairs; he stays)
#   build-soul.sh --roster "marcus newton feynman"   set the seats exactly
#   build-soul.sh --name "Atlas"     what the council is called as a whole
#   build-soul.sh --defaults         back to the standard nine
#   build-soul.sh --no-voice ...     skip the Hermes voice settings (tests)
#
# Options combine: build-soul.sh --bench maui --seat ada
# Choices live in <profile>/council.conf, outside the files an update
# replaces, so `hermes profile update` + this script keeps them.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${COUNCIL_HOME:-$(cd "$SKILL_DIR/../.." && pwd)}"   # the profile's Hermes home
MEMBERS="$SKILL_DIR/members"
CONF="$HOME_DIR/council.conf"
DEFAULT_SEATED="marcus romulus remus odysseus maui newton feynman scheherazade florence"
CHAIR="marcus"
MAX_SOUL_BYTES=26000   # the SOUL is sent with every message: keep it lean

die() { echo "$*" >&2; exit 1; }
all_members() { (cd "$MEMBERS" && ls -1 ./*.md | sed 's|^\./||; s|\.md$||' | grep -v '^_'); }
is_member() { [[ "$1" =~ ^[a-z0-9-]+$ && -f "$MEMBERS/$1.md" && "$1" != _* ]]; }
has() { [[ " $1 " == *" $2 "* ]]; }

SEATED="$DEFAULT_SEATED"; NAME=""
# shellcheck disable=SC1090
[[ -f "$CONF" ]] && source "$CONF"

VOICE=1; LIST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --seat|--add) m="${2:-}"; is_member "$m" || die "No member '$m'. Members: $(all_members | tr '\n' ' ')"
                  has "$SEATED" "$m" || SEATED="$SEATED $m"; shift 2 ;;
    --bench|--remove) m="${2:-}"; [[ "$m" != "$CHAIR" ]] || die "Marcus chairs the council and can't be benched. Say 'just Marcus' to hear only him."
                  SEATED="$(tr ' ' '\n' <<<"$SEATED" | grep -vx "$m" | tr '\n' ' ')"; shift 2 ;;
    --roster) SEATED="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --defaults) SEATED="$DEFAULT_SEATED"; shift ;;
    --no-voice) VOICE=0; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
done

# Clean the roster: known members only, no repeats, chair first.
clean="$CHAIR"
for m in $SEATED; do
  m="$(tr '[:upper:]' '[:lower:]' <<<"$m")"
  is_member "$m" || { echo "Skipping unknown member '$m'." >&2; continue; }
  has "$clean" "$m" || clean="$clean $m"
done
SEATED="$clean"
[[ "$(wc -w <<<"$SEATED")" -ge 2 ]] || die "Seat at least one member besides Marcus."
NAME="$(printf '%s' "$NAME" | tr -cd "A-Za-z '-" | cut -c1-30)"

field() { sed -n "s/^Seat: .*· Tag: //p" "$MEMBERS/$1.md" | head -1; }      # tag
seat() { sed -n "s/^Seat: \(.*\) · Tag: .*/\1/p" "$MEMBERS/$1.md" | head -1; }
fullname() { sed -n '1s/^# //p' "$MEMBERS/$1.md"; }
card() { awk '/^## Card/{on=1; next} /^## /{on=0} on' "$MEMBERS/$1.md" | sed '/^[[:space:]]*$/d'; }

if [[ $LIST -eq 1 ]]; then
  echo "Seated:"; for m in $SEATED; do printf '  %-13s %s (%s)\n' "$m" "$(fullname "$m")" "$(seat "$m")"; done
  echo "Bench:"; for m in $(all_members); do has "$SEATED" "$m" || printf '  %-13s %s (%s)\n' "$m" "$(fullname "$m")" "$(seat "$m" | sed 's/ (bench)//')"; done
  exit 0
fi

bench=""
for m in $(all_members); do has "$SEATED" "$m" || bench="${bench:+$bench, }$(fullname "$m") ($(seat "$m" | sed 's/ (bench)//'))"; done

tmp="$(mktemp)"
{
  cat "$SKILL_DIR/chair.md"
  [[ -n "$NAME" ]] && printf '\nYour person calls the council as a whole "%s". Members still use their own tags.\n' "$NAME"
  for m in $SEATED; do
    printf '\n## %s, %s (tag `%s:`)\n' "$(fullname "$m")" "$(seat "$m")" "$(field "$m")"
    card "$m"
  done
  printf '\nOn the bench (they speak only if your person asks for them by name; read their file first): %s.\n' "${bench:-nobody}"
  printf 'If a lane in the quick guide belongs to a benched member, the closest seated member covers it.\n\n'
  cat "$SKILL_DIR/house-rules.md"
  # Per-bot extra rules, kept outside the distribution so updates don't remove them.
  if [[ -f "$HOME_DIR/house-rules.local.md" ]]; then
    printf '\n'; cat "$HOME_DIR/house-rules.local.md"
  fi
} > "$tmp"

size="$(wc -c <"$tmp")"
[[ "$size" -le "$MAX_SOUL_BYTES" ]] || echo "Warning: SOUL.md is $size bytes (budget $MAX_SOUL_BYTES). Bench a member or trim a card." >&2

[[ -f "$HOME_DIR/SOUL.md" ]] && cp "$HOME_DIR/SOUL.md" "$HOME_DIR/SOUL.md.bak"
mv "$tmp" "$HOME_DIR/SOUL.md"
chmod 644 "$HOME_DIR/SOUL.md"
printf 'SEATED=%q\nNAME=%q\n' "$SEATED" "$NAME" > "$CONF"
# The council's notebook (banter level, benched, tally), if it's missing.
if [[ -f "$SKILL_DIR/notebook-template.md" && ! -f "$HOME_DIR/notes/council.md" ]]; then
  mkdir -p "$HOME_DIR/notes"; cp "$SKILL_DIR/notebook-template.md" "$HOME_DIR/notes/council.md"
fi
echo "SOUL.md built: $(wc -w <<<"$SEATED") seated ($SEATED), $size bytes."

# ------------------------------------------------------------------ voices
[[ $VOICE -eq 1 ]] || exit 0
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
command -v hermes >/dev/null 2>&1 || exit 0
[[ "$(basename "$(dirname "$HOME_DIR")")" == "profiles" ]] || { echo "Not inside a Hermes profile; voices not set." >&2; exit 0; }
prof="$(basename "$HOME_DIR")"
cfg() { hermes -p "$prof" config "$@"; }

json="$(python3 - "$MEMBERS/voices.conf" "$SEATED" "$MEMBERS" <<'PY'
import json, re, sys, os
conf, seated, members = sys.argv[1], sys.argv[2].split(), sys.argv[3]
voices, labels = {}, {}
for line in open(conf, encoding="utf-8"):
    parts = line.split()
    if not parts or parts[0].startswith("#") or parts[0] not in seated:
        continue
    slug, xv, xs, ev, es, el = (parts + [""] * 6)[:6]
    voices[slug] = {"xai": xv, "xai_speed": float(xs), "edge": ev, "edge_speed": float(es), "elevenlabs": el}
for slug in seated:
    text = open(os.path.join(members, slug + ".md"), encoding="utf-8").read()
    m = re.search(r"^Seat: .*· Tag: (.+)$", text, re.M)
    tag = (m.group(1).strip() if m else slug)
    for word in {tag.lower(), tag.lower().replace("ā", "a"), slug.replace("-", " ")}:
        if word != slug:
            labels[word] = slug
missing = [s for s in seated if s not in voices]
print(json.dumps({"voices": voices, "labels": labels, "speakers": seated, "missing": missing}, ensure_ascii=False))
PY
)"
missing="$(python3 -c 'import json,sys; print(" ".join(json.loads(sys.argv[1])["missing"]))' "$json")"
[[ -z "$missing" ]] || echo "No voices.conf line for: $missing (they'll use the chair's voice)." >&2
get() { python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1])[sys.argv[2]], ensure_ascii=False))' "$json" "$1"; }
# Set a JSON object in one go; if this Hermes won't take an object, set each leaf.
set_obj() {  # set_obj <key> <json-field>
  cfg set "$1" "$(get "$2")" >/dev/null 2>&1 && return 0
  python3 -c '
import json, sys
def walk(prefix, v):
    if isinstance(v, dict):
        for k, x in v.items(): yield from walk(f"{prefix}.{k}", x)
    else: yield prefix, v
for k, v in walk(sys.argv[1], json.loads(sys.argv[2])[sys.argv[3]]): print(f"{k}\t{v}")' "$1" "$json" "$2" |
  while IFS=$'\t' read -r k v; do cfg set "$k" "$v" >/dev/null 2>&1 || return 1; done
}

provider="$(cfg get tts.provider 2>/dev/null | tail -1 || true)"
if [[ "$provider" != "council" ]]; then
  # Remember the real engine (Grok, free Edge or ElevenLabs); the plugin speaks with it.
  case "$provider" in xai|edge|elevenlabs) ;; twins) provider="$(cfg get tts.twins.engine 2>/dev/null | tail -1 || echo edge)" ;; *) provider=edge ;; esac
  case "$provider" in xai|edge|elevenlabs) ;; *) provider=edge ;; esac
  cfg set tts.council.engine "$provider" >/dev/null 2>&1 || true
fi
if { cfg set tts.council.speakers "$(get speakers)"
     set_obj tts.council.voices voices
     set_obj tts.council.labels labels
     cfg set tts.council.lead "$CHAIR"
     hermes -p "$prof" plugins enable council-voices
     cfg set tts.provider council; } >/dev/null 2>&1; then
  echo "Voices: one per seated member, spoken by the council-voices plugin ($(cfg get tts.council.engine 2>/dev/null | tail -1) engine)."
else
  echo "Couldn't set the council's voices automatically; see docs/voice.md." >&2
fi
