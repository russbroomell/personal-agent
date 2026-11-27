#!/usr/bin/env bash
# The Council: turn on two-way speech, a voice per council member.
#
#   bash ~/personal-agent/scripts/voice-setup.sh grok   # expressive Grok voices (uses your xAI sign-in)
#   bash ~/personal-agent/scripts/voice-setup.sh free   # free voices, no account needed
#   bash ~/personal-agent/scripts/voice-setup.sh elevenlabs  # ElevenLabs voices (paid key)
#
# grok: speech-to-text and text-to-speech both through xAI (the same
#       SuperGrok/Premium+ sign-in or xAI API key as the chat model). Each
#       member gets a Grok voice (five voices, shared at different
#       speeds), with expressive delivery tags
#       ([laughs], [pause], ...) added automatically.
# free: speech-to-text runs locally on the server (Whisper "base", ~150 MB
#       download, ~300 MB RAM while in use); text-to-speech uses free Edge
#       voices, a different one for every member.
# elevenlabs: speech both ways through ElevenLabs (needs an API key; asks
#       for it and keeps it in the profile's .env). Council replies are spoken
#       as one natural dialogue, a distinct voice per member.
#
# Then talk to it: voice notes in Telegram, or the live voice conversation
# button in the workspace (needs the Tailscale HTTPS address). See docs/voice.md.
set -euo pipefail
# shellcheck source=lib/profile.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/profile.sh"
PROFILE="${PROFILE:-$(saved_profile)}"
MODE="${1:-}"
HH="$(profile_home "$PROFILE")"
export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
cfg() { hermes -p "$PROFILE" config set "$1" "$2" >/dev/null; }

[[ -d "$HH" ]] || { echo "Profile $PROFILE not installed. Run install.sh first." >&2; exit 1; }
case "$MODE" in grok|free|elevenlabs) ;; *) sed -n '2,21p' "$0"; exit 1 ;; esac

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Installing ffmpeg (turns replies into Telegram voice bubbles)..."
  if [[ $EUID -eq 0 ]]; then apt-get install -y ffmpeg >/dev/null; else sudo apt-get install -y ffmpeg >/dev/null; fi
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

# Hand speech to the council-voices plugin with this engine, and give every
# seated member their voice (build-soul.sh reads the engine just set).
case "$MODE" in grok) engine=xai ;; free) engine=edge ;; *) engine=elevenlabs ;; esac
hermes -p "$PROFILE" config set tts.council.engine "$engine" >/dev/null
bash "$HH/skills/council/build-soul.sh"
timeout 120 hermes -p default gateway restart >/dev/null 2>&1 || true

echo
echo "Two-way speech is on ($MODE voices). Each council member speaks in their own voice."
echo
echo "Try it:"
echo "  Telegram:  send a voice note; it answers with a voice note."
echo "             /voice tts = speak every reply, /voice off = text only"
echo "  Workspace: open your https://...ts.net address and press the voice"
echo "             conversation button (right of the microphone). Talk normally,"
echo "             interrupt any time, say \"stop\" to end."
