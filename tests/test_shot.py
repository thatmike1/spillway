"""Capture safety and input validation checks; no desktop process is launched."""
import argparse
import json
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import shot


class ShotTests(unittest.TestCase):
    def test_snapshot_excludes_only_the_frozen_fixture_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "checkout"
            for name in ("tests/fixtures/recording.r16run", "assets/fixtures/texture.png",
                         "assets/paint.png.import", "tests/map_test.gd"):
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("preserve")
            target = root / "snapshot"
            shot.shutil.copytree(source, target, ignore=shot.snapshot_ignore(source))
            self.assertFalse((target / "tests/fixtures").exists())
            for name in ("assets/fixtures/texture.png", "assets/paint.png.import", "tests/map_test.gd"):
                self.assertEqual((target / name).read_text(), "preserve")

    def test_movie_inspection_refuses_an_audio_only_container(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(shot.subprocess, "run") as run:
            run.return_value.stdout = json.dumps({"streams": [{"codec_type": "audio", "codec_name": "pcm_s16le"}]})
            with self.assertRaisesRegex(RuntimeError, "video stream"):
                shot.inspect_movie(Path(folder))
            run.assert_called_once()

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

    def test_action_strength_is_preserved_and_bounded(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "tape.json"
            rows = [{"time": 0, "action": "move_forward", "pressed": True, "strength": .25}]
            path.write_text(json.dumps(rows))
            self.assertEqual(shot.read_sequence(path, "tape"), rows)
            for strength in (-.1, 1.1, True, "0.5", float("nan")):
                rows[0]["strength"] = strength
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

    def test_resize_is_integer_bounded_and_separate_from_input(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "input.json"
            row = {"time": .5, "resize": [1280, 720]}
            path.write_text(json.dumps([row]))
            self.assertEqual(shot.read_sequence(path, "tape", (1920, 1080)), [row])
            for size in ([1921, 720], [1280, 1081], [0, 720], [True, 720],
                         [1280.0, 720], [1280], [1280, 720, 1], "1280x720"):
                path.write_text(json.dumps([{**row, "resize": size}]))
                with self.assertRaises(ValueError):
                    shot.read_sequence(path, "tape", (1920, 1080))
            path.write_text(json.dumps([{**row, "key": "Escape", "pressed": True}]))
            with self.assertRaisesRegex(ValueError, "separate"):
                shot.read_sequence(path, "tape")

    def test_movie_refuses_resize_before_engine_launch(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "input.json"
            path.write_text(json.dumps([{"time": 0, "resize": [640, 360]}]))
            with patch.object(sys, "argv", ["shot.py", "--map", "breakwater", "--tape", str(path),
                                             "--out", str(Path(folder) / "capture"), "--movie"]), \
                    patch.object(sys, "stderr"), patch.object(shot.engine, "check_pin") as launch:
                with self.assertRaises(SystemExit) as stopped:
                    shot.main()
                self.assertEqual(stopped.exception.code, 2)
                launch.assert_not_called()

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


CANONICAL = r'''
extends SceneTree
func _initialize() -> void:
	_start.call_deferred()
func _start() -> void:
	var main: Node = load("res://scripts/game.gd").new()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_physics_process(false)
	var player: Node3D = main.get("player")
	player.set_physics_process(false)
	main.call("restart_run", "capture")
	var rows: Array = []
	# these independent commands define the zero-based normal-spawn contract.
	for index: int in 32:
		var strength: float = .25 if index == 0 else (.75 if index == 1 else 0.0)
		if strength > 0:
			Input.action_press("move_forward", strength)
		else:
			Input.action_release("move_forward")
		player.call("_physics_process", 1.0 / 128)
		rows.append({"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"motion": player.call("get_motion_state").duplicate(true)})
	var output := FileAccess.open(str(OS.get_cmdline_user_args()[-1]), FileAccess.WRITE)
	output.store_string(JSON.stringify(rows))
	output.close()
	main.call("request_quit", 0)
'''


def native_contract(output, movie=False, movie_fps=30, resize=False):
    output = shot.external(output)
    output.mkdir(parents=True, exist_ok=False)
    tape = output / "input.json"
    events = [
        {"time": 0, "action": "move_forward", "pressed": True, "strength": .25},
        {"time": 1 / 128, "action": "move_forward", "pressed": True, "strength": .75},
        {"time": 2 / 128, "action": "move_forward", "pressed": False, "strength": .9},
    ]
    if resize:
        events.extend([{"time": 1 / 128, "resize": [320, 180]},
                       {"time": 3 / 128, "resize": [640, 360]}])
        events.sort(key=lambda event: event["time"])
    tape.write_text(json.dumps(events))
    subprocess.run([sys.executable, "-B", str(shot.engine.PROJECT / "tools/shot.py"),
                    "--map", "breakwater", "--tape", str(tape), "--seconds", str((12 if movie else 6) / 128),
                    "--every", str(1 / 128), "--size", "640x360", "--out", str(output / "native"), *(["--movie", "--movie-fps", str(movie_fps)] if movie else [])], check=True)
    with tempfile.TemporaryDirectory(prefix="canonical-", dir=output) as temporary:
        root = Path(temporary)
        source = root / "source"
        shot.shutil.copytree(shot.engine.PROJECT, source, ignore=shot.snapshot_ignore(shot.engine.PROJECT))
        (source / "canonical.gd").write_text(CANONICAL)
        shot.engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
                        profile=root / "profile", log=output / "canonical-import.log")
        shot.engine.run(["--headless", "--path", source, "--fixed-fps", str(movie_fps) if movie else "128", "--audio-driver", "Dummy",
                         "--script", "res://canonical.gd", "--", "--r16-map=breakwater",
                         "--no-records", "--no-run-recordings", str(output / "expected.json")],
                        cwd=source, profile=root / "profile", log=output / "canonical.log")
    expected = json.loads((output / "expected.json").read_text())
    actual = [json.loads(line) for line in (output / "native/frames.jsonl").read_text().splitlines()]
    ticks = []
    for frame in actual:
        tick = round(frame["time"] * 128)
        if tick < 1 or tick > len(expected):
            raise AssertionError(f"capture clock outside canonical ticks: {frame['time']}")
        reference = expected[tick - 1]
        if frame["position"] != reference["position"] or frame["motion"] != reference["motion"]:
            (output / "mismatch.json").write_text(json.dumps({"tick": tick, "actual": frame, "expected": reference}, indent=2))
            raise AssertionError(f"native normal-spawn tape diverged at tick {tick}; read {output / 'mismatch.json'}")
        ticks.append(tick)
    if not movie and not {1, 2}.issubset(ticks):
        raise AssertionError(f"native samples must observe the distinct t0/t1 commands: {ticks}")
    if not ticks:
        raise AssertionError("no native motor observations")
    if resize and not {(320, 180), (640, 360)}.issubset({tuple(frame["png_size"]) for frame in actual}):
        raise AssertionError("moving contract did not observe both resized readback dimensions")
    (output / "RESULT.json").write_text(json.dumps({"ok": True, "movie": movie, "movie_fps": movie_fps,
        "resize": resize, "exact_positions_and_state_ticks": ticks}) + "\n")
    print("native normal-spawn positions/state match canonical ticks:", ticks)


if __name__ == "__main__":
    if "--native-contract" in sys.argv:
        parser = argparse.ArgumentParser()
        parser.add_argument("--native-contract", action="store_true")
        parser.add_argument("--out", type=Path, required=True)
        parser.add_argument("--movie", action="store_true")
        parser.add_argument("--movie-fps", type=int, choices=(30, 60), default=30)
        parser.add_argument("--resize", action="store_true")
        args = parser.parse_args()
        if args.resize and args.movie:
            parser.error("resize contract requires PNG mode")
        native_contract(args.out, args.movie, args.movie_fps, args.resize)
    else:
        unittest.main()
