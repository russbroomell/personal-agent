"""Unit tests for the council-privacy plugin. No Hermes or network needed.

Run: python3 tests/council_privacy/test_council_privacy.py
"""

import importlib.util
import os
import sqlite3
import sys
import tempfile
import types
import unittest

sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.abspath(os.path.join(HERE, "..", "..", "distribution", "plugins", "council-privacy"))
sys.path.insert(0, PLUGIN)

import policy  # noqa: E402

ALICE, BOB = "111111111111111111", "222222222222222222"


def dm(user=ALICE):
    return policy.Session("discord", "dm", user)


def public(user=ALICE):
    return policy.Session("discord", "public", user)


class ClassifyTests(unittest.TestCase):
    def test_only_dm_is_private(self):
        self.assertEqual(policy.classify("dm"), "dm")
        for other in ("group", "thread", "forum", "", None, "DMish"):
            self.assertEqual(policy.classify(other), "public")

    def test_slug_is_safe(self):
        self.assertEqual(policy.person_slug("discord", "12/../34"), "discord-1234")
        self.assertEqual(policy.person_slug("discord", ""), "")


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.notes = os.path.join(self.tmp, "notes")

    def test_first_dm_runs_setup_in_their_folder(self):
        text = policy.turn_context(dm(), self.notes, profile_text="")
        self.assertIn("first-session skill now, in personal mode", text)
        self.assertIn(f"people/discord-{ALICE}/profile.md", text)
        self.assertNotIn(BOB, text)

    def test_returning_dm_gets_their_profile(self):
        text = policy.turn_context(dm(), self.notes, profile_text="Name: Alice\nFirst session: done 2026-11-27")
        self.assertIn("Name: Alice", text)
        self.assertNotIn("first-session skill now", text)

    def test_long_profile_is_truncated(self):
        text = policy.turn_context(dm(), self.notes, profile_text="First session: done\n" + "x" * 9000)
        self.assertIn("truncated", text)
        self.assertLess(len(text), policy.MAX_PROFILE_CHARS + 2000)

    def test_public_room_rules(self):
        text = policy.turn_context(public(), self.notes)
        self.assertIn("Public room", text)
        self.assertIn("unless the speaker asks in this message to share their own information", text)
        self.assertIn("Don't run the first-session interview here", text)

    def test_other_platforms_untouched(self):
        self.assertEqual(policy.turn_context(policy.Session("telegram", "dm", ALICE), self.notes), "")


class ToolTests(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.notes = os.path.join(self.home, "notes")
        self.alice = policy.person_dir(self.notes, "discord", ALICE)
        self.bob = policy.person_dir(self.notes, "discord", BOB)
        for d in (self.alice, self.bob):
            os.makedirs(d)

    def decide(self, tool, args, session=None):
        return policy.tool_decision(tool, args, session or dm(), self.notes, self.home, cwd=self.home)

    def test_own_folder_allowed_dm_and_public(self):
        for s in (dm(), public()):
            self.assertIsNone(self.decide("read_file", {"path": f"{self.alice}/profile.md"}, s))
            self.assertIsNone(self.decide("write_file", {"path": f"{self.alice}/money.md"}, s))

    def test_other_persons_folder_blocked(self):
        for s in (dm(), public()):
            self.assertIsNotNone(self.decide("read_file", {"path": f"{self.bob}/profile.md"}, s))
            self.assertIsNotNone(self.decide("patch", {"path": f"{self.bob}/profile.md"}, s))

    def test_relative_and_dotdot_paths(self):
        self.assertIsNotNone(self.decide("read_file", {"path": f"notes/people/discord-{BOB}/profile.md"}))
        sneaky = os.path.join(self.alice, "..", f"discord-{BOB}", "profile.md")
        self.assertIsNotNone(self.decide("read_file", {"path": sneaky}))

    def test_symlink_into_another_folder_blocked(self):
        link = os.path.join(self.alice, "peek")
        os.symlink(self.bob, link)
        self.assertIsNotNone(self.decide("read_file", {"path": os.path.join(link, "profile.md")}))

    def test_search_across_everyone_blocked_but_own_ok(self):
        self.assertIsNotNone(self.decide("search_files", {"path": self.notes}))
        self.assertIsNotNone(self.decide("search_files", {"path": self.home}))
        self.assertIsNone(self.decide("search_files", {"path": self.alice}))

    def test_shared_notes_file_ok(self):
        self.assertIsNone(self.decide("read_file", {"path": os.path.join(self.notes, "council.md")}))

    def test_cross_person_stores_off(self):
        self.assertIsNotNone(self.decide("session_search", {"query": "Bob"}))
        self.assertIsNotNone(self.decide("memory", {"action": "add", "target": "user", "content": "x"}))
        self.assertIsNotNone(self.decide("read_file", {"path": os.path.join(self.home, "state.db")}))
        self.assertIsNotNone(self.decide("terminal", {"command": "sqlite3 ~/.hermes/state.db 'select * from messages'"}))

    def test_commands(self):
        self.assertIsNone(self.decide("terminal", {"command": f"ls notes/people/discord-{ALICE}/"}))
        self.assertIsNotNone(self.decide("terminal", {"command": f"cat notes/people/discord-{BOB}/profile.md"}))
        self.assertIsNotNone(self.decide("terminal", {"command": "grep -r Bob notes/people/"}))
        self.assertIsNotNone(self.decide("terminal", {"command": "cat notes/people/*/profile.md"}))
        self.assertIsNone(self.decide("terminal", {"command": "date"}))

    def test_other_platforms_untouched(self):
        tg = policy.Session("telegram", "dm", ALICE)
        self.assertIsNone(self.decide("session_search", {"query": "x"}, tg))
        self.assertIsNone(self.decide("read_file", {"path": f"{self.bob}/profile.md"}, tg))


class HookTests(unittest.TestCase):
    """The plugin's hooks against a real (temporary) session database."""

    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("council_privacy_init", os.path.join(PLUGIN, "__init__.py"))
        cls.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.mod)

    def setUp(self):
        self.home = tempfile.mkdtemp()
        os.environ["HERMES_HOME"] = self.home
        sys.modules.pop("hermes_constants", None)
        con = sqlite3.connect(os.path.join(self.home, "state.db"))
        con.execute("CREATE TABLE sessions (id TEXT PRIMARY KEY, source TEXT, chat_type TEXT, user_id TEXT, "
                    "parent_session_id TEXT)")
        con.executemany("INSERT INTO sessions VALUES (?,?,?,?,?)", [
            ("s-dm-alice", "discord", "dm", ALICE, None),
            ("s-pub-alice", "discord", "group", ALICE, None),
            ("s-child", "subagent", "", "", "s-dm-alice"),
            ("s-tg", "telegram", "dm", "42", None),
        ])
        con.commit()
        con.close()
        self.mod._cache.clear()
        self.mod._known.clear()

    def test_dm_turn_creates_folder_and_starts_setup(self):
        out = self.mod.on_pre_llm_call(session_id="s-dm-alice", platform="discord", sender_id=ALICE)
        self.assertIn("first-session skill now", out["context"])
        self.assertTrue(os.path.isdir(os.path.join(self.home, "notes", "people", f"discord-{ALICE}")))

    def test_public_turn(self):
        out = self.mod.on_pre_llm_call(session_id="s-pub-alice", platform="discord", sender_id=ALICE)
        self.assertIn("Public room", out["context"])

    def test_unknown_discord_session_is_public(self):
        out = self.mod.on_pre_llm_call(session_id="nope", platform="discord", sender_id=ALICE)
        self.assertIn("Public room", out["context"])

    def test_telegram_untouched(self):
        self.assertIsNone(self.mod.on_pre_llm_call(session_id="s-tg", platform="telegram", sender_id="42"))
        self.assertIsNone(self.mod.on_pre_tool_call(tool_name="session_search", args={}, session_id="s-tg"))

    def test_tool_block_and_subagent_inherits(self):
        self.mod.on_pre_llm_call(session_id="s-dm-alice", platform="discord", sender_id=ALICE)
        bob = os.path.join(self.home, "notes", "people", f"discord-{BOB}", "profile.md")
        out = self.mod.on_pre_tool_call(tool_name="read_file", args={"path": bob}, session_id="s-child")
        self.assertEqual(out["action"], "block")
        out = self.mod.on_pre_tool_call(tool_name="session_search", args={}, task_id="s-dm-alice")
        self.assertEqual(out["action"], "block")

    def test_tool_call_without_prior_turn_uses_database(self):
        out = self.mod.on_pre_tool_call(tool_name="memory", args={"action": "add"}, session_id="s-pub-alice")
        self.assertEqual(out["action"], "block")


if __name__ == "__main__":
    unittest.main(verbosity=1)
