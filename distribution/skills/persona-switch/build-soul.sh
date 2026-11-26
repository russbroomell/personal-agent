#!/usr/bin/env bash
# Build SOUL.md from a persona plus the shared house rules, and point the
# text-to-speech voice at that persona's voice.
#   build-soul.sh <persona> [display-name]
#   persona: any file in personas/ (sam, pip, mortimer, rex, nova, vic,
#            romulus-remus)
# A persona whose file starts with "<!-- speakers: a b -->" talks in two
# voices: it keeps its own names and turns on the twin-voices plugin.
# With no arguments, rebuilds from the saved choice in persona.conf
# (used after `hermes profile update` refreshes the house rules).
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$(cd "$SKILL_DIR/../.." && pwd)"   # the profile's Hermes home
CONF="$HOME_DIR/persona.conf"
available="$(cd "$SKILL_DIR/personas" && ls -1 ./*.md | sed 's|^\./||; s|\.md$||' | grep -v '^_' | tr '\n' ' ')"

persona="${1:-}"
name="${2:-}"
if [[ -z "$persona" && -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
  persona="${PERSONA:-pip}"
  name="${NAME:-}"
fi
persona="$(printf '%s' "${persona:-pip}" | tr '[:upper:]' '[:lower:]')"

src="$SKILL_DIR/personas/$persona.md"
if [[ ! -f "$src" || "$persona" == _* || ! "$persona" =~ ^[a-z0-9_-]+$ ]]; then
  echo "Unknown persona '$persona'. Choose: $available" >&2
  exit 1
fi

speakers="$(sed -n 's/^<!-- speakers: \([a-z -]*\) -->$/\1/p' "$src" | head -1)"
if [[ -n "$speakers" ]]; then
  # Two voices, two names that the voice plugin listens for: no renaming.
  default_name="$(sed -n 's/^You are \([A-Za-z ]*\),.*/\1/p' "$src" | head -1)"
  name="$default_name"
else
  default_name="$(sed -n 's/^You are \([A-Za-z]*\),.*/\1/p' "$src" | head -1)"
  name="${name:-$default_name}"
  # Keep the name to letters, spaces, apostrophes and hyphens.
  name="$(printf '%s' "$name" | tr -cd "A-Za-z '-" | cut -c1-30)"
  [[ -n "$name" ]] || name="$default_name"
fi

tmp="$(mktemp)"
{
  sed -e '/^<!-- speakers:/d' -e "s/\b$default_name\b/$name/g" "$src"
  printf '\n'
  cat "$SKILL_DIR/house-rules.md"
  # Per-bot extra rules (e.g. a guest bot's), kept outside the distribution
  # so updates and resets don't remove them.
  if [[ -f "$HOME_DIR/house-rules.local.md" ]]; then
    printf '\n'
    cat "$HOME_DIR/house-rules.local.md"
  fi
} > "$tmp"

if [[ -f "$HOME_DIR/SOUL.md" ]]; then
  cp "$HOME_DIR/SOUL.md" "$HOME_DIR/SOUL.md.bak"
fi
mv "$tmp" "$HOME_DIR/SOUL.md"
chmod 644 "$HOME_DIR/SOUL.md"
printf 'PERSONA=%q\nNAME=%q\n' "$persona" "$name" > "$CONF"
# Two-speaker characters keep their banter level and tally in a note.
if [[ -n "$speakers" && -f "$SKILL_DIR/brothers-template.md" && ! -f "$HOME_DIR/notes/brothers.md" ]]; then
  mkdir -p "$HOME_DIR/notes"
  cp "$SKILL_DIR/brothers-template.md" "$HOME_DIR/notes/brothers.md"
fi
echo "SOUL.md now uses persona '$persona' named '$name'."

# Match the speaking voice to the persona (best effort; skipped if hermes
# isn't on PATH, e.g. in tests).
voice_line() {  # voice_line <name>: "xai_voice xai_speed edge_voice"
  local line
  line="$(grep -E "^${1}[[:space:]]" "$SKILL_DIR/personas/voices.conf" || echo "x eve 1.0 en-US-AriaNeural")"
  read -r _ v s e <<<"$line"
  echo "$v $s $e"
}
read -r xai_voice xai_speed edge_voice <<<"$(voice_line "$persona")"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
if command -v hermes >/dev/null 2>&1 && [[ "$(basename "$(dirname "$HOME_DIR")")" == "profiles" ]]; then
  prof="$(basename "$HOME_DIR")"
  cfg() { hermes -p "$prof" config "$@"; }
  provider="$(cfg get tts.provider 2>/dev/null | tail -1 || true)"
  if ! {
    cfg set tts.xai.voice_id "$xai_voice"
    cfg set tts.xai.speed "$xai_speed"
    cfg set tts.edge.voice "$edge_voice"
  } >/dev/null 2>&1; then
    echo "Couldn't set the voice automatically; see docs/voice.md." >&2
  elif [[ -n "$speakers" ]]; then
    # Remember the real engine (Grok, free or ElevenLabs), then hand speech
    # to the twin-voices plugin, which speaks each brother in his own voice.
    if [[ "$provider" != "twins" ]]; then
      case "$provider" in xai|edge|elevenlabs) ;; *) provider=edge ;; esac
      cfg set tts.twins.engine "$provider" >/dev/null 2>&1 || true
    fi
    ok=1
    for who in $speakers; do
      read -r v s e <<<"$(voice_line "$who")"
      { cfg set "tts.twins.voices.$who.xai" "$v"
        cfg set "tts.twins.voices.$who.xai_speed" "$s"
        cfg set "tts.twins.voices.$who.edge" "$e"; } >/dev/null 2>&1 || ok=0
    done
    lead="${speakers%% *}"
    { cfg set tts.twins.lead "$lead"
      hermes -p "$prof" plugins enable twin-voices
      cfg set tts.provider twins; } >/dev/null 2>&1 || ok=0
    if [[ $ok -eq 1 ]]; then
      echo "Voices: two speakers ($speakers), spoken by the twin-voices plugin."
    else
      echo "Couldn't turn on the two voices; see docs/romulus-remus.md." >&2
    fi
  else
    if [[ "$provider" == "twins" ]]; then
      # Back to one voice: give speech back to the engine twin-voices used.
      engine="$(cfg get tts.twins.engine 2>/dev/null | tail -1 || true)"
      case "$engine" in xai|edge|elevenlabs) ;; *) engine=edge ;; esac
      cfg set tts.provider "$engine" >/dev/null 2>&1 || true
    fi
    echo "Voice: $xai_voice (Grok voice) / $edge_voice (free voice)."
  fi
fi
