#!/usr/bin/env python3
"""p / r14 native acceptance: the authored practice tapes through the actual R14 main, rendered.

Each case runs the unchanged version 2 tape twice from this checkout through the unchanged
executor and the setup-only practice-root subclass (it only sets the authored 0.0022 rad/count
look scale): once headless, once native under a private Xvfb at the product's 1280x720
viewport. The native AVI is encoded here at a review CRF, checked against the AVI (frame
count, size, duration, clean decode) and only then deleted. compare() then reports the
tick-by-tick difference between the two runs. Nothing writes pose, velocity or input.

python3 tests/r14_native_acceptance.py --out DIR [--only server-basic,...] [--crf 28]
python3 tests/r14_native_acceptance.py --out DIR --tour   # tests/r14_native_acceptance_tour.gd, 1280x720
"""
import argparse
import gzip
import hashlib
import json
import os
import shutil
import signal
import subprocess
import tempfile
import sys
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
TOOL = PROJECT / "tools/momentum-tape.py"
BUILD = Path("/home/thatmike1/foldrunner-build-2026-11-05")
TAPES = BUILD / "checkpoints/spillway/r14/practice-source/v3/final"
GAME = BUILD / "checkpoints/spillway/r14/practice-root/game.gd"
CASES = [("server-basic", "server128"), ("server-advanced", "server128"), ("vanilla-basic", "vanilla64")]
FLOOR = 15 * 2 ** 30
GODOT = Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def desktop_answers():
    # the desktop's own display must answer before and after; nothing here touches it.
    env = {**os.environ, "DISPLAY": ":0"}
    return subprocess.run(["xdpyinfo"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10).returncode == 0


def probe(path):
    def ask(*fields):
        return subprocess.run(["ffprobe", "-v", "error", *fields, "-of", "csv=p=0", str(path)], capture_output=True, text=True).stdout.strip()
    frames = ask("-count_frames", "-select_streams", "v:0", "-show_entries", "stream=nb_read_frames")
    size = ask("-select_streams", "v:0", "-show_entries", "stream=width,height")
    duration = ask("-show_entries", "format=duration")
    decode = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], capture_output=True, text=True)
    return {"frames": int(frames) if frames.isdigit() else None, "size": size, "duration_s": float(duration) if duration else None,
            "decode_exit": decode.returncode, "decode_errors": decode.stderr.strip()[:400], "bytes": path.stat().st_size, "sha256": sha(path)}


def finalize(run, crf):
    """the executor's movie checks at a smaller review CRF; the avi goes only when all pass."""
    avi, mp4 = run / "movie.avi", run / "movie.mp4"
    source = probe(avi)
    encode = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-an", "-c:v", "libx264", "-preset", "slow", "-crf", str(crf),
                             "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)], capture_output=True, text=True)
    result = probe(mp4) if mp4.exists() else None
    checks = {"encode_exit": encode.returncode,
              "same_frame_count": bool(result) and source["frames"] and result["frames"] == source["frames"],
              "same_size": bool(result) and result["size"] == source["size"],
              "is_1280x720": source["size"] == "1280,720",
              "same_duration": bool(result) and None not in (result["duration_s"], source["duration_s"]) and abs(result["duration_s"] - source["duration_s"]) < 0.05,
              "decodes_cleanly": bool(result) and result["decode_exit"] == 0 and not result["decode_errors"] and source["decode_exit"] == 0}
    complete = encode.returncode == 0 and all(checks[k] for k in ("same_frame_count", "same_size", "same_duration", "decodes_cleanly"))
    record = {"avi": source, "mp4": result, "checks": checks, "complete": complete,
              "encoding": f"libx264 preset slow crf {crf} yuv420p (lossy review copy; the executor's own --mp4 uses crf 18)", "avi_removed": False}
    if complete:
        avi.unlink()
        record["avi_removed"] = True
    (run / "evaluator/movie-review.json").write_text(json.dumps(record, indent=1))
    return record


def drop_caches(profile):
    """mesa and godot shader caches are scratch of the run, not evidence; logs stay."""
    removed = {}
    for cache in [profile / "xdg_cache_home/mesa_shader_cache", *profile.glob("xdg_data_home/godot/app_userdata/*/shader_cache")]:
        if cache.is_dir():
            removed[str(cache.relative_to(profile))] = sum(f.stat().st_size for f in cache.rglob("*") if f.is_file())
            shutil.rmtree(cache)
    return removed


def run_tape(label, motor, out, native, args):
    cmd = [sys.executable, str(TOOL), "run", str(TAPES / label / "events.tape.json"), "--out", str(out), "--archive", "--warmup", "32",
           "--game-script", str(GAME), "--game-class", "", "--motor", motor, "--wall-budget", str(args.wall_budget)]
    if native:
        cmd += ["--display", str(args.display), "--resolution", "1280x720", "--actor-limit", str(args.actor_limit),
                "--max-movie-mib", str(args.max_movie_mib)]
    else:
        cmd += ["--headless"]
    with (out.parent / (out.name + ".log")).open("w") as log:
        code = subprocess.run(cmd, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT).returncode
    report = out / "evaluator/report.json"
    return {"command": cmd, "exit": code, "report": json.loads(report.read_text()) if report.exists() else None}


def game_rows(run):
    """the game's own progress per tape tick, read from the archived trace."""
    trace = run / "evaluator/trace.jsonl.gz"
    if not trace.exists():
        return None
    last, stages = None, []
    with gzip.open(trace, "rt") as rows:
        for line in rows:
            row = json.loads(line)
            game = row.get("game")
            if row.get("phase") == "tape" and game:
                last = game
                if not stages or stages[-1] != game.get("checkpoint"):
                    stages.append(game.get("checkpoint"))
    return {"final": last, "stage_sequence": stages}


def brief(report, run):
    if not report:
        return None
    keep = {k: report.get(k) for k in ("end", "neutral", "movement_flags", "integrity_flags")}
    keep["game"] = game_rows(run)
    keep["outcome"] = {k: (report.get("outcome") or {}).get(k) for k in ("end_p", "travel_m", "jumps", "respawns")}
    keep["delivery"] = (report.get("delivery") or {}).get("ok")
    keep["order"] = {k: (report.get("order") or {}).get(k) for k in ("ok", "strength", "counter_verified_ticks")}
    keep["rate"] = {k: (report.get("rate") or {}).get(k) for k in ("ok", "declared_hz", "engine_hz", "dt_observed", "bad_step_count", "fault")}
    keep["timing"] = report.get("timing")
    keep["cleanup"] = {k: (report.get("cleanup") or {}).get(k) for k in ("clean", "engine_exit", "leftover_owned_processes", "display_socket_removed")}
    return keep


def free_display(first):
    unix = Path("/proc/net/unix").read_text()
    for n in range(first, 200):
        if not Path(f"/tmp/.X11-unix/X{n}").exists() and not Path(f"/tmp/.X{n}-lock").exists() and f"/tmp/.X11-unix/X{n}\n" not in unix:
            return n
    raise RuntimeError("no free explicit private display")


def stop(proc):
    if proc is not None and proc.poll() is None:
        os.killpg(proc.pid, signal.SIGTERM)
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait(timeout=5)


def tour(out, args):
    """the input-driven preset tour on the real launch scene under a private Xvfb, records off."""
    case = out / "tour"
    if case.exists() and any(case.iterdir()):
        raise SystemExit(f"{case} is not fresh")
    case.mkdir(parents=True, exist_ok=True)
    free = shutil.disk_usage("/home").free
    meta = {"label": "input-driven preset tour on the runway; frames, not feel or records", "home_free_before": free,
            "desktop_before": desktop_answers(), "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip(),
            "tour_sha256": sha(PROJECT / "tests/r14_native_acceptance_tour.gd")}
    if free < FLOOR:
        meta["skipped"] = f"/home has {free / 2 ** 30:.3f} GiB free, below 15 GiB; nothing launched"
        (case / "run.json").write_text(json.dumps(meta, indent=1) + "\n")
        return 1
    work = Path(tempfile.mkdtemp(prefix="r14-native-tour-"))
    display = free_display(args.display)
    x = g = None
    env = {k: v for k, v in os.environ.items() if k not in ("WAYLAND_DISPLAY", "XAUTHORITY")}
    env.update({"DISPLAY": f":{display}", "XDG_DATA_HOME": str(work / "data"), "XDG_CONFIG_HOME": str(work / "config"),
                "XDG_CACHE_HOME": str(work / "cache"), "XDG_STATE_HOME": str(work / "state")})
    cmd = [str(GODOT), "--audio-driver", "Dummy", "--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed",
           "--resolution", "1280x720", "--fixed-fps", "30", "--write-movie", str(case / "movie.avi"), "--path", str(PROJECT),
           "--script", "res://tests/r14_native_acceptance_tour.gd", "--", f"--out={case}"]
    meta.update({"display": display, "command": cmd})
    try:
        with (case / "xvfb.log").open("w") as xf, (case / "godot.log").open("w") as gf:
            x = subprocess.Popen(["Xvfb", f":{display}", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-noreset"],
                                 stdout=xf, stderr=subprocess.STDOUT, start_new_session=True)
            for _ in range(100):
                if x.poll() is not None or Path(f"/tmp/.X11-unix/X{display}").exists():
                    break
                time.sleep(0.1)
            if x.poll() is not None:
                raise RuntimeError("Xvfb exited")
            started = time.monotonic()
            g = subprocess.Popen(cmd, env=env, cwd=str(work), stdout=gf, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                meta["exit"] = g.wait(timeout=args.wall_budget)
            except subprocess.TimeoutExpired:
                meta["exit"] = "timeout; stopped by the driver"
            meta["wall_s"] = time.monotonic() - started
    finally:
        stop(g)
        stop(x)
        meta["owned_processes_remaining"] = [q.pid for q in (g, x) if q is not None and q.poll() is None]
        meta["display_socket_remaining"] = Path(f"/tmp/.X11-unix/X{display}").exists()
        shutil.rmtree(work, ignore_errors=True)
        meta["scratch_removed"] = not work.exists()
    (case / "evaluator").mkdir(exist_ok=True)
    if (case / "movie.avi").exists():
        meta["movie"] = finalize(case, args.crf)
    meta["home_free_after"] = shutil.disk_usage("/home").free
    meta["desktop_after"] = desktop_answers()
    (case / "run.json").write_text(json.dumps(meta, indent=1) + "\n")
    print("tour", meta.get("exit"), (meta.get("movie") or {}).get("complete"), flush=True)
    return 0 if meta.get("exit") == 0 else 1


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--only", default="")
    p.add_argument("--crf", type=int, default=28)
    p.add_argument("--display", type=int, default=190)
    p.add_argument("--actor-limit", type=int, default=10)
    p.add_argument("--max-movie-mib", type=int, default=900)
    p.add_argument("--wall-budget", type=int, default=1200)
    p.add_argument("--tour", action="store_true")
    args = p.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if args.tour:
        return tour(out, args)
    only = [s for s in args.only.split(",") if s]
    results_path = out / "RESULTS.json"
    results = json.loads(results_path.read_text()) if results_path.exists() else {"cases": {}}
    results.update({"label": "actual R14 main via the unchanged executor, unchanged v2 tapes, warmup 32, setup-only look-scale subclass; route evidence, not enjoyment",
                    "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip(),
                    "source_status": subprocess.check_output(["git", "status", "--porcelain", "--", "."], cwd=PROJECT, text=True).splitlines(),
                    "game_script": str(GAME), "game_script_sha256": sha(GAME), "driver_sha256": sha(Path(__file__))})
    failed = 0
    for label, motor in CASES:
        if only and label not in only:
            continue
        case = {"tape": str(TAPES / label / "events.tape.json"), "tape_sha256": sha(TAPES / label / "events.tape.json"), "motor": motor}
        headless = out / label / "headless"
        native = out / label / "native"
        headless.parent.mkdir(parents=True, exist_ok=True)
        case["headless"] = run_tape(label, motor, headless, False, args)
        free = shutil.disk_usage("/home").free
        case["home_free_before_native"] = free
        case["desktop_before"] = desktop_answers()
        if free < FLOOR:
            case["native"] = {"skipped": f"/home has {free / 2 ** 30:.3f} GiB free, below 15 GiB; nothing launched"}
            failed += 1
        else:
            started = time.monotonic()
            case["native"] = run_tape(label, motor, native, True, args)
            case["native"]["wall_s"] = time.monotonic() - started
            if (native / "movie.avi").exists():
                case["movie"] = finalize(native, args.crf)
            case["scratch_removed"] = drop_caches(native / "profile")
            case["home_free_after_native"] = shutil.disk_usage("/home").free
            if case["headless"]["report"] and case["native"]["report"]:
                cmp = subprocess.run([sys.executable, str(TOOL), "compare", str(headless), str(native)], cwd=PROJECT, capture_output=True, text=True)
                case["compare"] = json.loads(cmp.stdout) if cmp.returncode == 0 else {"error": cmp.stderr[-2000:]}
        case["desktop_after"] = desktop_answers()
        for k in ("headless", "native"):
            if case[k].get("report") is not None:
                case[k]["summary"] = brief(case[k].pop("report"), headless if k == "headless" else native)
        results["cases"][label] = case
        results_path.write_text(json.dumps(results, indent=1) + "\n")
        print(label, json.dumps({k: case[k].get("exit") for k in ("headless", "native")}), json.dumps(case.get("compare", {}).get("max_position_m")), flush=True)
        failed += int(case["native"].get("exit", 1) != 0 or case["headless"].get("exit", 1) != 0)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
