#!/usr/bin/env python3
"""run, replay, evaluate and minimize spillway momentum input tapes.

the engine side is tools/momentum-tape.gd; the protocol is docs/momentum/TAPE.md, and the
rate-aware version 2 is docs/r14/REPLAY.md. this wrapper expands convenience curves, owns the
private display and engine process groups, records build identity, separates actor-facing
frames from evaluator telemetry and judges delivery, ordering, rate and movement from the
trace. it never steers a run.
"""

import argparse
import copy
import gzip
import hashlib
import json
import math
import os
import re
import shutil
import signal
import struct
import subprocess
import sys
import time
import uuid
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path(os.environ.get("GODOT", Path.home() / ".local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"))
EVIDENCE = Path("/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/tape-executor")
EXECUTOR = PROJECT / "tools/momentum-tape.gd"
FORMAT = "spillway-momentum-tape"
KEYS = ["w", "a", "s", "d", "space", "ctrl"]
MOVE_KEYS = {"w", "a", "s", "d"}
PROFILES = {"tick120": 1, "render30": 4}
MAX_TICKS = 120 * 600
# p / r14 version 2: one event slot per physics tick at vanilla 64, server-style 128 or r13's
# original 120 hz. the v1 profile names are 120 hz claims and never describe another rate.
V2_PROFILE = "physics_tick"
V2_RATES = (64, 120, 128)
MAX_SECONDS = 600
V2_FIELDS = {"format", "version", "name", "description", "physics_hz", "input_profile", "duration_ticks", "duration_s",
             "mouse_quantize", "events", "curves", "expanded", "submitted_sha256"}
# p / storage steering of 8 november: no native capture below this much free space.
MIN_FREE_GIB = 15.0
ARCHIVED = ["evaluator/trace.jsonl", "evaluator/frames.jsonl"]
# files whose bytes decide what a run executes; .godot/ import caches are not covered.
SOURCE_GLOBS = ["project.godot", "scripts/**/*.gd", "shaders/**/*", "scenes/**/*", "data/**/*", "tools/momentum-tape*"]


# --- tapes ------------------------------------------------------------------------------------

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def _shape(name, u):
    # cumulative fraction of a stroke; "smooth" has a bell-shaped speed (accelerate, then stop).
    if name == "linear":
        return u
    if name == "smooth":
        return u * u * (3.0 - 2.0 * u)
    raise ValueError(f"unknown curve shape {name}")


def tape_period(tape):
    return PROFILES.get(tape.get("input_profile"), 1) if tape.get("version") == 1 else 1


def _v2_header(tape, errors):
    """strict version 2 header: the rate is a declared fact checked twice, never inferred."""
    unknown = sorted(set(tape) - V2_FIELDS)
    if unknown:
        errors.append(f"unknown version 2 header fields {unknown}")
    hz = tape.get("physics_hz")
    if type(hz) is not int or hz not in V2_RATES:
        errors.append(f"version 2 physics_hz must be an integer in {list(V2_RATES)}, not {hz!r}")
        hz = 0
    profile = tape.get("input_profile")
    if profile in PROFILES:
        errors.append(f"input_profile {profile} is a version 1, 120 hz label; version 2 uses {V2_PROFILE}")
    elif profile != V2_PROFILE:
        errors.append(f"version 2 input_profile must be {V2_PROFILE}, not {profile!r}")
    duration = tape.get("duration_ticks")
    if type(duration) is not int or not 0 < duration <= max(hz, 1) * MAX_SECONDS:
        errors.append(f"duration_ticks must be an integer 1..{max(hz, 1) * MAX_SECONDS}")
        duration = 0
    seconds = tape.get("duration_s")
    # the redundant duration makes a header-only rate edit fail: relabelling is not resampling.
    if type(seconds) not in (int, float) or not hz or abs(seconds - duration / hz) > 1e-9:
        errors.append(f"duration_s {seconds!r} is not duration_ticks / physics_hz ({duration}/{hz})")
    if tape.get("mouse_quantize", "float32") not in ("float32", "integer"):
        errors.append(f"mouse_quantize must be float32 or integer, not {tape.get('mouse_quantize')!r}")
    if tape.get("expanded") and "curves" in tape:
        errors.append("an expanded tape cannot also carry curves")
    return hz, profile, duration


def expand(tape):
    """return an expanded, validated copy: explicit events only, mouse merged per tick."""
    errors = []
    version = tape.get("version")
    if tape.get("format") != FORMAT or type(version) is not int or version not in (1, 2):
        raise ValueError(f"not a {FORMAT} version 1 or 2 tape")
    if version == 1:
        hz = int(tape.get("physics_hz", 0))
        profile = tape.get("input_profile")
        if hz != 120:
            errors.append("a version 1 tape is a 120 hz claim; physics_hz must be 120 (use version 2 for 64 or 128)")
        if profile not in PROFILES:
            errors.append(f"input_profile must be one of {sorted(PROFILES)}")
        period = PROFILES.get(profile, 1)
        duration = int(tape.get("duration_ticks", 0))
        if not 0 < duration <= MAX_TICKS:
            errors.append(f"duration_ticks must be 1..{MAX_TICKS}")
    else:
        hz, profile, duration = _v2_header(tape, errors)
        period = 1
    keys = []
    mouse = {}
    for event in tape.get("events", []):
        tick = int(event["tick"])
        if "key" in event:
            keys.append((tick, event["key"], event["edge"]))
        elif "mouse" in event:
            dx, dy = (float(v) for v in event["mouse"])
            mouse[tick] = [mouse.get(tick, [0.0, 0.0])[0] + dx, mouse.get(tick, [0.0, 0.0])[1] + dy]
        else:
            errors.append(f"tick {tick}: event is neither key nor mouse")
    for curve in tape.get("curves", []):
        start, length = int(curve["start"]), int(curve["ticks"])
        if curve["kind"] == "hold":
            keys.append((start, curve["key"], "press"))
            keys.append((start + length, curve["key"], "release"))
        elif curve["kind"] == "mouse":
            if start % period or length % period or length <= 0:
                errors.append(f"mouse curve at {start} must start and last on the {profile} cadence")
                continue
            samples = length // period
            total = [float(v) for v in curve["total"]]
            for i in range(samples):
                fraction = _shape(curve.get("shape", "smooth"), (i + 1) / samples) - _shape(curve.get("shape", "smooth"), i / samples)
                tick = start + i * period
                previous = mouse.get(tick, [0.0, 0.0])
                mouse[tick] = [previous[0] + total[0] * fraction, previous[1] + total[1] * fraction]
        else:
            errors.append(f"unknown curve kind {curve['kind']}")
    down = {}
    # within a tick releases precede presses, so a release and re-press can share a boundary.
    keys.sort(key=lambda k: (k[0], 0 if k[2] == "release" else 1, KEYS.index(k[1]) if k[1] in KEYS else 99))
    events = []
    for tick, key, edge in keys:
        if key not in KEYS or edge not in ("press", "release"):
            errors.append(f"tick {tick}: unknown key {key} or edge {edge}")
        elif (edge == "press") == (key in down):
            errors.append(f"tick {tick}: {edge} of {key} does not match its held state")
        elif edge == "release" and down[key] == tick:
            errors.append(f"tick {tick}: {key} pressed and released on one tick is not a delivered tap")
        else:
            if edge == "press":
                down[key] = tick
            else:
                del down[key]
            events.append({"tick": tick, "key": key, "edge": edge})
    carry = [0.0, 0.0]
    for tick in sorted(mouse):
        motion = mouse[tick]
        if not all(math.isfinite(v) for v in motion):
            errors.append(f"tick {tick}: non-finite mouse")
            continue
        if tape.get("mouse_quantize") == "integer":
            # whole device counts, carrying the remainder, as a physical mouse reports them.
            wanted = [motion[0] + carry[0], motion[1] + carry[1]]
            motion = [float(round(wanted[0])), float(round(wanted[1]))]
            carry = [wanted[0] - motion[0], wanted[1] - motion[1]]
        # godot's Vector2 is single precision; the plan holds exactly what an event can carry.
        motion = [struct.unpack("f", struct.pack("f", v))[0] for v in motion]
        if motion != [0.0, 0.0]:
            events.append({"tick": tick, "mouse": motion})
    for event in events:
        if not 0 <= event["tick"] < duration or event["tick"] % period:
            errors.append(f"tick {event['tick']}: outside the tape or off the {profile} cadence")
    if errors:
        raise ValueError("; ".join(errors))
    events.sort(key=lambda e: (e["tick"], 0 if "key" in e else 1))
    if version == 2:
        return {"format": FORMAT, "version": 2, "expanded": True, "name": tape.get("name", ""),
                "description": tape.get("description", ""), "physics_hz": hz, "input_profile": profile,
                "duration_ticks": duration, "duration_s": duration / hz, "mouse_quantize": tape.get("mouse_quantize", "float32"),
                "events": events, "submitted_sha256": sha256_bytes(canonical(tape).encode())}
    return {"format": FORMAT, "version": 1, "expanded": True, "name": tape.get("name", ""),
            "description": tape.get("description", ""), "physics_hz": hz, "input_profile": profile,
            "duration_ticks": duration, "mouse_quantize": tape.get("mouse_quantize", "float32"), "events": events, "submitted_sha256": sha256_bytes(canonical(tape).encode())}


# --- identity ---------------------------------------------------------------------------------

def git(*args):
    result = subprocess.run(["git", "-C", str(PROJECT), *args], capture_output=True)
    return result.stdout if result.returncode == 0 else b""


def source_snapshot(out, extra):
    """hash and copy what this source-mode run executes; record the dirty checkout state."""
    manifest = {}
    files = set()
    for pattern in SOURCE_GLOBS:
        files.update(p for p in PROJECT.glob(pattern) if p.is_file() and "__pycache__" not in p.parts)
    for path in sorted(files):
        rel = str(path.relative_to(PROJECT))
        manifest[rel] = sha256_file(path)
        if rel.endswith((".gd", ".py", ".godot", ".gdshader")):
            target = out / "source" / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    for label, path in extra.items():
        manifest[label] = sha256_file(path)
        shutil.copy2(path, out / "source" / Path(path).name)
    diff = git("diff", "HEAD", "--binary", "--", ".")
    (out / "source/git-diff.patch").write_bytes(diff)
    status = git("status", "--porcelain", "--untracked-files=all", "--", ".").decode()
    identity = sha256_bytes("\n".join(f"{k} {v}" for k, v in sorted(manifest.items())).encode())
    return {"mode": "source checkout (godot --path), not a frozen pack", "project": str(PROJECT),
            "git_head": git("rev-parse", "HEAD").decode().strip(), "dirty": bool(status.strip()),
            "status": status.splitlines(), "diff_sha256": sha256_bytes(diff), "manifest": manifest,
            "source_identity_sha256": identity,
            "not_covered": ".godot/ import cache and engine-side editor settings are not hashed"}


# --- processes --------------------------------------------------------------------------------

def free_display(preferred):
    for number in [preferred] + list(range(154, 200)):
        if not Path(f"/tmp/.X11-unix/X{number}").exists() and not Path(f"/tmp/.X{number}-lock").exists():
            return number
    raise RuntimeError("no free private X display between :153 and :199")


def owned_leftovers(markers):
    found = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            cmd = (proc / "cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace")
        except OSError:
            continue
        if any(m in cmd for m in markers) and int(proc.name) != os.getpid():
            found.append({"pid": int(proc.name), "cmd": cmd[:200]})
    return found


def stop_group(proc, grace):
    """stop one owned process group: SIGTERM, then SIGKILL; return how it ended."""
    if proc.poll() is not None:
        return {"exit": proc.returncode, "signal": None}
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        proc.wait(grace)
        return {"exit": proc.returncode, "signal": "SIGTERM"}
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait(10)
        return {"exit": proc.returncode, "signal": "SIGKILL"}


def free_bytes(path):
    probe = Path(path)
    while not probe.exists():
        probe = probe.parent
    return shutil.disk_usage(probe).free


def execute(plan, out, cfg):
    """run one expanded plan in a fresh evidence directory; return the evaluated report."""
    out = Path(out).resolve()
    cfg = {k: str(v) if isinstance(v, Path) else v for k, v in cfg.items()}
    if PROJECT in out.parents or out == PROJECT:
        raise SystemExit("evidence must stay outside the checkout")
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f"evidence directory {out} is not fresh")
    for sub in ["evaluator", "actor", "control", "profile", "source"]:
        (out / sub).mkdir(parents=True, exist_ok=True)
    (out / "evaluator/plan.json").write_text(json.dumps(plan, indent=1))
    executor = Path(cfg.get("executor") or EXECUTOR).resolve()
    extra = {"executor_variant": executor} if executor != EXECUTOR else {}
    if cfg.get("motor_script"):
        extra["motor_variant"] = Path(cfg["motor_script"]).resolve()
    if cfg.get("game_script") and not str(cfg["game_script"]).startswith("res://"):
        extra["game_variant"] = Path(cfg["game_script"]).resolve()
    run_id = uuid.uuid4().hex
    headless = cfg.get("headless", False)
    timing = cfg.get("timing", "fixed")
    frames = "none" if headless else ("movie" if timing == "fixed" else "readback")
    width, height = (int(v) for v in str(cfg.get("resolution", "1280x720")).split("x"))
    meta = {"run_id": run_id, "config": cfg, "plan_sha256": sha256_bytes(canonical(plan).encode()),
            "engine_sha256": sha256_file(GODOT), "engine_path": str(GODOT),
            "helper_sha256": {"wrapper": sha256_file(Path(__file__)), "executor": sha256_file(executor)},
            "source": source_snapshot(out, extra), "timing": timing, "frames": frames,
            "render_fps": None if timing == "realtime" else cfg.get("render_fps", 30),
            "observation_policy": "actor/ holds rendered frames and their sim times only; evaluator/ holds telemetry. "
                                  "this is a directory convention, not filesystem isolation or proof of pixel-only discovery"}
    meta["storage"] = {"filesystem_of": str(out), "free_bytes_at_start": free_bytes(out),
                       "min_free_gib": None if headless else float(cfg.get("min_free_gib", MIN_FREE_GIB)),
                       "max_movie_mib": float(cfg.get("max_movie_mib", 2048)) if frames == "movie" else None}
    args = [str(GODOT), "--path", str(PROJECT), "--audio-driver", "Dummy"]
    if headless:
        args += ["--headless"]
    else:
        args += ["--display-driver", "x11", "--rendering-driver", "opengl3", "--windowed", "--resolution", f"{width}x{height}"]
    if timing == "fixed":
        args += ["--fixed-fps", str(cfg.get("render_fps", 30))]
    if frames == "movie":
        args += ["--write-movie", str(out / "movie.avi")]
    motor = cfg.get("motor_script") or cfg.get("motor", "flow")
    args += ["--script", str(executor), "--", f"--tape={out / 'evaluator/plan.json'}", f"--out={out}",
             f"--motor={motor}", f"--fixture={cfg.get('fixture', '')}",
             *([f"--game-script={cfg['game_script']}"] if cfg.get("game_script") else []),
             *([f"--game-class={cfg['game_class']}"] if cfg.get("game_class") is not None else []), f"--sensitivity={cfg.get('sensitivity', 1.0)}",
             f"--inject={cfg.get('inject', 'tick')}", f"--warmup={cfg.get('warmup', 8)}", f"--frames={frames}",
             f"--readback-every={cfg.get('readback_every', 4)}", f"--wall-budget-s={cfg.get('wall_budget', 120)}", f"--run-id={run_id}",
             # the engine is set to the tape's rate before the tape is validated or the world built.
             f"--physics-hz={plan.get('physics_hz')}", *(["--undeclared-rate=allow"] if cfg.get("undeclared_rate_ok") else [])]
    env = {k: v for k, v in os.environ.items() if k not in ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY")}
    for name in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME"]:
        env[name] = str(out / "profile" / name.lower())
    xvfb = None
    display = None
    markers = [run_id]
    cleanup = {}
    started = time.monotonic()
    meta["command"] = args
    cancel = {"requested": None}
    previous = {}
    godot = None
    godot_log = None
    launch_error = None
    stage = "display_launch"

    def on_signal(signum, _frame):
        cancel["requested"] = cancel["requested"] or signal.Signals(signum).name

    try:
        for signum in (signal.SIGINT, signal.SIGTERM):
            previous[signum] = signal.signal(signum, on_signal)
        if not headless:
            stage = "storage_check"
            floor = meta["storage"]["min_free_gib"] * 2 ** 30
            if meta["storage"]["free_bytes_at_start"] < floor:
                raise RuntimeError(f"{meta['storage']['free_bytes_at_start'] / 2 ** 30:.2f} GiB free on the evidence filesystem, "
                                   f"below the {meta['storage']['min_free_gib']} GiB native-capture floor; nothing was launched")
            stage = "display_launch"
            display = free_display(int(cfg.get("display", 153)))
            markers.append(f"Xvfb :{display} ")
            with open(out / "evaluator/xvfb.log", "wb") as log:
                xvfb = subprocess.Popen(["Xvfb", f":{display}", "-screen", "0", f"{width}x{height}x24", "-nolisten", "tcp", "-noreset"],
                                        stdout=log, stderr=log, start_new_session=True)
            stage = "display_ready"
            for _ in range(100):
                if Path(f"/tmp/.X11-unix/X{display}").exists() or xvfb.poll() is not None:
                    break
                time.sleep(0.1)
            if xvfb.poll() is not None or not Path(f"/tmp/.X11-unix/X{display}").exists():
                raise RuntimeError(f"Xvfb :{display} failed to become ready")
            env["DISPLAY"] = f":{display}"
        stage = "engine_launch"
        godot_log = open(out / "evaluator/godot.log", "wb")
        godot = subprocess.Popen(args, env=env, cwd=str(out / "profile"), stdout=godot_log, stderr=godot_log, start_new_session=True)
        # p / the wrapper's deadline also covers engines that never acknowledge a cancel.
        deadline = started + float(cfg.get("deadline", float(cfg.get("wall_budget", 120)) + 45))
        frozen = False
        stage = "running"
        while godot.poll() is None:
            now = time.monotonic()
            if cfg.get("cancel_after") and now - started > float(cfg["cancel_after"]):
                cancel["requested"] = cancel["requested"] or "cancel_after"
            movie = out / "movie.avi"
            if meta["storage"]["max_movie_mib"] and movie.exists() and movie.stat().st_size > meta["storage"]["max_movie_mib"] * 2 ** 20:
                # p / a bounded movie: a capture that outgrows its budget is cancelled, not trusted.
                cancel["requested"] = cancel["requested"] or "movie_budget"
            if cfg.get("hang_after") and not frozen and now - started > float(cfg["hang_after"]):
                # test-only: simulate an unresponsive engine to prove the hard-kill path.
                os.kill(godot.pid, signal.SIGSTOP)
                frozen = True
            if cancel["requested"] or now > deadline:
                reason = cancel["requested"] or "wrapper_deadline"
                (out / "control/cancel").write_text(json.dumps({"reason": reason, "wall_s": now - started}))
                ack = out / "control/cancel-ack.json"
                limit = time.monotonic() + float(cfg.get("ack_grace", 10))
                while godot.poll() is None and time.monotonic() < limit:
                    time.sleep(0.1)
                cleanup["cancel"] = {"reason": reason, "ack": json.loads(ack.read_text()) if ack.exists() else None}
                if godot.poll() is None:
                    cleanup["engine_forced"] = stop_group(godot, 5)
                break
            time.sleep(0.05)
        godot.wait(30)
    except (Exception, KeyboardInterrupt) as error:
        launch_error = {"stage": stage, "type": type(error).__name__, "message": str(error)}
        cleanup["exception"] = launch_error
    finally:
        for s, handler in previous.items():
            signal.signal(s, handler)
        if godot_log is not None:
            godot_log.close()
        if godot is not None and godot.poll() is None:
            cleanup["engine_forced"] = stop_group(godot, 5)
        if godot is not None and owned_leftovers([run_id]):
            try:
                os.killpg(godot.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        cleanup["engine_exit"] = godot.returncode if godot is not None else None
        if xvfb is not None:
            cleanup["display"] = stop_group(xvfb, 5)
            cleanup["display_socket_removed"] = not Path(f"/tmp/.X11-unix/X{display}").exists()
            cleanup["display_lock_removed"] = not Path(f"/tmp/.X{display}-lock").exists()
        cleanup["leftover_owned_processes"] = owned_leftovers(markers)
        cleanup["wall_s"] = time.monotonic() - started
    meta["display"] = f":{display}" if display else "headless"
    end_path = out / "end.json"
    end = json.loads(end_path.read_text()) if end_path.exists() else {"reason": "no end record (engine killed)", "neutral": None}
    if launch_error is not None:
        meta["wrapper_error"] = launch_error
        if not end_path.exists():
            end = {"reason": "launch_failed" if stage != "running" else "wrapper_failed", "neutral": None, "error": launch_error}
            end_path.write_text(json.dumps(end, indent=1))
    cleanup["neutral_input"] = end.get("neutral") if end.get("neutral") is not None else "not observable: engine did not finish"
    cleanup["clean"] = not cleanup["leftover_owned_processes"] and (xvfb is None or cleanup["display_socket_removed"])
    (out / "evaluator/cleanup.json").write_text(json.dumps(cleanup, indent=1))
    engine_meta = out / "evaluator/engine.json"
    meta["engine"] = json.loads(engine_meta.read_text()) if engine_meta.exists() else None
    meta["end"] = end
    (out / "run.json").write_text(json.dumps(meta, indent=1))
    if end.get("reason") == "rejected" or not (out / "evaluator/trace.jsonl").exists():
        return {"run": str(out), "end": end, "cleanup": cleanup}
    if frames == "movie" and (out / "movie.avi").exists():
        actor_frames(out, int(cfg.get("actor_every", 6)), cfg.get("actor_limit"))
        if cfg.get("mp4"):
            finalize_movie(out, keep_avi=cfg.get("keep_avi", False))
    report = evaluate(out)
    report["cleanup"] = cleanup
    (out / "evaluator/report.json").write_text(json.dumps(report, indent=1))
    if cfg.get("archive"):
        report["archive"] = archive_run(out)
        (out / "evaluator/report.json").write_text(json.dumps(report, indent=1))
    return report


def actor_frames(out, every, limit=None):
    """sample the native movie for the actor folder: images and sim times, no telemetry.

    `limit` keeps at most that many evenly spaced samples, so a capture retains selected
    frames rather than every Nth one of a long run."""
    draws = {d["draw"]: d for d in read_jsonl(out / "evaluator/frames.jsonl")}
    target = out / "actor/frames"
    target.mkdir(parents=True, exist_ok=True)
    count = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
                            "stream=nb_read_frames", "-of", "csv=p=0", str(out / "movie.avi")], capture_output=True, text=True).stdout.strip()
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(out / "movie.avi"), "-vf", f"select=not(mod(n\\,{every}))",
                    "-fps_mode", "vfr", "-start_number", "0", str(target / "raw_%06d.png")], check=True)
    manifest = []
    raws = sorted(target.glob("raw_*.png"))
    if limit and len(raws) > int(limit):
        step = (len(raws) - 1) / (int(limit) - 1) if int(limit) > 1 else len(raws)
        keep = {raws[round(i * step)] for i in range(int(limit))}
        for raw in raws:
            if raw not in keep:
                raw.unlink()
        raws = sorted(keep)
    for raw in raws:
        draw = int(raw.stem.split("_")[1]) * every
        sim = draws.get(draw, {}).get("sim_s")
        name = f"{len(manifest):04d}_" + (f"t{sim:07.3f}s" if sim is not None else "warmup") + ".png"
        raw.rename(target / name)
        manifest.append({"seq": len(manifest), "file": f"frames/{name}", "sim_s": sim})
    (out / "actor/manifest.json").write_text(json.dumps({"frames": manifest, "every_nth_rendered_frame": every, "limit": limit,
                                                          "note": "rendered native frames with the game's own visible hud only"}, indent=1))
    timed = [m for m in manifest if m["sim_s"] is not None]
    pick = timed[:: max(1, len(timed) // 16)][:16]
    if pick:
        inputs = []
        for m in pick:
            inputs += ["-i", str(out / "actor" / m["file"])]
        layout = "|".join(f"{(i % 4) * 320}_{(i // 4) * 180}" for i in range(len(pick)))
        graph = ";".join(f"[{i}:v]scale=320:180[s{i}]" for i in range(len(pick))) + ";" + "".join(f"[s{i}]" for i in range(len(pick)))
        graph += f"xstack=inputs={len(pick)}:layout={layout}" if len(pick) > 1 else "copy"
        subprocess.run(["ffmpeg", "-v", "error", *inputs, "-filter_complex", graph, "-frames:v", "1", str(out / "actor/contact-sheet.png")])
    logged = len(draws)
    (out / "evaluator/movie-frames.json").write_text(json.dumps({"movie_frames": int(count) if count.isdigit() else None,
                                                                   "logged_draws": logged,
                                                                   "mapping": "movie frame i is the i-th frame_post_draw since the executor started; "
                                                                              "frames after the end record are the quit tail"}, indent=1))


def probe_movie(path):
    def ask(*fields):
        return subprocess.run(["ffprobe", "-v", "error", *fields, "-of", "csv=p=0", str(path)], capture_output=True, text=True).stdout.strip()
    frames = ask("-count_frames", "-select_streams", "v:0", "-show_entries", "stream=nb_read_frames")
    size = ask("-select_streams", "v:0", "-show_entries", "stream=width,height")
    duration = ask("-show_entries", "format=duration")
    decode = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], capture_output=True, text=True)
    return {"frames": int(frames) if frames.isdigit() else None, "size": size, "duration_s": float(duration) if duration else None,
            "decode_exit": decode.returncode, "decode_errors": decode.stderr.strip()[:400], "bytes": path.stat().st_size,
            "sha256": sha256_file(path)}


def finalize_movie(out, keep_avi=False):
    """encode the native mjpeg as an mp4; remove the avi only after the mp4 checks complete."""
    out = Path(out)
    avi, mp4 = out / "movie.avi", out / "movie.mp4"
    source = probe_movie(avi)
    encode = subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(avi), "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
                             "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(mp4)], capture_output=True, text=True)
    result = probe_movie(mp4) if mp4.exists() else None
    checks = {"encode_exit": encode.returncode, "encode_errors": encode.stderr.strip()[:400],
              "same_frame_count": bool(result) and source["frames"] is not None and result["frames"] == source["frames"] and source["frames"] > 0,
              "same_size": bool(result) and result["size"] == source["size"],
              "same_duration": bool(result) and None not in (result["duration_s"], source["duration_s"]) and abs(result["duration_s"] - source["duration_s"]) < 0.05,
              "decodes_cleanly": bool(result) and result["decode_exit"] == 0 and not result["decode_errors"] and source["decode_exit"] == 0}
    complete = encode.returncode == 0 and all(checks[k] for k in ("same_frame_count", "same_size", "same_duration", "decodes_cleanly"))
    record = {"avi": source, "mp4": result, "checks": checks, "complete": complete, "encoding": "libx264 crf 18 yuv420p (lossy, for review)",
              "avi_removed": False, "note": "movie frame i is still the i-th frame_post_draw; ssim on mp4 includes encoder loss"}
    if complete and not keep_avi:
        avi.unlink()
        record["avi_removed"] = True
    (out / "evaluator/movie.json").write_text(json.dumps(record, indent=1))
    return record


def movie_path(run_dir):
    for name in ("movie.avi", "movie.mp4"):
        if (Path(run_dir) / name).exists():
            return Path(run_dir) / name
    return None


# --- trace archive ----------------------------------------------------------------------------

def archive_run(run_dir):
    """gzip the evaluator traces losslessly, verify each by decompressing, then drop the raw file."""
    run_dir = Path(run_dir)
    manifest_path = run_dir / "evaluator/archive.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "format": "spillway-tape-archive", "version": 1, "files": {},
        "note": "gzip of the exact trace bytes; readers verify the uncompressed sha256 before use"}
    for rel in ARCHIVED:
        raw = run_dir / rel
        packed = raw.with_name(raw.name + ".gz")
        if not raw.exists():
            continue
        if packed.exists():
            raise SystemExit(f"{packed} exists; refusing to overwrite an archive")
        digest, size, lines = hashlib.sha256(), 0, 0
        partial = packed.with_name(packed.name + ".partial")
        with open(raw, "rb") as source, open(partial, "wb") as sink, gzip.GzipFile(filename="", mode="wb", fileobj=sink, mtime=0, compresslevel=6) as zipped:
            for block in iter(lambda: source.read(1 << 20), b""):
                digest.update(block)
                size += len(block)
                lines += block.count(b"\n")
                zipped.write(block)
        check = hashlib.sha256()
        with gzip.open(partial, "rb") as back:
            for block in iter(lambda: back.read(1 << 20), b""):
                check.update(block)
        if check.hexdigest() != digest.hexdigest():
            partial.unlink()
            raise SystemExit(f"archive of {raw} did not decompress to the same bytes; raw kept")
        partial.rename(packed)
        manifest["files"][raw.name] = {"gzip": packed.name, "sha256_uncompressed": digest.hexdigest(), "bytes_uncompressed": size,
                                       "lines": lines, "sha256_gzip": sha256_file(packed), "bytes_gzip": packed.stat().st_size}
        raw.unlink()
    manifest_path.write_text(json.dumps(manifest, indent=1))
    return manifest


def jsonl_exists(path):
    path = Path(path)
    return path.exists() or path.with_name(path.name + ".gz").exists()


def read_trace_bytes(path, info=None):
    """the raw bytes of a jsonl file, from the file itself or its verified .gz archive."""
    path = Path(path)
    info = {} if info is None else info
    if path.exists():
        info.update({"file": str(path), "archived": False})
        return path.read_bytes()
    packed = path.with_name(path.name + ".gz")
    data = gzip.decompress(packed.read_bytes())
    manifest = path.parent / "archive.json"
    entry = json.loads(manifest.read_text())["files"].get(path.name) if manifest.exists() else None
    info.update({"file": str(packed), "archived": True, "sha256_uncompressed": sha256_bytes(data)})
    if entry is None:
        info["verified"] = "no archive manifest entry: decompressed, hash not checked against a record"
    elif entry["sha256_uncompressed"] != info["sha256_uncompressed"]:
        raise ValueError(f"{packed} decompresses to {info['sha256_uncompressed']}, not the recorded {entry['sha256_uncompressed']}")
    else:
        info["verified"] = True
    return data


# --- evaluation -------------------------------------------------------------------------------

def read_jsonl(path, info=None):
    lines = [line for line in read_trace_bytes(path, info).decode().splitlines() if line.strip()]
    rows = []
    for i, line in enumerate(lines):
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            # only a killed engine leaves a cut-off final line; anything else is corrupt.
            if i != len(lines) - 1:
                raise
    return rows


def wrap(angle):
    return (angle + math.pi) % math.tau - math.pi


def hlen(v):
    return math.hypot(v[0], v[2])


def runs(ticks, minimum):
    """collapse sorted ticks into [start, end] windows at least `minimum` long."""
    out, start, last = [], None, None
    for t in ticks + [None]:
        if t is not None and last is not None and t == last + 1:
            last = t
            continue
        if start is not None and last - start + 1 >= minimum:
            out.append([start, last])
        start = last = t
    return out


def evaluate(run_dir):
    run_dir = Path(run_dir)
    plan = json.loads((run_dir / "evaluator/plan.json").read_text())
    engine = json.loads((run_dir / "evaluator/engine.json").read_text())
    end_path = run_dir / "end.json"
    end = json.loads(end_path.read_text()) if end_path.exists() else {"reason": "killed: no end record", "neutral": None}
    trace_info = {}
    rows = read_jsonl(run_dir / "evaluator/trace.jsonl", trace_info)
    # a row cut short by a rate fault has no post sample; it stays in the trace and rate report.
    tape = [r for r in rows if r["phase"] == "tape" and "post" in r]
    by_tick = {r["tick"]: r for r in tape}
    sens = float(engine["settings"]["mouse_sensitivity"])
    pitch_limit = float(engine["settings"].get("pitch_limit", 1.4))
    hz = engine["physics_hz"]
    dt = 1.0 / hz
    planned_keys = {}
    planned_mouse = {}
    for e in plan["events"]:
        if "key" in e:
            planned_keys.setdefault(e["tick"], []).append((e["key"], e["edge"]))
        else:
            planned_mouse[e["tick"]] = e["mouse"]
    delivery, order = [], []
    counter_verified_ticks = 0
    held, expected = set(), {}
    for t in range(plan["duration_ticks"]):
        for key, edge in planned_keys.get(t, []):
            (held.add if edge == "press" else held.discard)(key)
        expected[t] = set(held)
    # discontinuities: game resets between the pre sample and the motor (respawn, restart).
    jumps = set()
    for r in tape:
        if r.get("game") and r.get("game_pre") and r["game"]["respawns"] != r["game_pre"]["respawns"]:
            jumps.add(r["tick"])
    held_bad = []
    previous = None
    for r in tape:
        t, post = r["tick"], r["post"]
        if previous is not None and r["step"] != previous["step"] + 1:
            order.append({"tick": t, "kind": "skipped_step"})
        o = r["order"]
        if o.get("step_count_delta") is not None and t not in jumps:
            if o["step_count_delta"] == 1:
                counter_verified_ticks += 1
            else:
                order.append({"tick": t, "kind": "motor_step_count", "delta": o["step_count_delta"]})
        if not (o["same_physics_frame"] and o["in_physics"]) or o["motor_cur_matches_body"] is False:
            order.append({"tick": t, "kind": "capture_not_after_motor", "order": o})
        if o["motor_prev_matches_pre"] is False and t not in jumps:
            order.append({"tick": t, "kind": "motor_did_not_run_between_samples", "order": o})
        if set(post["actions"]) != expected.get(t, set()):
            held_bad.append(t)
        for key, edge in planned_keys.get(t, []):
            seen = post["just_pressed"] if edge == "press" else post["just_released"]
            if key not in seen:
                delivery.append({"tick": t, "kind": "edge_not_seen_by_motor_tick", "key": key, "edge": edge})
        applied = [(k["key"], k["edge"]) for k in r["keys"] if k["source"] == "tape"]
        if sorted(applied) != sorted(planned_keys.get(t, [])):
            delivery.append({"tick": t, "kind": "applied_keys_differ_from_plan", "planned": planned_keys.get(t, []), "applied": applied})
        m = r["mouse"]
        turned = 0.0
        if t in planned_mouse:
            dx, dy = planned_mouse[t]
            if not m:
                delivery.append({"tick": t, "kind": "mouse_not_applied"})
            else:
                turned = m["yaw_after"] - m["yaw_before"]
                for field in ("relative", "screen_relative"):
                    if abs(m[field][0] - dx) > 1e-9 or abs(m[field][1] - dy) > 1e-9:
                        delivery.append({"tick": t, "kind": f"mouse_{field}_differs", "planned": [dx, dy], "sent": m[field]})
                want_pitch = min(pitch_limit, max(-pitch_limit, m["pitch_before"] - dy * sens)) - m["pitch_before"]
                if abs(turned + dx * sens) > 1e-9 or abs((m["pitch_after"] - m["pitch_before"]) - want_pitch) > 1e-9:
                    delivery.append({"tick": t, "kind": "view_did_not_follow_mouse", "expected_yaw": -dx * sens, "observed_yaw": turned})
        elif m:
            delivery.append({"tick": t, "kind": "unplanned_mouse_applied"})
        if previous is not None and t not in jumps:
            unexplained = post["yaw"] - previous["post"]["yaw"] - turned
            if abs(unexplained) > 1e-9:
                delivery.append({"tick": t, "kind": "unplanned_view_change", "radians": unexplained})
        body_policy = engine.get("body_yaw_policy", "view_yaw")
        if body_policy not in ("view_yaw", "axis_aligned"):
            order.append({"tick": t, "kind": "unknown_body_yaw_policy", "policy": body_policy})
        expected_body_yaw = 0.0 if body_policy == "axis_aligned" else post["yaw"]
        if abs(wrap(post["motor_rotation_y"] - expected_body_yaw)) > 1e-5:
            order.append({"tick": t, "kind": "motor_body_yaw_differs_from_policy", "policy": body_policy,
                          "rotation_y": post["motor_rotation_y"], "expected_yaw": expected_body_yaw})
        previous = r
    for window in runs(held_bad, 1):
        delivery.append({"tick": window[0], "kind": "held_state_differs_from_plan", "until": window[1],
                         "expected": sorted(expected.get(window[0], [])), "observed": by_tick[window[0]]["post"]["actions"]})
    if end.get("still_pressed_after_release"):
        delivery.append({"kind": "still_pressed_after_neutral_release", "keys": end["still_pressed_after_release"]})
    if end.get("undelivered"):
        delivery.append({"kind": "undelivered_events", "events": end["undelivered"]})
    if end.get("reason") == "completed" and len(tape) != plan["duration_ticks"]:
        order.append({"kind": "tick_count", "captured": len(tape), "planned": plan["duration_ticks"]})

    # movement: actual finite-difference displacement, never the reported speed alone.
    disp = {r["tick"]: hlen(r["post"]["disp_v"]) for r in tape}
    reported = {r["tick"]: float(r["post"]["speed_reported"]) for r in tape}
    vpost = {r["tick"]: hlen(r["post"]["v"]) for r in tape}
    walls = {r["tick"]: [c["body"] for c in r["post"]["contacts"] if abs(c["normal"][1]) < 0.7] for r in tape}
    ticks = sorted(disp)
    stuck = runs([t for t in ticks if t not in jumps and disp[t] < 0.25 and MOVE_KEYS & set(by_tick[t]["post"]["actions"])], 60)
    hard = []
    for t in ticks:
        before = [disp.get(t - k) for k in (3, 4, 5, 6)]
        if None not in before and not any(t - k in jumps for k in (3, 4, 5, 6)) and sum(before) / 4 > 4.0 and disp[t] < 0.5 and (walls[t] or walls.get(t - 1)) and t not in jumps:
            if not hard or t - hard[-1]["tick"] > 30:
                hard.append({"tick": t, "sim_s": t * dt, "approach_m_s": sum(before) / 4, "after_m_s": disp[t],
                             "p": by_tick[t]["post"]["p"], "contacts": walls[t] or walls.get(t - 1)})

    def mismatch(values):
        bad = [t for t in ticks if t not in jumps and abs(values[t] - disp[t]) > max(1.0, 0.25 * max(values[t], disp[t]))]
        return [{"from_tick": a, "to_tick": b, "reported_m_s": values[a], "displacement_m_s": disp[a]} for a, b in runs(bad, 30)]

    # p / horizontal vectors, not only their lengths: opposite headings at equal speed
    # must fail too. vertical support motion is deliberately outside this check's scope.
    vector_error = {t: math.hypot(by_tick[t]["post"]["v"][0] - by_tick[t]["post"]["disp_v"][0],
                                by_tick[t]["post"]["v"][2] - by_tick[t]["post"]["disp_v"][2]) for t in ticks}
    vector_bad = [t for t in ticks if t not in jumps and vector_error[t] > max(1.0, 0.25 * max(vpost[t], disp[t]))]
    vector_mismatches = [{"from_tick": a, "to_tick": b, "error_m_s": vector_error[a],
                          "post_velocity": by_tick[a]["post"]["v"],
                          "displacement_velocity": by_tick[a]["post"]["disp_v"]} for a, b in runs(vector_bad, 30)]

    frames = read_jsonl(run_dir / "evaluator/frames.jsonl") if jsonl_exists(run_dir / "evaluator/frames.jsonl") else []
    detached = []
    follow_errors = []
    for f in frames:
        if f.get("sim_s") is None:
            continue
        c, p = f["camera"]["p"], f["feet"]
        if math.hypot(c[0] - p[0], c[2] - p[2]) > 0.35 or not 0.3 <= c[1] - p[1] <= 2.2:
            detached.append(f["draw"])
        if f.get("motor_prev") is not None and f.get("motor_cur") is not None and f.get("interp_fraction") is not None:
            # the eye is placed horizontally on the physics interpolation of the body itself.
            a, b, u = f["motor_prev"], f["motor_cur"], min(1.0, max(0.0, f["interp_fraction"]))
            error = math.hypot(c[0] - (a[0] + (b[0] - a[0]) * u), c[2] - (a[2] + (b[2] - a[2]) * u))
            follow_errors.append(error)
            if error > 1e-3 and f["draw"] not in detached:
                detached.append(f["draw"])
    jump_edges = [t for t, edges in planned_keys.items() for k, e in edges if k == "space" and e == "press"]
    jump_results = []
    for t in sorted(jump_edges):
        if t not in by_tick:
            continue
        base = by_tick[t]["post"]["jumps"] - (1 if by_tick[t]["post"]["jumps"] > by_tick.get(t - 1, by_tick[t])["post"]["jumps"] else 0)
        later = next((u for u in range(t, min(t + 15, plan["duration_ticks"])) if u in by_tick and by_tick[u]["post"]["jumps"] > base), None)
        jump_results.append({"press_tick": t, "jump_tick": later, "grounded_at_press": by_tick[t]["pre"]["grounded"]})
    # wall time against simulated time; under --fixed-fps this is compute cost, not latency.
    rate = rate_report(plan, engine, rows, end)
    lag = sorted((r["wall_us_pre"] - tape[0]["wall_us_pre"]) / 1e6 - r["tick"] * dt for r in tape) if tape else [0.0]
    timing = {"fixed_fps": "--fixed-fps" in engine["cmdline"], "wall_s": (tape[-1]["wall_us_post"] - tape[0]["wall_us_pre"]) / 1e6 if tape else 0,
              "sim_s": len(tape) * dt, "wall_minus_sim_max_s": lag[-1], "wall_minus_sim_p95_s": lag[int(0.95 * (len(lag) - 1))],
              "note": "fixed-fps runs are not paced to wall time" if "--fixed-fps" in engine["cmdline"] else "realtime: positive lag means ticks ran late against the wall clock"}
    first, last = tape[0]["pre"]["p"] if tape else None, tape[-1]["post"]["p"] if tape else None
    movement = {
        "stuck_windows": [{"from_tick": a, "to_tick": b, "contacts": sorted({x for t in range(a, b + 1) for x in walls[t]})} for a, b in stuck],
        "contact_hard_stops": hard,
        "reported_speed_unsupported": mismatch(reported),
        "post_velocity_unsupported": vector_mismatches,
        "camera_detached_draws": detached[:50],
        "camera_follow": {"draws_checked": len(follow_errors), "max_horizontal_error_m": max(follow_errors, default=None),
                          "method": "camera xz against lerp(_previous_position, _current_position, physics interpolation fraction) at each draw"
                          if follow_errors else "coarse only: within 0.35 m horizontally and 0.3..2.2 m above the feet"},
        "jump_presses": jump_results,
        "discontinuities": sorted(jumps),
    }
    flags = [name for name in ["stuck_windows", "contact_hard_stops"] if movement[name]]
    integrity = [name for name in ["reported_speed_unsupported", "post_velocity_unsupported", "camera_detached_draws"] if movement[name]]
    travel_ticks = [t for t in ticks if t not in jumps]
    return {
        "run": str(run_dir), "tape": plan["name"], "world": engine["world"], "start": engine["start"], "motor": engine["motor"],
        "profile": plan["input_profile"], "inject": engine["inject"], "sensitivity": engine["settings"],
        "end": end.get("reason"), "neutral": end.get("neutral"),
        "delivery": {"ok": not delivery, "errors": delivery[:60], "error_count": len(delivery)},
        "order": {"ok": not order, "errors": order[:30], "error_count": len(order),
                  "counter_verified_ticks": counter_verified_ticks,
                  "strength": "counter_verified" if counter_verified_ticks == len(tape) and tape else "state_or_priority_consistency_only",
                  "proof": "per tick: pre sample and mouse in Early (priority -1000), post sample in Late (priority 1000) in the same physics frame; "
                           "interpolation fields check state consistency; only a tape_step_count delta of one verifies exactly one motor step, "
                           "because unchanged positions alone cannot detect a skipped or repeated stationary step"},
        "movement_flags": flags, "integrity_flags": integrity, "movement": movement, "timing": timing, "rate": rate,
        "trace_source": trace_info,
        "outcome": {"ticks": len(tape), "start_p": first, "end_p": last,
                    "travel_m": sum(disp[t] for t in travel_ticks) * dt,
                    "max_displacement_m_s": max((disp[t] for t in travel_ticks), default=0.0),
                    "travel_excludes_discontinuities": True,
                    "end_yaw": tape[-1]["post"]["yaw"] if tape else None, "jumps": tape[-1]["post"]["jumps"] if tape else 0,
                    "respawns": tape[-1].get("game", {}).get("respawns")},
    }


def rate_report(plan, engine, rows, end):
    """the declared rate against what the engine actually handed each sampled step."""
    hz = plan["physics_hz"]
    dt = 1.0 / hz
    tape = [r for r in rows if r["phase"] == "tape"]
    sampled = [r for r in rows if "rate" in r]
    if not sampled:
        return {"ok": None, "declared_hz": hz, "note": "trace predates per-tick rate fields; only the engine metadata rate is known",
                "engine_hz": engine.get("physics_hz")}
    bad = [{"step": r["step"], "tick": r["tick"], "rate": r["rate"]} for r in sampled
           if r["rate"]["dt"] != dt or r["rate"].get("dt_late", dt) != dt or r["rate"]["engine_hz"] != hz
           or r["rate"].get("engine_hz_late", hz) != hz or r["rate"]["time_scale"] != 1.0]
    sim_sum = math.fsum(r["rate"]["dt"] for r in tape if "dt_late" in r["rate"])
    complete = [r for r in tape if "post" in r]
    # p / labelled consistency: the executor's running sum of actual deltas equals tick count / rate.
    drift = max((abs(r["rate"]["sim_dt_sum_s"] - r["tick"] * dt) for r in complete if r["rate"].get("sim_dt_sum_s") is not None), default=0.0)
    return {"ok": not bad and engine.get("physics_hz") == hz and not end.get("rate_fault") and drift < 1e-9,
            "declared_hz": hz, "tape_version": plan.get("version"), "engine_hz": engine.get("physics_hz"),
            "requested_hz": engine.get("physics_hz_requested"), "project_hz": engine.get("physics_hz_project"),
            "declared_by_game": engine.get("rate_declared"), "policy": engine.get("rate_policy"),
            "dt_expected": dt, "dt_observed": sorted({r["rate"]["dt"] for r in sampled}),
            "sampled_steps": len(sampled), "tape_ticks": len(complete), "sim_s_from_actual_dt": sim_sum,
            "sim_s_from_ticks": len(complete) * dt, "dt_sum_drift_s": drift,
            "bad_steps": bad[:20], "bad_step_count": len(bad), "fault": end.get("rate_fault"),
            "priorities": engine.get("priorities")}


def applied_tape(run_dir):
    """the relative events the executor actually applied, as a replayable expanded tape."""
    run_dir = Path(run_dir)
    plan = json.loads((run_dir / "evaluator/plan.json").read_text())
    events = []
    for r in read_jsonl(run_dir / "evaluator/trace.jsonl"):
        if r["phase"] != "tape":
            continue
        for k in r["keys"]:
            if k["source"] == "tape":
                events.append({"tick": r["tick"], "key": k["key"], "edge": k["edge"]})
        if r["mouse"]:
            events.append({"tick": r["tick"], "mouse": [r["mouse"]["dx"], r["mouse"]["dy"]]})
    events.sort(key=lambda e: (e["tick"], 0 if "key" in e else 1))
    applied = {"format": FORMAT, "version": plan["version"], "expanded": True, "name": plan["name"] + " / applied",
               "description": f"applied relative events of {run_dir}", "physics_hz": plan["physics_hz"],
               "input_profile": plan["input_profile"], "duration_ticks": plan["duration_ticks"], "events": events}
    if plan["version"] == 2:
        applied["duration_s"] = plan["duration_s"]
    return applied


def ssim(a, b):
    result = subprocess.run(["ffmpeg", "-v", "info", "-i", str(a), "-i", str(b), "-lavfi", "[0:v][1:v]ssim", "-f", "null", "-"],
                            capture_output=True, text=True)
    match = re.search(r"All:([0-9.]+)", result.stderr)
    return float(match.group(1)) if match else None


def compare(a, b):
    a, b = Path(a), Path(b)
    info_a, info_b = {}, {}
    ra = {r["tick"]: r for r in read_jsonl(a / "evaluator/trace.jsonl", info_a) if r["phase"] == "tape" and "post" in r}
    rb = {r["tick"]: r for r in read_jsonl(b / "evaluator/trace.jsonl", info_b) if r["phase"] == "tape" and "post" in r}
    hz = [json.loads((d / "evaluator/plan.json").read_text())["physics_hz"] for d in (a, b)]
    common = sorted(set(ra) & set(rb))
    dp = [max(abs(x - y) for x, y in zip(ra[t]["post"]["p"], rb[t]["post"]["p"])) for t in common]
    dv = [max(abs(x - y) for x, y in zip(ra[t]["post"]["v"], rb[t]["post"]["v"])) for t in common]
    dyaw = [abs(ra[t]["post"]["yaw"] - rb[t]["post"]["yaw"]) for t in common]
    first = next((t for t, d in zip(common, dp) if d > 0.0), None)
    result = {"a": str(a), "b": str(b), "ticks_a": len(ra), "ticks_b": len(rb), "common": len(common),
              "max_position_m": max(dp, default=None), "max_velocity_m_s": max(dv, default=None), "max_yaw_rad": max(dyaw, default=None),
              "first_position_difference_tick": first,
              "end_yaw": [ra[common[-1]]["post"]["yaw"], rb[common[-1]]["post"]["yaw"]] if common else None,
              "same_applied_events": applied_tape(a)["events"] == applied_tape(b)["events"],
              "physics_hz": hz, "same_rate": hz[0] == hz[1], "trace_source": [info_a, info_b]}
    if hz[0] != hz[1]:
        result["note"] = "different rates: tick n is not the same simulated time in both runs"
    movies = [movie_path(a), movie_path(b)]
    if None not in movies:
        result["movie_ssim_all"] = ssim(*movies)
        result["movie_files"] = [m.name for m in movies]
    return result


# --- minimization -----------------------------------------------------------------------------

def units(plan):
    """removable pieces: each key hold (press with its release) and each mouse stroke."""
    out, open_press, stroke = [], {}, []
    period = tape_period(plan)
    for i, e in enumerate(plan["events"]):
        if "key" in e:
            if e["edge"] == "press":
                open_press[e["key"]] = [i]
            else:
                out.append(open_press.pop(e["key"]) + [i])
        else:
            if stroke and e["tick"] != plan["events"][stroke[-1]]["tick"] + period:
                out.append(stroke)
                stroke = []
            stroke.append(i)
    out += [v for v in open_press.values()] + ([stroke] if stroke else [])
    return out


def predicate_holds(report, spec):
    if not report.get("delivery", {}).get("ok"):
        return False
    if spec["flag"] not in report.get("movement_flags", []):
        return False
    end = report["outcome"]["end_p"]
    return spec.get("final_y_above") is None or (end is not None and end[1] > spec["final_y_above"])


def minimize(plan, out, cfg, spec):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=False)
    log = open(out / "minimize-log.jsonl", "w")
    attempt = [0]

    def trial(candidate, note):
        attempt[0] += 1
        report = execute(candidate, out / f"attempt-{attempt[0]:03d}", dict(cfg, headless=True))
        holds = predicate_holds(report, spec)
        log.write(json.dumps({"attempt": attempt[0], "note": note, "events": len(candidate["events"]),
                              "duration": candidate["duration_ticks"], "holds": holds, "flags": report.get("movement_flags")}) + "\n")
        log.flush()
        return holds, report

    holds, report = trial(plan, "original")
    if not holds:
        raise SystemExit("the original tape does not show the failure; nothing to minimize")
    current = plan
    changed = True
    while changed:
        changed = False
        for unit in sorted(units(current), key=len, reverse=True):
            candidate = copy.deepcopy(current)
            candidate["events"] = [e for i, e in enumerate(current["events"]) if i not in unit]
            ok, _ = trial(candidate, f"drop events {unit}")
            if ok:
                current, changed = candidate, True
                break
    # cut the tape shortly after the first flagged tick; later events cannot cause it.
    _, report = trial(current, "locate the first flagged tick")
    found = report["movement"][spec["flag"]][0]
    first = found.get("tick", found.get("from_tick"))
    period = tape_period(current)
    for duration in sorted({min(current["duration_ticks"], first + span) for span in (30, 60, 120)}):
        duration += -duration % period
        if duration >= current["duration_ticks"]:
            continue
        candidate = dict(copy.deepcopy(current), duration_ticks=duration)
        if candidate["version"] == 2:
            candidate["duration_s"] = duration / candidate["physics_hz"]
        candidate["events"] = [e for e in candidate["events"] if e["tick"] < duration]
        ok, _ = trial(candidate, f"truncate to {duration}")
        if ok:
            current = candidate
            break
    current["name"] = plan["name"] + " / minimized"
    current["description"] = f"minimized from {plan['name']} for {spec}; {attempt[0]} headless attempts"
    log.close()
    (out / "minimized.json").write_text(json.dumps(current, indent=1))
    return current


# --- command line -----------------------------------------------------------------------------

def run_config(args):
    keys = ["world", "motor", "motor_script", "game_script", "game_class", "fixture", "sensitivity", "inject", "timing", "render_fps", "headless",
            "wall_budget", "deadline", "display", "executor", "actor_every", "warmup", "cancel_after", "hang_after", "readback_every",
            "undeclared_rate_ok", "resolution", "mp4", "keep_avi", "actor_limit", "archive", "min_free_gib", "max_movie_mib"]
    cfg = {k: getattr(args, k) for k in keys if getattr(args, k, None) is not None}
    if cfg.get("world", "lab").startswith("fixture:"):
        cfg["fixture"] = cfg.pop("world").split(":", 1)[1]
    else:
        cfg.pop("world", None)
    return cfg


def add_run_options(p):
    p.add_argument("--world", default="lab", help="lab (normal spawn on the course) or fixture:NAME (flat, step)")
    p.add_argument("--motor", default="flow", help="passed to the game's `motor` property; in a fixture: flow, r12 or a script path")
    p.add_argument("--game-script", help="lab world factory: a res:// Node script (default the r13 lab)")
    p.add_argument("--game-class", help="inner class of --game-script to instantiate ('' for the script itself)")
    p.add_argument("--motor-script", help="fixture only: a disposable motor variant script")
    p.add_argument("--sensitivity", type=float, default=1.0, help="main's settings multiplier (0.0022 rad per pixel at 1.0)")
    p.add_argument("--inject", choices=["tick", "process"], default="tick")
    p.add_argument("--timing", choices=["fixed", "realtime"], default="fixed")
    p.add_argument("--render-fps", type=int, default=30)
    p.add_argument("--headless", action="store_true", help="no display or frames; physics and input only")
    p.add_argument("--wall-budget", type=float, default=120, help="executor wall-time budget, seconds")
    p.add_argument("--deadline", type=float, help="wrapper hard deadline, seconds (default budget + 45)")
    p.add_argument("--display", type=int, default=153)
    p.add_argument("--executor", help="a disposable executor variant (negative controls only)")
    p.add_argument("--actor-every", type=int, default=6, help="sample every Nth rendered frame for actor/")
    p.add_argument("--readback-every", type=int, default=4)
    p.add_argument("--warmup", type=int, default=8)
    p.add_argument("--cancel-after", type=float, help="request cancellation after N wall seconds")
    p.add_argument("--hang-after", type=float, help="test only: SIGSTOP the engine after N seconds")
    p.add_argument("--undeclared-rate-ok", action="store_true", default=None,
                   help="allow a non-project rate when neither game nor motor declares physics_hz (an off-design probe)")
    p.add_argument("--resolution", help="native window and display size, WxH (default 1280x720)")
    p.add_argument("--mp4", action="store_true", default=None, help="encode movie.avi as mp4 and remove the avi after completeness checks")
    p.add_argument("--keep-avi", action="store_true", default=None, help="with --mp4, keep the avi too")
    p.add_argument("--actor-limit", type=int, help="keep at most N evenly spaced actor frames")
    p.add_argument("--archive", action="store_true", default=None, help="after evaluation, gzip trace/frames losslessly and drop the raw files")
    p.add_argument("--min-free-gib", type=float, help=f"refuse a native start below this free space (default {MIN_FREE_GIB})")
    p.add_argument("--max-movie-mib", type=float, help="cancel a native capture whose avi outgrows this (default 2048)")


def summary(report):
    keys = ["run", "end", "neutral", "movement_flags", "integrity_flags", "outcome"]
    s = {k: report.get(k) for k in keys}
    s["delivery_ok"] = report.get("delivery", {}).get("ok")
    s["delivery_errors"] = [e["kind"] for e in report.get("delivery", {}).get("errors", [])][:10]
    s["order_ok"] = report.get("order", {}).get("ok")
    s["rate_ok"] = report.get("rate", {}).get("ok")
    s["archived"] = bool(report.get("archive"))
    s["clean"] = report.get("cleanup", {}).get("clean")
    return s


def execution_exit(report):
    end = report.get("end")
    reason = end.get("reason") if isinstance(end, dict) else end
    return 2 if reason in {"launch_failed", "wrapper_failed", "rejected", "rate_changed"} else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("expand", help="validate a tape and print its expanded form")
    p.add_argument("tape", type=Path)
    p = sub.add_parser("run", help="run a tape in a fresh evidence directory")
    p.add_argument("tape", type=Path)
    p.add_argument("--out", type=Path, required=True)
    add_run_options(p)
    p = sub.add_parser("replay", help="replay a run's applied events in a fresh run and profile")
    p.add_argument("source", type=Path)
    p.add_argument("--out", type=Path, required=True)
    add_run_options(p)
    p = sub.add_parser("evaluate", help="re-evaluate an existing run")
    p.add_argument("run", type=Path)
    p = sub.add_parser("compare", help="compare two runs tick by tick")
    p.add_argument("a", type=Path)
    p.add_argument("b", type=Path)
    p = sub.add_parser("archive", help="gzip an evaluated run's traces losslessly and drop the raw files")
    p.add_argument("run", type=Path)
    p = sub.add_parser("cancel", help="ask a running executor to stop with neutral input")
    p.add_argument("run", type=Path)
    p = sub.add_parser("minimize", help="shrink a tape while a movement flag still fires (headless)")
    p.add_argument("tape", type=Path)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--flag", default="contact_hard_stops")
    p.add_argument("--final-y-above", type=float)
    add_run_options(p)
    args = parser.parse_args()
    if args.command == "expand":
        print(json.dumps(expand(json.loads(args.tape.read_text())), indent=1))
    elif args.command == "run":
        report = execute(expand(json.loads(args.tape.read_text())), args.out, run_config(args))
        print(json.dumps(summary(report), indent=1))
        return execution_exit(report)
    elif args.command == "replay":
        tape = applied_tape(args.source)
        report = execute(expand(tape), args.out, run_config(args))
        print(json.dumps(summary(report), indent=1))
        return execution_exit(report)
    elif args.command == "evaluate":
        print(json.dumps(evaluate(args.run), indent=1))
    elif args.command == "compare":
        print(json.dumps(compare(args.a, args.b), indent=1))
    elif args.command == "archive":
        print(json.dumps(archive_run(args.run), indent=1))
    elif args.command == "cancel":
        (args.run / "control/cancel").write_text(json.dumps({"reason": "cancel command"}))
    elif args.command == "minimize":
        spec = {"flag": args.flag, "final_y_above": args.final_y_above}
        print(json.dumps(minimize(expand(json.loads(args.tape.read_text())), args.out, run_config(args), spec), indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
