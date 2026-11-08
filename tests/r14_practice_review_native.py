#!/usr/bin/env python3
"""bounded private player-view capture of the review's local tail-ramp obstruction."""
import argparse
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time

PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--product", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    free = shutil.disk_usage(Path.home()).free
    if free < 15 * 2**30:
        raise SystemExit("native refused: less than 15 GiB free on /home")
    display = next(n for n in range(170, 200) if not Path(f"/tmp/.X11-unix/X{n}").exists() and not Path(f"/tmp/.X{n}-lock").exists())
    report = {"free_bytes_before": free, "display": display}
    xvfb = game = None
    with tempfile.TemporaryDirectory(prefix="r14-practice-review-profile-") as profile:
        env = dict(os.environ, DISPLAY=f":{display}", LIBGL_ALWAYS_SOFTWARE="1")
        for name in ["WAYLAND_DISPLAY", "PULSE_SERVER", "XAUTHORITY"]:
            env.pop(name, None)
        for name in ["DATA", "CONFIG", "CACHE", "STATE"]:
            env[f"XDG_{name}_HOME"] = str(Path(profile) / name.lower())
        try:
            with open(out / "xvfb.log", "w") as log:
                xvfb = subprocess.Popen(["Xvfb", f":{display}", "-screen", "0", "640x360x24", "-nolisten", "tcp", "-noreset"], stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            for _ in range(100):
                if Path(f"/tmp/.X11-unix/X{display}").exists():
                    break
                time.sleep(.03)
            command = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed", "--resolution", "640x360", "--fixed-fps", "30", "--script", "res://tests/r14_practice_review_contacts.gd", "--", f"--out={out}", "--only=tail128_x-227.8", "--visual=1"]
            if args.product:
                command[command.index("--fixed-fps") + 1] = "8"
                command[command.index("--script") + 1] = "res://tests/r14_practice_review_policy.gd"
                command = command[:command.index("--") + 1] + [f"--out={out}", "--preset=server128", "--route=g3_miss", "--seed=1", "--tail-edge=block", "--visual=1", "--max-ticks=15000"]
            report["command"] = command
            with open(out / "game.log", "w") as log:
                game = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                game.wait(timeout=240)
            report["exit"] = game.returncode
            if game.returncode:
                raise RuntimeError("native game failed")
        finally:
            for proc in [game, xvfb]:
                if proc and proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGTERM)
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait()
            report["cleanup"] = {"game_exit": game.poll() if game else None, "xvfb_exit": xvfb.poll() if xvfb else None, "socket_left": Path(f"/tmp/.X11-unix/X{display}").exists(), "lock_left": Path(f"/tmp/.X{display}-lock").exists()}
    report["profile_removed"] = not Path(profile).exists()
    report["bytes"] = sum(f.stat().st_size for f in out.rglob("*") if f.is_file())
    (out / "native.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
