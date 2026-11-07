#!/usr/bin/env bash
# Build SOUL.md from a persona plus the shared house rules, and point the
# text-to-speech voice at that persona's voice.
#   build-soul.sh <persona> [display-name]
#   persona: any file in personas/ (sam, pip, mortimer, rex, nova, vic)
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

default_name="$(sed -n 's/^You are \([A-Za-z]*\),.*/\1/p' "$src" | head -1)"
name="${name:-$default_name}"
# Keep the name to letters, spaces, apostrophes and hyphens.
name="$(printf '%s' "$name" | tr -cd "A-Za-z '-" | cut -c1-30)"
[[ -n "$name" ]] || name="$default_name"

tmp="$(mktemp)"
{
  sed "s/\b$default_name\b/$name/g" "$src"
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
echo "SOUL.md now uses persona '$persona' named '$name'."

# Match the speaking voice to the persona (best effort; skipped if hermes
# isn't on PATH, e.g. in tests).
read -r _ xai_voice xai_speed edge_voice < <(grep -E "^${persona}[[:space:]]" "$SKILL_DIR/personas/voices.conf" || echo "x eve 1.0 en-US-AriaNeural")
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
if command -v hermes >/dev/null 2>&1 && [[ "$(basename "$(dirname "$HOME_DIR")")" == "profiles" ]]; then
  prof="$(basename "$HOME_DIR")"
  {
    hermes -p "$prof" config set tts.xai.voice_id "$xai_voice"
    hermes -p "$prof" config set tts.xai.speed "$xai_speed"
    hermes -p "$prof" config set tts.edge.voice "$edge_voice"
  } >/dev/null 2>&1 && echo "Voice: $xai_voice (Grok voice) / $edge_voice (free voice)." \
    || echo "Couldn't set the voice automatically; see docs/voice.md." >&2
fi
