"""Unit tests for the council-voices plugin. No Hermes, network or ffmpeg needed.

Run: python3 tests/council_voices/test_council_voices.py
"""

import os
import sys
import tempfile
import types
import unittest

sys.dont_write_bytecode = True  # keep __pycache__ out of the shipped plugin folder

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = os.path.join(HERE, "..", "..", "distribution", "plugins", "council-voices")
sys.path.insert(0, os.path.abspath(PLUGIN))

import engines  # noqa: E402
import speakers  # noqa: E402

CAST = speakers.Cast(speakers=("romulus", "remus"), lead="romulus")  # the original twins
COUNCIL = speakers.Cast(speakers=("marcus", "newton", "maui", "sun-tzu", "remus"), lead="marcus",
                        labels={"māui": "maui", "sun tzu": "sun-tzu"})


class SplitTests(unittest.TestCase):
    def test_duet(self):
        lines, tagged = speakers.split_lines(
            "Romulus: Book the 6pm table. Remus: Or 7:30 on the patio. Both: Your call?", CAST)
        self.assertTrue(tagged)
        self.assertEqual(lines, [("romulus", "Book the 6pm table."),
                                 ("remus", "Or 7:30 on the patio."),
                                 ("romulus", "Your call?")])

    def test_untagged_is_lead(self):
        lines, tagged = speakers.split_lines("Done. Your 3pm is moved to Friday.", CAST)
        self.assertFalse(tagged)
        self.assertEqual(lines, [("romulus", "Done. Your 3pm is moved to Friday.")])

    def test_name_mid_sentence_is_not_a_tag(self):
        lines, _ = speakers.split_lines("Remus: I told Romulus: no way. Romulus: Fair.", CAST)
        self.assertEqual(lines, [("remus", "I told Romulus: no way."), ("romulus", "Fair.")])

    def test_markdown_leftovers_and_case(self):
        lines, _ = speakers.split_lines("**Remus:** hi. ROMULUS: hello.", CAST)
        self.assertEqual(lines, [("remus", "hi."), ("romulus", "hello.")])

    def test_same_speaker_merged(self):
        lines, _ = speakers.split_lines("Remus: one. Remus: two.", CAST)
        self.assertEqual(lines, [("remus", "one. two.")])

    def test_empty(self):
        self.assertEqual(speakers.split_lines("   ", CAST), ([], False))

    def test_custom_labels(self):
        cast = speakers.Cast(speakers=("romulus", "remus"), labels={"rom": "romulus"})
        lines, _ = speakers.split_lines("Rom: steady.", cast)
        self.assertEqual(lines, [("romulus", "steady.")])


class MemoryTests(unittest.TestCase):
    def test_sticky_then_resets(self):
        now = [0.0]
        mem = speakers.SpeakerMemory(sticky_seconds=8, clock=lambda: now[0])
        self.assertEqual(mem.split("Remus: Or the patio.", CAST), [("remus", "Or the patio.")])
        now[0] = 2
        self.assertEqual(mem.split("It's warmer tonight.", CAST), [("remus", "It's warmer tonight.")])
        now[0] = 20
        self.assertEqual(mem.split("New reply.", CAST), [("romulus", "New reply.")])


class BatchTests(unittest.TestCase):
    def test_batches_respect_limit(self):
        lines = [("romulus", "a" * 50), ("remus", "b" * 50), ("romulus", "c" * 50)]
        batches = speakers.batch_lines(lines, 120)
        self.assertEqual([len(b) for b in batches], [2, 1])

    def test_long_line_split_at_sentence(self):
        words = ("Sentence one is here. " * 10).strip()
        batches = speakers.batch_lines([("remus", words)], 60)
        for batch in batches:
            self.assertLessEqual(sum(len(w) for _, w in batch), 60)
        self.assertEqual(" ".join(w for b in batches for _, w in b), words)


class EngineTests(unittest.TestCase):
    def test_line_config_overrides_voice_only_in_copy(self):
        base = {"provider": "council", "xai": {"voice_id": "eve", "speed": 1.0}}
        cfg = engines.line_config(base, "xai", "rex", 1.08)
        self.assertEqual(cfg["xai"], {"voice_id": "rex", "speed": 1.08})
        self.assertEqual(cfg["provider"], "xai")
        self.assertEqual(base["xai"]["voice_id"], "eve")

    def test_edge_and_elevenlabs_keys(self):
        self.assertEqual(engines.line_config({}, "edge", "en-US-EricNeural", None)["edge"],
                         {"voice": "en-US-EricNeural"})
        self.assertEqual(engines.line_config({}, "elevenlabs", "abc", 1.2)["elevenlabs"],
                         {"voice_id": "abc"})

    def _fake_synth(self, calls):
        def synth(engine, text, voice, speed, out_path, cfg):
            calls.append((engine, voice, speed, text))
            with open(out_path, "wb") as fh:
                fh.write(f"[{voice}:{text}]".encode())
        return synth

    def test_render_line_by_line_without_ffmpeg(self):
        calls = []
        old = engines.shutil.which
        engines.shutil.which = lambda _name: None
        try:
            with tempfile.TemporaryDirectory() as tmp:
                out = engines.render([("romulus", "A."), ("remus", "B.")], os.path.join(tmp, "x.mp3"),
                                     engine="edge", voices={"romulus": "R1", "remus": "R2"},
                                     speeds={"romulus": None, "remus": 1.05}, tts_config={},
                                     dialogue=True, line_synth=self._fake_synth(calls))
                with open(out, "rb") as fh:
                    self.assertEqual(fh.read(), b"[R1:A.][R2:B.]")
        finally:
            engines.shutil.which = old
        self.assertEqual(calls, [("edge", "R1", None, "A."), ("edge", "R2", 1.05, "B.")])

    def test_ogg_without_ffmpeg_becomes_honest_mp3(self):
        old = engines.shutil.which
        engines.shutil.which = lambda _name: None
        try:
            with tempfile.TemporaryDirectory() as tmp:
                out = engines.render([("romulus", "A."), ("remus", "B.")], os.path.join(tmp, "x.ogg"),
                                     engine="xai", voices={"romulus": "sal", "remus": "rex"}, speeds={},
                                     tts_config={}, dialogue=False, line_synth=self._fake_synth([]))
                self.assertTrue(out.endswith(".mp3"))
        finally:
            engines.shutil.which = old

    def test_dialogue_used_then_falls_back(self):
        sent = []

        def dialogue(batch, voices, out_path, cfg):
            sent.append(batch)
            with open(out_path, "wb") as fh:
                fh.write(b"D")

        with tempfile.TemporaryDirectory() as tmp:
            out = engines.render([("romulus", "A."), ("remus", "B.")], os.path.join(tmp, "x.mp3"),
                                 engine="elevenlabs", voices={"romulus": "v1", "remus": "v2"}, speeds={},
                                 tts_config={}, dialogue=True, line_synth=self._fake_synth([]),
                                 dialogue_synth=dialogue)
            with open(out, "rb") as fh:
                self.assertEqual(fh.read(), b"D")
        self.assertEqual(len(sent), 1)

        def broken(*_a, **_k):
            raise RuntimeError("no key")

        calls = []
        old = engines.shutil.which
        engines.shutil.which = lambda _name: None
        try:
            with tempfile.TemporaryDirectory() as tmp:
                engines.render([("romulus", "A."), ("remus", "B.")], os.path.join(tmp, "x.mp3"),
                               engine="elevenlabs", voices={"romulus": "v1", "remus": "v2"}, speeds={},
                               tts_config={}, dialogue=True, line_synth=self._fake_synth(calls),
                               dialogue_synth=broken)
        finally:
            engines.shutil.which = old
        self.assertEqual(len(calls), 2)

    def test_dialogue_request_shape(self):
        seen = {}

        class Resp:
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def read(self):
                return b"MP3"

        def opener(req, timeout):
            seen["url"] = req.full_url
            seen["key"] = req.get_header("Xi-api-key")
            seen["body"] = req.data
            return Resp()

        os.environ["ELEVENLABS_API_KEY"] = "test-key"
        try:
            with tempfile.TemporaryDirectory() as tmp:
                path = os.path.join(tmp, "d.mp3")
                engines.elevenlabs_dialogue([("romulus", "Hi."), ("remus", "Yo.")],
                                            {"romulus": "v1", "remus": "v2"}, path, {}, opener=opener)
                with open(path, "rb") as fh:
                    self.assertEqual(fh.read(), b"MP3")
        finally:
            del os.environ["ELEVENLABS_API_KEY"]
        self.assertIn("/v1/text-to-dialogue", seen["url"])
        self.assertEqual(seen["key"], "test-key")
        self.assertIn(b'"voice_id": "v2"', seen["body"])
        self.assertIn(b'"eleven_v3"', seen["body"])

    def test_unknown_engine(self):
        with self.assertRaises(ValueError):
            engines.render([("romulus", "A.")], "/tmp/x.mp3", engine="openai", voices={}, speeds={},
                           tts_config={}, dialogue=False)


class CouncilSplitTests(unittest.TestCase):
    def test_council_reply(self):
        lines, _ = speakers.split_lines(
            "Newton: The repair is $1,900. Māui: Or wrap it in your logo! Marcus: Fix and wrap.", COUNCIL)
        self.assertEqual(lines, [("newton", "The repair is $1,900."), ("maui", "Or wrap it in your logo!"),
                                 ("marcus", "Fix and wrap.")])

    def test_two_word_tag_and_all(self):
        lines, _ = speakers.split_lines("Sun Tzu: Fight on speed. All: Agreed.", COUNCIL)
        self.assertEqual(lines, [("sun-tzu", "Fight on speed."), ("marcus", "Agreed.")])

    def test_unknown_name_is_not_a_speaker(self):
        lines, _ = speakers.split_lines("Marcus: Call Sam. Sam: is not a member.", COUNCIL)
        self.assertEqual(lines, [("marcus", "Call Sam. Sam: is not a member.")])

    def test_ascii_maui_via_label(self):
        cast = speakers.Cast(speakers=("marcus", "maui"), labels={"māui": "maui"})
        lines, _ = speakers.split_lines("Maui: Bigger! Māui: Much bigger.", cast)
        self.assertEqual(lines, [("maui", "Bigger! Much bigger.")])


class ProviderSettingsTests(unittest.TestCase):
    """Loads __init__.py with a stand-in for Hermes's TTSProvider base class."""

    @classmethod
    def setUpClass(cls):
        agent = types.ModuleType("agent")
        tts_provider = types.ModuleType("agent.tts_provider")
        tts_provider.TTSProvider = object
        sys.modules.setdefault("agent", agent)
        sys.modules.setdefault("agent.tts_provider", tts_provider)
        import importlib.util
        spec = importlib.util.spec_from_file_location("council_voices_init", os.path.join(PLUGIN, "__init__.py"))
        cls.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.mod)

    def provider(self):
        return self.mod.CouncilVoicesProvider()

    def test_defaults(self):
        s = self.provider().settings({})
        self.assertEqual(s["engine"], "edge")
        self.assertEqual(s["cast"].lead, "marcus")
        self.assertEqual(s["voices"]["remus"], "en-US-EricNeural")

    def test_configured_council(self):
        cfg = {"council": {"engine": "xai", "lead": "marcus", "speakers": ["marcus", "newton", "maui"],
                           "labels": {"māui": "maui"},
                           "voices": {"marcus": {"xai": "leo", "xai_speed": 0.9},
                                      "newton": {"xai": "sal", "xai_speed": 1.05},
                                      "maui": {"xai": "rex"}}}}
        s = self.provider().settings(cfg)
        self.assertEqual(s["voices"], {"marcus": "leo", "newton": "sal", "maui": "rex"})
        self.assertEqual(s["speeds"]["newton"], 1.05)
        self.assertEqual(s["cast"].speaker_for("Māui"), "maui")

    def test_member_without_voice_uses_lead(self):
        cfg = {"council": {"engine": "edge", "speakers": ["marcus", "hypatia"],
                           "voices": {"marcus": {"edge": "en-GB-RyanNeural"}}}}
        s = self.provider().settings(cfg)
        self.assertEqual(s["voices"]["hypatia"], "en-GB-RyanNeural")

    def test_lead_without_voice_is_clear(self):
        with self.assertRaises(ValueError) as err:
            self.provider().settings({"council": {"engine": "xai", "lead": "nova", "speakers": ["nova"]}})
        self.assertIn("tts.council.voices.nova.xai", str(err.exception))

    def test_old_twins_settings_still_work(self):
        cfg = {"twins": {"engine": "xai", "voices": {"romulus": {"xai": "leo"}, "remus": {"xai": "ara"}}}}
        s = self.provider().settings(cfg)
        self.assertEqual(s["cast"].lead, "romulus")
        self.assertEqual(s["voices"], {"romulus": "leo", "remus": "ara"})
        self.assertEqual(s["speeds"]["remus"], 1.1)  # default for remus on xai


if __name__ == "__main__":
    unittest.main(verbosity=1)
