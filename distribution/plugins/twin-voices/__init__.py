"""twin-voices: one assistant, two speaking voices.

A Hermes text-to-speech provider named ``twins``. The assistant writes replies
where each line starts with a speaker's name ("Romulus: ...", "Remus: ...",
"Both: ..."). This provider speaks each line in that speaker's voice and hands
Hermes one audio file, which Telegram shows as a single voice bubble.

Turn it on (build-soul.sh does this when you pick a two-speaker character):

    hermes -p sidekick plugins enable twin-voices
    hermes -p sidekick config set tts.provider twins

Settings live under ``tts.twins`` in config.yaml; see README.md in this folder.
"""

from __future__ import annotations

import logging
import os
from typing import Any, Dict, Optional

from agent.tts_provider import TTSProvider  # public Hermes plugin API

try:
    from . import engines, speakers
except ImportError:  # pragma: no cover - direct import from the folder
    import engines  # type: ignore[no-redef]
    import speakers  # type: ignore[no-redef]

logger = logging.getLogger("plugins.twin-voices")

PROVIDER_NAME = "twins"

# Used when config.yaml doesn't say otherwise. Edge voices are free; the xAI
# ones are Grok voices; the ElevenLabs ones are its stock "Adam" and "Antoni".
DEFAULT_VOICES: Dict[str, Dict[str, Any]] = {
    "romulus": {"xai": "sal", "xai_speed": 0.95, "edge": "en-US-ChristopherNeural",
                "edge_speed": 1.0, "elevenlabs": "pNInz6obpgDQGcFmaJgB"},
    "remus": {"xai": "rex", "xai_speed": 1.08, "edge": "en-US-EricNeural",
              "edge_speed": 1.05, "elevenlabs": "ErXwobaYiN019PkySvjV"},
}


def _load_tts_config() -> Dict[str, Any]:
    try:
        from hermes_cli.config import load_config  # public Hermes API
        tts = (load_config() or {}).get("tts")
    except Exception:
        logger.debug("twin-voices: couldn't read config", exc_info=True)
        tts = None
    return tts if isinstance(tts, dict) else {}


def _float(value: Any) -> Optional[float]:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


class TwinVoicesProvider(TTSProvider):
    """Speaks a tagged multi-speaker reply with one voice per speaker."""

    def __init__(self) -> None:
        self._memory = speakers.SpeakerMemory()

    @property
    def name(self) -> str:
        return PROVIDER_NAME

    @property
    def display_name(self) -> str:
        return "Twin voices (two speakers, one reply)"

    @property
    def voice_compatible(self) -> bool:
        return True  # Hermes turns our audio into a Telegram voice bubble

    def is_available(self) -> bool:
        engine = str(_load_tts_config().get("twins", {}).get("engine", "edge")).lower()
        if engine == "elevenlabs":
            return bool(engines._env("ELEVENLABS_API_KEY"))
        return engine in engines.ENGINES

    def list_voices(self) -> list[dict[str, Any]]:
        return [{"id": "romulus", "display": "Romulus (lead)"}, {"id": "remus", "display": "Remus"}]

    def get_setup_schema(self) -> dict[str, Any]:
        return {"name": self.display_name, "badge": "plugin", "tag": "Two voices in one reply",
                "env_vars": []}

    # --- the work ---------------------------------------------------------

    def settings(self, tts_config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Resolve ``tts.twins`` into engine, cast, voices and speeds."""
        tts_config = tts_config if tts_config is not None else _load_tts_config()
        twins = tts_config.get("twins") if isinstance(tts_config.get("twins"), dict) else {}
        engine = str(twins.get("engine") or "edge").strip().lower()
        configured = twins.get("voices") if isinstance(twins.get("voices"), dict) else {}
        names = [str(n).strip().lower() for n in (twins.get("speakers") or list(configured) or list(DEFAULT_VOICES))]
        voices: Dict[str, str] = {}
        speeds: Dict[str, Optional[float]] = {}
        for who in names:
            mine = configured.get(who) if isinstance(configured.get(who), dict) else {}
            fallback = DEFAULT_VOICES.get(who, {})
            voice = mine.get(engine) or fallback.get(engine)
            if not voice:
                raise ValueError(f"No {engine} voice set for '{who}': set tts.twins.voices.{who}.{engine}")
            voices[who] = str(voice)
            speeds[who] = _float(mine.get(f"{engine}_speed", fallback.get(f"{engine}_speed")))
        cast = speakers.Cast(speakers=tuple(names), lead=str(twins.get("lead") or names[0]),
                             labels={str(k): str(v) for k, v in (twins.get("labels") or {}).items()})
        sticky = _float(twins.get("sticky_seconds"))
        if sticky is not None:
            self._memory.sticky_seconds = sticky
        return {"engine": engine, "cast": cast, "voices": voices, "speeds": speeds,
                "dialogue": bool(twins.get("elevenlabs_dialogue", True)), "tts_config": tts_config}

    def synthesize(self, text: str, output_path: str, *, voice: Optional[str] = None,
                   model: Optional[str] = None, speed: Optional[float] = None, format: str = "mp3",
                   **extra: Any) -> str:
        # ``voice``/``model``/``speed`` (tts.voice etc.) are ignored: each speaker has their own.
        s = self.settings()
        lines = self._memory.split(text, s["cast"])
        if not lines:
            raise ValueError("Nothing to say")
        os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)
        logger.info("twin-voices: %d line(s) via %s", len(lines), s["engine"])
        return engines.render(lines, output_path, engine=s["engine"], voices=s["voices"],
                              speeds=s["speeds"], tts_config=s["tts_config"], dialogue=s["dialogue"])


def register(ctx) -> None:
    ctx.register_tts_provider(TwinVoicesProvider())
