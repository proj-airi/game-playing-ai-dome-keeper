import json
from pathlib import Path
import tempfile
import subprocess
import unittest

from PIL import Image
import torch

from lower_v0 import PAIRS, Policy, Windows, extract_sessions, read_sessions, split_sessions
from session_schema import Instruction


class DataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        directory = self.root / "sessions" / "sample"
        (directory / "frames").mkdir(parents=True)
        self.path = directory / "session.json"
        self.session = dict(schema_version=1, id="sample", instruction=dict(task="pickup", target="iron"),
                            scenario_id="seed-1", scenario=dict(seed=1), versions=dict(collector="test"),
                            bindings=[dict(action="ui_left", keycode=0, physical_keycode=65)], events=[
                                dict(order=2, time_us=2000, physics_frame=1, kind="input", action="ui_left"),
                                dict(order=5, time_us=102000, physics_frame=7, kind="input", action="none")],
                            outcome=dict(status="success", final_held_action="none",
                                         order=6, time_us=103000, physics_frame=7), steps=[])
        for i in range(2):
            Image.new("RGB", (384, 216), (i * 100, 0, 0)).save(directory / "frames" / f"{i}.png")
            self.session["steps"].append(dict(frame_id=i, time_us=i * 100000,
                decision_time_us=i * 100000 + 1000, physics_frame=i * 6,
                decision_physics_frame=i * 6 + 1, capture_order=i * 3, order=i * 3 + 1,
                held_action="none" if i == 0 else "ui_left", next_action="ui_left" if i == 0 else "none"))

    def load(self):
        self.path.write_text(json.dumps(self.session))
        return read_sessions(self.root)

    def test_causal_padding_and_label(self):
        windows = Windows(self.load())
        frames, held, instruction, label = windows[1]
        self.assertEqual(tuple(frames.shape), (10, 3, 216, 384))
        self.assertTrue(torch.equal(frames[0], frames[8]))
        self.assertFalse(torch.equal(frames[8], frames[9]))
        self.assertEqual(held.argmax(1).tolist(), [8] * 9 + [2])
        self.assertEqual(instruction.tolist(), [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0])
        self.assertEqual(label, 8)
        self.assertEqual(windows[0][1].argmax(1).tolist(), [8] * 10)

    def test_repeated_scenarios_cannot_leak(self):
        sessions = [dict(id=f"{pair}-{seed}-{repeat}", pair=pair, scenario_id=f"{pair}-{seed}")
                    for pair in PAIRS for seed in range(4) for repeat in range(2)]
        train, valid = split_sessions(sessions, 0.25, 4)
        self.assertFalse({s["scenario_id"] for s in train} & {s["scenario_id"] for s in valid})
        self.assertEqual({s["pair"] for s in valid}, set(PAIRS))
        self.assertEqual(len(valid), 18)

    def test_enter_mine_extends_only_the_instruction(self):
        self.assertEqual(Instruction(task="enter", target="mine").model_dump(),
                         {"task": "enter", "target": "mine"})
        with self.assertRaises(ValueError):
            Instruction(task="enter", target="iron")
        with self.assertRaises(ValueError):
            Instruction(task="pickup", target="mine")
        model = Policy([16], pretrained=False)
        logits = model(torch.zeros(1, 10, 3, 216, 384), torch.zeros(1, 10, 9),
                       torch.zeros(1, 11))
        self.assertEqual(tuple(logits.shape), (1, 9))

    def test_extract_recorded_video_indices_before_promotion(self):
        movie = self.root / "test.mkv"
        frames = self.path.parent / "frames"
        subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-n", "-framerate", "10",
                        "-i", str(frames / "%d.png"), "-vf", "fps=30", "-c:v", "ffv1",
                        str(movie)], check=True)
        self.session["movie"] = str(movie)
        for i, step in enumerate(self.session["steps"]):
            step.update(video_frame=i * 3, decision_video_frame=i * 3 + 1)
        self.load()
        frames.rename(self.root / "reference")
        frames.mkdir()
        (self.root / "sessions").rename(self.root / ".incomplete")
        extract_sessions(self.root, movie)
        sessions = read_sessions(self.root)
        self.assertEqual(len(sessions), 1)
        for i in range(2):
            with Image.open(frames / f"{i}.png") as image:
                self.assertEqual(image.getpixel((100, 100)), (i * 100, 0, 0))
        self.assertFalse((self.root / ".incomplete" / "sample").exists())


if __name__ == "__main__":
    unittest.main()
