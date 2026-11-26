"""Turn voiced lines into one audio file.

Each line is spoken by one of Hermes's own voice engines (xAI/Grok, Edge or
ElevenLabs), so it uses the same sign-in, keys and settings as the rest of
Hermes. With ElevenLabs there is also a "dialogue" mode: one Text to
Dialogue request per batch of lines, which makes the hand-offs between the
two voices sound like a real exchange.
"""

from __future__ import annotations

import copy
import json
import logging
import os
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from typing import Any, Callable, Dict, List, Optional, Tuple

try:  # works when Hermes loads the folder as a package, and in tests
    from .speakers import batch_lines
except ImportError:  # pragma: no cover - direct import from the folder
    from speakers import batch_lines  # type: ignore[no-redef]

logger = logging.getLogger("plugins.twin-voices")

ENGINES = ("xai", "edge", "elevenlabs")

# Where each engine reads its voice (and speed) inside the tts config.
_VOICE_KEY = {"xai": "voice_id", "edge": "voice", "elevenlabs": "voice_id"}
_SPEED_KEY = {"xai": "speed", "edge": "speed"}

ELEVENLABS_BASE_URL = "https://api.elevenlabs.io"
DIALOGUE_MODEL = "eleven_v3"
DIALOGUE_MAX_CHARS = 1900  # ElevenLabs asks for at most 2,000 per request

LineSynth = Callable[[str, str, str, Optional[float], str, Dict[str, Any]], None]


def line_config(tts_config: Dict[str, Any], engine: str, voice: str, speed: Optional[float]) -> Dict[str, Any]:
    """A copy of the tts config with ``engine`` set to speak in ``voice``."""
    cfg = copy.deepcopy(tts_config) if isinstance(tts_config, dict) else {}
    section = cfg.get(engine)
    if not isinstance(section, dict):
        section = {}
    section = dict(section)
    if voice:
        section[_VOICE_KEY[engine]] = voice
    if speed is not None and engine in _SPEED_KEY:
        section[_SPEED_KEY[engine]] = speed
    cfg[engine] = section
    cfg["provider"] = engine
    return cfg


def hermes_line_synth(engine: str, text: str, voice: str, speed: Optional[float], out_path: str,
                      tts_config: Dict[str, Any]) -> None:
    """Speak one line with Hermes's built-in engine. These are Hermes
    internals: checked against Hermes 0.22.6 and 0.23.4 (see HERMES_VERSION)."""
    from tools import tts_tool  # imported lazily: only inside a running Hermes

    selected, error = tts_tool._select_builtin_engine(engine)
    if error:
        raise RuntimeError(f"Voice engine '{engine}' isn't ready: {error}")
    tts_tool._synthesize_builtin(selected, text, out_path, line_config(tts_config, engine, voice, speed), None)
    if not os.path.isfile(out_path) or os.path.getsize(out_path) == 0:
        raise RuntimeError(f"Voice engine '{engine}' wrote no audio")


def _env(key: str) -> str:
    try:
        from hermes_cli.config import get_env_value  # public Hermes API
        value = get_env_value(key)
    except Exception:
        value = None
    return (value or os.environ.get(key) or "").strip()


def elevenlabs_dialogue(lines: List[Tuple[str, str]], voices: Dict[str, str], out_path: str,
                        tts_config: Dict[str, Any], *, opener: Callable[..., Any] = urllib.request.urlopen,
                        timeout: float = 90.0) -> None:
    """One ElevenLabs Text to Dialogue request (``eleven_v3``) for these lines."""
    api_key = _env("ELEVENLABS_API_KEY")
    if not api_key:
        raise RuntimeError("ELEVENLABS_API_KEY is not set")
    el_cfg = tts_config.get("elevenlabs") if isinstance(tts_config.get("elevenlabs"), dict) else {}
    base = str(el_cfg.get("base_url") or ELEVENLABS_BASE_URL).rstrip("/")
    payload = {
        "inputs": [{"text": words, "voice_id": voices[speaker]} for speaker, words in lines],
        "model_id": str((tts_config.get("twins") or {}).get("dialogue_model") or DIALOGUE_MODEL),
    }
    request = urllib.request.Request(
        f"{base}/v1/text-to-dialogue?output_format=mp3_44100_128",
        data=json.dumps(payload).encode("utf-8"),
        headers={"xi-api-key": api_key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
        method="POST",
    )
    try:
        with opener(request, timeout=timeout) as response:
            audio = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read(300).decode("utf-8", "replace") if hasattr(exc, "read") else ""
        raise RuntimeError(f"ElevenLabs dialogue failed ({exc.code}): {detail}") from exc
    if not audio:
        raise RuntimeError("ElevenLabs dialogue returned no audio")
    with open(out_path, "wb") as handle:
        handle.write(audio)


def join_audio(parts: List[str], out_path: str) -> str:
    """Join MP3 parts into ``out_path``. With ffmpeg, an ``.ogg`` path gets
    real Ogg/Opus (a Telegram voice bubble); without it, MP3 frames are joined
    byte for byte and an ``.ogg`` path is renamed to ``.mp3`` so it's honest.
    Returns the path written."""
    if not parts:
        raise RuntimeError("nothing to join")
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as listing:
            for part in parts:
                listing.write("file '{}'\n".format(part.replace("'", "'\\''")))
            list_path = listing.name
        try:
            codec = (["-c:a", "libopus", "-b:a", "48k"] if out_path.endswith(".ogg")
                     else ["-c:a", "libmp3lame", "-b:a", "128k"] if out_path.endswith(".mp3")
                     else [])
            cmd = [ffmpeg, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", list_path,
                   *codec, out_path]
            result = subprocess.run(cmd, capture_output=True, timeout=120)
            if result.returncode == 0 and os.path.getsize(out_path) > 0:
                return out_path
            logger.warning("ffmpeg join failed (%s); joining bytes instead",
                           result.stderr.decode("utf-8", "replace")[:200])
        finally:
            os.unlink(list_path)
    if out_path.endswith(".ogg"):
        out_path = out_path[:-4] + ".mp3"
    with open(out_path, "wb") as handle:
        for part in parts:
            with open(part, "rb") as src:
                handle.write(src.read())
    return out_path


def render(lines: List[Tuple[str, str]], out_path: str, *, engine: str, voices: Dict[str, str],
           speeds: Dict[str, Optional[float]], tts_config: Dict[str, Any], dialogue: bool,
           line_synth: LineSynth = hermes_line_synth,
           dialogue_synth: Callable[..., None] = elevenlabs_dialogue) -> str:
    """Speak every line in its speaker's voice and join them into ``out_path``.
    Returns the path written (its extension may change to match the audio)."""
    if engine not in ENGINES:
        raise ValueError(f"tts.twins.engine must be one of {', '.join(ENGINES)}, not '{engine}'")
    with tempfile.TemporaryDirectory(prefix="twin-voices-") as work:
        parts: List[str] = []
        if engine == "elevenlabs" and dialogue and len({s for s, _ in lines}) > 1:
            try:
                for i, batch in enumerate(batch_lines(lines, DIALOGUE_MAX_CHARS)):
                    part = os.path.join(work, f"dialogue_{i:03d}.mp3")
                    dialogue_synth(batch, voices, part, tts_config)
                    parts.append(part)
            except Exception as exc:  # fall back to one request per line
                logger.warning("ElevenLabs dialogue unavailable (%s); speaking line by line", exc)
                parts = []
        if not parts:
            for i, (speaker, words) in enumerate(lines):
                part = os.path.join(work, f"line_{i:03d}_{speaker}.mp3")
                line_synth(engine, words, voices[speaker], speeds.get(speaker), part, tts_config)
                parts.append(part)
        if len(parts) == 1 and out_path.endswith(".mp3"):
            shutil.copyfile(parts[0], out_path)
            return out_path
        return join_audio(parts, out_path)  # also converts a lone part to .ogg or another format
