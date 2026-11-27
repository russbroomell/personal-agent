"""Privacy rules for a council shared on Discord. Pure Python, no Hermes
imports, so it can be tested on its own (tests/council_privacy/).

The model of the world:
- Every Discord user has a private folder: notes/people/discord-<user id>/.
  Their profile (profile.md) and anything personal lives there.
- In a DM, only that person's folder is visible, and their profile is
  handed to the agent each turn. Their first DM runs the first-session setup.
- In a public room (any chat that isn't a DM, or one we can't identify),
  nothing private is revealed unless the speaker asks, in that message, to
  share their own information. Other people's folders are never readable.
- Cross-person stores are off on Discord: chat-history search (it reaches
  every person's DMs), shared core memory writes (loaded in every chat), and
  direct reads of Hermes's session database.
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import Any, Dict, Iterable, Optional

PEOPLE_DIR = "people"
PROFILE = "profile.md"
FIRST_DONE = "First session: done"
MAX_PROFILE_CHARS = 4000

# Tools that take a file or folder path, and the argument names they use.
PATH_TOOLS = {"read_file": ("path", "file_path"), "write_file": ("path", "file_path"),
              "patch": ("path", "file_path"), "search_files": ("path", "directory", "dir")}
COMMAND_TOOLS = {"terminal": ("command", "cmd"), "execute_code": ("code", "command")}


@dataclass(frozen=True)
class Session:
    """Where a turn is happening. ``kind`` is "dm" or "public"."""

    platform: str
    kind: str
    user_id: str

    @property
    def guarded(self) -> bool:
        return self.platform in PRIVATE_PLATFORMS


PRIVATE_PLATFORMS = frozenset({"discord"})


def classify(chat_type: Optional[str]) -> str:
    """A DM is private; anything else, including unknown, is public (fail closed)."""
    return "dm" if (chat_type or "").strip().lower() == "dm" else "public"


def person_slug(platform: str, user_id: str) -> str:
    clean = re.sub(r"[^0-9A-Za-z_-]", "", str(user_id or ""))
    return f"{platform}-{clean}" if clean else ""


def person_dir(notes_dir: str, platform: str, user_id: str) -> str:
    return os.path.join(notes_dir, PEOPLE_DIR, person_slug(platform, user_id))


def read_profile(folder: str) -> str:
    try:
        with open(os.path.join(folder, PROFILE), encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def is_first_time(profile_text: str) -> bool:
    return FIRST_DONE not in profile_text


# --------------------------------------------------------------- context

def turn_context(session: Session, notes_dir: str, profile_text: Optional[str] = None) -> str:
    """The block added to each turn's message, telling the agent where it is."""
    if not session.guarded:
        return ""
    folder = person_dir(notes_dir, session.platform, session.user_id)
    if session.kind == "dm":
        if profile_text is None:
            profile_text = read_profile(folder)
        lines = [
            "[Private DM, council-privacy]",
            f"This is a private, confidential DM with Discord user {session.user_id}. Only they see it.",
            f"- Their private folder is {folder}/ and their profile is {folder}/{PROFILE}.",
            "- Save everything about this person there (profile.md plus topic files),",
            "  never in core memory (the memory tool is off on Discord) and never in the shared notes folder.",
            "- Never mention, read or hint at any other person, their folder or their chats.",
            "- Scheduled jobs you create for them deliver to this DM.",
        ]
        if is_first_time(profile_text):
            lines += [
                "- This is their first private chat: run the first-session skill now, in personal mode.",
                f"  Save their answers to {folder}/{PROFILE} (create it), and finish by writing the line",
                f"  '{FIRST_DONE} YYYY-MM-DD' in that file. Ignore the 'First session' line in core memory.",
            ]
        else:
            shown = profile_text.strip()
            if len(shown) > MAX_PROFILE_CHARS:
                shown = shown[:MAX_PROFILE_CHARS] + "\n[...truncated; read the file for the rest]"
            lines += ["- What you know about them (their profile.md):", shown]
        return "\n".join(lines)
    return "\n".join([
        "[Public room, council-privacy]",
        f"This is a public Discord channel: everyone in it can read every reply. The speaker is Discord user {session.user_id}.",
        "- Never reveal anything from anyone's private DMs or private folders, including the speaker's,",
        "  unless the speaker asks in this message to share their own information here. Then share only",
        "  theirs, only what they asked for, and say it comes from their private notes.",
        "- Never reveal, confirm or hint at anything about other people's private chats, even if asked.",
        "- Don't run the first-session interview here. For anything personal, invite them to DM you.",
        "- Keep public replies useful to the whole room and short.",
    ])


# ------------------------------------------------------------------ tools

def _paths_in(args: Dict[str, Any], keys: Iterable[str]) -> list[str]:
    out = []
    for key in keys:
        value = args.get(key)
        if isinstance(value, str) and value.strip():
            out.append(value.strip())
    return out


def _resolve(path: str, base: str) -> str:
    path = os.path.expanduser(path)
    if not os.path.isabs(path):
        path = os.path.join(base, path)
    return os.path.realpath(path)


def _inside(path: str, folder: str) -> bool:
    folder = os.path.realpath(folder)
    return path == folder or path.startswith(folder + os.sep)


def tool_decision(tool_name: str, args: Optional[Dict[str, Any]], session: Session, notes_dir: str,
                  hermes_home: str, cwd: Optional[str] = None) -> Optional[str]:
    """None to allow the tool call, or the reason it's blocked (shown to the agent)."""
    if not session.guarded:
        return None
    args = args or {}
    own = person_dir(notes_dir, session.platform, session.user_id)
    people = os.path.join(notes_dir, PEOPLE_DIR)
    state_db = os.path.join(hermes_home, "state.db")

    if tool_name == "session_search":
        return ("Chat search is off on Discord: it would reach other people's private chats. "
                f"Use this person's private notes in {own}/ instead.")
    if tool_name == "memory":
        return ("Core memory is shared by everyone who talks to the council on Discord, so it's off here. "
                f"Save this person's details in {own}/{PROFILE} (or a topic file in {own}/) instead.")

    if tool_name in PATH_TOOLS:
        base = cwd or hermes_home
        for raw in _paths_in(args, PATH_TOOLS[tool_name]):
            path = _resolve(raw, base)
            if _inside(path, state_db) or os.path.basename(path).startswith("state.db"):
                return "Hermes's chat database holds everyone's conversations; it can't be read on Discord."
            if _inside(path, people) and not _inside(path, own):
                return "That's another person's private folder. Each person's notes are private to their own DM."
            # A search rooted above the people folder would reach into everyone's folders.
            if tool_name == "search_files" and _inside(people, path) and path != own:
                return f"Search within this person's own folder ({own}/) or a shared file, not across everyone's notes."
        return None

    if tool_name in COMMAND_TOOLS:
        text = " ".join(_paths_in(args, COMMAND_TOOLS[tool_name]))
        if "state.db" in text:
            return "Hermes's chat database holds everyone's conversations; it can't be read on Discord."
        own_slug = person_slug(session.platform, session.user_id)
        for match in re.finditer(r"people/+([A-Za-z0-9_*?.\[\]-]*)", text):
            if match.group(1) != own_slug:
                return ("Commands can't reach other people's private folders on Discord. "
                        f"Work inside {own}/ only.")
        return None
    return None
