#!/usr/bin/env python3
"""p / native r14 ui tour: runs tests/test_r14_loop_tour.gd on a private Xvfb with Dummy audio and
an isolated XDG profile, polls the X window title, encodes the bounded movie to MP4, checks
the frames, gzips the per-tick trace after verifying its hash, and removes every process it
started. evidence of presentation only: not a course route, timing or feel claim.

python3 tests/test_r14_loop_native.py --out DIR [--godot PATH] [--resolution 960x540]
exit 0 ok, 1 a check failed, 3 refused (free space below the floor).
"""
import argparse
import ctypes
import gzip
import hashlib
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
MIN_FREE_GIB = 15.0
MAX_MOVIE_MIB = 1500


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def free_display() -> int:
    for n in range(140, 200):
        if not Path(f"/tmp/.X11-unix/X{n}").exists() and not Path(f"/tmp/.X{n}-lock").exists():
            return n
    raise RuntimeError("no free display number")


def window_titles(display: int) -> list:
    """names of the top-level windows on a display, read through libX11 (no x11 utilities needed)."""
    x = ctypes.CDLL("libX11.so.6")
    x.XOpenDisplay.restype = ctypes.c_void_p
    x.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x.XDefaultRootWindow.restype = ctypes.c_ulong
    x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong),
                             ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_uint)]
    x.XFetchName.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_char_p)]
    x.XCloseDisplay.argtypes = [ctypes.c_void_p]
    dpy = x.XOpenDisplay(f":{display}".encode())
    if not dpy:
        return []
    names = []
    root, parent = ctypes.c_ulong(), ctypes.c_ulong()
    children, count = ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
    if x.XQueryTree(dpy, x.XDefaultRootWindow(dpy), ctypes.byref(root), ctypes.byref(parent), ctypes.byref(children), ctypes.byref(count)):
        for i in range(count.value):
            name = ctypes.c_char_p()
            if x.XFetchName(dpy, children[i], ctypes.byref(name)) and name.value:
                names.append(name.value.decode("utf-8", "replace"))
    x.XCloseDisplay(dpy)
    return names


def probe(path: Path) -> dict:
    out = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
                          "stream=nb_read_frames,width,height,duration", "-of", "json", str(path)], capture_output=True, text=True)
    stream = json.loads(out.stdout or "{}").get("streams", [{}])[0]
    return {"frames": int(stream.get("nb_read_frames", 0)), "width": stream.get("width"), "height": stream.get("height"),
            "duration": float(stream.get("duration", 0) or 0)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--godot", default=str(GODOT))
    ap.add_argument("--resolution", default="1280x720")
    ap.add_argument("--deadline", type=float, default=600.0)
    args = ap.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    checks = []

    def check(name, ok, detail=""):
        checks.append({"name": name, "ok": bool(ok), "detail": str(detail)[:600]})
        if not ok:
            print(f"  fail: {name} ({str(detail)[:200]})", file=sys.stderr)

    free = shutil.disk_usage(out).free / 2**30
    home_free = shutil.disk_usage(Path.home()).free / 2**30
    run = {"started": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "free_gib_out": round(free, 2), "free_gib_home": round(home_free, 2),
           "min_free_gib": MIN_FREE_GIB, "godot": args.godot, "project": str(PROJECT), "resolution": args.resolution}
    if min(free, home_free) < MIN_FREE_GIB:
        run["refused"] = "free space below the floor; nothing launched"
        (out / "run.json").write_text(json.dumps(run, indent=1))
        print(run["refused"], file=sys.stderr)
        return 3
    git = subprocess.run(["git", "-C", str(PROJECT), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    status = subprocess.run(["git", "-C", str(PROJECT), "status", "--short", "--", "."], capture_output=True, text=True).stdout
    run["git_head"] = git
    run["git_status"] = status
    run["source_hashes"] = {p: sha256(PROJECT / p) for p in ["scripts/r14_main.gd", "scripts/r14_hud.gd", "scripts/r14_presets.gd", "scripts/r14_strafe_stats.gd",
                                                           "scripts/r14_launch.gd", "scenes/r14.tscn", "tests/test_r14_loop_tour.gd",
                                                           "scripts/r14_source_player.gd", "scripts/r14_source_motion.gd", "scripts/r14_practice_level.gd"]}
    profile = out / "profile"
    run["passes"] = {}

    def play(sub: Path, movie: bool) -> dict:
        """one tour on its own private display; returns exit, window titles seen and cleanup."""
        sub.mkdir(parents=True, exist_ok=True)
        display = free_display()
        width, height = args.resolution.split("x")
        env = dict(os.environ, DISPLAY=f":{display}", XDG_DATA_HOME=str(profile / "data"), XDG_CONFIG_HOME=str(profile / "config"),
                   XDG_CACHE_HOME=str(profile / "cache"))
        env.pop("WAYLAND_DISPLAY", None)
        avi = sub / "movie.avi"
        xvfb = subprocess.Popen(["Xvfb", f":{display}", "-screen", "0", f"{width}x{height}x24", "-nolisten", "tcp", "-noreset"],
                                stdout=subprocess.DEVNULL, stderr=open(sub / "xvfb.log", "w"))
        godot = None
        result = {"display": display, "titles": []}
        try:
            for _ in range(50):
                if Path(f"/tmp/.X11-unix/X{display}").exists():
                    break
                time.sleep(0.1)
            cmd = [args.godot, "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--resolution", args.resolution, "--fixed-fps", "30"]
            if movie:
                cmd += ["--write-movie", str(avi)]
            cmd += ["--path", str(PROJECT), "--script", "res://tests/test_r14_loop_tour.gd", "--", f"--out={sub}"]
            result["command"] = cmd
            godot = subprocess.Popen(cmd, env=env, stdout=open(sub / "godot.log", "w"), stderr=subprocess.STDOUT, start_new_session=True)
            began = time.time()
            while godot.poll() is None:
                if time.time() - began > args.deadline:
                    result["timeout"] = True
                    break
                if avi.exists() and avi.stat().st_size > MAX_MOVIE_MIB * 2**20:
                    result["movie_over_budget"] = True
                    break
                for name in window_titles(display):
                    if "Spillway" in name and (not result["titles"] or result["titles"][-1]["title"] != name):
                        result["titles"].append({"t": round(time.time() - began, 2), "title": name})
                time.sleep(0.03)
            result["exit"] = godot.poll()
        finally:
            if godot is not None and godot.poll() is None:
                os.killpg(godot.pid, signal.SIGTERM)
                try:
                    godot.wait(10)
                except subprocess.TimeoutExpired:
                    os.killpg(godot.pid, signal.SIGKILL)
            xvfb.terminate()
            try:
                xvfb.wait(10)
            except subprocess.TimeoutExpired:
                xvfb.kill()
        result["cleanup"] = {"godot_running": godot is not None and godot.poll() is None, "xvfb_exit": xvfb.poll(),
                             "display_socket_left": Path(f"/tmp/.X11-unix/X{display}").exists(), "lock_left": Path(f"/tmp/.X{display}-lock").exists()}
        return result

    movie = out / "movie.avi"
    # pass 1 records the movie; the movie writer owns the window title while it records, so
    # pass 2 replays the same tour without it to read the title the game sets.
    recorded = play(out, True)
    titled = play(out / "title-pass", False)
    run["passes"] = {"movie": recorded, "title": titled}
    for label, result in [("movie", recorded), ("title", titled)]:
        check(f"{label} pass: godot exited 0", result.get("exit") == 0, result.get("exit"))
        c = result["cleanup"]
        check(f"{label} pass: no owned process or display left", not c["godot_running"] and not c["display_socket_left"] and not c["lock_left"], c)
    titles = titled["titles"]
    check("x window title followed map and preset", any("Penstock Yard" in t["title"] and "bhop server" in t["title"] for t in titles)
          and any("R13" in t["title"] for t in titles) and any("vanilla" in t["title"] for t in titles) and any("· Overflow ·" in t["title"] for t in titles), titles)
    title_tour = json.loads((out / "title-pass" / "tour.json").read_text()) if (out / "title-pass" / "tour.json").exists() else {}
    title_moments = {m["frame"]: m for m in title_tour.get("moments", [])}
    shutil.rmtree(out / "title-pass" / "frames", ignore_errors=True)
    tour = json.loads((out / "tour.json").read_text()) if (out / "tour.json").exists() else {}
    moments = {m["frame"]: m for m in tour.get("moments", [])}
    check("tour reached every moment", len(moments) in (11, 12), list(moments))
    expect = {"01-default-spawn": ("practice", "server128", 128), "04-switch-vanilla": ("practice", "vanilla64", 64), "05-switch-r13": ("practice", "r13_original120", 120),
              "06-switch-server": ("practice", "server128", 128), "09-overflow": ("overflow", "server128", 128), "11-back-penstock": ("practice", "server128", 128)}
    for name, (map_id, preset, hz) in expect.items():
        m = moments.get(name, {})
        check(f"{name}: {map_id} / {preset} / {hz} Hz", m.get("map") == map_id and m.get("preset") == preset and m.get("engine_hz") == hz and m.get("physics_hz") == hz, m)
        t = title_moments.get(name, {})
        check(f"{name}: hud names it", m.get("identity", "").count(str(hz) + " Hz") == 1, m.get("identity"))
        check(f"{name}: get_window().title names it (title pass)", str(hz) + " Hz" in t.get("window_title", "") and t.get("preset") == preset, t.get("window_title"))
    check("mid-air switches made the attempt practice", moments.get("04-switch-vanilla", {}).get("practice_reason") == "preset", moments.get("04-switch-vanilla", {}).get("practice_tag"))
    check("pause frames were paused", moments.get("07-pause", {}).get("paused") and moments.get("08-pause-maps", {}).get("paused"))
    check("the strafe chain recorded hops", "last hop  " in moments.get("03-hop-stats", {}).get("strafe", ["", ""])[1] and "—" not in moments.get("03-hop-stats", {}).get("strafe", ["", ""])[1].split("sync")[0], moments.get("03-hop-stats", {}).get("strafe"))
    frames = sorted((out / "frames").glob("*.png"))
    check("selected frames saved", len(frames) == len(moments), [f.name for f in frames])
    if movie.exists():
        avi = probe(movie)
        run["avi"] = avi | {"bytes": movie.stat().st_size, "sha256": sha256(movie)}
        mp4 = out / "movie.mp4"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(movie), "-c:v", "libx264", "-preset", "veryfast", "-crf", "24", "-pix_fmt", "yuv420p", str(mp4)], check=True)
        m = probe(mp4)
        decode = subprocess.run(["ffmpeg", "-v", "error", "-i", str(mp4), "-f", "null", "-"], capture_output=True, text=True)
        run["mp4"] = m | {"bytes": mp4.stat().st_size, "sha256": sha256(mp4), "decode_errors": decode.stderr.strip()}
        ok = m["frames"] == avi["frames"] and m["width"] == avi["width"] and abs(m["duration"] - avi["duration"]) < 0.1 and not decode.stderr.strip()
        check("mp4 matches the avi and decodes cleanly", ok, [avi, m, decode.stderr[:200]])
        if ok:
            movie.unlink()
            run["avi_removed"] = True
        # a contact sheet of the selected frames.
        if frames:
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-pattern_type", "glob", "-i", str(out / "frames" / "*.png"), "-vf", "scale=480:-1,tile=3x4", "-frames:v", "1", str(out / "contact-sheet.png")])
    else:
        check("movie written", False, "no movie.avi")
    trace = out / "trace.jsonl"
    if trace.exists():
        raw = sha256(trace)
        lines = sum(1 for _ in open(trace))
        with open(trace, "rb") as src, gzip.open(str(trace) + ".gz", "wb", compresslevel=9) as dst:
            shutil.copyfileobj(src, dst)
        back = hashlib.sha256(gzip.open(str(trace) + ".gz").read()).hexdigest()
        if back == raw:
            run["trace"] = {"sha256_raw": raw, "lines": lines, "bytes_raw": trace.stat().st_size, "sha256_gz": sha256(Path(str(trace) + ".gz"))}
            trace.unlink()
        check("trace gzipped with a verified hash", back == raw, [raw, back])
    # the game's own log, written inside each callback, of deltas that differed from 1/physics_hz.
    run["rate_log"] = tour.get("rate_log", [])
    run["rate_mismatch_started"] = [e for e in run["rate_log"] if e.get("started")]
    shutil.rmtree(profile / "cache", ignore_errors=True)
    title_trace = out / "title-pass" / "trace.jsonl"
    if title_trace.exists():
        title_trace.unlink()
    run["checks"] = checks
    run["failed"] = sum(1 for c in checks if not c["ok"])
    run["out_bytes"] = sum(f.stat().st_size for f in out.rglob("*") if f.is_file())
    (out / "run.json").write_text(json.dumps(run, indent=1))
    print(f"r14 native tour: {len(checks)} checks, {run['failed']} failed, {run['out_bytes'] / 2**20:.1f} MiB in {out}")
    return 1 if run["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
