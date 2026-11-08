#!/usr/bin/env python3
"""independent review of packed_input_audit(): engine input reductions, crouch timing sweeps and
broken-data controls, on a frozen committed snapshot plus the two review harness files.

source mode only, under the pinned editor. no export, release runtime or native render runs.
expected results are fixed before the run: "pass" cases are real play the audit must accept,
"refuse" cases are real capture regressions or broken records it must reject, and "gap" cases
document what this audit does not judge (they are not failures of the run).
"""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import io
import json
import math
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
OWN = ["tests/r15_pack_observer_review.gd", "tests/r15_pack_observer_review.gd.uid"]
FROZEN = ["tools/package-r15.py", "tools/r15-pack-probe.gd", "tools/momentum-tape.py", "tools/momentum-tape.gd",
          "scripts/r15_main.gd", "scripts/r15_source_player.gd", "scripts/r14_source_player.gd", "scripts/r14_source_motion.gd",
          "tests/r15_loop_fixture_level.gd", "tests/test_r15_pack_observer.py", "tests/test_r15_pack_observer.gd"]
U = 0.0254


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def edge(tick, key, state):
    return {"tick": tick, "key": key, "edge": state}


def tape(events, duration, hz=128):
    return {"format": "spillway-momentum-tape", "version": 2, "name": "pack observer review", "physics_hz": hz,
            "duration_ticks": duration, "duration_s": duration / hz, "input_profile": "physics_tick", "expanded": True, "events": events}


def hop(extra, duration):
    return sorted([edge(0, "w", "press"), edge(10, "space", "press"), edge(11, "space", "release")] + extra
                  + [edge(duration - 2, "w", "release")], key=lambda e: e["tick"])


def build_cases(full):
    """(name, expect, plan, options). expectations are fixed here, before any engine output."""
    mouse = [{"tick": 45, "mouse": [20, -10]}, {"tick": 46, "mouse": [-10, 2500]}, {"tick": 47, "mouse": [0, -2500]}]
    base = hop([edge(35, "ctrl", "press"), edge(70, "ctrl", "release")] + mouse, 256)
    cases = [("baseline-air-f2", "pass", tape(base, 256), {}),
             ("baseline-air-f5", "pass", tape(base, 256), {"preset": "server128_aa1000"}),
             # real input reductions: the harness's own injection regresses, the game is untouched.
             ("drop-w-release", "refuse", tape(base, 256), {"variant": {"drop_tick": 70}}),
             ("ctrl-one-tick-late", "refuse", tape(base, 256), {"variant": {"late_tick": 35}}),
             ("ctrl-one-tick-early", "refuse", tape(base, 256), {"variant": {"early_tick": 35}}),
             ("logical-key-only", "refuse", tape(base, 256), {"variant": {"key_mode": "logical_only"}}),
             ("action-press-only", "refuse", tape(base, 256), {"variant": {"key_mode": "action_only"}}),
             ("mouse-after-motor", "refuse", tape(base, 256), {"variant": {"mouse_after_motor": True}}),
             ("pack-sensitivity-2.0", "refuse", tape(base, 256), {"sensitivity": 2.0, "audit_settings_from": "baseline-air-f2"}),
             ("forced-respawn", "refuse-labelled", tape(base, 256), {"variant": {"respawn_tick": 150}}),
             ("r13-120-with-ctrl", "pass", tape(hop([edge(35, "ctrl", "press"), edge(70, "ctrl", "release")] + mouse, 240), 240, 120),
              {"preset": "r13_original120"})]
    # crouch timing sweeps around takeoff, flight and landing (expected: every one accepted).
    presses = range(6, 104) if full else [9, 10, 11, 12, 60, 90]
    for p in presses:
        cases.append(("press-%03d" % p, "pass", tape(hop([edge(p, "ctrl", "press"), edge(p + 20, "ctrl", "release")], 160), 160), {}))
    releases = range(36, 112) if full else [60, 80, 95]
    for r in releases:
        cases.append(("release-%03d" % r, "pass", tape(hop([edge(35, "ctrl", "press"), edge(r, "ctrl", "release")], 160), 160), {}))
    for p in (range(10, 100, 3) if full else [12, 50]):
        cases.append(("tap-%03d" % p, "pass", tape(hop([edge(p, "ctrl", "press"), edge(p + 1, "ctrl", "release")], 160), 160), {}))
    for r in (range(12, 104, 4) if full else [40]):
        cases.append(("duckjump-%03d" % r, "pass", tape(hop([edge(5, "ctrl", "press"), edge(r, "ctrl", "release")], 160), 160), {}))
    for p in ([11, 40, 80] if full else [40]):
        cases.append(("f5-press-%03d" % p, "pass", tape(hop([edge(p, "ctrl", "press"), edge(p + 30, "ctrl", "release")], 160), 160),
                      {"preset": "server128_aa1000"}))
    # roof: ducked walk under the slab, a hop under it with the release in flight (blocked
    # standing), then the first clear tick after the roof, in the air or on the floor.
    for s in (range(100, 420, 16) if full else [150]):
        events = [edge(0, "w", "press"), edge(1, "ctrl", "press"), edge(s, "space", "press"), edge(s + 1, "space", "release"),
                  edge(s + 3, "ctrl", "release"), edge(638, "w", "release")]
        cases.append(("roof-hop-%03d" % s, "pass", tape(events, 640), {"roof": True}))
    return cases


def box_oracle(rows):
    """independent of the audit: on every tick the observed box must match the duck state."""
    bad = []
    for row in rows:
        hull = row["audit"].get("hull_origin")
        if not hull:
            continue
        for at in ("before", "after"):
            h = hull[at]
            height = (h["duck_u"] if h["ducked"] else h["standing_u"]) * U
            if abs(h["box_size_m"][1] - height) > 1e-6 or abs(h["box_center_m"][1] - height / 2) > 1e-6:
                bad.append({"tick": row["tick"], "at": at})
    return bad


def transitions(rows):
    out = {"duck": 0, "duck_air": 0, "unduck": 0, "unduck_air": 0, "stand_blocked": 0, "landing_ticks": [], "takeoff_ticks": []}
    previous = None
    for row in rows:
        events = row["audit"]["post"]["motion_state"].get("duck", {}).get("events", [])
        for e in events:
            if e in out:
                out[e] += 1
        grounded = row["audit"]["pre"]["grounded"]
        if previous is not None and grounded != previous:
            out["landing_ticks" if grounded else "takeoff_ticks"].append(row["tick"])
        previous = grounded
    return out


def mutations(module, rows, plan, settings, air_tick, label):
    """broken records and settings: each must be refused. returns result rows."""
    out = []
    def refused(name, mutate=None, plan_change=None, settings_change=None):
        r, p, s = copy.deepcopy(rows), copy.deepcopy(plan), copy.deepcopy(settings)
        if mutate:
            mutate(r)
        if plan_change:
            plan_change(p)
        if settings_change is not None:
            s = settings_change(s)
        try:
            audit = module.packed_input_audit(r, p, s)
            ok, errors = audit["ok"], audit["errors"][:2]
        except Exception as error:  # an exception escaping the audit is itself a finding
            ok, errors = "raised", repr(error)
        out.append({"name": label + ": " + name, "expect": "refuse", "audit_ok": ok, "errors": errors, "passed": ok is False})
    refused("source sensitivity missing", settings_change=lambda s: {})
    refused("source sensitivity None", settings_change=lambda s: {**s, "mouse_sensitivity": None})
    refused("source sensitivity zero", settings_change=lambda s: {**s, "mouse_sensitivity": 0.0})
    refused("source sensitivity NaN", settings_change=lambda s: {**s, "mouse_sensitivity": float("nan")})
    refused("source sensitivity as text", settings_change=lambda s: {**s, "mouse_sensitivity": str(s["mouse_sensitivity"])})
    refused("source sensitivity +1e-6 relative", settings_change=lambda s: {**s, "mouse_sensitivity": s["mouse_sensitivity"] * (1 + 1e-6)})
    refused("pitch limit missing", settings_change=lambda s: {"mouse_sensitivity": s["mouse_sensitivity"]})
    other = 120 if plan["physics_hz"] == 128 else 128
    refused("plan relabelled %d Hz" % other, plan_change=lambda p: p.update(physics_hz=other))
    refused("last row dropped", lambda r: r.pop())
    refused("middle row dropped", lambda r: r.pop(100))
    refused("row duplicated", lambda r: r.insert(100, copy.deepcopy(r[100])))
    refused("rows swapped", lambda r: r.__setitem__(slice(99, 101), [r[100], r[99]]))
    refused("keys field missing", lambda r: r[60]["audit"].pop("keys"))
    refused("post physical missing", lambda r: r[60]["audit"]["post"].pop("physical"))
    refused("actions as a string", lambda r: r[60]["audit"]["post"].update(actions="w"))
    refused("duplicate action entry", lambda r: r[60]["audit"]["post"]["actions"].append("w"))
    refused("extra held key, action and physical", lambda r: [r[60]["audit"][at][f].append("d") for at in ("input_early", "post") for f in ("actions", "physical")])
    refused("step delta as bool", lambda r: r[60]["audit"]["order"].update(step_count_delta=True))
    refused("motor steps as float", lambda r: r[60].update(motor_steps=float(r[60]["motor_steps"])))
    refused("nonfinite yaw", lambda r: r[60].update(yaw=float("nan")))
    mouse_ticks = sorted(e["tick"] for e in plan["events"] if "mouse" in e)
    if mouse_ticks:
        m = mouse_ticks[0]
        refused("infinite mouse relative", lambda r: r[m]["audit"]["mouse"].update(relative=[float("inf"), -10]))
    if rows[0]["audit"]["keys"]:
        refused("tick-0 edge claimed in physics", lambda r: [e.update(in_physics=True) for e in r[0]["audit"]["keys"]])
    refused("physics frame differs between samples", lambda r: r[60].update(physics_frame=r[60]["physics_frame"] + 1))
    if air_tick is not None:
        refused("air duck observed while grounded", lambda r: r[air_tick]["audit"]["pre"].update(grounded=True))
        refused("hull observation removed on the shift tick", lambda r: r[air_tick]["audit"].pop("hull_origin"))
        refused("motor previous origin off by 1 mm", lambda r: r[air_tick]["audit"]["hull_origin"]["motor_previous"].__setitem__(1,
                r[air_tick]["audit"]["hull_origin"]["motor_previous"][1] + 0.001))
        refused("duck event missing", lambda r: r[air_tick]["audit"]["post"]["motion_state"]["duck"].update(events=[]))
        refused("ctrl absent from post actions on the duck tick", lambda r: r[air_tick]["audit"]["post"]["actions"].remove("ctrl"))
        refused("shift reported, anchor unknown", lambda r: r[air_tick]["audit"]["hull_origin"]["before"].update(anchor="top"))
        refused("box scaled 1.01", lambda r: r[air_tick]["audit"]["hull_origin"]["after"].update(scale=[1.0, 1.01, 1.0]))
    return out


def gaps(module, rows, plan, settings, air_tick):
    """documented non-coverage: these mutations are accepted by the audit. not run failures."""
    out = []
    def accepted(name, mutate, why):
        r = copy.deepcopy(rows)
        mutate(r)
        audit = module.packed_input_audit(r, plan, settings)
        out.append({"name": name, "expect": "gap", "audit_ok": audit["ok"], "why": why})
    steady = [r["tick"] for r in rows if r["audit"].get("hull_origin", {}).get("after", {}).get("ducked")
              and r["audit"]["post"]["motion_state"]["duck_shift"] == [0.0, 0.0, 0.0]]
    t = steady[len(steady) // 2] if steady else None
    if t is not None:
        accepted("standing-size box on a steady ducked tick", lambda r: r[t]["audit"]["hull_origin"]["after"].update(
            box_size_m=[0.8128, 72 * U, 0.8128], box_center_m=[0.0, 36 * U, 0.0]),
            "the box is judged only on a nonzero duck shift; motion equality and the UI coroutine cover the rest")
    if air_tick is not None:
        def ignored(r):
            row = r[air_tick]["audit"]
            row["post"]["motion_state"]["duck_shift"] = [0.0, 0.0, 0.0]
            row["post"]["motion_state"]["duck"]["events"] = []
            row["hull_origin"]["after"] = copy.deepcopy(row["hull_origin"]["before"])
            row["order"]["motor_prev_matches_pre"] = True
        accepted("air ctrl press with no duck at all (crouch ignored by the motor)", ignored,
                 "the audit proves the key reached Input, not that the motor ducked; only motion equality can catch this")
    return out


def provenance(source, scratch, rows, plan, settings, air_tick):
    """the audit judges hull origins with momentum-tape.py beside the running package-r15.py."""
    if air_tick is None:
        return {"skipped": "no air duck tick"}
    alt = scratch / "alt-checkout"
    (alt / "tools").mkdir(parents=True)
    shutil.copy2(source / "tools/package-r15.py", alt / "tools/package-r15.py")
    text = (source / "tools/momentum-tape.py").read_text()
    marker = "def hull_origin_compensation(row):\n"
    assert marker in text
    text = text.replace(marker, marker + "    observed = row.get('hull_origin')\n    if observed and row.get('post', {}).get('motion_state', {}).get('duck_shift', [0, 0, 0]) != [0.0, 0.0, 0.0]:\n"
                        "        return {'valid': True, 'reason': 'altered helper', 'shift_m': row['post']['motion_state']['duck_shift']}\n", 1)
    (alt / "tools/momentum-tape.py").write_text(text)
    forged = copy.deepcopy(rows)
    forged[air_tick]["audit"]["hull_origin"]["motor_previous"][1] += 0.05
    real = load(source / "tools/package-r15.py", "r15_real").packed_input_audit(forged, plan, settings)
    other = load(alt / "tools/package-r15.py", "r15_alt").packed_input_audit(forged, plan, settings)
    return {"package_r15_sha256_same": sha(source / "tools/package-r15.py") == sha(alt / "tools/package-r15.py"),
            "momentum_tape_sha256": [sha(source / "tools/momentum-tape.py"), sha(alt / "tools/momentum-tape.py")],
            "frozen_helper_verdict_ok": real["ok"], "altered_sibling_helper_verdict_ok": other["ok"],
            "note": "same package-r15.py bytes, different verdict; the check result records only tool_sha256 and probe_sha256"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--scratch", type=Path, help="parent for the owned snapshot (default: system temp)")
    parser.add_argument("--retained", type=Path, help="root's packed-observer/final directory for offline controls")
    parser.add_argument("--course-run", type=Path, help="standard executor run dir of the retained Whiteout gantry capture")
    parser.add_argument("--quick", action="store_true", help="a few sweep cases only")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    before = {p: sha(PROJECT / p) for p in FROZEN}
    summary = {"scope": "source-mode review of the packed probe capture and packed_input_audit; no export, release runtime or native render"}
    with tempfile.TemporaryDirectory(prefix="r15-pack-review-", dir=args.scratch) as temp:
        temp = Path(temp)
        source = temp / "source"
        top = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], cwd=PROJECT, text=True).strip())
        prefix = str(PROJECT.relative_to(top))
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip()
        archive = subprocess.check_output(["git", "archive", "--format=tar", "HEAD", prefix], cwd=top)
        with tarfile.open(fileobj=io.BytesIO(archive)) as frozen:
            frozen.extractall(temp / "tree", filter="data")
        (temp / "tree" / prefix).rename(source)
        for p in OWN:
            if (PROJECT / p).is_file():
                shutil.copy2(PROJECT / p, source / p)
        snapshot = {p: sha(source / p) for p in FROZEN}
        summary["source"] = {"head": head, "frozen_sha256": snapshot, "frozen_equals_checkout": snapshot == before,
                             "review_files_sha256": {p: sha(PROJECT / p) for p in OWN if (PROJECT / p).is_file()}}
        module = load(source / "tools/package-r15.py", "r15_pack")
        executor = load(source / "tools/momentum-tape.py", "r15_executor")
        env = module.engine_env(temp / "profile")
        code, text = module.run_engine([module.EDITOR, "--headless", "--path", source, "--import"], source, env, out / "import.log", 240)
        summary["import"] = {"exit": code, "errors": bool(module.ERRORS.search(text))}
        uid = source / "tests/r15_pack_observer_review.gd.uid"
        if uid.is_file() and not (PROJECT / OWN[1]).is_file():
            shutil.copy2(uid, PROJECT / OWN[1])
        cases = build_cases(not args.quick)
        specs = []
        for name, expect, plan, options in cases:
            plan = executor.expand(plan)
            path = temp / "tapes" / (name + ".json")
            path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps(plan))
            specs.append({"name": name, "tape": str(path), "preset": options.get("preset", "server128"), "fixture": True,
                          "roof": options.get("roof", False), "variant": options.get("variant", {}),
                          "sensitivity": options.get("sensitivity", 2.5)})
        traces = temp / "traces"
        spec = temp / "spec.json"
        spec.write_text(json.dumps({"out": str(traces), "cases": specs}))
        code, text = module.run_engine([module.EDITOR, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", source,
                                        "--script", "res://tests/r15_pack_observer_review.gd", "--", "--spec=" + str(spec)],
                                       source, env, out / "engine.log", 590)
        summary["engine"] = {"exit": code, "errors": module.ERRORS.findall(text)[:5]}
        runs = {r["name"]: r for r in json.loads((traces / "runs.json").read_text())} if (traces / "runs.json").is_file() else {}
        rows_by, results, keep = {}, [], {"baseline-air-f2", "ctrl-one-tick-late", "forced-respawn", "r13-120-with-ctrl"}
        for name, expect, plan_raw, options in cases:
            run = runs.get(name)
            plan = json.loads((temp / "tapes" / (name + ".json")).read_text())
            if run is None:
                results.append({"name": name, "expect": expect, "ran": False, "passed": False})
                continue
            path = traces / name / "trace.jsonl"
            rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
            rows_by[name] = (rows, plan, run["input_settings"])
            settings = runs[options["audit_settings_from"]]["input_settings"] if "audit_settings_from" in options else run["input_settings"]
            audit = module.packed_input_audit(rows, plan, settings)
            kinds = sorted({e["kind"] for e in audit["errors"]})
            seen = transitions(rows)
            oracle = box_oracle(rows)
            entry = {"name": name, "expect": expect, "ran": run["completed"] and run["rows"] == plan["duration_ticks"], "audit_ok": audit["ok"],
                     "error_count": audit["error_count"], "error_kinds": kinds, "first_errors": audit["errors"][:3],
                     "valid_compensations": sum(c["valid"] for c in audit["hull_origin_compensations"]),
                     "air_transitions": seen["duck_air"] + seen["unduck_air"], "transitions": seen, "box_oracle_bad": oracle[:3],
                     "neutral": run["neutral"], "respawns": run["respawns"], "persist": run["persist"]}
            if expect == "pass":
                entry["passed"] = (entry["ran"] and audit["ok"] and not oracle and run["neutral"] and not run["persist"]
                                   and entry["valid_compensations"] == entry["air_transitions"])
            else:
                entry["passed"] = entry["ran"] and audit["ok"] is False
            results.append(entry)
            if name in keep:
                with gzip.open(out / (name + ".trace.jsonl.gz"), "wb") as stream:
                    stream.write(path.read_bytes())
        summary["engine_cases"] = results
        offline = []
        if "baseline-air-f2" in rows_by:
            rows, plan, settings = rows_by["baseline-air-f2"]
            air = next((c["tick"] for c in module.packed_input_audit(rows, plan, settings)["hull_origin_compensations"] if c["valid"]), None)
            offline += mutations(module, rows, plan, settings, air, "review baseline")
            summary["gaps"] = gaps(module, rows, plan, settings, air)
            summary["provenance"] = provenance(source, temp, rows, plan, settings, air)
        if args.retained:
            retained_runs = {r["name"]: r for r in json.loads((args.retained / "runs.json").read_text())}
            for name in ("air-f2", "r13-control"):
                rows = [json.loads(line) for line in gzip.decompress((args.retained / name / "trace.jsonl.gz").read_bytes()).decode().splitlines() if line.strip()]
                plan = json.loads((args.retained / (name + ".tape.json")).read_text())
                settings = retained_runs[name]["input_settings"]
                audit = module.packed_input_audit(rows, plan, settings)
                offline.append({"name": "retained %s accepted as recorded" % name, "expect": "pass", "audit_ok": audit["ok"], "passed": audit["ok"] is True})
                air = next((c["tick"] for c in audit["hull_origin_compensations"] if c["valid"]), None)
                offline += mutations(module, rows, plan, settings, air, "retained " + name)
        if args.retained and args.course_run:
            # check_runs' own data path: settings from the standard executor's engine.json, not
            # from the game that produced the capture.
            engine = json.loads((args.course_run / "evaluator/engine.json").read_text())
            plan = json.loads((args.course_run / "evaluator/plan.json").read_text())
            rows = [json.loads(line) for line in gzip.decompress((args.retained / "whiteout-gantry/trace.jsonl.gz").read_bytes()).decode().splitlines() if line.strip()]
            settings = engine.get("settings", {})
            audit = module.packed_input_audit(rows, plan, settings)
            self_sourced = {r["name"]: r for r in json.loads((args.retained / "runs.json").read_text())}["whiteout-gantry"]["input_settings"]
            offline.append({"name": "retained Whiteout capture audited with the executor's engine.json settings", "expect": "pass",
                            "audit_ok": audit["ok"], "ticks": audit["ticks"], "valid_compensations": sum(c["valid"] for c in audit["hull_origin_compensations"]),
                            "settings": {k: settings.get(k) for k in ("mouse_sensitivity", "pitch_limit")}, "self_sourced": self_sourced,
                            "passed": audit["ok"] is True})
            offline += mutations(module, rows, plan, settings, next((c["tick"] for c in audit["hull_origin_compensations"] if c["valid"]), None),
                                 "retained whiteout-gantry")
        summary["offline_controls"] = offline
    after = {p: sha(PROJECT / p) for p in FROZEN}
    summary["frozen_unchanged_after"] = after == before
    summary["scratch_removed"] = not temp.exists()
    every = summary.get("engine_cases", []) + summary.get("offline_controls", [])
    summary["passed"] = sum(1 for r in every if r.get("passed"))
    summary["failed"] = [r["name"] for r in every if not r.get("passed")]
    (out / "RESULTS.json").write_text(json.dumps(summary, indent=1) + "\n")
    print("%d/%d review expectations met; unmet: %s" % (summary["passed"], len(every), summary["failed"][:12]))
    for g in summary.get("gaps", []):
        print("GAP accepted=%s %s" % (g["audit_ok"], g["name"]))
    print("provenance:", json.dumps(summary.get("provenance")))
    raise SystemExit(0 if not summary["failed"] and summary["frozen_unchanged_after"] else 1)


if __name__ == "__main__":
    main()
