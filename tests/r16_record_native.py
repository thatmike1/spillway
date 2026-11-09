#!/usr/bin/env python3
"""p / r16 ghost native sample on the private AMD/X11 display (tools/r14_native_display.py).

runs tests/r16_record_native.gd from a source copy with godot's movie writer, from the player's
own camera with the hud. the AVI stays in RAM scratch; selected frames are cut to JPEG. the MP4
is kept only when /home stays at least 15 GiB plus its size free, otherwise only the frames are.
nothing launches below 15 GiB free; nothing falls back to software rendering (the helper refuses).

python3 -I tests/r16_record_native.py --evidence DIR --project SRC [--frames 1,4,8,12] [--fps 32]
"""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
GODOT = Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
FLOOR = 15 * 2 ** 30
spec = importlib.util.spec_from_file_location("r16_nd", HERE / "tools/r14_native_display.py")
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
owner_spec = importlib.util.spec_from_file_location("r16_owner", HERE / "tools/package-r14.py")
owner = importlib.util.module_from_spec(owner_spec)
owner_spec.loader.exec_module(owner)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def home_free():
    return shutil.disk_usage("/home").free


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--frames", default="1,3,5,7,9,11,13")
    p.add_argument("--fps", type=int, default=32)
    p.add_argument("--crf", type=int, default=32)
    args = p.parse_args()
    free = home_free()
    if free < FLOOR:
        raise SystemExit("HOME has %.4f GiB free, below 15 GiB: nothing launched" % (free / 2 ** 30))
    scratch = Path(tempfile.mkdtemp(prefix="r16-ghost-native-", dir="/dev/shm"))
    work = scratch / "evidence"
    work.mkdir()
    record = {"label": "native ghost sample: the real R15 host on the labelled loop fixture, player camera and hud, key and mouse events through Input; visual check only",
              "home_free_before": free, "godot": str(GODOT), "godot_sha256": sha(GODOT), "project": str(args.project),
              "scripts": {n: sha(args.project / n) for n in ["tests/r16_record_native.gd", "tests/r16_record_adapter.gd", "scripts/r16_ghost.gd", "scripts/r16_run_recorder.gd", "scripts/r16_run_reader.gd"]}}
    try:
        env = {k: v for k, v in os.environ.items()}
        for name in ["data", "config", "cache", "state"]:
            (scratch / name).mkdir()
            env["XDG_%s_HOME" % name.upper()] = str(scratch / name)
        avi = scratch / "movie.avi"
        run = scratch / "run"
        with nd.NativeDisplay(work / "display", displays=range(190, 200)) as display:
            cmd = [str(GODOT), "--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed", "--resolution", "1280x720",
                   "--fixed-fps", str(args.fps), "--write-movie", str(avi), "--path", str(args.project), "--script", "res://tests/r16_record_native.gd", "--", "--out=%s" % run]
            record["command"] = cmd
            record["display"] = display.display
            watch = display.gpu_watch()
            started = time.monotonic()
            try:
                record["exit"], _text = owner.run_engine(cmd, scratch, display.child_env(env), work / "engine.log", 600, watch=watch)
            finally:
                watch.stop()
            record["wall_s"] = round(time.monotonic() - started, 2)
            record["gpu"] = watch.verdict()
            text = (work / "engine.log").read_text(errors="replace")
            record["device"] = nd.godot_device(text)
            record["amd"] = record["gpu"]["ok"] and record["device"] is not None and "AMD" in record["device"].get("device", "")
        record["display_released"] = True
        summary = json.loads((run / "summary.json").read_text())
        (work / "summary.json").write_text(json.dumps(summary, indent=1))
        record["ghost_load"] = summary.get("ghost_load")
        mp4 = scratch / "movie.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-an", "-vf", "scale=960:-2", "-c:v", "libx264", "-preset", "slow", "-crf", str(args.crf), "-pix_fmt", "yuv420p",
                        "-movflags", "+faststart", str(mp4)], check=True)
        probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=width,height,nb_frames", "-of", "json", str(mp4)], capture_output=True, text=True)
        record["mp4"] = {"probe": json.loads(probe.stdout), "bytes": mp4.stat().st_size, "sha256": sha(mp4), "avi_bytes_deleted": avi.stat().st_size}
        avi.unlink()
        for t in [float(s) for s in args.frames.split(",") if s]:
            shot = work / ("frame-%04.1fs.jpg" % t)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(t), "-i", str(mp4), "-frames:v", "1", "-q:v", "5", str(shot)], check=True)
        frames = sum(f.stat().st_size for f in work.glob("*.jpg"))
        keep_mp4 = home_free() - frames - mp4.stat().st_size - 200_000 >= FLOOR
        if keep_mp4:
            shutil.copy2(mp4, work / "movie.mp4")
        record["mp4"]["retained"] = keep_mp4
        record["mp4"]["note"] = "kept beside the frames" if keep_mp4 else "not retained: /home would fall below 15 GiB free; frames only"
        if home_free() - sum(f.stat().st_size for f in work.rglob("*") if f.is_file()) < FLOOR - 2 * 2 ** 20:
            raise SystemExit("evidence would take /home below the floor; left in %s" % work)
        args.evidence.mkdir(parents=True, exist_ok=False)
        for f in work.rglob("*"):
            if f.is_file():
                target = args.evidence / f.relative_to(work)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, target)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    record["scratch_removed"] = not scratch.exists()
    record["home_free_after"] = home_free()
    (args.evidence / "run.json").write_text(json.dumps(record, indent=1) + "\n")
    print("native", record.get("exit"), "amd", record.get("amd"), "ghost", (record.get("ghost_load") or {}).get("ok"), "mp4 kept", record["mp4"]["retained"])


if __name__ == "__main__":
    main()
