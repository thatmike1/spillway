#!/usr/bin/env python3
"""r14 rate-aware tape checks: version 2 at 64/120/128 hz, archives and legacy v1 (docs/r14/REPLAY.md).

python3 tests/test_r14_tape.py [--only GROUP ...] [--evidence DIR]
groups: headers reject delivery repeat elapsed midrun archive cleanup legacy native
every run uses tests/r14_tape_rate_game.gd (a labelled test game with existing r13 motors),
not the r14 main or the source motor; those are accepted separately once they exist.
"""

import argparse
import gzip
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
TAPES = PROJECT / "tests/momentum_tapes"
EVIDENCE = Path("/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/tape-rates")
R13_CONTROL = Path("/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/r13-control")
# the last r13 revision of the tape tools, for byte-identity of version 1 expansion.
R13_TOOL_REVISION = "086c9396"
GAME = "res://tests/r14_tape_rate_game.gd"
RATES = (64, 120, 128)


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


mt = load("momentum_tape", PROJECT / "tools/momentum-tape.py")
results = []
evidence = None


def check(name, ok, detail=None):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f"  {json.dumps(detail, default=str)[:500]}"), flush=True)


def v2(hz, ticks, events=(), curves=(), name="", **extra):
    return dict({"format": mt.FORMAT, "version": 2, "name": name or f"r14-{hz}", "physics_hz": hz, "input_profile": mt.V2_PROFILE,
                 "duration_ticks": ticks, "duration_s": ticks / hz, "events": list(events), "curves": list(curves)}, **extra)


def run(name, plan, motor=None, hz=None, **cfg):
    cfg.setdefault("headless", True)
    cfg.setdefault("archive", True)
    if "fixture" not in cfg and "game_script" not in cfg:
        cfg.update(game_script=GAME, game_class="", motor=motor or f"flow@{hz or plan['physics_hz']}")
    elif motor:
        cfg["motor"] = motor
    return mt.execute(plan, evidence / name, cfg)


def rows(report):
    return [r for r in mt.read_jsonl(Path(report["run"]) / "evaluator/trace.jsonl") if r["phase"] == "tape"]


def end_of(report):
    end = report["end"]
    return end if isinstance(end, dict) else json.loads((Path(report["run"]) / "end.json").read_text())


def basic(name, report):
    check(f"{name}: completed with neutral input", report.get("end") == "completed" and report.get("neutral") is True, report.get("end"))
    check(f"{name}: delivery ok", report["delivery"]["ok"], report["delivery"]["errors"][:4])
    check(f"{name}: order ok", report["order"]["ok"], report["order"]["errors"][:4])
    check(f"{name}: actual rate and delta held for every step", report["rate"]["ok"] is True, report["rate"])
    check(f"{name}: owned processes cleaned up", report["cleanup"]["clean"], report["cleanup"])


def variant(name, *pairs):
    """a disposable executor copy with deliberate defects, outside the checkout."""
    source = (PROJECT / "tools/momentum-tape.gd").read_text()
    for old, new in pairs:
        assert source.count(old) == 1, old
        source = source.replace(old, new)
    path = evidence / "variants" / f"{name}.gd"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source)
    return path


def edges_tape(hz):
    """key edges and mouse placed by time, then fixed to this rate's ticks before expansion."""
    t = lambda s: round(s * hz)
    events = [{"tick": 0, "key": "w", "edge": "press"}, {"tick": 0, "mouse": [3.25, -1.5]},
              {"tick": t(0.25), "key": "space", "edge": "press"}, {"tick": t(0.25) + 3, "key": "space", "edge": "release"},
              {"tick": t(0.45), "key": "a", "edge": "press"}, {"tick": t(0.6), "key": "a", "edge": "release"},
              # a release and a re-press of different keys on one boundary, and a one-tick hold.
              {"tick": t(0.6), "key": "d", "edge": "press"}, {"tick": t(0.75), "key": "d", "edge": "release"},
              {"tick": t(0.8), "key": "s", "edge": "press"}, {"tick": t(0.8) + 1, "key": "s", "edge": "release"},
              {"tick": t(0.9), "key": "w", "edge": "release"}, {"tick": t(0.95), "mouse": [-7.0, 0.0]}]
    curves = [{"kind": "mouse", "start": 1, "ticks": t(0.4), "total": [-180.0, 24.0], "shape": "smooth"}]
    return mt.expand(v2(hz, hz, events, curves, name=f"edges-{hz}"))


# --- groups ----------------------------------------------------------------------------------

def g_headers():
    for hz in RATES:
        plan = mt.expand(v2(hz, 2 * hz, [{"tick": 0, "key": "w", "edge": "press"}],
                            [{"kind": "mouse", "start": 0, "ticks": hz // 2, "total": [100, 0], "shape": "linear"}]))
        check(f"v2 {hz} hz: expands with its rate, profile and duration_s",
              plan["version"] == 2 and plan["physics_hz"] == hz and plan["input_profile"] == "physics_tick" and plan["duration_s"] == 2.0
              and len([e for e in plan["events"] if "mouse" in e]) == hz // 2, {k: plan[k] for k in ("version", "physics_hz", "duration_s")})
    good = v2(64, 128)
    bad = [
        ("a v1 tape at 64 hz", dict(good, version=1, input_profile="tick120")),
        ("a v1 tape relabelled version 2 with its tick120 profile", dict(good, input_profile="tick120")),
        ("render30 in version 2", dict(good, input_profile="render30")),
        ("a header-only rate edit 120 -> 64 (ticks and duration_s kept)", dict(v2(120, 240), physics_hz=64)),
        ("missing duration_s", {k: v for k, v in good.items() if k != "duration_s"}),
        ("physics_hz 100", dict(good, physics_hz=100, duration_s=1.28)),
        ("physics_hz as float 64.0", dict(good, physics_hz=64.0)),
        ("physics_hz as string", dict(good, physics_hz="64")),
        ("physics_hz true", dict(good, physics_hz=True)),
        ("an unknown header field render_fps", dict(good, render_fps=30)),
        ("a conflicting tick_hz field", dict(good, tick_hz=128)),
        ("expanded and still carrying curves", dict(good, expanded=True, curves=[{"kind": "hold", "key": "w", "start": 0, "ticks": 4}])),
        ("version 3", dict(good, version=3)),
        ("version as string", dict(good, version="2")),
        ("unknown mouse_quantize", dict(good, mouse_quantize="int")),
        ("duration over ten minutes", dict(good, duration_ticks=64 * 601, duration_s=601.0)),
        ("same-tick tap at 128", v2(128, 64, [{"tick": 3, "key": "space", "edge": "press"}, {"tick": 3, "key": "space", "edge": "release"}])),
        ("event beyond the tape", v2(64, 64, [{"tick": 64, "key": "w", "edge": "press"}])),
    ]
    for label, tape in bad:
        try:
            mt.expand(tape)
            check(f"expand rejects {label}", False)
        except ValueError as error:
            check(f"expand rejects {label}", True, str(error))
    # version 1: byte-identical expansion to the last r13 tool for every retained tape.
    legacy_tool = evidence / "legacy/momentum-tape-r13.py"
    legacy_tool.parent.mkdir(parents=True, exist_ok=True)
    legacy_tool.write_bytes(subprocess.run(["git", "-C", str(PROJECT), "show", f"{R13_TOOL_REVISION}:projects/foldrunner/tools/momentum-tape.py"],
                                           capture_output=True, check=True).stdout)
    old = load("momentum_tape_r13", legacy_tool)
    tapes = sorted(TAPES.glob("*.json")) + [R13_CONTROL / "source-ordinary/evaluator/plan.json"]
    differ = [p.name for p in tapes if json.dumps(old.expand(json.loads(p.read_text()))) != json.dumps(mt.expand(json.loads(p.read_text())))]
    check(f"v1: {len(tapes)} retained tapes expand byte-identically to the r13 tool ({R13_TOOL_REVISION})", not differ, differ)
    same = {"events": [{"tick": 0, "key": "w", "edge": "press"}, {"tick": 5, "mouse": [4, 0]}]}
    one = mt.expand(dict({"format": mt.FORMAT, "version": 1, "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 60}, **same))
    two = mt.expand(dict(v2(120, 60), **same))
    check("v2 at 120 hz expands to the same events as v1 tick120", one["events"] == two["events"])


def g_reject():
    base = mt.expand(v2(64, 64, [{"tick": 0, "key": "w", "edge": "press"}]))
    # plans that bypass expand: the executor validates the rate itself.
    tampered = [
        ("v1 header at 64 hz", dict(base, version=1, input_profile="tick120"), "version 1 tape is a 120 hz claim"),
        ("v2 at 100 hz", dict(base, physics_hz=100), "--physics-hz 100 is not one of"),
        ("v2 duration_s not ticks / rate", dict(base, duration_s=0.5), "duration_s"),
        ("v2 with a v1 profile label", dict(base, input_profile="tick120"), "input_profile must be physics_tick"),
    ]
    for label, plan, needle in tampered:
        report = run(f"reject-{label.replace(' ', '-').replace('/', '')}", plan, motor="flow@64")
        errors = report["end"].get("errors", []) if isinstance(report["end"], dict) else []
        check(f"executor rejects {label}", report["end"].get("reason") == "rejected" and any(needle in e for e in errors), errors)
        check(f"executor rejects {label}: CLI exit is a failure", mt.execution_exit(report) == 2)
    cases = [
        ("game sets 128 hz in _ready under a 64 hz tape", "flow@128", "runs at 128 hz after the game's _ready"),
        ("game declares 128 hz without changing the engine", "flow@128+declare-only", "game.physics_hz declares 128"),
    ]
    for label, motor, needle in cases:
        report = run(f"reject-{motor.replace('@', '').replace('+', '-')}", base, motor=motor)
        errors = report["end"].get("errors", []) if isinstance(report["end"], dict) else []
        check(f"after ready: {label} is rejected", report["end"].get("reason") == "rejected" and any(needle in e for e in errors), errors)
        check(f"after ready: {label}: no trace, cleanup clean", not mt.jsonl_exists(Path(report["run"]) / "evaluator/trace.jsonl") and report["cleanup"]["clean"])
    undeclared = run("reject-fixture-undeclared-64", base, fixture="flat")
    errors = undeclared["end"].get("errors", []) if isinstance(undeclared["end"], dict) else []
    check("fixture world at 64 hz with an r13 motor that declares no rate is refused by default",
          undeclared["end"].get("reason") == "rejected" and any("nothing declares physics_hz" in e for e in errors), errors)
    allowed = run("fixture-undeclared-64-allowed", base, fixture="flat", undeclared_rate_ok=True)
    engine = json.loads((Path(allowed["run"]) / "evaluator/engine.json").read_text())
    check("the same probe runs with --undeclared-rate-ok and is labelled off-design",
          allowed["end"] == "completed" and allowed["rate"]["ok"] and "off-design" in engine["rate_policy"], engine["rate_policy"])


def g_delivery():
    for hz in RATES:
        plan = edges_tape(hz)
        report = run(f"delivery-{hz}", plan)
        basic(f"delivery {hz} hz", report)
        trace = {r["tick"]: r for r in rows(report)}
        sens = json.loads((Path(report["run"]) / "evaluator/engine.json").read_text())["settings"]["mouse_sensitivity"]
        late = []
        for e in plan["events"]:
            if "key" not in e:
                continue
            t, key, press = e["tick"], e["key"], e["edge"] == "press"
            seen = trace[t]["post"]["just_pressed" if press else "just_released"]
            before = trace[t - 1]["post"]["actions"] if t else []
            if key not in seen or (key in before) == press or any(k["point"] != ("process_arm" if t == 0 else "late_physics") for k in trace[t]["keys"]):
                late.append(e)
        check(f"delivery {hz} hz: every edge is just-pressed/released on its own tick, delivered between steps", not late, late[:3])
        jump = next(j for j in report["movement"]["jump_presses"])
        check(f"delivery {hz} hz: the grounded jump fires on its press tick", jump["jump_tick"] == jump["press_tick"] == round(0.25 * hz), jump)
        wrong = []
        for e in plan["events"]:
            if "mouse" not in e:
                continue
            m = trace[e["tick"]]["mouse"]
            if not m or m["relative"] != e["mouse"] or m["screen_relative"] != e["mouse"] or m["point"] != "early_physics" \
                    or abs((m["yaw_after"] - m["yaw_before"]) + e["mouse"][0] * sens) > 1e-12:
                wrong.append({"tick": e["tick"], "planned": e["mouse"], "got": m})
        mice = [e for e in plan["events"] if "mouse" in e]
        check(f"delivery {hz} hz: {len(mice)} mouse deltas arrive at tick start with relative = screen_relative = dx and yaw = -dx x sens",
              not wrong and len(mice) > hz // 3, wrong[:2])
    # negative controls at a non-120 rate: the checks must fail for the right reason.
    plan = edges_tape(128)
    early = run("neg-keys-inside-step-128", plan, archive=False, executor=variant(
        "keys-inside-step",
        ("\t\tif inject == \"tick\":\n\t\t\t_deliver_keys(tick + 1, \"late_physics\")\n", ""),
        ("\tif armed and inject == \"tick\":\n\t\trow[\"mouse\"] = _deliver_mouse(tick, \"early_physics\")\n",
         "\tif armed and inject == \"tick\":\n\t\t_deliver_keys(tick, \"early_physics\")\n\t\trow[\"keys\"] = pending.get(tick, [])\n"
         "\t\tpending.erase(tick)\n\t\trow[\"mouse\"] = _deliver_mouse(tick, \"early_physics\")\n")))
    kinds = {e["kind"] for e in early["delivery"]["errors"]}
    check("neg 128 hz: key edges parsed inside the physics step are caught as not just-pressed on their tick",
          "edge_not_seen_by_motor_tick" in kinds and early["rate"]["ok"], sorted(kinds))
    omitted = run("neg-no-screen-relative-64", edges_tape(64), archive=False,
                  executor=variant("no-screen-relative", ("\tevent.screen_relative = delta\n", "")))
    kinds = {e["kind"] for e in omitted["delivery"]["errors"]}
    check("neg 64 hz: an event without screen_relative is caught as a field and view mismatch",
          {"mouse_screen_relative_differs", "view_did_not_follow_mouse"} <= kinds and not omitted["movement_flags"], sorted(kinds))


def g_repeat():
    for hz in (64, 128):
        first = evidence / f"delivery-{hz}"
        if not (first / "run.json").exists():
            g_delivery()
        again = run(f"repeat-{hz}", edges_tape(hz))
        basic(f"repeat {hz} hz", again)
        c = mt.compare(first, Path(again["run"]))
        check(f"repeat {hz} hz: same tape, fresh run and profile, 0.0 m / 0.0 m/s / 0.0 rad",
              c["max_position_m"] == 0.0 and c["max_velocity_m_s"] == 0.0 and c["max_yaw_rad"] == 0.0 and c["same_applied_events"]
              and c["common"] == hz, c)
    one = mt.expand({"format": mt.FORMAT, "version": 1, "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 120,
                     "events": edges_tape(120)["events"]})
    v1 = run("repeat-v1-tick120", one, motor="flow@120")
    c = mt.compare(Path(v1["run"]), evidence / "delivery-120")
    check("v2 at 120 hz reproduces the same events as v1 tick120 exactly", c["max_position_m"] == 0.0 and c["max_yaw_rad"] == 0.0 and c["same_applied_events"], c)
    c = mt.compare(evidence / "delivery-64", evidence / "delivery-128")
    check("compare labels a cross-rate comparison: tick n is not the same time", c["same_rate"] is False and "note" in c, c.get("physics_hz"))


def g_elapsed():
    # p / labelled consistency check, not a physics acceptance: one second of held W per rate.
    travel = {}
    for hz in RATES:
        plan = mt.expand(v2(hz, hz, [{"tick": 0, "key": "w", "edge": "press"}], name=f"one-second-{hz}"))
        report = run(f"elapsed-{hz}", plan)
        basic(f"elapsed {hz} hz", report)
        trace = rows(report)
        dts = [r["rate"]["dt"] for r in trace] + [r["rate"]["dt_late"] for r in trace]
        game = trace[-1]["game"]["elapsed"] - trace[0]["game"]["elapsed"]
        check(f"elapsed {hz} hz: {hz} ticks, every engine delta exactly 1/{hz}, and they sum to 1.0 s",
              len(trace) == hz and set(dts) == {1.0 / hz} and abs(report["rate"]["sim_s_from_actual_dt"] - 1.0) < 1e-12, report["rate"])
        check(f"elapsed {hz} hz: the game's own delta sum advances (ticks - 1)/rate between first and last tick",
              abs(game - (hz - 1) / hz) < 1e-12, game)
        travel[hz] = report["outcome"]["travel_m"]
    (evidence / "elapsed-observation.json").write_text(json.dumps({"travel_m_after_1s_held_w": travel,
        "label": "observation of the unchanged r13 flow motor off its 120 hz design rate, not an r14 acceptance"}, indent=1))
    check("elapsed: r13 flow travel after one second recorded per rate (observation only)", len(travel) == 3, travel)


def g_midrun():
    plan = mt.expand(v2(64, 192, [{"tick": 0, "key": "w", "edge": "press"}, {"tick": 10, "key": "a", "edge": "press"}]))
    for label, motor in (("engine rate switched to 128 hz", "flow@64+switch@40"), ("time_scale set to 0.5", "flow@64+timescale@40")):
        report = run(f"midrun-{motor.split('+')[1].replace('@', '')}", plan, motor=motor)
        end = end_of(report)
        fault = end.get("rate_fault", {})
        check(f"mid-run: {label} ends the run as rate_changed with exit 5",
              end.get("reason") == "rate_changed" and report["cleanup"]["engine_exit"] == 5 and mt.execution_exit(report) == 2, end.get("reason"))
        check(f"mid-run: {label}: neutral input, no owned process left", end.get("neutral") is True and report["cleanup"]["clean"])
        check(f"mid-run: {label}: the report and the fault row say what changed and when",
              report["rate"]["ok"] is False and fault.get("tape_hz") == 64 and ("engine_hz" in fault) and fault.get("tick", -1) >= 0
              and len(rows(report)) < 192, fault)


def g_archive():
    source = evidence / "delivery-64"
    if not (source / "run.json").exists():
        g_delivery()
    raw = run("archive-raw-64", edges_tape(64), archive=False)
    folder = Path(raw["run"])
    digest = mt.sha256_file(folder / "evaluator/trace.jsonl")
    before = mt.evaluate(folder)
    applied_before = mt.applied_tape(folder)
    copy = evidence / "archive-raw-64-unarchived-copy"
    shutil.copytree(folder, copy)
    manifest = mt.archive_run(folder)
    entry = manifest["files"]["trace.jsonl"]
    check("archive: raw traces replaced by gzip with the uncompressed hash recorded",
          not (folder / "evaluator/trace.jsonl").exists() and (folder / "evaluator/trace.jsonl.gz").exists()
          and entry["sha256_uncompressed"] == digest and "frames.jsonl" in manifest["files"], entry)
    check("archive: gzip is lossless (decompressed bytes hash to the raw trace)",
          hashlib.sha256(gzip.decompress((folder / "evaluator/trace.jsonl.gz").read_bytes())).hexdigest() == digest)
    after = mt.evaluate(folder)
    strip = lambda r: {k: v for k, v in r.items() if k not in ("trace_source", "run")}
    check("archive: evaluate from the archive equals evaluate from the raw trace", strip(after) == strip(before) and after["trace_source"]["verified"] is True)
    check("archive: applied events read from the archive equal the raw ones", mt.applied_tape(folder) == applied_before)
    c = mt.compare(folder, copy)
    check("archive: compare archived against unarchived is exact", c["max_position_m"] == 0.0 and c["same_applied_events"] and c["trace_source"][0]["archived"], c)
    replay = run("archive-replay-64", mt.expand(mt.applied_tape(folder)))
    c = mt.compare(folder, Path(replay["run"]))
    check("archive: a replay built from the archived trace reproduces it exactly", c["max_position_m"] == 0.0 and c["max_yaw_rad"] == 0.0 and c["same_applied_events"], c)
    check("archive: no raw trace was restored to disk by evaluate/replay/compare", not (folder / "evaluator/trace.jsonl").exists())
    shutil.rmtree(copy)
    tampered = evidence / "archive-tampered"
    shutil.copytree(folder, tampered)
    data = gzip.decompress((tampered / "evaluator/trace.jsonl.gz").read_bytes()).replace(b'"dt":0.015625', b'"dt":0.0156250', 1)
    (tampered / "evaluator/trace.jsonl.gz").write_bytes(gzip.compress(data))
    try:
        mt.evaluate(tampered)
        check("archive: a trace that no longer matches its recorded hash is refused", False)
    except ValueError as error:
        check("archive: a trace that no longer matches its recorded hash is refused", "not the recorded" in str(error), str(error))
    again = mt.archive_run(folder)
    check("archive: archiving an archived run is a no-op that keeps the manifest", again["files"] == manifest["files"])


def g_cleanup():
    plan = mt.expand(v2(128, 128 * 600, [{"tick": 0, "key": "w", "edge": "press"}, {"tick": 20, "key": "d", "edge": "press"}]))
    cancelled = run("cleanup-cancel-128", plan, cancel_after=2, wall_budget=60)
    end = end_of(cancelled)
    check("cancel 128 hz: acknowledged with neutral input, exit 4, nothing left",
          end.get("reason") == "cancelled" and end.get("neutral") is True and cancelled["cleanup"]["engine_exit"] == 4
          and cancelled["cleanup"]["cancel"]["ack"] and cancelled["cleanup"]["clean"], cancelled["cleanup"])
    check("cancel 128 hz: the partial trace still has actual rate fields and was archived",
          cancelled["rate"]["ok"] is True and cancelled.get("archive", {}).get("files", {}).get("trace.jsonl"))
    real = mt.GODOT
    fake = evidence / "variants/non-executable-engine"
    fake.parent.mkdir(parents=True, exist_ok=True)
    fake.write_text("#!/bin/sh\nexit 0\n")
    fake.chmod(0o600)
    try:
        mt.GODOT = fake
        failed = run("cleanup-launch-failure-64", mt.expand(v2(64, 64)), headless=False, display=161, wall_budget=5, deadline=8)
        folder = Path(failed["run"])
        check("launch failure 64 hz: provenance kept, display and owned processes cleaned, CLI fails",
              failed["end"].get("reason") == "launch_failed" and (folder / "run.json").exists() and failed["cleanup"]["clean"]
              and failed["cleanup"].get("display_socket_removed") and mt.execution_exit(failed) == 2, failed["cleanup"])
    finally:
        mt.GODOT = real
    starved = run("cleanup-storage-refusal", mt.expand(v2(64, 64)), headless=False, min_free_gib=1e6)
    meta = json.loads((Path(starved["run"]) / "run.json").read_text())
    check("storage: a native start below the free-space floor launches nothing and keeps provenance",
          starved["end"].get("reason") == "launch_failed" and starved["end"]["error"]["stage"] == "storage_check"
          and starved["cleanup"]["engine_exit"] is None and "display" not in starved["cleanup"] and meta["storage"]["min_free_gib"] == 1e6,
          starved["end"])


def g_legacy():
    # the unchanged r13 control route, v1 at 120 hz through the r13 product main.
    plan = json.loads((R13_CONTROL / "source-ordinary/evaluator/plan.json").read_text())
    baseline = json.loads((R13_CONTROL / "BASELINE.json").read_text())
    report = mt.execute(mt.expand(plan), evidence / "legacy-r13-control", {"motor": "candidate", "game_script": "res://scripts/momentum_overflow_main.gd",
                                                                          "headless": True, "archive": True, "wall_budget": 400})
    trace = rows(report)
    game = trace[-1]["game"]
    check("r13 control: finishes clean in the recorded 24.8916667 s, no respawn",
          game["finished"] and game["finish_kind"] == "clean" and game["respawns"] == 0 and game["elapsed"] == baseline["game"]["elapsed"], game)
    info = {}
    data = mt.read_trace_bytes(R13_CONTROL / "source-ordinary/evaluator/trace.jsonl", info)
    check("r13 control: the baseline's gzip trace (no manifest) matches its BASELINE.json uncompressed hash",
          hashlib.sha256(data).hexdigest() == baseline["trace_sha256_uncompressed"], info)
    c = mt.compare(R13_CONTROL / "source-ordinary", Path(report["run"]))
    check("r13 control: tick-by-tick identical to the archived baseline (position, velocity, yaw)",
          c["max_position_m"] == 0.0 and c["max_velocity_m_s"] == 0.0 and c["max_yaw_rad"] == 0.0 and c["same_applied_events"], c)
    check("r13 control: delivery, order and the now-recorded 120 hz rate all hold",
          report["delivery"]["ok"] and report["order"]["ok"] and report["order"]["strength"] == "counter_verified" and report["rate"]["ok"], report["rate"])
    old = json.loads((R13_CONTROL / "source-ordinary/evaluator/report.json").read_text())
    check("r13 control: movement flags and outcome equal the baseline report",
          old["movement_flags"] == report["movement_flags"] and old["outcome"] == report["outcome"], [old["outcome"], report["outcome"]])
    replay = mt.execute(mt.expand(mt.applied_tape(Path(report["run"]))), evidence / "legacy-r13-control-replay",
                        {"motor": "candidate", "game_script": "res://scripts/momentum_overflow_main.gd", "headless": True, "archive": True, "wall_budget": 400})
    c = mt.compare(Path(report["run"]), Path(replay["run"]))
    check("r13 control: v1 replay of the archived applied events is exact", c["max_position_m"] == 0.0 and c["same_applied_events"], c)
    # v1 render30: physics-boundary and process-point injection still agree.
    r30 = mt.expand(json.loads((TAPES / "render30-batches.json").read_text()))
    tick = mt.execute(r30, evidence / "legacy-render30-tick", {"headless": True, "archive": True})
    proc = mt.execute(r30, evidence / "legacy-render30-process", {"headless": True, "archive": True, "inject": "process"})
    c = mt.compare(Path(tick["run"]), Path(proc["run"]))
    check("v1 render30: both injection points still give the same motor result", c["max_position_m"] == 0.0 and c["max_yaw_rad"] == 0.0
          and tick["delivery"]["ok"] and proc["delivery"]["ok"], c)
    # one short native v1 run: the exact camera-follow check on the real r13 course and motor.
    if mt.free_bytes(evidence) >= mt.MIN_FREE_GIB * 2 ** 30:
        short = dict(mt.expand(plan), duration_ticks=360, name="r13 control, first 3 s")
        short["events"] = [e for e in short["events"] if e["tick"] < 360]
        native = mt.execute(short, evidence / "legacy-r13-control-native-3s",
                            {"motor": "candidate", "game_script": "res://scripts/momentum_overflow_main.gd", "archive": True,
                             "resolution": "640x360", "mp4": True, "actor_limit": 8, "wall_budget": 300})
        c = mt.compare(Path(report["run"]), Path(native["run"]))
        follow = native["movement"]["camera_follow"]
        check("r13 native v1: the first 3 s match the headless control exactly and the camera sits on the body",
              native["end"] == "completed" and c["max_position_m"] == 0.0 and c["common"] == 360 and follow["draws_checked"] > 80
              and follow["max_horizontal_error_m"] < 1e-3 and not native["integrity_flags"], [c["max_position_m"], follow, native["integrity_flags"]])
    else:
        check("r13 native v1: skipped below the free-space floor", False, mt.free_bytes(evidence) / 2 ** 30)
    # the headless r13 executor groups, unchanged, against the current tools.
    out = evidence / "legacy-suite"
    done = subprocess.run([sys.executable, str(PROJECT / "tests/test_momentum_tape.py"), "--only", "units", "audit", "negative", "review",
                           "--evidence", str(out)], capture_output=True, text=True, timeout=900)
    (evidence / "legacy-suite.log").write_text(done.stdout + done.stderr)
    summary = json.loads((out / "test-summary.json").read_text()) if (out / "test-summary.json").exists() else {}
    check("r13 tape suite groups units/audit/negative/review pass on the current tools", done.returncode == 0,
          [c for c in summary.get("checks", []) if not c["ok"]][:3])


def g_native():
    free = mt.free_bytes(evidence) / 2 ** 30
    if free < mt.MIN_FREE_GIB:
        check(f"native: at least {mt.MIN_FREE_GIB} GiB free before capture", False, free)
        return
    check(f"native: {free:.1f} GiB free before capture (floor {mt.MIN_FREE_GIB})", True)
    for hz in (64, 128):
        t = lambda s: round(s * hz)
        # the step fixture: run at the 0.7 m face, look about, jump after contact, climb on and go on.
        plan = mt.expand(v2(hz, 6 * hz, [{"tick": 0, "key": "w", "edge": "press"}, {"tick": t(2.5), "key": "space", "edge": "press"},
                                         {"tick": t(2.6), "key": "space", "edge": "release"}, {"tick": t(3.4), "key": "d", "edge": "press"},
                                         {"tick": t(4.0), "key": "d", "edge": "release"}, {"tick": t(5.8), "key": "w", "edge": "release"}],
                            [{"kind": "mouse", "start": t(0.5), "ticks": t(0.35), "total": [30, 10], "shape": "smooth"},
                             {"kind": "mouse", "start": t(1.0), "ticks": t(0.35), "total": [-30, -10], "shape": "smooth"},
                             {"kind": "mouse", "start": t(3.4), "ticks": t(0.6), "total": [90, 0], "shape": "smooth"}], name=f"native-step-{hz}"))
        report = run(f"native-{hz}", plan, motor=f"flow@{hz}:step", headless=False, resolution="640x360", mp4=True, actor_limit=16,
                     actor_every=3, wall_budget=300)
        folder = Path(report["run"])
        basic(f"native {hz} hz", report)
        follow = report["movement"]["camera_follow"]
        check(f"native {hz} hz: approach, contact stop, then a jump recovers onto the 0.7 m ledge",
              report["movement"]["contact_hard_stops"] and report["outcome"]["end_p"][1] > 0.6 and report["outcome"]["end_p"][2] < -14, report["outcome"])
        check(f"native {hz} hz: every drawn frame's camera sits on the interpolated physical body",
              follow["draws_checked"] > 150 and follow["max_horizontal_error_m"] < 1e-3 and not report["movement"]["camera_detached_draws"], follow)
        movie = json.loads((folder / "evaluator/movie.json").read_text())
        frames = json.loads((folder / "evaluator/movie-frames.json").read_text())
        check(f"native {hz} hz: mp4 complete (frames, size, duration, clean decode) before the avi was removed",
              movie["complete"] and movie["avi_removed"] and not (folder / "movie.avi").exists() and (folder / "movie.mp4").exists()
              and movie["mp4"]["frames"] == movie["avi"]["frames"] >= frames["logged_draws"] > 150, movie["checks"])
        manifest = json.loads((folder / "actor/manifest.json").read_text())
        check(f"native {hz} hz: bounded selected actor frames and a contact sheet",
              0 < len(manifest["frames"]) <= 16 and len(list((folder / "actor/frames").glob("*.png"))) == len(manifest["frames"])
              and (folder / "actor/contact-sheet.png").exists(), len(manifest["frames"]))
        engine = json.loads((folder / "evaluator/engine.json").read_text())
        check(f"native {hz} hz: opengl3 on the private display at the requested rate, labelled test-game start",
              engine["physics_hz"] == hz and engine["rendering_driver"] == "opengl3" and engine["start"].startswith("fixture:step")
              and engine["window_size"] == [640, 360], {k: engine[k] for k in ("physics_hz", "rendering_driver", "adapter", "window_size")})
    plan = mt.expand(v2(64, 64 * 300, [{"tick": 0, "key": "w", "edge": "press"}]))
    cancelled = run("native-cancel-64", plan, headless=False, resolution="640x360", cancel_after=14, wall_budget=120, actor_limit=4)
    end = end_of(cancelled)
    check("native cancel 64 hz: acknowledged, neutral, private display stopped and released",
          end.get("reason") == "cancelled" and end.get("neutral") and cancelled["cleanup"]["clean"]
          and cancelled["cleanup"]["display_socket_removed"] and cancelled["cleanup"]["display_lock_removed"], cancelled["cleanup"])
    (Path(cancelled["run"]) / "movie.avi").unlink(missing_ok=True)
    capped = run("native-movie-budget-64", plan, headless=False, resolution="640x360", max_movie_mib=1, wall_budget=120, actor_limit=4)
    end = end_of(capped)
    check("native movie budget: a capture over its size budget is cancelled with neutral input",
          capped["cleanup"].get("cancel", {}).get("reason") == "movie_budget" and end.get("neutral") and capped["cleanup"]["clean"], capped["cleanup"])
    (Path(capped["run"]) / "movie.avi").unlink(missing_ok=True)


def g_source():
    # the real Source hull stays axis aligned while its view turns. this is not r13's body-yaw rule.
    for hz, alias in [(64, "source_vanilla"), (128, "source_server")]:
        t = lambda seconds: round(seconds * hz)
        plan = mt.expand(v2(hz, 3 * hz, [
            {"tick": 0, "key": "w", "edge": "press"},
            {"tick": hz, "key": "w", "edge": "release"},
            {"tick": hz, "key": "a", "edge": "press"},
            {"tick": hz, "key": "space", "edge": "press"},
            {"tick": hz + 1, "key": "space", "edge": "release"},
            {"tick": t(1.35), "key": "a", "edge": "release"},
        ], [{"kind": "mouse", "start": hz, "ticks": hz, "total": [-250, 0], "shape": "linear"}]))
        report = run(f"source-boundary-{hz}", plan, motor=f"{alias}@{hz}")
        basic(f"source {hz} hz", report)
        data = rows(report)
        engine = json.loads((Path(report["run"]) / "evaluator/engine.json").read_text())
        check(f"source {hz} hz: axis-aligned hull and separately turning view declared and observed",
              engine["body_yaw_policy"] == "axis_aligned" and any(abs(r["post"]["yaw"]) > 0.1 for r in data),
              "the orientation assertion checks zero body yaw, not camera yaw")
        airborne = [r for r in data[t(1.36):t(1.60)] if not r["post"]["grounded"]]
        speeds = [mt.hlen(r["post"]["v"]) for r in airborne]
        check(f"source {hz} hz: release preserves airborne line while the mouse keeps turning",
              len(speeds) >= 10 and max(speeds) - min(speeds) < 1e-6,
              {"samples": len(speeds), "range": max(speeds) - min(speeds) if speeds else None})
        # a declared axis-aligned hull which actually rotates must still fail. mutate a copy of the recorded sample.
        folder = Path(report["run"])
        archived = folder / "evaluator/trace.jsonl.gz"
        original = archived.read_bytes()
        raw = folder / "evaluator/trace.jsonl"
        all_rows = mt.read_jsonl(raw)
        target = next(r for r in all_rows if r["phase"] == "tape" and r["tick"] == hz + 1)
        target["post"]["motor_rotation_y"] = 0.1
        raw.write_text("".join(json.dumps(r) + "\n" for r in all_rows))
        try:
            rejected = mt.evaluate(folder)
            check(f"source {hz} hz: rotating a supposedly axis-aligned hull is caught",
                  any(e["kind"] == "motor_body_yaw_differs_from_policy" for e in rejected["order"]["errors"]))
        finally:
            raw.unlink()
        check(f"source {hz} hz: negative analysis leaves the archived run unchanged", archived.read_bytes() == original)


GROUPS = {"headers": g_headers, "reject": g_reject, "delivery": g_delivery, "repeat": g_repeat, "elapsed": g_elapsed,
          "midrun": g_midrun, "archive": g_archive, "cleanup": g_cleanup, "legacy": g_legacy, "native": g_native,
          "source": g_source}


def main():
    global evidence
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", nargs="*", choices=list(GROUPS))
    parser.add_argument("--evidence", type=Path, default=EVIDENCE / time.strftime("test-%Y%m%d-%H%M%S"))
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    for name in args.only or list(GROUPS):
        try:
            GROUPS[name]()
        except Exception as error:  # a crashed group is a failed check, and the rest still run
            check(f"{name}: group ran", False, repr(error))
    failed = [r for r in results if not r["ok"]]
    (evidence / "test-summary.json").write_text(json.dumps({"passed": len(results) - len(failed), "failed": len(failed),
                                                             "wall_s": time.monotonic() - started, "checks": results}, indent=1))
    print(f"{len(results) - len(failed)} passed, {len(failed)} failed; evidence {evidence}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
