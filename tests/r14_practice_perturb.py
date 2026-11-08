#!/usr/bin/env python3
"""Perturb frozen Penstock Yard v2 momentum tapes and replay them open loop.

  r14_practice_perturb.py run TAPE --preset csgo_server --out DIR [--godot PATH] [--jobs N]

Writes one variant tape per perturbation into DIR/<variant>/tape.json, replays each through
tests/r14_practice_driver.gd --tape= (no state is read to choose input), and writes
DIR/perturb.json with the outcome of every variant. Perturbations, each on its own:

  space_shift_K    every space press and release moved K ticks (K = -2, -1, +1, +2)
  strafe_shift_K   every a and d press and release moved K ticks
  key_jitter_S     every a, d and space edge moved -1, 0 or +1 ticks at random (seed S)
  mouse_gain_G     every mouse count scaled by G (0.95, 1.05)
  mouse_noise_S    every mouse count times 1 + N(0, 0.03), plus N(0, 0.02) counts (seed S)

A variant survives when it finishes clean with no respawn, no pit or return lane and no wall
contact. Each also says when it first ran 0.25 m and 1 m off the unperturbed replay.

Integer fields stay ints and mouse counts are float32 values, as the strict v2 validator
expects. A key's edges stay strictly in order: an edge that would land on or before the
previous edge of the same key moves to the tick after it.
"""
import argparse
import concurrent.futures
import gzip
import json
import os
import random
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
DEFAULT_GODOT = os.path.expanduser("~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64")
RATES = {"csgo_server": 128, "csgo_vanilla": 64}


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


def shift_keys(tape, keys, delta_for):
    """move each edge of `keys` by delta_for(event); keep an edge whose move breaks order."""
    last = tape["duration_ticks"] - 1
    events = [dict(e) for e in tape["events"]]
    by_key = {}
    for i, e in enumerate(events):
        if e.get("key") in keys:
            by_key.setdefault(e["key"], []).append(i)
    for idx in by_key.values():
        idx.sort(key=lambda i: events[i]["tick"])
        floor = 0
        for i in idx:
            # a key's edges stay strictly in order: an edge never lands on or before the last one.
            events[i]["tick"] = int(min(last, max(floor, events[i]["tick"] + delta_for(events[i]))))
            floor = events[i]["tick"] + 1
    return events


def variants(tape):
    out = {}
    for k in (-2, -1, 1, 2):
        out[f"space_shift_{k:+d}"] = shift_keys(tape, {"space"}, lambda e, k=k: k)
        out[f"strafe_shift_{k:+d}"] = shift_keys(tape, {"a", "d"}, lambda e, k=k: k)
    for seed in (1, 2, 3):
        rng = random.Random(seed)
        out[f"key_jitter_{seed}"] = shift_keys(tape, {"a", "d", "space"}, lambda e, rng=rng: rng.choice((-1, 0, 1)))
    for gain in (0.95, 1.05):
        out[f"mouse_gain_{gain:.2f}"] = [
            dict(e, mouse=[f32(e["mouse"][0] * gain), 0.0]) if "mouse" in e else dict(e) for e in tape["events"]]
    for seed in (1, 2, 3):
        rng = random.Random(100 + seed)
        out[f"mouse_noise_{seed}"] = [
            dict(e, mouse=[f32(e["mouse"][0] * (1.0 + rng.gauss(0.0, 0.03)) + rng.gauss(0.0, 0.02)), 0.0]) if "mouse" in e else dict(e)
            for e in tape["events"]]
    return out


def write_tape(tape, events, name, path):
    events = sorted(events, key=lambda e: (e["tick"], 0 if "mouse" in e else 1))
    body = {k: v for k, v in tape.items() if k != "events"}
    body["name"] = f"{tape.get('name', 'tape')}-{name}"
    body["description"] = f"perturbed ({name}) from a closed-loop tape; open-loop replay"
    for key in ("version", "physics_hz", "duration_ticks"):
        body[key] = int(body[key])
    body["events"] = [dict(e, tick=int(e["tick"])) for e in events]
    with open(path, "w") as f:
        json.dump(body, f)


def outcome(summary):
    pits = [s for s in summary.get("supports", []) if any(w in s["piece"] for w in ("pit", "lane", "return"))]
    reached = max((int(c["checkpoint"]) for c in summary.get("checkpoints", [])), default=0)
    # a finish that leaned on a wall on the way does not count as surviving.
    clean = summary.get("finish_kind") == "clean" and int(summary.get("respawns", 0)) == 0 and not pits \
        and int(summary.get("wall_contact_ticks", 0)) == 0
    return {
        "survived": clean, "finish_kind": summary.get("finish_kind"), "finish_time_s": summary.get("finish_time_s"),
        "respawns": summary.get("respawns"), "wall_contact_ticks": summary.get("wall_contact_ticks"),
        "max_display_speed_ups": summary.get("max_display_speed_ups"), "checkpoint_reached": reached,
        "first_pit": pits[0] if pits else None,
    }


def positions(out_dir):
    with gzip.open(os.path.join(out_dir, "trace.jsonl.gz")) as f:
        return {(r := json.loads(line))["t"]: (r["p"], r["cp"]) for line in f}


def divergence(base, run, hz):
    """first tick where the replay is 0.25 m and 1 m off the unperturbed run, with its stage."""
    out = {}
    for limit in (0.25, 1.0):
        hit = None
        for t in sorted(base):
            if t not in run:
                break
            a, b = base[t][0], run[t][0]
            if sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5 > limit:
                hit = t
                break
        key = f"off_{limit:g}m"
        out[key] = None if hit is None else {"tick": hit, "s": round(hit / hz, 3), "checkpoint": base[hit][1]}
    return out


def replay(godot, preset, tape_path, out_dir):
    hz = RATES[preset]
    log = os.path.join(out_dir, "driver.log")
    with open(log, "w") as f:
        subprocess.run([godot, "--headless", "--audio-driver", "Dummy", "--fixed-fps", str(hz), "--path", PROJECT,
                        "--script", "res://tests/r14_practice_driver.gd", "--", f"--out={out_dir}", f"--preset={preset}",
                        f"--tape={tape_path}"], stdout=f, stderr=subprocess.STDOUT, timeout=900, check=False)
    with open(os.path.join(out_dir, "summary.json")) as f:
        return outcome(json.load(f))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["run"])
    p.add_argument("tape")
    p.add_argument("--preset", required=True, choices=sorted(RATES))
    p.add_argument("--out", required=True)
    p.add_argument("--godot", default=DEFAULT_GODOT)
    p.add_argument("--jobs", type=int, default=6)
    a = p.parse_args()
    with open(a.tape) as f:
        tape = json.load(f)
    assert tape.get("version") == 2 and int(tape["physics_hz"]) == RATES[a.preset], "tape rate does not match the preset"
    os.makedirs(a.out, exist_ok=True)
    jobs = {}
    for name, events in variants(tape).items():
        d = os.path.join(a.out, name)
        os.makedirs(d, exist_ok=True)
        write_tape(tape, events, name, os.path.join(d, "tape.json"))
        jobs[name] = d
    base = os.path.join(a.out, "unperturbed")
    os.makedirs(base, exist_ok=True)
    write_tape(tape, tape["events"], "unperturbed", os.path.join(base, "tape.json"))
    jobs = {"unperturbed": base, **jobs}
    with concurrent.futures.ThreadPoolExecutor(a.jobs) as pool:
        futures = {n: pool.submit(replay, a.godot, a.preset, os.path.join(d, "tape.json"), d) for n, d in jobs.items()}
        results = {n: f.result() for n, f in futures.items()}
    hz = RATES[a.preset]
    base_trace = positions(base)
    for n, d in jobs.items():
        results[n].update(divergence(base_trace, positions(d), hz))
    report = {"tape": os.path.abspath(a.tape), "preset": a.preset, "variants": results}
    with open(os.path.join(a.out, "perturb.json"), "w") as f:
        json.dump(report, f, indent=1)
    for n, r in results.items():
        pit = r["first_pit"]["piece"] if r["first_pit"] else ""
        off = r["off_0.25m"]
        held = f"{off['s']:7.2f}s (stage {off['checkpoint']})" if off else "   never"
        print(f"{n:18s} {'ok  ' if r['survived'] else 'FAIL'} {r['finish_kind'] or '-':6s} {r['finish_time_s'] or 0:8.3f}s "
              f"cp {r['checkpoint_reached']} walls {r['wall_contact_ticks']:5d} 0.25 m off at {held} {pit}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
