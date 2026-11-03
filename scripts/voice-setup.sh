#!/usr/bin/env bash
# Sidekick: turn on two-way speech.
#
#   bash ~/personal-agent/scripts/voice-setup.sh grok   # expressive Grok voices (uses your xAI sign-in)
#   bash ~/personal-agent/scripts/voice-setup.sh free   # free voices, no account needed
#
# grok: speech-to-text and text-to-speech both through xAI (the same
#       SuperGrok/Premium+ sign-in or xAI API key as the chat model). Each
#       persona gets its own Grok voice, with expressive delivery tags
#       ([laughs], [pause], ...) added automatically.
# free: speech-to-text runs locally on the server (Whisper "base", ~150 MB
#       download, ~300 MB RAM while in use); text-to-speech uses free Edge
#       voices, one per persona.
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
case "$MODE" in grok|free) ;; *) sed -n '2,16p' "$0"; exit 1 ;; esac

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Installing ffmpeg (turns replies into Telegram voice bubbles)..."
  sudo apt-get install -y ffmpeg >/dev/null
fi

if [[ "$MODE" == "grok" ]]; then
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
