"""Split a two-speaker reply into voiced lines.

Pure Python with no Hermes imports, so it can be tested on its own.

A reply looks like this (Hermes has already flattened line breaks into spaces
by the time it reaches the speech provider):

    Romulus: Book the 6pm table. Remus: Or 7:30 on the patio. Both: Your call?

A speaker tag counts only at the start of the text or right after the end of
a sentence, so "I told Remus: no" mid-sentence stays one line.
"""

from __future__ import annotations

import re
import threading
import time
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional, Tuple

# Characters that can end the text before a new speaker's tag.
_SENTENCE_END = ".!?…:;\"'”’)]"
_TAG_RE_CACHE: Dict[Tuple[str, ...], "re.Pattern[str]"] = {}


def _tag_re(labels: Tuple[str, ...]) -> "re.Pattern[str]":
    pattern = _TAG_RE_CACHE.get(labels)
    if pattern is None:
        names = "|".join(re.escape(label) for label in sorted(labels, key=len, reverse=True))
        # Optional leftover markdown around the name: **Romulus:** or *Romulus*:
        pattern = re.compile(rf"[*_]{{0,2}}\b({names})\b[*_]{{0,2}}\s*[:：][*_]{{0,2}}\s*", re.IGNORECASE)
        _TAG_RE_CACHE[labels] = pattern
    return pattern


@dataclass
class Cast:
    """Who can speak. ``labels`` maps a lower-case tag word to a speaker key;
    ``both_labels`` are tags spoken by the lead (for lines said together)."""

    speakers: Tuple[str, ...] = ("romulus", "remus")
    lead: str = "romulus"
    labels: Dict[str, str] = field(default_factory=dict)
    both_labels: Tuple[str, ...] = ("both", "together")

    def __post_init__(self) -> None:
        self.speakers = tuple(s.strip().lower() for s in self.speakers if s and s.strip())
        if not self.speakers:
            raise ValueError("at least one speaker is required")
        self.lead = (self.lead or self.speakers[0]).strip().lower()
        if self.lead not in self.speakers:
            self.lead = self.speakers[0]
        labels = {s: s for s in self.speakers}
        labels.update({k.strip().lower(): v.strip().lower() for k, v in self.labels.items() if v})
        self.labels = {k: v for k, v in labels.items() if v in self.speakers}
        self.both_labels = tuple(b.strip().lower() for b in self.both_labels)

    def tag_words(self) -> Tuple[str, ...]:
        return tuple(self.labels) + self.both_labels

    def speaker_for(self, word: str) -> str:
        word = word.strip().lower()
        if word in self.both_labels:
            return self.lead
        return self.labels.get(word, self.lead)


def split_lines(text: str, cast: Cast, first_speaker: Optional[str] = None) -> Tuple[List[Tuple[str, str]], bool]:
    """Return ``([(speaker, words), ...], starts_tagged)``.

    ``first_speaker`` voices any words before the first tag (the lead when
    None). Consecutive lines by the same speaker are merged, empty lines
    dropped, and the tags themselves are never spoken.
    """
    text = (text or "").strip()
    if not text:
        return [], False
    pattern = _tag_re(cast.tag_words())
    segments: List[Tuple[str, str]] = []
    current = (first_speaker or cast.lead).lower()
    if current not in cast.speakers:
        current = cast.lead
    pos = 0
    starts_tagged = False
    for match in pattern.finditer(text):
        before = text[: match.start()].rstrip()
        if before and before[-1] not in _SENTENCE_END:
            continue  # a name mid-sentence ("I told Remus: no"), not a new speaker
        chunk = text[pos: match.start()].strip()
        if chunk:
            segments.append((current, chunk))
        elif not segments and not before:
            starts_tagged = True
        current = cast.speaker_for(match.group(1))
        pos = match.end()
    tail = text[pos:].strip()
    if tail:
        segments.append((current, tail))
    merged: List[Tuple[str, str]] = []
    for speaker, words in segments:
        if merged and merged[-1][0] == speaker:
            merged[-1] = (speaker, f"{merged[-1][1]} {words}")
        else:
            merged.append((speaker, words))
    return merged, starts_tagged


class SpeakerMemory:
    """Carries the current speaker across calls.

    The desktop and CLI speak a reply one sentence at a time, so a sentence
    with no tag belongs to whoever spoke last, unless there has been a pause
    longer than ``sticky_seconds`` (a new reply), when it goes back to the lead.
    """

    def __init__(self, sticky_seconds: float = 8.0, clock: Callable[[], float] = time.monotonic) -> None:
        self.sticky_seconds = sticky_seconds
        self._clock = clock
        self._lock = threading.Lock()
        self._last_speaker: Optional[str] = None
        self._last_time: float = float("-inf")

    def split(self, text: str, cast: Cast) -> List[Tuple[str, str]]:
        with self._lock:
            now = self._clock()
            carry = (
                self._last_speaker
                if self._last_speaker and now - self._last_time <= self.sticky_seconds
                else None
            )
            lines, _ = split_lines(text, cast, first_speaker=carry)
            if lines:
                self._last_speaker = lines[-1][0]
            self._last_time = now
            return lines


def batch_lines(lines: List[Tuple[str, str]], max_chars: int) -> List[List[Tuple[str, str]]]:
    """Group lines into requests of at most ``max_chars`` characters, splitting
    an over-long line at sentence ends (or spaces) so no request is too big."""
    pieces: List[Tuple[str, str]] = []
    for speaker, words in lines:
        while len(words) > max_chars:
            cut = max(words.rfind(". ", 0, max_chars), words.rfind("? ", 0, max_chars),
                      words.rfind("! ", 0, max_chars))
            cut = cut + 1 if cut > 0 else words.rfind(" ", 0, max_chars)
            if cut <= 0:
                cut = max_chars
            pieces.append((speaker, words[:cut].strip()))
            words = words[cut:].strip()
        if words:
            pieces.append((speaker, words))
    batches: List[List[Tuple[str, str]]] = []
    size = 0
    for piece in pieces:
        if batches and size + len(piece[1]) <= max_chars:
            batches[-1].append(piece)
            size += len(piece[1])
        else:
            batches.append([piece])
            size = len(piece[1])
    return batches
