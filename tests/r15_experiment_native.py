#!/usr/bin/env python3
"""p / movement lab native evidence on the private AMD/X11 display (tools/r14_native_display.py).

movie:   the combined lab tape (tests/test_r15_experiment.gd, tapes/r15-lab-combined.json)
         replayed through the actual tape executor and the actual r15 main on the lab map
         (tests/r15_experiment_tape_game.gd), rendered from the player's own camera with the hud
         by godot's movie writer at one draw per physics tick. a headless replay of the same tape
         is the reference; the evaluator judges both and compare() measures them tick for tick.
         the AVI lives in /dev/shm, is encoded to a bounded MP4, JPEGs are cut at the moves, and
         the AVI is deleted.
osinput: the actual r15 main on the lab map (tests/r15_experiment_observer_game.gd, read-only
         observer), driven only by xdotool keys and a mouse click plus libXtst relative mouse
         motion on that display, recorded with x11grab. the actor is coordinate-aware: it reads
         the observer to time presses and to steer the view onto the anchor, as a player
         watching the screen would. it proves the os input path and the moves' response, not
         open-loop reproducibility.

every launch needs HOME >= 15 GiB free and a new evidence directory; nothing falls back to
software rendering (the helper refuses). records are off; profiles are scratch in /dev/shm.

python3 -I tests/r15_experiment_native.py movie --evidence DIR --tape TAPE
python3 -I tests/r15_experiment_native.py osinput --evidence DIR
"""
import argparse
import ctypes
import gzip
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import traceback

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get("GODOT", Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"))
FLOOR = 15 * 2 ** 30
U = 0.0254
A1 = (0.0, 10.5, -80.0)
spec = importlib.util.spec_from_file_location("lab_nd", PROJECT / "tools/r14_native_display.py")
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
spec = importlib.util.spec_from_file_location("lab_mt", PROJECT / "tools/momentum-tape.py")
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)
OWNED = ["scripts/r15_experiment_player.gd", "scripts/r15_experiment_level.gd", "scripts/r15_experiment_art.gd", "scripts/r15_main.gd",
         "scripts/r15_hud.gd", "scripts/r15_source_player.gd", "tests/r15_experiment_tape_game.gd", "tests/r15_experiment_observer_game.gd",
         "tests/r15_experiment_native.py", "tools/momentum-tape.gd", "tools/momentum-tape.py", "tools/r14_native_display.py"]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def identity():
    return {"godot_sha256": digest(GODOT), "files": {f: digest(PROJECT / f) for f in OWNED}}


def require_space():
    free = shutil.disk_usage(Path.home()).free
    if free < FLOOR:
        raise SystemExit("HOME has %.2f GiB free, below 15 GiB: nothing launched" % (free / 2 ** 30))
    return free


def profile_env(scratch):
    env = dict(os.environ)
    for name in ["data", "config", "cache", "state"]:
        (scratch / name).mkdir(parents=True, exist_ok=True)
        env["XDG_%s_HOME" % name.upper()] = str(scratch / name)
    return env


def encode(avi, mp4, crf, fps):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-an", "-vf", "fps=%d,scale=1280:-2" % fps, "-c:v", "libx264", "-preset", "slow",
                    "-crf", str(crf), "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)], check=True)
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=width,height,nb_frames,r_frame_rate", "-of", "json", str(mp4)],
                           capture_output=True, text=True, check=True)
    return json.loads(probe.stdout)


def cut(mp4, at, path):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % at, "-i", str(mp4), "-frames:v", "1", "-q:v", "4", str(path)], check=True)


# --- movie ------------------------------------------------------------------------------------

def movie(args):
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    tape = args.tape.resolve()
    plan = mt.expand(json.loads(tape.read_text()))
    hz = int(plan["physics_hz"])
    record = {"label": "OPEN LOOP replay of the combined lab tape on the actual r15 main and lab runner; the player's own camera and hud; key and mouse events only after the main's normal spawn and an 8-tick warmup",
              "tape": str(tape), "tape_sha256": digest(tape), "identity": identity(), "physics_hz": hz, "warmup": 8, "motor": "server128",
              "home_free_before": require_space()}
    scratch = Path(tempfile.mkdtemp(prefix="r15-lab-movie-", dir="/dev/shm"))
    try:
        reference = scratch / "headless"
        cmd = [sys.executable, "-I", str(PROJECT / "tools/momentum-tape.py"), "run", str(tape), "--out", str(reference), "--headless", "--archive",
               "--wall-budget", "300", "--render-fps", str(hz), "--warmup", "8", "--game-script", "res://tests/r15_experiment_tape_game.gd", "--game-class", "", "--motor", "server128"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        record["headless"] = {"command": cmd, "exit": result.returncode, "summary": json.loads(result.stdout) if result.stdout.strip().startswith("{") else result.stdout[-600:]}
        native = scratch / "native"
        for sub in ["evaluator", "actor", "control", "profile"]:
            (native / sub).mkdir(parents=True)
        (native / "evaluator/plan.json").write_text(json.dumps(plan, indent=1))
        avi = scratch / "movie.avi"
        gcmd = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed",
                "--resolution", "1280x720", "--fixed-fps", str(hz), "--write-movie", str(avi), "--script", str(PROJECT / "tools/momentum-tape.gd"), "--",
                "--tape=%s" % (native / "evaluator/plan.json"), "--out=%s" % native, "--motor=server128", "--fixture=",
                "--game-script=res://tests/r15_experiment_tape_game.gd", "--game-class=", "--sensitivity=1.0", "--inject=tick", "--warmup=8",
                "--frames=movie", "--readback-every=4", "--wall-budget-s=600", "--run-id=lab-native-%d" % os.getpid(), "--physics-hz=%d" % hz]
        env = profile_env(native / "profile")
        with nd.NativeDisplay(evidence / "display", displays=range(190, 200)) as display:
            record["display"] = display.display
            watch = display.gpu_watch()
            started = time.monotonic()
            with open(native / "evaluator/godot.log", "wb") as log:
                game = subprocess.Popen(gcmd, env=display.child_env(env), cwd=native / "profile", stdout=log, stderr=subprocess.STDOUT,
                                        start_new_session=True, preexec_fn=nd._owned_child(os.getpid()))
            watch.follow(game.pid)
            try:
                code = game.wait(args.wall)
            except BaseException:
                nd._stop_group(game)
                raise
            finally:
                watch.stop()
            record["native_wall_s"] = round(time.monotonic() - started, 2)
        record["display_released"] = display.released
        text = (native / "evaluator/godot.log").read_text(errors="replace")
        report = mt.evaluate(native)
        (native / "evaluator/report.json").write_text(json.dumps(report, indent=1))
        mt.archive_run(native)
        end = json.loads((native / "end.json").read_text())
        rows = [r for r in mt.read_jsonl(native / "evaluator/trace.jsonl") if r["phase"] == "tape"]
        record["native"] = {"command": gcmd, "exit": code, "end": end, "gpu": watch.verdict(), "device": nd.godot_device(text),
                            "errors": [l for l in text.splitlines() if "ERROR" in l][:5], "delivery_ok": report["delivery"]["ok"], "order_ok": report["order"]["ok"],
                            "rate_ok": report["rate"]["ok"], "neutral": report["neutral"], "movement_flags": report["movement_flags"],
                            "integrity_flags": report["integrity_flags"], "outcome": report["outcome"], "game_last": rows[-1]["game"],
                            "draws_per_step": end.get("draws", 0) / max(1, end.get("steps", 1))}
        record["native"]["amd"] = record["native"]["gpu"]["ok"] and record["native"]["device"] is not None and "AMD" in record["native"]["device"].get("device", "")
        record["comparison"] = mt.compare(reference, native)
        # the moments worth a frame: from the trace's own ticks (movie frame i is draw i).
        moments = {}
        for r in rows:
            ex = (r["post"].get("motion_state") or {}).get("experiment", {})
            for event in ex.get("events", []):
                moments.setdefault(event, r["tick"])
            if r["game"].get("finished") and "finish" not in moments:
                moments["finish"] = r["tick"]
        under = next((r["tick"] for r in rows if -26.0 < r["post"]["p"][2] < -24.0 and r["post"]["crouched"]), None)
        swing = next((r["tick"] + 64 for r in rows if "grapple" in ((r["post"].get("motion_state") or {}).get("experiment", {}).get("events", []))), None)
        picks = {"slide-start": moments.get("slide"), "slide-under-rack": under, "wall-jump-1": moments.get("wall_jump"), "grapple-latch": moments.get("grapple"),
                 "grapple-swing": swing, "grapple-release": moments.get("grapple_release"), "finish": moments.get("finish")}
        draws_before = end.get("arm_step", 0) or 0
        mp4 = evidence / "combined-native.mp4"
        record["mp4"] = {"probe": encode(avi, mp4, args.crf, args.fps), "crf": args.crf, "fps": args.fps, "source_fps": hz, "avi_bytes_deleted": avi.stat().st_size}
        record["mp4"].update(bytes=mp4.stat().st_size, sha256=digest(mp4))
        shots = {}
        for name, tick in picks.items():
            if tick is None:
                continue
            at = (draws_before + tick + 1) / hz
            path = evidence / ("combined-%s.jpg" % name)
            cut(mp4, at, path)
            shots[path.name] = {"tick": tick, "movie_s": round(at, 3), "sha256": digest(path)}
        record["shots"] = shots
        record["shot_timing"] = "movie second = (executor arm step + tape tick + 1) / %d; one draw per physics tick (draws_per_step above)" % hz
        with gzip.open(evidence / "native-trace-excerpt.jsonl.gz", "wt") as out:
            for r in rows:
                ex = (r["post"].get("motion_state") or {}).get("experiment", {})
                out.write(json.dumps({"t": r["tick"], "p": r["post"]["p"], "v": r["post"]["v"], "g": r["post"]["grounded"], "duck": r["post"]["crouched"],
                                      "yaw": r["post"]["yaw"], "pitch": r["post"]["pitch"], "actions": r["post"]["actions"], "events": ex.get("events"),
                                      "impulses_u": ex.get("impulses_u"), "contacts": r["post"]["contacts"], "game": r["game"]}) + "\n")
        avi.unlink()
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    record["scratch_removed"] = not scratch.exists()
    record["home_free_after"] = shutil.disk_usage(Path.home()).free
    (evidence / "run.json").write_text(json.dumps(record, indent=1, default=str) + "\n")
    n = record.get("native", {})
    print(json.dumps({"exit": n.get("exit"), "amd": n.get("amd"), "delivery": n.get("delivery_ok"), "order": n.get("order_ok"), "flags": [n.get("movement_flags"), n.get("integrity_flags")],
                      "game": n.get("game_last"), "identical": record.get("comparison", {}).get("identical"), "mp4_bytes": record.get("mp4", {}).get("bytes")}, indent=1, default=str))


# --- os input ---------------------------------------------------------------------------------

class Session:
    """one game on the private display, its observer and the actor's input helpers."""

    def __init__(self, display, env, out, scratch, report, deadline):
        self.display, self.env, self.out, self.scratch, self.report, self.deadline = display, env, out, scratch, report, deadline
        self.game = self.gpu = self.window = self.xt = self.recorder = None
        self.observer = scratch / "observer"
        self.observer.mkdir()
        self.actions = report["actions"]

    def run(self, cmd, timeout=8, check=True):
        if time.monotonic() > self.deadline:
            raise TimeoutError("global budget")
        return subprocess.run(cmd, env=self.env, capture_output=True, text=True, timeout=timeout, check=check)

    def xdo(self, *parts, check=True):
        assert self.env["DISPLAY"] == self.display.display and 190 <= self.display.number <= 199
        return self.run(["xdotool", *map(str, parts)], check=check)

    def latest(self):
        try:
            return json.loads((self.observer / "latest.json").read_text())
        except (OSError, ValueError):
            return {}

    def wait(self, predicate, seconds=10, what="condition", each=None):
        until = min(self.deadline, time.monotonic() + seconds)
        while time.monotonic() < until:
            row = self.latest()
            if row and predicate(row):
                return row
            if self.game.poll() is not None:
                raise RuntimeError("game exited %s" % self.game.returncode)
            if each is not None and row:
                each(row)
            time.sleep(.003)
        raise TimeoutError("%s timed out; latest=%r" % (what, {k: self.latest().get(k) for k in ("t", "p", "v", "g", "lab")}))

    def launch(self):
        cmd = [str(GODOT), "--path", str(PROJECT), "--verbose", "--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3",
               "--windowed", "--resolution", "1280x720", "--script", "res://tests/r15_experiment_observer_game.gd", "--", "--no-records", "--observer=" + str(self.observer)]
        self.report["command"] = cmd
        self.log = (self.out / "osinput-engine.log").open("w")
        self.game = subprocess.Popen(cmd, cwd=self.scratch, env=self.env, stdout=self.log, stderr=subprocess.STDOUT, start_new_session=True,
                                     preexec_fn=nd._owned_child(os.getpid()))
        self.gpu = nd.GpuWatch().follow(self.game.pid)
        self.wait(lambda r: r.get("g") and r.get("t", 0) > 30, 60, "game ready")
        self.window = self.xdo("search", "--onlyvisible", "--name", "EXPERIMENTAL").stdout.split()[0]
        self.xdo("windowfocus", self.window)
        time.sleep(.3)
        self.xdo("keyup", "w", "a", "s", "d", "space", "Shift_L", "e", "Control_L", check=False)

    def act(self, label, *parts):
        row = self.latest()
        self.actions.append({"label": label, "xdotool": [str(p) for p in parts], "at_tick": row.get("t"), "feet_m": row.get("p"), "wall_s": round(time.monotonic() - self.t0, 3)})
        self.xdo(*parts)

    def tap(self, label, key, hold=.02):
        self.act(label + " down", "keydown", key)
        time.sleep(hold)
        self.act(label + " up", "keyup", key)

    def mouse(self, dx, dy):
        if self.xt is None:
            x11 = ctypes.CDLL("libX11.so.6")
            xt = ctypes.CDLL("libXtst.so.6")
            x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
            x11.XOpenDisplay.restype = ctypes.c_void_p
            x11.XFlush.argtypes = [ctypes.c_void_p]
            x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
            xt.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
            handle = x11.XOpenDisplay(self.display.display.encode())
            assert handle
            self.x11, self.xtst, self.xt = x11, xt, handle
        assert self.xtst.XTestFakeRelativeMotionEvent(self.xt, int(dx), int(dy), 0)
        self.x11.XFlush(self.xt)
        self.report["mouse_events"] += 1

    def steer(self, row, target, step=6):
        """one small relative motion toward `target` (a world point), as a player tracks it."""
        p, eye = row["p"], row.get("eye_m", 1.6)
        to = [target[0] - p[0], target[1] - (p[1] + eye), target[2] - p[2]]
        want_yaw = math.atan2(-to[0], -to[2])
        want_pitch = math.atan2(to[1], math.hypot(to[0], to[2]))
        per = row["per_px_rad"]
        dx = (math.remainder(row["yaw"] - want_yaw, math.tau)) / per
        dy = (row["pitch"] - want_pitch) / per
        dx, dy = max(-step, min(step, round(dx * .5))), max(-step, min(step, round(dy * .5)))
        if dx or dy:
            self.mouse(dx, dy)
            time.sleep(.004)
        return abs(dx) + abs(dy)

    def record(self, seconds):
        path = self.out / "osinput.mp4"
        cmd = ["ffmpeg", "-v", "error", "-y", "-f", "x11grab", "-framerate", "30", "-video_size", "1296x736", "-i", self.display.display,
               "-t", str(seconds), "-vf", "scale=960:-2", "-c:v", "libx264", "-preset", "veryfast", "-crf", "30", "-pix_fmt", "yuv420p", str(path)]
        self.report["recorder"] = cmd
        self.recorder = subprocess.Popen(cmd, env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
                                         preexec_fn=nd._owned_child(os.getpid()))

    def shot(self, label):
        path = self.out / ("osinput-%s.jpg" % label)
        row = self.latest()
        self.run(["ffmpeg", "-v", "error", "-y", "-f", "x11grab", "-video_size", "1296x736", "-i", self.display.display, "-frames:v", "1", "-q:v", "5", str(path)], timeout=15)
        self.report["shots"].append({"file": path.name, "tick": row.get("t"), "feet_m": row.get("p"), "lab": row.get("lab")})

    def close(self):
        if self.game and self.game.poll() is None:
            self.xdo("keyup", "w", "a", "s", "d", "space", "Shift_L", "e", check=False)
            (self.observer / "quit").write_text("1")
            try:
                self.game.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
        if self.recorder:
            try:
                self.recorder.wait(timeout=30)
            except subprocess.TimeoutExpired:
                nd._stop_group(self.recorder)
        if self.game:
            nd._stop_group(self.game)
        if self.gpu:
            self.gpu.stop()
        self.log.close()
        self.report["exit"] = self.game.returncode if self.game else None
        self.report["gpu"] = self.gpu.verdict() if self.gpu else None
        text = (self.out / "osinput-engine.log").read_text(errors="replace")
        self.report["device"] = nd.godot_device(text)
        self.report["engine_errors"] = [l for l in text.splitlines() if "ERROR" in l][:5]
        lines = text.splitlines()
        (self.out / "osinput-engine.log").write_text("\n".join(lines[:80] + ["..."] + lines[-40:]) + "\n")
        telemetry = self.observer / "telemetry.jsonl"
        if telemetry.exists():
            with telemetry.open("rb") as source, gzip.open(self.out / "osinput-telemetry.jsonl.gz", "wb", compresslevel=9) as target:
                shutil.copyfileobj(source, target)
        if self.xt:
            self.x11.XCloseDisplay(self.xt)


def line(s):
    """the combined line by os input: slide the rack, climb the chamber, swing from A1, finish."""
    s.record(40)
    s.t0 = time.monotonic()
    time.sleep(.5)
    s.act("click to capture the mouse", "click", "1")
    s.wait(lambda r: r.get("mouse_captured"), 5, "mouse captured")
    yaw0 = s.latest()["yaw"]
    s.mouse(4, 0)
    s.wait(lambda r: r["yaw"] != yaw0, 3, "xtest motion turns the view")
    s.report["mouse_turns_view"] = True
    s.wait(lambda r: abs(s.steer(r, (0.0, r["p"][1] + r["eye_m"], -60.0), 3)) == 0, 5, "face down the hall")
    s.act("R: clean attempt from the spawn", "key", "r")
    time.sleep(.2)
    s.act("run", "keydown", "w")
    s.wait(lambda r: r["p"][2] < -20.9, 20, "slide mark")
    s.act("slide", "keydown", "Shift_L")
    s.shot("slide-entry")
    s.wait(lambda r: r["p"][2] < -24.5, 5, "under the rack")
    s.shot("slide-under-rack")
    s.wait(lambda r: r["p"][2] < -27.45 and r["g"], 5, "past the rack")
    s.tap("jump the trench", "space")
    s.act("end slide", "keyup", "Shift_L")
    s.wait(lambda r: r["g"] and r["p"][2] < -30.6, 5, "landed past the trench")
    s.wait(lambda r: r["p"][2] < -45.0, 10, "chamber mouth")
    s.act("hug the west face", "keydown", "a")
    s.wait(lambda r: r["p"][2] < -50.3, 10, "climb mark")
    s.tap("jump", "space")
    s.wait(lambda r: not r["g"] and r["v"][1] / U < 30.0, 3, "top of the jump")
    s.act("off the west face", "keyup", "a")
    s.tap("wall jump west", "space")
    s.wait(lambda r: r["p"][0] > 1.6 - 0.405 - 0.03, 3, "east face")
    s.tap("wall jump east", "space")
    s.shot("wall-jump-east")
    s.tap("check the push", "d", .016)
    s.wait(lambda r: r["g"] and r["p"][1] > 3.0, 5, "on the mezzanine")
    a1 = A1
    s.wait(lambda r: r["p"][2] < -69.6, 10, "mezzanine edge", each=lambda r: s.steer(r, a1, 8))
    s.tap("jump off the edge", "space")
    s.wait(lambda r: r["lab"]["target"] == "ok", 2, "A1 targeted", each=lambda r: s.steer(r, a1, 12))
    s.act("grapple", "keydown", "e")
    s.wait(lambda r: r["lab"]["line"], 1, "latched")
    s.shot("grapple-swing")
    s.wait(lambda r: r["p"][2] < -83.0 or r["g"], 4, "far side of the swing")
    s.act("release", "keyup", "e")
    s.wait(lambda r: r["finished"], 10, "finish")
    s.shot("finish")
    s.act("stop", "keyup", "w")
    time.sleep(1.0)


def analyze(out, report):
    rows = []
    path = out / "osinput-telemetry.jsonl.gz"
    if path.exists():
        with gzip.open(path, "rt") as f:
            rows = [json.loads(l) for l in f if l.strip()]
    last = rows[-1] if rows else {}
    counts = last.get("lab", {}).get("counts", {})
    gpu, device = report.get("gpu") or {}, report.get("device") or {}
    return {
        "game ran on the lab runner": bool(rows) and all(r["runner"] == "res://scripts/r15_experiment_player.gd" and r["map"] == "experiment" for r in rows),
        "the game rendered on the amd render node": bool(gpu.get("ok")) and "AMD" in device.get("device", ""),
        "xtest relative motion turned the view": bool(report.get("mouse_turns_view")),
        "slide, two wall jumps and a grapple fired": counts.get("slide", 0) >= 1 and counts.get("wall_jump", 0) >= 2 and counts.get("grapple", 0) >= 1,
        "the line finished clean with no respawn": last.get("finished") is True and last.get("kind") == "clean" and last.get("respawns") == 0,
        "no engine errors": not report.get("engine_errors"),
        "recorded a moving native view": (out / "osinput.mp4").exists() and (out / "osinput.mp4").stat().st_size > 50000,
    }


def osinput(args):
    out = args.evidence.resolve()
    out.mkdir(parents=True, exist_ok=False)
    report = {"actions": [], "shots": [], "mouse_events": 0, "identity": identity(), "limitations": [
        "XTest and xdotool are OS synthetic input on a private display, not physical-device latency or feel.",
        "The actor reads observer telemetry to time presses and to track the anchor (coordinate-aware), like a player watching the screen.",
        "Source checkout run of uncommitted files, not a pack."]}
    scratch = None
    deadline = time.monotonic() + 240
    try:
        report["home_free_before"] = require_space()
        scratch = Path(tempfile.mkdtemp(prefix="r15-lab-os-", dir="/dev/shm"))
        env = profile_env(scratch)
        with nd.NativeDisplay(out / "display", displays=range(190, 200)) as display:
            report["display"] = display.display
            session = Session(display, display.child_env(env), out, scratch, report, deadline)
            try:
                session.launch()
                line(session)
            except BaseException as error:
                report["failure"] = {"type": type(error).__name__, "message": str(error), "traceback": traceback.format_exc()[-1500:]}
            finally:
                session.close()
        report["display_released"] = display.released
        report["checks"] = analyze(out, report)
        report["passed"] = all(report["checks"].values()) and "failure" not in report
    except BaseException as error:
        report.setdefault("failure", {"type": type(error).__name__, "message": str(error), "traceback": traceback.format_exc()[-1500:]})
    finally:
        if scratch and scratch.exists():
            report["records_created"] = [str(p.relative_to(scratch)) for p in (scratch / "data").rglob("*") if p.is_file()]
            shutil.rmtree(scratch)
            report["scratch_removed"] = not scratch.exists()
        report["home_free_after"] = shutil.disk_usage(Path.home()).free
        report["evidence_bytes"] = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
        (out / "run.json").write_text(json.dumps(report, indent=1, default=str) + "\n")
    print(json.dumps({k: report.get(k) for k in ["failure", "passed", "checks", "display_released", "scratch_removed", "evidence_bytes"]}, indent=1, default=str))
    return 0 if report.get("passed") else 1


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="mode", required=True)
    m = sub.add_parser("movie")
    m.add_argument("--evidence", type=Path, required=True)
    m.add_argument("--tape", type=Path, required=True)
    m.add_argument("--fps", type=int, default=64)
    m.add_argument("--crf", type=int, default=30)
    m.add_argument("--wall", type=int, default=600)
    o = sub.add_parser("osinput")
    o.add_argument("--evidence", type=Path, required=True)
    args = p.parse_args()
    return {"movie": movie, "osinput": osinput}[args.mode](args) or 0


if __name__ == "__main__":
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("outer alarm")))
    signal.alarm(900)
    raise SystemExit(main())
