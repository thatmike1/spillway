#!/usr/bin/env python3
"""exercise the packed observer on real source input and adversarial captured-data controls.

this imports a frozen external source snapshot, not a release pack. no render/export occurs.
"""
import argparse
import copy
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]


def load(path):
    spec = importlib.util.spec_from_file_location("r15_pack_audit", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def tape(events, duration=256):
    return {"format": "spillway-momentum-tape", "version": 2, "name": "packed-observer exercise",
            "physics_hz": 128, "duration_ticks": duration, "duration_s": duration / 128,
            "input_profile": "physics_tick", "expanded": True, "events": events}


def edge(tick, key, state):
    return {"tick": tick, "key": key, "edge": state}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--course-tape", type=Path, help="optional already expanded Whiteout gantry tape")
    parser.add_argument("--course-reference", type=Path, help="full standard-executor trace for the optional Whiteout case")
    args = parser.parse_args()
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    results = []
    def check(name, ok, detail=None):
        results.append({"name": name, "ok": bool(ok), "detail": detail})
        print(("PASS " if ok else "FAIL ") + name, flush=True)
    with tempfile.TemporaryDirectory(prefix="r15-pack-observer-") as temp:
        source = Path(temp) / "source"
        source.mkdir()
        files = subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard", "-z", "--", "."], cwd=PROJECT).split(b"\0")
        sources = {}
        for entry in sorted(set(files) - {b""}):
            relative = entry.decode()
            origin, dest = PROJECT / relative, source / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origin, dest)
            sources[relative] = hashlib.sha256(dest.read_bytes()).hexdigest()
        (args.out / "source-sha256.json").write_text(json.dumps(sources, indent=1) + "\n")
        module = load(source / "tools/package-r15.py")
        env = module.engine_env(Path(temp) / "profile")
        code, text = module.run_engine([module.EDITOR, "--headless", "--path", source, "--import"], source, env, args.out / "import.log", 180)
        check("snapshot imports without engine errors", code == 0 and not module.ERRORS.search(text), code)
        if not results[-1]["ok"]:
            raise RuntimeError("source import failed")
        events = [edge(0, "w", "press"), edge(10, "space", "press"), edge(11, "space", "release"),
                  edge(35, "ctrl", "press"), {"tick": 45, "mouse": [20, -10]},
                  {"tick": 46, "mouse": [-10, 2500]}, {"tick": 47, "mouse": [0, -2500]},
                  edge(70, "ctrl", "release"), edge(180, "w", "release")]
        executor = load(source / "tools/momentum-tape.py")
        cases = []
        for name, preset, roof, fixture in [("air-f2", "server128", False, True), ("air-f5", "server128_aa1000", False, True),
                                              ("roof-f2", "server128", True, True), ("breakwater-air", "server128", False, False),
                                              ("r13-control", "r13_original120", False, True)]:
            plan = tape(events)
            if roof:
                plan = tape([edge(0, "w", "press"), edge(1, "ctrl", "press"), edge(200, "ctrl", "release"), edge(600, "w", "release")], 640)
            if name == "r13-control":
                plan["physics_hz"] = 120
                plan["duration_s"] = plan["duration_ticks"] / 120
                plan["events"] = [e for e in events if e.get("key") != "ctrl"]
            plan = executor.expand(plan)
            path = args.out / (name + ".tape.json")
            path.write_text(json.dumps(plan))
            cases.append({"name": name, "preset": preset, "roof": roof, "fixture": fixture, "tape": str(path)})
        if args.course_tape:
            cases.append({"name": "whiteout-gantry", "preset": "server128", "fixture": False, "map": "whiteout-relay",
                          "tape": str(args.course_tape.resolve()), "warmup": 33})
        spec = args.out / "spec.json"
        spec.write_text(json.dumps({"out": str(args.out), "cases": cases}))
        code, text = module.run_engine([module.EDITOR, "--headless", "--audio-driver", "Dummy", "--fixed-fps", "128", "--path", source,
                                        "--script", "res://tests/test_r15_pack_observer.gd", "--", "--spec=" + str(spec)],
                                       source, env, args.out / "engine.log", 240)
        check("actual probe capture/injection completes without engine errors", code == 0 and not module.ERRORS.search(text), code)
        runs = json.loads((args.out / "runs.json").read_text()) if (args.out / "runs.json").exists() else []
        check("every requested case ran", len(runs) == len(cases))
        controls = json.loads((args.out / "crouch-controls.json").read_text()) if (args.out / "crouch-controls.json").exists() else []
        check("release crouch-control coroutine passes on actual source scene", bool(controls) and all(c["ok"] for c in controls), controls)
        baseline = None
        for case, run in zip(cases, runs):
            path = args.out / case["name"] / "trace.jsonl"
            rows = [json.loads(line) for line in path.read_text().splitlines()]
            plan = json.loads(Path(case["tape"]).read_text())
            audit = module.packed_input_audit(rows, plan, run["input_settings"])
            (path.parent / "audit.json").write_text(json.dumps(audit, indent=1))
            check(case["name"] + " input, rate, origin and counter proof", audit["ok"], audit)
            check(case["name"] + " neutral and no records", run["neutral"] and not run["persist"])
            if case["name"] not in ("roof-f2", "r13-control"):
                check(case["name"] + " real airborne duck observed", any(c["valid"] and c["shift_m"][1] > 0 for c in audit["hull_origin_compensations"]))
            elif case["name"] == "roof-f2":
                blocked = [r for r in rows if r["audit"]["post"]["motion_state"].get("duck", {}).get("stand_blocked")]
                check("roof release really defers standing", len(blocked) > 0 and all("ctrl" not in r["audit"]["post"]["actions"] for r in blocked))
                check("roof exit stands on first clear tick", not rows[-1]["audit"]["hull_origin"]["after"]["ducked"])
            if case["name"] == "whiteout-gantry":
                check("normal Whiteout gantry route finishes clean", run["finished"] and run["finish_kind"] == "clean" and run["respawns"] == 0, run["elapsed"])
                if args.course_reference:
                    comparison = module.shipped_trace_match(path, args.course_reference.resolve())
                    (path.parent / "standard-reference.json").write_text(json.dumps(comparison, indent=1))
                    check("packed injector equals the standard executor on every course tick", comparison["ok"], comparison)
            if baseline is None:
                baseline = (rows, plan, run["input_settings"])
            raw = path.read_bytes()
            with gzip.open(str(path) + ".gz", "wb") as stream:
                stream.write(raw)
            assert gzip.decompress(Path(str(path) + ".gz").read_bytes()) == raw
            path.unlink()
        if baseline:
            rows, plan, settings = baseline
            def alter(name, mutate):
                changed = copy.deepcopy(rows)
                mutate(changed)
                audit = module.packed_input_audit(changed, plan, settings)
                check(name + " refused", not audit["ok"], audit["errors"][:2])
            alter("dropped held key", lambda r: r[10]["audit"]["post"]["actions"].remove("w"))
            alter("dropped press edge", lambda r: r[10]["audit"]["post"]["just_pressed"].clear())
            alter("missing physical key", lambda r: r[10]["audit"]["input_early"]["physical"].remove("space"))
            alter("duplicated applied edge", lambda r: r[10]["audit"]["keys"].append(copy.deepcopy(r[10]["audit"]["keys"][0])))
            alter("wrong injection step", lambda r: r[10]["audit"]["keys"][0].update(motor_steps=-1))
            alter("missing screen-relative", lambda r: r[45]["audit"]["mouse"].update(screen_relative=[0, 0]))
            alter("wrong mouse view", lambda r: r[45]["audit"]["mouse"].update(yaw_after=0.0))
            alter("post-step view drift", lambda r: r[50].update(yaw=1.0))
            alter("missing motor step", lambda r: r[50].update(motor_steps=r[50]["pre_steps"]))
            alter("previous-origin lie", lambda r: r[50]["audit"]["order"].update(motor_prev_matches_pre=False))
            alter("wrong real crouch box", lambda r: r[35]["audit"]["hull_origin"]["after"]["box_size_m"].__setitem__(1, 72 * .0254))
            alter("wrong reported crouch shift", lambda r: r[35]["audit"]["post"]["motion_state"].update(duck_shift=[0, 1, 0]))
            alter("skipped step hidden by crouch", lambda r: r[35]["audit"]["order"].update(step_count_delta=0))
            alter("missing observation", lambda r: r[50].pop("audit"))
            alter("out-of-physics capture", lambda r: r[50]["audit"]["order"].update(in_physics=False))
    summary = {"checks": results, "passed": sum(r["ok"] for r in results), "failed": sum(not r["ok"] for r in results),
               "scope": "source-mode packed-probe component and corrupt-capture controls; no release runtime/export or native render",
               "scratch_removed": not Path(temp).exists()}
    (args.out / "RESULTS.json").write_text(json.dumps(summary, indent=1) + "\n")
    print("%d/%d checks pass" % (summary["passed"], len(results)))
    raise SystemExit(bool(summary["failed"]))


if __name__ == "__main__":
    main()
