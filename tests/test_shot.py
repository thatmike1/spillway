"""Capture safety and input validation checks; no desktop process is launched."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import shot


class ShotTests(unittest.TestCase):
    def test_output_rejects_git_ancestors(self):
        with tempfile.TemporaryDirectory() as root:
            folder = Path(root)
            (folder / ".git").write_text("gitdir: elsewhere")
            with self.assertRaises(ValueError):
                shot.external(folder / "frames")

    def test_tape_rejects_unordered_and_nonfinite_values(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "input.json"
            for rows in ([{"time": 1, "mouse": [0, 0]}, {"time": 0, "mouse": [0, 0]}],
                         [{"time": 0, "mouse": [float("nan"), 0]}],
                         [{"time": 0, "action": "jump", "pressed": "false"}]):
                path.write_text(json.dumps(rows))
                with self.assertRaises(ValueError):
                    shot.read_sequence(path, "tape")

    def test_pose_and_tape_accept_documented_shapes(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "input.json"
            for mode, rows in (("poses", [{"position": [0, 2, 0], "yaw": 90}]),
                               ("tape", [{"time": 0, "action": "move_forward", "pressed": True}])):
                path.write_text(json.dumps(rows))
                self.assertEqual(rows, shot.read_sequence(path, mode))

    def test_busy_range_never_starts_a_display(self):
        with patch.object(shot, "answers", return_value=False), patch.object(shot, "busy", return_value=True), \
                patch.object(shot.subprocess, "Popen") as start:
            with self.assertRaises(RuntimeError):
                with shot.private_display("unused", {}):
                    self.fail("all displays busy")
            start.assert_not_called()

    def test_private_display_uses_explicit_number_and_cleans_on_failure(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(shot, "answers", side_effect=[True, True, True]), \
                patch.object(shot, "busy", return_value=False), \
                patch.object(shot.subprocess, "Popen") as start:
            process = start.return_value
            process.poll.return_value = None
            process.returncode = 0
            log = Path(folder) / "display.log"
            with self.assertRaisesRegex(RuntimeError, "body failure"):
                with shot.private_display(log, {}) as display:
                    self.assertEqual(display, ":190")
                    raise RuntimeError("body failure")
            command = start.call_args.args[0]
            self.assertEqual(command[:2], ["Xvfb", ":190"])
            self.assertNotIn("-displayfd", command)
            process.terminate.assert_called_once()
            process.wait.assert_called_once()
            evidence = json.loads(log.with_suffix(".json").read_text())
            self.assertEqual(evidence["desktop_before"], evidence["desktop_after"])

    def test_desktop_change_is_reported_after_child_cleanup(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(shot, "answers", side_effect=[True, True, False]), \
                patch.object(shot, "busy", return_value=False), \
                patch.object(shot.subprocess, "Popen") as start:
            process = start.return_value
            process.poll.return_value = None
            process.returncode = 0
            with self.assertRaisesRegex(RuntimeError, "availability changed"):
                with shot.private_display(Path(folder) / "display.log", {}):
                    pass
            process.terminate.assert_called_once()
            process.wait.assert_called_once()

    def test_failed_desktop_probe_never_starts_a_display(self):
        with patch.object(shot, "answers", return_value=False), patch.object(shot.Path, "exists", return_value=True), \
                patch.object(shot.subprocess, "Popen") as start:
            with self.assertRaises(RuntimeError):
                with shot.private_display("unused", {}):
                    self.fail("desktop unavailable")
            start.assert_not_called()


if __name__ == "__main__":
    unittest.main()
