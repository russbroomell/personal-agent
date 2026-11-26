"""council-voices: one assistant, many speaking voices.

A Hermes text-to-speech provider named ``council``. The assistant writes
replies where each line starts with a member's tag ("Newton: ...",
"Māui: ...", "Marcus: ..."). This provider speaks each line in that member's
voice and hands Hermes one audio file, which Telegram shows as a single
voice bubble.

Turn it on (the council skill's build-soul.sh does this):

    hermes -p council plugins enable council-voices
    hermes -p council config set tts.provider council

Settings live under ``tts.council`` in config.yaml (``tts.twins`` from the
older two-voice plugin is still read):

    engine: xai | edge | elevenlabs      which Hermes engine speaks
    speakers: [marcus, newton, ...]      who can speak (first = lead if no lead)
    lead: marcus                         speaks untagged text and "All:" lines
    labels: {"māui": maui}               extra tag words -> speaker
    voices: {newton: {xai: sal, xai_speed: 1.05, edge: ..., elevenlabs: ...}}
    elevenlabs_dialogue: true            one dialogue request instead of one per line
    sticky_seconds: 8                    live voice: untagged sentence keeps last speaker
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

logger = logging.getLogger("plugins.council-voices")

PROVIDER_NAME = "council"

# Fallback voices if config.yaml has none (normally build-soul.sh writes them
# from members/voices.conf). Members missing here use the lead's voice.
DEFAULT_VOICES: Dict[str, Dict[str, Any]] = {
    "marcus": {"xai": "leo", "xai_speed": 0.9, "edge": "en-GB-RyanNeural", "edge_speed": 0.95,
               "elevenlabs": "JBFqnCBsd6RMkjVDRZzb"},
    "romulus": {"xai": "sal", "xai_speed": 0.95, "edge": "en-US-ChristopherNeural", "edge_speed": 1.0,
                "elevenlabs": "pNInz6obpgDQGcFmaJgB"},
    "remus": {"xai": "rex", "xai_speed": 1.1, "edge": "en-US-EricNeural", "edge_speed": 1.08,
              "elevenlabs": "ErXwobaYiN019PkySvjV"},
}


def _load_tts_config() -> Dict[str, Any]:
    try:
        from hermes_cli.config import load_config  # public Hermes API
        tts = (load_config() or {}).get("tts")
    except Exception:
        logger.debug("council-voices: couldn't read config", exc_info=True)
        tts = None
    return tts if isinstance(tts, dict) else {}


def _section(tts_config: Dict[str, Any]) -> Dict[str, Any]:
    for key in ("council", "twins"):
        value = tts_config.get(key)
        if isinstance(value, dict) and value:
            return value
    return {}


def _float(value: Any) -> Optional[float]:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


class CouncilVoicesProvider(TTSProvider):
    """Speaks a tagged multi-speaker reply with one voice per speaker."""

    def __init__(self) -> None:
        self._memory = speakers.SpeakerMemory()

    @property
    def name(self) -> str:
        return PROVIDER_NAME

    @property
    def display_name(self) -> str:
        return "Council voices (a voice per member, one reply)"

    @property
    def voice_compatible(self) -> bool:
        return True  # Hermes turns our audio into a Telegram voice bubble

    def is_available(self) -> bool:
        engine = str(_section(_load_tts_config()).get("engine", "edge")).lower()
        if engine == "elevenlabs":
            return bool(engines._env("ELEVENLABS_API_KEY"))
        return engine in engines.ENGINES

    def list_voices(self) -> list[dict[str, Any]]:
        cfg = _section(_load_tts_config())
        names = cfg.get("speakers") or list(cfg.get("voices") or DEFAULT_VOICES)
        return [{"id": str(n), "display": str(n).title()} for n in names]

    def get_setup_schema(self) -> dict[str, Any]:
        return {"name": self.display_name, "badge": "plugin", "tag": "A voice per council member",
                "env_vars": []}

    # --- the work ---------------------------------------------------------

    def settings(self, tts_config: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Resolve ``tts.council`` into engine, cast, voices and speeds."""
        tts_config = tts_config if tts_config is not None else _load_tts_config()
        council = _section(tts_config)
        engine = str(council.get("engine") or "edge").strip().lower()
        configured = council.get("voices") if isinstance(council.get("voices"), dict) else {}
        names = [str(n).strip().lower() for n in (council.get("speakers") or list(configured) or list(DEFAULT_VOICES))]
        names = [n for n in names if n]
        lead = str(council.get("lead") or names[0]).strip().lower()
        if lead not in names:
            names.insert(0, lead)

        def voice_for(who: str) -> tuple[Optional[str], Optional[float]]:
            mine = configured.get(who) if isinstance(configured.get(who), dict) else {}
            fallback = DEFAULT_VOICES.get(who, {})
            voice = mine.get(engine) or fallback.get(engine)
            speed = _float(mine.get(f"{engine}_speed", fallback.get(f"{engine}_speed")))
            return (str(voice) if voice else None), speed

        voices: Dict[str, str] = {}
        speeds: Dict[str, Optional[float]] = {}
        lead_voice, lead_speed = voice_for(lead)
        if not lead_voice:
            raise ValueError(f"No {engine} voice set for the lead '{lead}': set tts.council.voices.{lead}.{engine}")
        for who in names:
            voice, speed = voice_for(who)
            if not voice:
                logger.warning("council-voices: no %s voice for '%s'; using %s's", engine, who, lead)
                voice, speed = lead_voice, lead_speed
            voices[who] = voice
            speeds[who] = speed
        labels = council.get("labels") if isinstance(council.get("labels"), dict) else {}
        cast = speakers.Cast(speakers=tuple(names), lead=lead,
                             labels={str(k): str(v) for k, v in labels.items()})
        sticky = _float(council.get("sticky_seconds"))
        if sticky is not None:
            self._memory.sticky_seconds = sticky
        return {"engine": engine, "cast": cast, "voices": voices, "speeds": speeds,
                "dialogue": bool(council.get("elevenlabs_dialogue", True)), "tts_config": tts_config}

    def synthesize(self, text: str, output_path: str, *, voice: Optional[str] = None,
                   model: Optional[str] = None, speed: Optional[float] = None, format: str = "mp3",
                   **extra: Any) -> str:
        # ``voice``/``model``/``speed`` (tts.voice etc.) are ignored: each member has their own.
        s = self.settings()
        lines = self._memory.split(text, s["cast"])
        if not lines:
            raise ValueError("Nothing to say")
        os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)
        logger.info("council-voices: %d line(s) via %s", len(lines), s["engine"])
        return engines.render(lines, output_path, engine=s["engine"], voices=s["voices"],
                              speeds=s["speeds"], tts_config=s["tts_config"], dialogue=s["dialogue"])


def register(ctx) -> None:
    ctx.register_tts_provider(CouncilVoicesProvider())
