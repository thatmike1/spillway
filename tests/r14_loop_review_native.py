#!/usr/bin/env python3
"""private native default launch and OS input review, bounded MP4 and selected PNGs."""
import argparse
import hashlib
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
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    free = shutil.disk_usage(Path.home()).free
    if free < 15 * 2**30:
        raise SystemExit("refused native capture: /home below 15 GiB")
    display = next(n for n in range(160, 200) if not Path(f"/tmp/.X11-unix/X{n}").exists() and not Path(f"/tmp/.X{n}-lock").exists())
    xvfb = game = movie = None
    report = {"free_home_before": free, "display": display, "events": [], "launch": [str(GODOT), "--audio-driver", "Dummy", "--path", str(PROJECT)]}
    with tempfile.TemporaryDirectory(prefix="r14-loop-native-") as profile:
        env = dict(os.environ, DISPLAY=f":{display}", XDG_DATA_HOME=f"{profile}/data", XDG_CONFIG_HOME=f"{profile}/config", XDG_CACHE_HOME=f"{profile}/cache", LIBGL_ALWAYS_SOFTWARE="1")
        env.pop("WAYLAND_DISPLAY", None)
        env.pop("PULSE_SERVER", None)

        def run(*cmd, **kw):
            return subprocess.run(cmd, env=env, check=True, capture_output=True, text=True, **kw)

        def event(name):
            report["events"].append({"name": name, "seconds": round(time.monotonic() - started, 4), "title": run("xdotool", "getwindowname", window).stdout.strip()})

        def snap(name):
            run("ffmpeg", "-v", "error", "-y", "-f", "x11grab", "-video_size", "1280x720", "-i", f":{display}", "-frames:v", "1", str(out / f"{name}.png"))
            event(name)

        def key(*keys):
            run("xdotool", "key", "--clearmodifiers", *keys)

        def click(x, y):
            run("xdotool", "mousemove", "--window", window, str(x), str(y), "click", "1")
            time.sleep(0.15)

        try:
            xvfb = subprocess.Popen(["Xvfb", f":{display}", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-noreset"], stdout=subprocess.DEVNULL, stderr=open(out / "xvfb.log", "w"))
            for _ in range(100):
                if Path(f"/tmp/.X11-unix/X{display}").exists():
                    break
                time.sleep(0.03)
            game = subprocess.Popen(report["launch"], env=env, stdout=open(out / "game.log", "w"), stderr=subprocess.STDOUT, start_new_session=True)
            window = ""
            for _ in range(200):
                search = subprocess.run(["xdotool", "search", "--onlyvisible", "--pid", str(game.pid)], env=env, capture_output=True, text=True)
                if search.stdout.strip():
                    window = search.stdout.strip().splitlines()[0]
                    break
                time.sleep(0.05)
            if not window:
                raise RuntimeError("no native Godot window")
            for _ in range(600):
                if "r14: build=" in (out / "game.log").read_text():
                    break
                if game.poll() is not None:
                    raise RuntimeError("game exited during startup")
                time.sleep(0.05)
            else:
                raise RuntimeError("R14 scene did not finish startup")
            time.sleep(12.0)
            run("xdotool", "windowfocus", window)
            movie = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "x11grab", "-video_size", "1280x720", "-framerate", "30", "-i", f":{display}", "-an", "-c:v", "libx264", "-preset", "ultrafast", "-crf", "27", "-pix_fmt", "yuv420p", str(out / "default-native.mp4")], env=env, stdout=subprocess.DEVNULL, stderr=open(out / "capture.log", "w"))
            started = time.monotonic()
            time.sleep(1)
            snap("01-default")
            if (out / "01-default.png").stat().st_size < 100_000:
                raise RuntimeError("default frame still resembles startup splash; exclude run")
            run("xdotool", "keydown", "w")
            time.sleep(0.7)
            run("xdotool", "keyup", "w", "keydown", "space")
            time.sleep(0.12)
            key("F1")
            run("xdotool", "keyup", "space")
            snap("02-midair-vanilla")
            key("F3")
            time.sleep(0.1)
            snap("03-r13")
            key("F2")
            time.sleep(0.5)
            snap("04-server")
            key("Escape")
            time.sleep(0.3)
            snap("05-menu")
            click(200, 225)
            snap("06-preset-click")
            run("xdotool", "mousemove", "300", "400", "click", "--repeat", "12", "--delay", "40", "5")
            time.sleep(0.3)
            snap("07-menu-bottom")
            # these coordinates deliberately exercise visible settings through OS mouse events.
            click(400, 365)
            snap("08-setting-click")
            key("Escape")
            time.sleep(0.3)
            snap("09-resume")
            key("r")
            time.sleep(0.3)
            snap("10-restart")
            run("xdotool", "keydown", "w")
            time.sleep(0.8)
            run("xdotool", "keyup", "w", "keydown", "space", "keydown", "a")
            for _ in range(10):
                run("xdotool", "mousemove_relative", "--", "-10", "0")
                time.sleep(0.04)
            snap("11-native-strafe")
            run("xdotool", "keyup", "a", "keyup", "space")
            time.sleep(0.7)
            snap("12-native-hop-feedback")
            key("Escape")
            run("xdotool", "mousemove", "300", "400", "click", "--repeat", "12", "--delay", "40", "5")
            time.sleep(0.2)
            click(200, 255)
            time.sleep(0.3)
            snap("13-map-overflow")
            # persist only the review profile's cfg as evidence, then remove its directory.
            configs = list(Path(profile).rglob("*.cfg"))
            report["profile_cfgs"] = {str(p.relative_to(profile)): p.read_text() for p in configs}
        finally:
            if movie and movie.poll() is None:
                movie.send_signal(signal.SIGINT)
                movie.wait(timeout=10)
            if game and game.poll() is None:
                os.killpg(game.pid, signal.SIGTERM)
                try:
                    game.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    os.killpg(game.pid, signal.SIGKILL)
                    game.wait()
            if xvfb:
                xvfb.terminate()
                xvfb.wait(timeout=8)
            report["cleanup"] = {"game_exit": game.poll() if game else None, "xvfb_exit": xvfb.poll() if xvfb else None, "socket_left": Path(f"/tmp/.X11-unix/X{display}").exists(), "lock_left": Path(f"/tmp/.X{display}-lock").exists()}
    report["profile_removed"] = not Path(profile).exists()
    report["bytes"] = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    report["hashes"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
    (out / "run.json").write_text(json.dumps(report, indent=2))
    print(json.dumps({"events": report["events"], "cleanup": report["cleanup"], "bytes": report["bytes"]}, indent=2))


if __name__ == "__main__":
    main()
