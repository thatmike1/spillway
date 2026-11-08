#!/usr/bin/env python3
"""real-input checks of the movement lab's tape key extension (shift and e, version 2 only).

runs the actual tools/momentum-tape.py and tools/momentum-tape.gd: expansion against the
committed helper for every retained tape, refusals of the new keys in version 1 and of keys
outside the alphabet (in the wrapper and, bypassing it, in the executor), refusal of a lab key
in a game that does not bind its action, a real lab replay whose shift and e edges reach the
motor tick, and the retained r15 air-crouch replay with its corrupt-capture controls.

usage: tests/r15_experiment_tape.py --tape TAPE.json --out DIR [--committed FILE]   (DIR outside the checkout)
TAPE is a version 2 lab tape from tests/test_r15_experiment.gd (tapes/r15-lab-combined.json).
"""

import argparse
import copy
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
LAB_GAME = "res://tests/r15_experiment_tape_game.gd"


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def outcome(module, tape):
    try:
        return {"ok": module.expand(copy.deepcopy(tape))}
    except (ValueError, KeyError, TypeError) as error:
        return {"error": str(error)}


def v2(events, ticks=64):
    return {"format": "spillway-momentum-tape", "version": 2, "name": "lab-key-check", "description": "", "physics_hz": 128,
            "input_profile": "physics_tick", "duration_ticks": ticks, "duration_s": ticks / 128.0, "events": events}


def v1(events, ticks=64):
    return {"format": "spillway-momentum-tape", "version": 1, "name": "lab-key-check", "physics_hz": 120,
            "input_profile": "tick120", "duration_ticks": ticks, "events": events}


def held(key, start=4, end=40):
    return [{"tick": start, "key": key, "edge": "press"}, {"tick": end, "key": key, "edge": "release"}]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tape", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--committed", type=Path, help="the committed tools/momentum-tape.py (default: git show HEAD), for a copy outside git")
    args = parser.parse_args()
    out = args.out.resolve()
    if PROJECT in out.parents:
        raise SystemExit("--out must stay outside the checkout")
    out.mkdir(parents=True, exist_ok=False)
    tool = load(PROJECT / "tools/momentum-tape.py", "lab_tape")
    committed_src = args.committed.read_bytes() if args.committed else \
        subprocess.run(["git", "show", "HEAD:./tools/momentum-tape.py"], cwd=PROJECT, check=True, capture_output=True).stdout
    (out / "committed-momentum-tape.py").write_bytes(committed_src)
    committed = load(out / "committed-momentum-tape.py", "committed_tape")
    checks = []

    def check(name, ok, detail=None):
        checks.append({"name": name, "ok": bool(ok), "detail": detail})
        print(("ok    " if ok else "FAIL  ") + name + ("" if ok else f" ({str(detail)[:300]})"))

    # 1. expansion: every retained tape, and the old alphabet in both versions, expands exactly
    # as the committed helper expands it (same plan, or the same refusal).
    retained = sorted((PROJECT / "tests/momentum_tapes").glob("*.json"))
    synthetic = {"v1 ctrl": v1(held("ctrl")), "v2 ctrl": v2(held("ctrl")), "v1 unknown q": v1(held("q")), "v2 unknown q": v2(held("q")),
                 "v1 wasd": v1(held("w") + held("d", 10, 30)), "v2 mouse": v2(held("w") + [{"tick": 5, "mouse": [3.0, -1.0]}])}
    for path in retained:
        tape = json.loads(path.read_text())
        check(f"retained {path.name} expands as the committed helper", outcome(tool, tape) == outcome(committed, tape))
    for name, tape in synthetic.items():
        check(f"{name} expands as the committed helper", outcome(tool, tape) == outcome(committed, tape), outcome(tool, tape))
    # 2. the new keys: accepted in version 2, refused in version 1, and nothing else is admitted.
    lab = outcome(tool, v2(held("shift") + held("e", 8, 50)))
    check("v2 shift and e expand", "ok" in lab and [e["key"] for e in lab["ok"]["events"]] == ["shift", "e", "shift", "e"], lab)
    for name, tape in {"v1 shift": v1(held("shift")), "v1 e": v1(held("e")), "v2 E": v2(held("E")), "v2 Shift": v2(held("Shift")),
                       "v2 lshift": v2(held("lshift")), "v2 q": v2(held("q"))}.items():
        result = outcome(tool, tape)
        check(f"{name} is refused by the wrapper", "error" in result and "unknown key" in result["error"], result)
    check("v2 shift tapped on one tick is refused", "error" in outcome(tool, v2([{"tick": 4, "key": "shift", "edge": "press"}, {"tick": 4, "key": "shift", "edge": "release"}])))
    check("v2 e pressed twice is refused", "error" in outcome(tool, v2([{"tick": 4, "key": "e", "edge": "press"}, {"tick": 6, "key": "e", "edge": "press"}])))

    def run(name, plan, game, motor="server128"):
        report = tool.execute(plan, out / name, {"game_script": game, "game_class": "", "motor": motor, "headless": True, "warmup": 8,
                                                 "render_fps": 128, "wall_budget": 100, "archive": True})
        end = json.loads((out / name / "end.json").read_text())
        return report, end

    # 3. the executor's own validation, bypassing the wrapper: hand-made "expanded" plans.
    forged_v1 = {**v1(held("shift")), "expanded": True}
    _, end = run("refuse-v1-shift", forged_v1, LAB_GAME)
    check("executor refuses shift in a version 1 plan", end.get("reason") == "rejected" and any("shift" in e for e in end.get("errors", [])), end)
    forged_q = {**v2(held("q")), "expanded": True}
    _, end = run("refuse-v2-q", forged_q, LAB_GAME)
    check("executor refuses an unknown key in a version 2 plan", end.get("reason") == "rejected" and any("q" in e for e in end.get("errors", [])), end)
    unbound = tool.expand(v2(held("w", 2, 60) + held("shift", 30, 50), 80))
    _, end = run("refuse-unbound-shift", unbound, "res://scripts/r14_main.gd")
    check("executor refuses shift in a game without the r15_slide action", end.get("reason") == "rejected" and any("r15_slide" in e for e in end.get("errors", [])), end)
    # 4. a real lab replay: every shift and e edge reaches its motor tick, the moves fire, the
    # evaluator is clean and the line finishes.
    plan = tool.expand(json.loads(args.tape.read_text()))
    report, end = run("lab-replay", plan, LAB_GAME)
    rows = [r for r in tool.read_jsonl(out / "lab-replay/evaluator/trace.jsonl") if r["phase"] == "tape"]
    by_tick = {r["tick"]: r for r in rows}
    edges = [e for e in plan["events"] if e.get("key") in ("shift", "e")]
    seen = all(e["key"] in by_tick[e["tick"]]["post"]["just_pressed" if e["edge"] == "press" else "just_released"] for e in edges)
    counts = (rows[-1]["post"]["motion_state"] or {}).get("experiment", {}).get("counts", {})
    check("lab replay uses shift and e", {e["key"] for e in edges} == {"shift", "e"}, edges)
    check("lab replay: every shift and e edge is seen by its motor tick", seen)
    check("lab replay: delivery, order and rate clean, input neutral", report["delivery"]["ok"] and report["order"]["ok"] and report["rate"]["ok"] and report["neutral"],
          {k: report.get(k) for k in ("delivery", "neutral")})
    check("lab replay: no movement or integrity flags", not report["movement_flags"] and not report["integrity_flags"], [report["movement_flags"], report["integrity_flags"]])
    check("lab replay: slide, wall jump and grapple fired", counts.get("slide", 0) >= 1 and counts.get("wall_jump", 0) >= 2 and counts.get("grapple", 0) >= 1, counts)
    check("lab replay: finished clean", rows[-1]["game"].get("finished") is True and rows[-1]["game"].get("finish_kind") == "clean", rows[-1]["game"])
    # 5. the retained r15 air-crouch replay and its corrupt-capture controls, on the changed helper.
    crouch = tool.expand(json.loads((PROJECT / "tests/momentum_tapes/r15-air-crouch.json").read_text()))
    report, end = run("air-crouch", crouch, "res://scripts/r15_main.gd")
    controls = subprocess.run([sys.executable, "-I", str(PROJECT / "tests/test_r15_tape_crouch.py"), "--run", str(out / "air-crouch"),
                               "--out", str(out / "air-crouch-controls.json")], capture_output=True, text=True)
    check("retained air-crouch replay passes its controls on the changed helper", controls.returncode == 0, controls.stdout[-400:] + controls.stderr[-400:])
    failed = [c for c in checks if not c["ok"]]
    (out / "summary.json").write_text(json.dumps({"checks": checks, "failed": len(failed)}, indent=1))
    print(f"r15 experiment tape keys: {len(checks)} checks, {len(failed)} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
