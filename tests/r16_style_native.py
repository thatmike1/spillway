#!/usr/bin/env python3
"""p / R16 style panel native evidence on the private AMD/X11 display (tools/r14_native_display.py).

tests/r16_style_views.gd on the actual r15 main with its hud and the style panel, from the
player's own camera: strafe run with sync callouts and the multiplier to the finish, a ground
crouch save, the pause menu. one launch per resolution; the first also writes a movie (AVI in
/dev/shm, encoded to MP4, AVI deleted). selected JPEGs are the views script's own frames.

every launch needs /home >= 15 GiB free and a new evidence directory; nothing falls back to
software rendering. records are off; user data is scratch.

python3 -I tests/r16_style_native.py --evidence DIR --project SRC [--sizes 1280x720,1920x1080] [--crf 30]
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
spec = importlib.util.spec_from_file_location("style_nd", HERE / "tools/r14_native_display.py")
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)
owner_spec = importlib.util.spec_from_file_location("style_owner", HERE / "tools/package-r14.py")
owner = importlib.util.module_from_spec(owner_spec)
owner_spec.loader.exec_module(owner)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def scratch_env(scratch):
    env = dict(os.environ)
    for name in ["data", "config", "cache", "state"]:
        (scratch / name).mkdir(parents=True, exist_ok=True)
        env["XDG_%s_HOME" % name.upper()] = str(scratch / name)
    return env


def launch(evidence, project, size, scratch, movie, fps):
    free = shutil.disk_usage("/home").free
    if free < FLOOR:
        raise SystemExit("HOME has %.2f GiB free, below 15 GiB: nothing launched" % (free / 2 ** 30))
    run = scratch / "run"
    args = ["--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed", "--resolution", size,
            "--fixed-fps", str(fps)]
    if movie:
        args += ["--write-movie", str(scratch / "movie.avi")]
    args += ["--path", str(project), "--script", "res://tests/r16_style_views.gd", "--", "--out=%s" % run, "--no-records"]
    record = {"size": size, "home_free_before": free, "godot": str(GODOT), "godot_sha256": sha(GODOT), "fixed_fps": fps}
    with nd.NativeDisplay(evidence / "display", displays=range(190, 200)) as display:
        env = display.child_env(scratch_env(scratch))
        record["command"] = [str(GODOT), *args]
        record["display"] = display.display
        watch = display.gpu_watch()
        started = time.monotonic()
        try:
            record["exit"], _text = owner.run_engine([str(GODOT), *args], scratch, env, evidence / "engine.log", 900, watch=watch)
        finally:
            watch.stop()
        record["wall_s"] = round(time.monotonic() - started, 2)
        record["gpu"] = watch.verdict()
        text = (evidence / "engine.log").read_text(errors="replace")
        record["device"] = nd.godot_device(text)
        record["amd"] = record["gpu"]["ok"] and record["device"] is not None and "AMD" in record["device"].get("device", "")
    record["display_released"] = True
    record["home_free_after"] = shutil.disk_usage("/home").free
    return record, run


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--project", type=Path, required=True)
    p.add_argument("--sizes", default="1280x720,1920x1080")
    p.add_argument("--fps", type=int, default=32)
    p.add_argument("--crf", type=int, default=30)
    a = p.parse_args()
    root = a.evidence.resolve()
    root.mkdir(parents=True, exist_ok=False)
    out = {"label": "player camera + r15 hud + r16 style panel on the r15 main hosting the labelled style fixture; key and mouse events only",
           "views_sha256": sha(a.project / "tests/r16_style_views.gd"), "style_sha256": sha(a.project / "scripts/r16_style.gd"),
           "panel_sha256": sha(a.project / "scripts/r16_style_panel.gd"), "runs": []}
    for i, size in enumerate(a.sizes.split(",")):
        evidence = root / size
        evidence.mkdir()
        scratch = Path(tempfile.mkdtemp(prefix="r16-style-native-", dir="/dev/shm"))
        try:
            record, run = launch(evidence, a.project.resolve(), size, scratch, movie=(i == 0), fps=a.fps)
            shots = json.loads((run / "shots.json").read_text())
            (evidence / "shots").mkdir()
            for shot in shots["shots"]:
                if shot.get("file"):
                    shutil.copy2(run / shot["file"], evidence / shot["file"])
            (evidence / "shots.json").write_text(json.dumps(shots, indent=1) + "\n")
            record["shots"] = {s.name: sha(s) for s in sorted((evidence / "shots").glob("*.jpg"))}
            avi = scratch / "movie.avi"
            if avi.exists():
                mp4 = evidence / "movie.mp4"
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-an", "-c:v", "libx264", "-preset", "slow", "-crf", str(a.crf),
                                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)], check=True)
                probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=width,height,nb_frames", "-of", "json", str(mp4)],
                                       capture_output=True, text=True)
                record["mp4"] = {"probe": json.loads(probe.stdout), "bytes": mp4.stat().st_size, "sha256": sha(mp4), "avi_bytes_deleted": avi.stat().st_size}
                avi.unlink()
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
        record["scratch_removed"] = not scratch.exists()
        (evidence / "run.json").write_text(json.dumps(record, indent=1) + "\n")
        out["runs"].append({k: record.get(k) for k in ["size", "exit", "amd", "device", "wall_s", "mp4"]} | {"shots": len(record.get("shots", {}))})
        print(size, "exit", record.get("exit"), "amd", record.get("amd"), "shots", len(record.get("shots", {})))
    (root / "native.json").write_text(json.dumps(out, indent=1) + "\n")


if __name__ == "__main__":
    main()
