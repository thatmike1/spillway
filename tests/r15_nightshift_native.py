#!/usr/bin/env python3
"""p / Night Shift native evidence on the private AMD/X11 display (tools/r14_native_display.py).

views: the fixed authored cameras of tests/r15_nightshift_views.gd, saved as JPEGs. not the
       player's camera; art and readability only.
movie: a version 2 tape from tests/r15_nightshift_driver.gd replayed OPEN LOOP through the same
       driver on the actual r15 main, rendered from the player's own camera with the hud, with
       godot's movie writer. the AVI lives in /dev/shm, is encoded to an MP4 here, selected
       frames are cut to JPEG, and the AVI is deleted. the replay's trace is compared tick for
       tick with a headless replay of the same tape.

every launch needs /home >= 15 GiB free and an empty evidence directory; nothing falls back to
software rendering (the helper refuses). records are off; profiles are scratch.

python3 -I tests/r15_nightshift_native.py views --evidence DIR
python3 -I tests/r15_nightshift_native.py movie --evidence DIR --tape TAPE [--frames 3,12,30] [--crf 30]
"""
import argparse
import gzip
import hashlib
import importlib.util
import json
import math
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
FLOOR = 15 * 2 ** 30
spec = importlib.util.spec_from_file_location("ns_nd", PROJECT / "tools/r14_native_display.py")
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
# reuse the verified process-group owner, including deferred launch/cancel cleanup.
owner_spec = importlib.util.spec_from_file_location("ns_owner", PROJECT / "tools/package-r14.py")
owner = importlib.util.module_from_spec(owner_spec)
owner_spec.loader.exec_module(owner)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def home_free():
    return shutil.disk_usage("/home").free


def godot(args, env, cwd, log, timeout):
    code, _text = owner.run_engine([str(GODOT), *args], cwd, env, log, timeout)
    return None, code


def scratch_env(scratch):
    env = {k: v for k, v in os.environ.items()}
    for name in ["data", "config", "cache", "state"]:
        (scratch / name).mkdir(parents=True, exist_ok=True)
        env["XDG_%s_HOME" % name.upper()] = str(scratch / name)
    return env


def native_run(evidence, args, scratch, timeout):
    """one godot launch on the private display, watched for amd rendering."""
    free = home_free()
    if free < FLOOR:
        raise SystemExit("HOME has %.2f GiB free, below 15 GiB: nothing launched" % (free / 2 ** 30))
    record = {"home_free_before": free, "godot": str(GODOT), "godot_sha256": sha(GODOT)}
    with nd.NativeDisplay(evidence / "display", displays=range(190, 200)) as display:
        env = display.child_env(scratch_env(scratch))
        cmd = ["--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed", "--resolution", "1280x720", *args]
        record["command"] = [str(GODOT), *cmd]
        record["display"] = display.display
        watch = display.gpu_watch()
        started = time.monotonic()
        try:
            record["exit"], _text = owner.run_engine([str(GODOT), *cmd], scratch, env,
                                                   evidence / "engine.log", timeout, watch=watch)
        finally:
            watch.stop()
        record["process_owner_sha256"] = sha(PROJECT / "tools/package-r14.py")
        record["wall_s"] = round(time.monotonic() - started, 2)
        record["gpu"] = watch.verdict()
        text = (evidence / "engine.log").read_text(errors="replace")
        record["device"] = nd.godot_device(text)
        record["amd"] = record["gpu"]["ok"] and record["device"] is not None and "AMD" in record["device"].get("device", "")
    record["display_released"] = True
    record["home_free_after"] = home_free()
    return record


def views(args):
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    scratch = Path(tempfile.mkdtemp(prefix="ns-views-", dir="/dev/shm"))
    try:
        record = native_run(evidence, ["--path", str(PROJECT), "--script", "res://tests/r15_nightshift_views.gd", "--", "--out=%s" % (scratch / "views"), "--no-records"], scratch, 300)
        shots = sorted((scratch / "views").glob("*.jpg"))
        for shot in shots:
            shutil.copy2(shot, evidence / shot.name)
        record["label"] = "fixed authored cameras, not the player's camera; art and readability frames only"
        record["shots"] = {s.name: sha(evidence / s.name) for s in shots}
        record["views_script_sha256"] = sha(PROJECT / "tests/r15_nightshift_views.gd")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    record["scratch_removed"] = not scratch.exists()
    (evidence / "run.json").write_text(json.dumps(record, indent=1) + "\n")
    print("views", record.get("exit"), "amd", record.get("amd"), len(record.get("shots", {})))


def compare(a, b):
    # the driver's samples round positions to 1 mm and velocities to 0.001 u/s.
    # compare every captured field, not a zip of potentially incomplete vectors.
    rows = []
    def finite(value):
        if isinstance(value, dict):
            return all(finite(v) for v in value.values())
        if isinstance(value, list):
            return all(finite(v) for v in value)
        return not isinstance(value, float) or math.isfinite(value)
    for path in (a, b):
        with gzip.open(path, "rt") as f:
            captured = [json.loads(line) for line in f if line.strip()]
        for tick, row in enumerate(captured):
            if type(row.get("t")) is not int or row["t"] != tick or not finite(row):
                raise ValueError("invalid trace tick or nonfinite value")
            for key in ("p", "v"):
                if not isinstance(row.get(key), list) or len(row[key]) != 3 or not all(type(n) in (int, float) for n in row[key]):
                    raise ValueError("invalid three-component vector")
        rows.append(captured)
    worst = {"p": 0.0, "v": 0.0, "yaw": 0.0}
    different = []
    for tick, (x, y) in enumerate(zip(*rows)):
        for key in ("p", "v"):
            worst[key] = max(worst[key], max(abs(i - j) for i, j in zip(x[key], y[key])))
        worst["yaw"] = max(worst["yaw"], abs(x["yaw"] - y["yaw"]))
        if x != y:
            different.append(tick)
    return {"ticks": [len(rows[0]), len(rows[1])], "max_abs_diff": worst,
            "different_sample_ticks": different, "identical": bool(rows[0]) and len(rows[0]) == len(rows[1]) and not different,
            "precision": "driver samples: p 0.001 m, v 0.001 u/s, yaw 0.000001 rad; all fields compared"}


def movie(args):
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    tape = args.tape.resolve()
    scratch = Path(tempfile.mkdtemp(prefix="ns-movie-", dir="/dev/shm"))
    record = {"label": "OPEN LOOP replay of a driver tape on the actual r15 main hosting Night Shift; the player's own camera and hud; key and mouse events only after the main's labelled spawn",
              "tape": str(tape), "tape_sha256": sha(tape), "driver_sha256": sha(PROJECT / "tests/r15_nightshift_driver.gd")}
    try:
        # the headless reference replay of the same tape first.
        head = scratch / "headless"
        proc, code = godot(["--headless", "--audio-driver", "Dummy", "--path", str(PROJECT), "--script", "res://tests/r15_nightshift_driver.gd", "--",
                            "--out=%s" % head, "--tape=%s" % tape, "--no-records"], scratch_env(scratch / "h"), scratch, (evidence / "headless.log"), 600)
        record["headless_exit"] = code
        run = scratch / "native"
        avi = scratch / "movie.avi"
        record["native"] = native_run(evidence, ["--fixed-fps", str(args.fps), "--write-movie", str(avi), "--path", str(PROJECT), "--script", "res://tests/r15_nightshift_driver.gd", "--",
                                                 "--out=%s" % run, "--tape=%s" % tape, "--no-records"], scratch, args.wall)
        for name in ["summary.json", "trace.jsonl.gz"]:
            shutil.copy2(run / name, evidence / name)
        shutil.copy2(head / "summary.json", evidence / "headless-summary.json")
        record["compare_headless_native"] = compare(head / "trace.jsonl.gz", run / "trace.jsonl.gz")
        summary = json.loads((run / "summary.json").read_text())
        record["outcome"] = {k: summary.get(k) for k in ["reason", "finish_kind", "finish_time_s", "respawns", "respawn_events", "checkpoints", "max_display_speed_ups", "min_y"]}
        mp4 = evidence / "movie.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-an", "-c:v", "libx264", "-preset", "slow", "-crf", str(args.crf), "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)], check=True)
        probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=width,height,nb_frames", "-of", "json", str(mp4)], capture_output=True, text=True)
        record["mp4"] = {"probe": json.loads(probe.stdout), "bytes": mp4.stat().st_size, "sha256": sha(mp4), "avi_bytes_deleted": avi.stat().st_size, "fps": args.fps, "crf": args.crf}
        for t in [float(s) for s in args.frames.split(",") if s]:
            shot = evidence / ("frame-%05.1fs.jpg" % t)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(t), "-i", str(mp4), "-frames:v", "1", "-q:v", "4", str(shot)], check=True)
        avi.unlink()
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    record["scratch_removed"] = not scratch.exists()
    (evidence / "run.json").write_text(json.dumps(record, indent=1) + "\n")
    print("movie", record["native"].get("exit"), "amd", record["native"].get("amd"), record.get("outcome"), record.get("compare_headless_native", {}).get("identical"))


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="mode", required=True)
    v = sub.add_parser("views")
    v.add_argument("--evidence", type=Path, required=True)
    m = sub.add_parser("movie")
    m.add_argument("--evidence", type=Path, required=True)
    m.add_argument("--tape", type=Path, required=True)
    m.add_argument("--frames", default="2,10,20,30,40")
    m.add_argument("--fps", type=int, default=32)
    m.add_argument("--crf", type=int, default=30)
    m.add_argument("--wall", type=int, default=900)
    args = p.parse_args()
    {"views": views, "movie": movie}[args.mode](args)


if __name__ == "__main__":
    main()
