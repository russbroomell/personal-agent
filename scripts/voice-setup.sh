#!/usr/bin/env bash
# Sidekick: turn on two-way speech.
#
#   bash ~/personal-agent/scripts/voice-setup.sh grok   # expressive Grok voices (uses your xAI sign-in)
#   bash ~/personal-agent/scripts/voice-setup.sh free   # free voices, no account needed
#   bash ~/personal-agent/scripts/voice-setup.sh elevenlabs  # ElevenLabs voices (paid key)
#
# grok: speech-to-text and text-to-speech both through xAI (the same
#       SuperGrok/Premium+ sign-in or xAI API key as the chat model). Each
#       persona gets its own Grok voice, with expressive delivery tags
#       ([laughs], [pause], ...) added automatically.
# free: speech-to-text runs locally on the server (Whisper "base", ~150 MB
#       download, ~300 MB RAM while in use); text-to-speech uses free Edge
#       voices, one per persona.
# elevenlabs: speech both ways through ElevenLabs (needs an API key; asks
#       for it and keeps it in the profile's .env). With Romulus and Remus,
#       the brothers' lines are spoken as one natural dialogue.
#
# Then talk to it: voice notes in Telegram, or the live voice conversation
# button in the workspace (needs the Tailscale HTTPS address). See docs/voice.md.
set -euo pipefail
PROFILE="${PROFILE:-sidekick}"
MODE="${1:-}"
HH="$HOME/.hermes/profiles/$PROFILE"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
cfg() { hermes -p "$PROFILE" config set "$1" "$2" >/dev/null; }

[[ -d "$HH" ]] || { echo "Profile $PROFILE not installed. Run scripts/install-agent.sh first." >&2; exit 1; }
case "$MODE" in grok|free|elevenlabs) ;; *) sed -n '2,21p' "$0"; exit 1 ;; esac

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Installing ffmpeg (turns replies into Telegram voice bubbles)..."
  sudo apt-get install -y ffmpeg >/dev/null
fi

if [[ "$MODE" == "elevenlabs" ]]; then
  # shellcheck source=lib/ask.sh
  source "$(dirname "${BASH_SOURCE[0]}")/lib/ask.sh"
  envf="$(hermes -p "$PROFILE" config env-path 2>/dev/null | tail -1)"
  envf="${envf:-$HH/.env}"
  if ! grep -q '^ELEVENLABS_API_KEY=.' "$envf" 2>/dev/null; then
    if ask "No ElevenLabs key yet. Paste one now (from elevenlabs.io, Developers, API keys)?" Y; then
      read -r -s -p "ElevenLabs API key: " key </dev/tty; echo
      [[ -n "$key" ]] || { echo "No key given; nothing changed." >&2; exit 1; }
      touch "$envf"; chmod 600 "$envf"
      grep -v '^ELEVENLABS_API_KEY=' "$envf" > "$envf.tmp" || true
      printf 'ELEVENLABS_API_KEY=%s\n' "$key" >> "$envf.tmp"
      mv "$envf.tmp" "$envf"; chmod 600 "$envf"
    else
      echo "Add ELEVENLABS_API_KEY to $envf, then run this again." >&2; exit 1
    fi
  fi
  hermes pm install --extra tts-premium >/dev/null 2>&1 \
    || echo "Couldn't install the ElevenLabs package; run: hermes pm install --extra tts-premium" >&2
  cfg tts.provider elevenlabs
  cfg stt.provider elevenlabs
elif [[ "$MODE" == "grok" ]]; then
  cfg tts.provider xai
  cfg tts.xai.auto_speech_tags true
  cfg tts.xai.language en
  cfg stt.provider xai
else
  cfg tts.provider edge
  cfg stt.provider local
  cfg stt.local.model base
fi
cfg stt.language en

# Match the voice to the current persona (build-soul.sh sets it).
bash "$HH/skills/persona-switch/build-soul.sh" >/dev/null
PERSONA=pip; NAME=""
# shellcheck disable=SC1091
source "$HH/persona.conf"
hermes -p "$PROFILE" gateway restart >/dev/null 2>&1 || true

echo
echo "Two-way speech is on ($MODE voices). ${NAME:-Your assistant} now speaks as $PERSONA."
echo
echo "Try it:"
echo "  Telegram:  send a voice note; it answers with a voice note."
echo "             /voice tts = speak every reply, /voice off = text only"
echo "  Workspace: open your https://...ts.net address and press the voice"
echo "             conversation button (right of the microphone). Talk normally,"
echo "             interrupt any time, say \"stop\" to end."
