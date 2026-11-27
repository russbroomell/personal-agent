"""council-privacy: one council, many Discord users, each with a private DM.

On Discord, every person gets their own private folder and first-time setup
in their DM, and nothing from a DM shows up in a public channel unless that
person asks, in that message, to share their own information. Other
platforms (Telegram, the terminal, the workspace) are unchanged: there the
council works for its one owner.

How: two Hermes plugin hooks.
- ``pre_llm_call`` adds a short block to each turn: in a DM, that person's
  folder and profile (or the first-session instruction); in a public room,
  the public-room rules.
- ``pre_tool_call`` blocks, in code, the tool calls that would cross people:
  another person's folder, a search across everyone's notes, chat-history
  search, shared core-memory writes, and reading Hermes's session database.

Where a turn is happening (DM or not, which user) comes from Hermes's own
session store, read-only. Anything it can't identify is treated as public.
The rules live in policy.py.
"""

from __future__ import annotations

import logging
import os
import sqlite3
import threading
from typing import Any, Dict, Optional, Tuple

try:
    from . import policy
except ImportError:  # pragma: no cover - direct import from the folder
    import policy  # type: ignore[no-redef]

logger = logging.getLogger("plugins.council-privacy")

_cache: Dict[str, Tuple[str, str, str, str]] = {}
# Where each conversation is, as seen at the start of its turn; tool calls in
# the same session (or its subagents) reuse it, so they can't fail open.
_known: Dict[str, "policy.Session"] = {}
_lock = threading.Lock()


def _hermes_home() -> str:
    try:
        from hermes_constants import get_hermes_home  # public Hermes helper
        return str(get_hermes_home())
    except Exception:
        return os.environ.get("HERMES_HOME") or os.path.expanduser("~/.hermes")


def _notes_dir(home: str) -> str:
    return os.path.join(home, "notes")


def _lookup(session_id: str, home: str) -> Tuple[str, str, str, str]:
    """(platform, chat_type, user_id, root session id) for a session,
    following subagents to their root conversation. Empty strings if unknown."""
    if not session_id:
        return ("", "", "", "")
    with _lock:
        if session_id in _cache:
            return _cache[session_id]
    found = ("", "", "", session_id)
    db = os.path.join(home, "state.db")
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)
        try:
            sid = session_id
            for _ in range(6):  # a subagent's parent, and so on, up to the conversation
                row = con.execute("SELECT source, chat_type, user_id, parent_session_id FROM sessions WHERE id = ?",
                                  (sid,)).fetchone()
                if not row:
                    found = ("", "", "", sid)
                    break
                source, chat_type, user_id, parent = (str(v) if v is not None else "" for v in row)
                if source in ("subagent", "delegate") and parent:
                    sid = parent
                    continue
                found = (source.lower(), chat_type.lower(), user_id, sid)
                break
            else:
                found = ("", "", "", sid)
        finally:
            con.close()
    except Exception:
        logger.debug("council-privacy: session lookup failed for %s", session_id, exc_info=True)
    if found[0]:
        with _lock:
            _cache[session_id] = found
    return found


def _session(session_id: str, platform_hint: str = "", sender_id: str = "") -> Optional[policy.Session]:
    with _lock:
        if session_id in _known:
            return _known[session_id]
    home = _hermes_home()
    platform, chat_type, user_id, root = _lookup(session_id, home)
    if root and root != session_id:
        with _lock:
            if root in _known:
                return _known[root]
    platform = platform or (platform_hint or "").lower()
    if platform not in policy.PRIVATE_PLATFORMS:
        return None
    user_id = user_id or sender_id or ""
    kind = policy.classify(chat_type)
    if kind == "dm" and not user_id:
        kind = "public"  # a DM we can't attribute to a person is treated as public
    return policy.Session(platform=platform, kind=kind, user_id=user_id)


def on_pre_llm_call(session_id: str = "", platform: str = "", sender_id: str = "", **_: Any):
    try:
        session = _session(session_id, platform, sender_id)
        if session is None:
            return None
        with _lock:
            _known[session_id] = session
        home = _hermes_home()
        notes = _notes_dir(home)
        if session.kind == "dm":
            os.makedirs(policy.person_dir(notes, session.platform, session.user_id), exist_ok=True)
        text = policy.turn_context(session, notes)
        return {"context": text} if text else None
    except Exception:
        logger.warning("council-privacy: couldn't build turn context", exc_info=True)
        # Fail closed: when in doubt, the public-room rules.
        return {"context": policy.turn_context(policy.Session("discord", "public", sender_id or "unknown"), "")}


def on_pre_tool_call(tool_name: str = "", args: Optional[Dict[str, Any]] = None, task_id: str = "",
                     session_id: str = "", **_: Any):
    sid = session_id or task_id
    home = _hermes_home()
    session = _session(sid)
    if session is None:
        return None
    reason = policy.tool_decision(tool_name, args, session, _notes_dir(home), home, cwd=os.getcwd())
    if reason:
        logger.info("council-privacy: blocked %s in a Discord %s", tool_name, session.kind)
        return {"action": "block", "message": reason}
    return None


def register(ctx) -> None:
    ctx.register_hook("pre_llm_call", on_pre_llm_call)
    ctx.register_hook("pre_tool_call", on_pre_tool_call)
