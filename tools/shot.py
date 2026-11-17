#!/usr/bin/env python3
"""Capture the current game on an explicitly numbered, isolated software X display."""
import argparse
from contextlib import contextmanager
import json
import math
from pathlib import Path
import shutil
import re
import signal
import socket
import subprocess
import tempfile
import time

import engine
import contact_sheet


def external(path):
    path = Path(path).resolve()
    for parent in (path, *path.parents):
        if (parent / ".git").exists():
            raise ValueError("output must be outside every Git checkout")
    return path


def snapshot_ignore(checkout):
    checkout = Path(checkout).resolve()
    caches = shutil.ignore_patterns(".git", ".godot", "__pycache__", "builds")

    def ignore(directory, names):
        omitted = set(caches(directory, names))
        # frozen recording fixtures are unnecessary for captures, unlike authored imports.
        if Path(directory) == checkout / "tests":
            omitted.add("fixtures")
        return omitted

    return ignore


def answers(number, env=None):
    result = subprocess.run(["xdpyinfo", "-display", f":{number}"], env=env,
                            capture_output=True, timeout=5)
    return result.returncode == 0


def busy(number):
    if Path(f"/tmp/.X{number}-lock").exists() or Path(f"/tmp/.X11-unix/X{number}").exists():
        return True
    # abstract sockets need checking too, even when no filesystem socket exists.
    with socket.socket(socket.AF_UNIX) as probe:
        probe.settimeout(.1)
        try:
            probe.connect(f"\0/tmp/.X11-unix/X{number}")
            return True
        except OSError:
            return False


@contextmanager
def private_display(log, env, size="1280x720"):
    # caller holds engine.locked for this entire context, including cleanup.
    before = answers(0)
    desktop_socket = Path("/tmp/.X11-unix/X0")
    if desktop_socket.exists() and not before:
        raise RuntimeError("desktop :0 exists but does not answer; refusing to start")
    desktop_identity = desktop_socket.stat().st_ino if desktop_socket.exists() else None
    number = next((n for n in range(190, 200) if not busy(n)), None)
    if number is None:
        raise RuntimeError("all private displays :190 through :199 are busy")
    with Path(log).open("w") as stream:
        process = subprocess.Popen(["Xvfb", f":{number}", "-screen", "0", size + "x24",
                                    "-nolisten", "tcp", "-ac", "-noreset"],
                                   stdout=stream, stderr=subprocess.STDOUT)
        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError(f"Xvfb failed; read {log}")
                if answers(number, env):
                    yield f":{number}"
                    break
                time.sleep(.05)
            else:
                raise RuntimeError("private Xvfb did not become ready")
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            after = answers(0)
            identity_after = desktop_socket.stat().st_ino if desktop_socket.exists() else None
            Path(log).with_suffix(".json").write_text(json.dumps({"private_display": number,
                "desktop_before": before, "desktop_after": after, "desktop_socket_before": desktop_identity,
                "desktop_socket_after": identity_after, "private_server_exit": process.returncode}, indent=2) + "\n")
            if after != before or identity_after != desktop_identity:
                raise RuntimeError("desktop :0 availability changed during capture")


HARNESS = r'''
extends SceneTree
var main: Node
var options: Dictionary
var age: float = 0
var next_capture: float = 0
var frame_index: int = 0
var event_index: int = 0
var capturing: bool = false
var ready_to_run: bool = false
var trace: FileAccess
var driver: Node
var clock: Node
func _initialize() -> void:
	options = JSON.parse_string(FileAccess.get_file_as_string("res://capture-options.json"))
	RenderingServer.render_loop_enabled = bool(options.get("movie", false))
	_start.call_deferred()
func _start() -> void:
	main = load("res://scripts/game.gd").new()
	root.add_child(main)
	await process_frame
	await process_frame
	if str(main.get("map_id")) != str(options.map):
		push_error("requested map did not load: " + str(options.map))
		quit(2)
		return
	for key: String in options.settings:
		main.call("change_setting", key, options.settings[key])
	main.call("set_look", options.look != "old")
	main.call("set_paused", false)
	trace = FileAccess.open(str(options.out).path_join("frames.jsonl"), FileAccess.WRITE)
	if options.mode in ["route", "tape"]:
		main.call("restart_run", "capture")
	if options.mode == "route":
		var routes: Dictionary = main.get("level").get("routes")
		if not routes.has(str(options.route)):
			push_error("map has no named route: " + str(options.route))
			quit(2)
			return
		var original_points: Array = routes[str(options.route)]
		var original_routes: PackedByteArray = var_to_bytes(routes)
		var points: Array = []
		for entry: Variant in original_points:
			points.append({"pos": entry, "radius": 1.0} if entry is Vector3 else entry)
		# attach copies its navigation tape; restore the authored hints before any motor tick.
		routes[str(options.route)] = points
		driver = load("res://scripts/spillway_driver.gd").new()
		main.add_child(driver)
		driver.call("attach", main, str(options.route), 0)
		routes[str(options.route)] = original_points
		if var_to_bytes(routes) != original_routes:
			push_error("named route capture changed authored route hints")
			quit(2)
			return
		if bool(driver.get("done")):
			push_error("route setup failed: " + str(driver.get("failure_reason")))
			quit(2)
			return
	elif options.mode == "tape":
		var playback := TapeInput.new()
		playback.options = options
		playback.process_physics_priority = -100
		main.add_child(playback)
	elif options.mode == "poses":
		main.get("hud").hide()
		main.call("set_physics_process", false)
		main.get("player").set_physics_process(false)
		main.get("player").set_process(false)
	clock = CaptureClock.new()
	clock.process_physics_priority = -200
	main.add_child(clock)
	ready_to_run = true
func _process(_delta: float) -> bool:
	if not ready_to_run:
		return false
	age = float(clock.get("age"))
	if age <= 0:
		return false
	if age >= float(options.seconds) and not capturing and frame_index > 0:
		main.call("request_quit", 0)
		return false
	if not capturing and age >= next_capture:
		if options.mode == "poses" and frame_index >= options.poses.size():
			main.call("request_quit", 0)
			return false
		capturing = true
		_capture.call_deferred()
		next_capture = age + float(options.every)
	if age >= float(options.seconds) and not capturing:
		main.call("request_quit", 0)
	return false
func _capture() -> void:
	var player: Node3D = main.get("player")
	if options.mode == "poses":
		var pose: Dictionary = options.poses[frame_index]
		var camera: Camera3D = root.get_camera_3d()
		camera.global_position = Vector3(pose.position[0], pose.position[1], pose.position[2])
		camera.global_rotation = Vector3(deg_to_rad(pose.get("pitch", 0)), deg_to_rad(pose.get("yaw", 0)), 0)
		# camera internal transforms must reach the rendering server before readback.
		await process_frame
		await process_frame
	if bool(options.get("movie", false)):
		await RenderingServer.frame_post_draw
	else:
		RenderingServer.force_draw(true, float(options.every))
	var path := str(options.out).path_join("frame-%05d.png" % frame_index)
	var error := root.get_texture().get_image().save_png(path)
	var observation: Dictionary = player.call("get_motion_state") if player.has_method("get_motion_state") else {}
	trace.store_line(JSON.stringify({"motion": observation, "finished": main.get("finished"), "finish_kind": main.get("finish_kind"),
		"checkpoint": main.get("checkpoint_index"), "respawns": main.get("respawn_count"), "frame": frame_index, "time": age, "path": path,
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"mode": options.mode, "error": error}))
	trace.flush()
	if error != OK:
		push_error("PNG capture failed")
		quit(2)
	frame_index += 1
	capturing = false
class CaptureClock extends Node:
	var age: float = 0
	func _physics_process(delta: float) -> void:
		age += delta

class TapeInput extends Node:
	var options: Dictionary
	var age: float = 0
	var event_index: int = 0
	func _physics_process(delta: float) -> void:
		while event_index < options.events.size() and float(options.events[event_index].time) <= age:
			var row: Dictionary = options.events[event_index]
			var event: InputEvent
			if row.has("key"):
				var key := InputEventKey.new()
				key.keycode = OS.find_keycode_from_string(str(row.key))
				key.physical_keycode = key.keycode
				key.pressed = bool(row.pressed)
				event = key
			elif row.has("button"):
				var button := InputEventMouseButton.new()
				button.button_index = int(row.button)
				button.pressed = bool(row.pressed)
				event = button
			elif row.has("action"):
				var action := InputEventAction.new()
				action.action = str(row.action)
				action.pressed = bool(row.pressed)
				action.strength = float(row.get("strength", 1.0)) if action.pressed else 0.0
				event = action
			else:
				var motion := InputEventMouseMotion.new()
				motion.relative = Vector2(float(row.mouse[0]), float(row.mouse[1]))
				motion.screen_relative = motion.relative
				event = motion
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			event_index += 1
		age += delta
'''


def read_sequence(path, mode):
    rows = json.loads(Path(path).read_text())
    if not isinstance(rows, list) or not rows:
        raise ValueError("sequence must be a nonempty JSON array")
    previous = -1
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("sequence entries must be objects")
        if mode == "poses":
            xyz = row.get("position")
            if not isinstance(xyz, list) or len(xyz) != 3:
                raise ValueError("pose requires position [x,y,z]")
            values = [*xyz, row.get("yaw", 0), row.get("pitch", 0)]
        else:
            stamp = row.get("time", -1)
            if not isinstance(stamp, (int, float)) or stamp < previous or stamp < 0:
                raise ValueError("tape times must be nonnegative and ordered")
            previous = stamp
            if "key" in row:
                if not isinstance(row["key"], str) or not row["key"] or not isinstance(row.get("pressed"), bool):
                    raise ValueError("key requires a name and boolean pressed")
                values = [stamp]
            elif "button" in row:
                if type(row["button"]) is not int or not 1 <= row["button"] <= 9 or not isinstance(row.get("pressed"), bool):
                    raise ValueError("button requires index 1–9 and boolean pressed")
                values = [stamp]
            elif "action" in row:
                if not isinstance(row["action"], str) or not isinstance(row.get("pressed"), bool):
                    raise ValueError("action requires a name and boolean pressed")
                strength = row.get("strength", 1.0)
                if type(strength) not in (int, float) or not math.isfinite(strength) or not 0 <= strength <= 1:
                    raise ValueError("action strength must be a finite number in [0,1]")
                values = [stamp, strength]
            else:
                mouse = row.get("mouse")
                if not isinstance(mouse, list) or len(mouse) != 2:
                    raise ValueError("tape requires action/pressed or mouse [dx,dy]")
                values = [stamp, *mouse]
        if any(not isinstance(v, (float, int)) or not math.isfinite(v) for v in values):
            raise ValueError("sequence numbers must be finite")
    return rows


def sys_exit():
    raise SystemExit("capture interrupted")


def inspect_movie(output):
    movie = output / "capture.avi"
    result = subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)],
                            capture_output=True, text=True, check=True, timeout=30)
    info = json.loads(result.stdout)
    video = next((s for s in info["streams"] if s.get("codec_type") == "video"), None)
    if video is None:
        raise RuntimeError("MovieMaker did not produce a video stream")
    audio = next((s for s in info["streams"] if s.get("codec_type") == "audio"), None)
    if audio is None or not audio.get("codec_name", "").startswith("pcm_"):
        raise RuntimeError("MovieMaker did not produce the expected uncompressed audio stream")
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(movie), "-map", "0:a:0", "-c:a", "pcm_s16le",
                    str(output / "capture.wav")], check=True, timeout=30)
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", type=Path, default=engine.PROJECT)
    parser.add_argument("--map", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--route")
    mode.add_argument("--tape", type=Path)
    mode.add_argument("--poses", type=Path)
    parser.add_argument("--setting", action="append", default=[], metavar="KEY=JSON", help="host setting, e.g. tether_model=\"elastic-arc\"")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--movie", action="store_true", help="full-render MovieMaker AVI with native PCM audio")
    parser.add_argument("--movie-fps", type=int, choices=(30, 60), default=30)
    parser.add_argument("--look", choices=("old", "new"), default="new")
    parser.add_argument("--size", default="1280x720", help="frame size, WIDTHxHEIGHT")
    parser.add_argument("--seconds", type=float)
    parser.add_argument("--every", type=float, default=1)
    args = parser.parse_args()
    if args.seconds is None:
        args.seconds = 3.0 if args.movie else 12.0
    if not all(math.isfinite(v) and v > 0 for v in (args.seconds, args.every)):
        parser.error("seconds/every must be finite and positive")
    if not re.fullmatch(r"[1-9][0-9]{1,3}x[1-9][0-9]{1,3}", args.size):
        parser.error("size must be WIDTHxHEIGHT")
    if any(v > 4096 for v in map(int, args.size.split("x"))):
        parser.error("size must be at most 4096 per side")
    if args.movie and (args.seconds > 10 or any(v > limit for v, limit in zip(map(int, args.size.split("x")), (1920, 1080)))):
        parser.error("software movie capture is limited to 10 seconds and 1920x1080")
    checkout = args.checkout.resolve()
    if not (checkout / "project.godot").is_file():
        parser.error("checkout must contain project.godot")
    output = external(args.out)
    settings = {}
    for setting in args.setting:
        key, separator, value = setting.partition("=")
        if not separator or not key:
            parser.error("setting requires KEY=JSON")
        settings[key] = json.loads(value)
    options = dict(movie=args.movie, movie_fps=args.movie_fps, look=args.look, size=args.size, settings=settings, map=args.map, route=args.route, out=str(output), seconds=args.seconds, every=args.every,
                   mode="route" if args.route else ("tape" if args.tape else "poses"))
    if args.tape:
        options["events"] = read_sequence(args.tape, "tape")
    if args.poses:
        options["poses"] = read_sequence(args.poses, "poses")
        options["seconds"] = max(args.seconds, len(options["poses"]) * args.every + 2)
    if args.movie and options["seconds"] > 10:
        parser.error("movie pose sequences must finish within 10 seconds")
    provenance = subprocess.run(["git", "-C", str(checkout), "rev-parse", "HEAD"],
                                capture_output=True, text=True, check=True).stdout.strip()
    dirty = subprocess.run(["git", "-C", str(checkout), "status", "--porcelain"],
                           capture_output=True, text=True, check=True).stdout.splitlines()
    engine.check_pin()
    signal.signal(signal.SIGTERM, lambda *_: sys_exit())
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="spillway-shot-") as temporary:
        scratch = Path(temporary)
        source = scratch / "source"
        shutil.copytree(checkout, source, ignore=snapshot_ignore(checkout))
        (source / "capture.gd").write_text(HARNESS)
        (source / "capture-options.json").write_text(json.dumps(options))
        profile = scratch / "profile"
        engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
                   profile=profile, log=output / "import.log")
        env = engine.environment(profile)
        env.update(LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe")
        with engine.locked(), private_display(output / "display.log", env, args.size) as display:
            env["DISPLAY"] = display
            movie_arguments = ["--write-movie", str(output / "capture.avi")] if args.movie else []
            with (output / "engine.log").open("w") as log:
                result = subprocess.run([str(engine.GODOT), "--path", str(source), "--script", "res://capture.gd",
                    "--display-driver", "x11", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                    "--windowed", "--resolution", args.size, "--position", "0,0", "--fixed-fps", str(args.movie_fps if args.movie else 128), *movie_arguments, "--",
                    "--r16-map=" + args.map, "--no-records", "--no-run-recordings", "--route=" + (args.route or "safe"),
                    "--evidence-dir=" + str(output)], env=env, cwd=source, stdout=log, stderr=subprocess.STDOUT,
                    timeout=max(180, options["seconds"] * 30))
        log_text = (output / "engine.log").read_text()
        if result.returncode or any(s in log_text for s in ("ERROR:", "SCRIPT ERROR:", "Parse Error")):
            raise RuntimeError(f"capture failed; read {output / 'engine.log'}\n{log_text[-2500:]}")
    movie_info = inspect_movie(output) if args.movie else None
    frames = sorted(output.glob("frame-*.png"))
    contact_sheet.create(frames, output / "contact-sheet.png")
    (output / "capture.json").write_text(json.dumps({**options, "checkout": str(checkout),
        "movie_info": movie_info, "source_commit": provenance, "source_status": dirty, "engine_sha256": engine.EDITOR_SHA256, "renderer": "Compatibility / Mesa llvmpipe software",
        "frames": [p.name for p in frames], "display": display}, indent=2) + "\n")
    print(output / "contact-sheet.png")


if __name__ == "__main__":
    main()
