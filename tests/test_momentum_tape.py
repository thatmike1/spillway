#!/usr/bin/env python3
"""end-to-end checks for the momentum tape executor (docs/momentum/TAPE.md).

python3 tests/test_momentum_tape.py [--only GROUP ...] [--evidence DIR]
groups: units audit smooth replay render30 failure negative realtime cleanup review
native groups use a private Xvfb display; evidence stays outside the checkout.
"""

import argparse
import importlib.util
import json
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
TAPES = PROJECT / "tests/momentum_tapes"
spec = importlib.util.spec_from_file_location("momentum_tape", PROJECT / "tools/momentum-tape.py")
mt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mt)

# p / replay tolerance, frozen after three unmodified same-build native runs measured 0.0 m.
REPLAY_TOLERANCE_M = 0.0
results = []
evidence = None


def check(name, ok, detail=None):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f"  {json.dumps(detail, default=str)[:400]}"), flush=True)


def tape(name):
    return mt.expand(json.loads((TAPES / f"{name}.json").read_text()))


def run(name, plan, **cfg):
    return mt.execute(plan, evidence / name, cfg)


def trace(report):
    return [r for r in mt.read_jsonl(Path(report["run"]) / "evaluator/trace.jsonl") if r["phase"] == "tape"]


def basic(name, report, delivery=True):
    check(f"{name}: completed with neutral input", report["end"] == "completed" and report["neutral"] is True, report.get("end"))
    if delivery:
        check(f"{name}: delivery ok", report["delivery"]["ok"], report["delivery"]["errors"][:5])
    check(f"{name}: capture ordering and available motor evidence agree", report["order"]["ok"], report["order"]["errors"][:5])
    check(f"{name}: owned processes and display cleaned up", report["cleanup"]["clean"], report["cleanup"])


def variant(name, old, new):
    """a disposable executor copy with one deliberate defect, outside the checkout."""
    source = (PROJECT / "tools/momentum-tape.gd").read_text()
    assert source.count(old) == 1, old
    path = evidence / "variants" / f"{name}.gd"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(source.replace(old, new))
    return path


# --- groups ----------------------------------------------------------------------------------

def g_units():
    smooth = mt.expand({"format": mt.FORMAT, "version": 1, "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 100,
                        "curves": [{"kind": "mouse", "start": 10, "ticks": 40, "total": [-300, 20], "shape": "smooth"}]})
    dx = [e["mouse"][0] for e in smooth["events"]]
    check("expand: smooth stroke sums to its total", abs(sum(dx) + 300) < 1e-3, sum(dx))
    check("expand: smooth stroke speed varies (accelerates, then stops)", max(map(abs, dx)) / min(map(abs, dx)) > 10, [dx[0], dx[20]])
    paced = mt.expand({"format": mt.FORMAT, "version": 1, "physics_hz": 120, "input_profile": "render30", "duration_ticks": 100,
                       "curves": [{"kind": "mouse", "start": 8, "ticks": 40, "total": [100, 0], "shape": "linear"}]})
    check("expand: render30 curves land only on 4-tick boundaries with a constant step",
          all(e["tick"] % 4 == 0 for e in paced["events"]) and len({e["mouse"][0] for e in paced["events"]}) == 1, paced["events"][:3])
    whole = mt.expand({"format": mt.FORMAT, "version": 1, "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 100, "mouse_quantize": "integer",
                       "curves": [{"kind": "mouse", "start": 0, "ticks": 37, "total": [101, -7], "shape": "smooth"}]})
    check("expand: integer quantization keeps the total in whole counts",
          sum(e["mouse"][0] for e in whole["events"]) == 101 and all(float(e["mouse"][0]).is_integer() for e in whole["events"]))
    bad = [
        ("double press", {"events": [{"tick": 0, "key": "w", "edge": "press"}, {"tick": 5, "key": "w", "edge": "press"}]}),
        ("same-tick tap", {"events": [{"tick": 3, "key": "space", "edge": "press"}, {"tick": 3, "key": "space", "edge": "release"}]}),
        ("off cadence", {"input_profile": "render30", "events": [{"tick": 3, "key": "w", "edge": "press"}]}),
        ("unknown key", {"events": [{"tick": 0, "key": "r", "edge": "press"}]}),
        ("beyond the tape", {"events": [{"tick": 100, "key": "w", "edge": "press"}]}),
    ]
    for label, extra in bad:
        base = {"format": mt.FORMAT, "version": 1, "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 100}
        try:
            mt.expand(dict(base, **extra))
            check(f"expand rejects {label}", False)
        except ValueError:
            check(f"expand rejects {label}", True)
    raw = json.loads((TAPES / "flat-strafe-turn.json").read_text())
    report = mt.execute(raw, evidence / "units-unexpanded", {"fixture": "flat", "headless": True})
    check("executor refuses a tape whose curves were not expanded", report["end"].get("reason") == "rejected", report["end"])
    for name in ["smooth-turn-jump-strafe", "render30-batches", "flat-strafe-turn", "step-face-press", "step-late-jump",
                 "fixture-glance-strafe", "course-strafe-wall-stop-min", "long-run-for-cleanup"]:
        tape(name)
    check("every retained example tape expands", True)


def g_audit():
    # no pose, velocity, camera or progress writes outside labelled setup (_build_world).
    source = (PROJECT / "tools/momentum-tape.gd").read_text()
    funcs = re.split(r"\n(?=func )", source)
    pattern = re.compile(r"reset_to|\.velocity\s*=|global_position\s*=|global_transform\s*=|\.position\s*=|"
                         r"set\(\"(yaw|pitch|velocity|checkpoint_index|elapsed|finished|respawn_count)\"|rotation\s*=")
    offenders = [f.splitlines()[0] for f in funcs if pattern.search(f) and not f.startswith("func _build_world")]
    check("executor writes body/camera/progress state only in labelled setup", not offenders, offenders)
    check("executor reads no state to choose input (no aim/route helpers)", "atan2" not in source and "routes" not in source)


def g_smooth():
    plan = tape("smooth-turn-jump-strafe")
    flow = run("smooth-flow", plan)
    basic("smooth flow", flow)
    rows = trace(flow)
    edges = sum(len(r["keys"]) for r in rows)
    check("smooth flow: ten independent key edges applied at their planned ticks", edges == 10, edges)
    first = [abs(r["mouse"]["dx"]) for r in rows if r["mouse"] and 24 <= r["tick"] < 96]
    check("smooth flow: the turn is time-varying (per-tick mouse step changes > 10x)", max(first) / min(first) > 10, [min(first), max(first)])
    yaw = {r["tick"]: r["post"]["yaw"] for r in rows}
    still = all(not by["mouse"] for by in rows if 96 <= by["tick"] < 120)
    check("smooth flow: the mouse stops between the turn and the overshoot", still and abs(yaw[119] - yaw[96]) < 1e-9)
    peak = max(yaw.values())
    check("smooth flow: overshoot past the first turn, then a correction back",
          peak - yaw[96] > 0.3 and peak - yaw[230] > 0.4, {"after_turn": yaw[96], "peak": peak, "after_correction": yaw[230]})
    check("smooth flow: a grounded jump press jumps on its own tick",
          any(j["press_tick"] == 263 and j["jump_tick"] == 263 for j in flow["movement"]["jump_presses"]), flow["movement"]["jump_presses"])
    check("smooth flow: camera stays on the body in every drawn frame", not flow["movement"]["camera_detached_draws"])
    movie = json.loads((Path(flow["run"]) / "evaluator/movie-frames.json").read_text())
    check("smooth flow: native movie frames cover every logged draw", movie["movie_frames"] >= movie["logged_draws"] > 100, movie)
    manifest = json.loads((Path(flow["run"]) / "actor/manifest.json").read_text())
    check("smooth flow: actor frames carry sim time only", all(set(m) == {"seq", "file", "sim_s"} for m in manifest["frames"]) and len(manifest["frames"]) > 15)
    profile = Path(flow["run"]) / "profile"
    check("smooth flow: isolated profile, no records written", not list(profile.rglob("spillway_r12.cfg")) and not list(profile.rglob("spillway_v1.cfg")))
    r12 = run("smooth-r12", plan, motor="r12")
    basic("smooth r12", r12)
    a = json.loads((Path(flow["run"]) / "evaluator/engine.json").read_text())
    b = json.loads((Path(r12["run"]) / "evaluator/engine.json").read_text())
    check("r12 and flow share camera/settings defaults", a["settings"] == b["settings"] and a["viewport_size"] == b["viewport_size"], [a["settings"], b["settings"]])
    run_meta = json.loads((Path(flow["run"]) / "run.json").read_text())
    check("run identity records engine, helpers, source mode and dirty state",
          run_meta["engine_sha256"] and run_meta["helper_sha256"]["executor"] and "source checkout" in run_meta["source"]["mode"] and "dirty" in run_meta["source"])


def g_replay():
    base = evidence / "smooth-flow"
    if not (base / "run.json").exists():
        g_smooth()
    applied = mt.expand(mt.applied_tape(base))
    comparisons = []
    for i in (1, 2):
        again = run(f"replay-{i}", applied)
        basic(f"replay {i}", again)
        comparisons.append(mt.compare(base, Path(again["run"])))
    worst = max(c["max_position_m"] for c in comparisons)
    check(f"replay: same build, fresh run/profile, within {REPLAY_TOLERANCE_M} m", worst <= REPLAY_TOLERANCE_M and all(c["same_applied_events"] for c in comparisons), comparisons)
    (evidence / "replay-comparisons.json").write_text(json.dumps(comparisons, indent=1))
    headless = run("replay-headless", applied, headless=True)
    hc = mt.compare(base, Path(headless["run"]))
    check("replay: headless physics matches the native run (rendering does not touch the motor)", hc["max_position_m"] <= REPLAY_TOLERANCE_M, hc)
    sens = run("replay-sensitivity-1.5", applied, sensitivity=1.5)
    basic("replay sensitivity 1.5", sens)
    sc = mt.compare(base, Path(sens["run"]))
    turned = lambda rows: sum(r["mouse"]["yaw_after"] - r["mouse"]["yaw_before"] for r in rows if r["mouse"])
    ratio = turned(trace(sens)) / turned(trace({"run": str(base)}))
    check("sensitivity 1.5: the same relative events turn the view 1.5x, uncorrected", abs(ratio - 1.5) < 1e-6, ratio)
    check("sensitivity 1.5: the line visibly changes", sc["max_position_m"] > 0.5 and sc["movie_ssim_all"] < comparisons[0]["movie_ssim_all"], sc)
    (evidence / "sensitivity-comparison.json").write_text(json.dumps(sc, indent=1))


def g_render30():
    plan = tape("render30-batches")
    physics = run("render30-tick-inject", plan)
    process = run("render30-process-inject", plan, inject="process")
    basic("render30 physics-boundary injection", physics)
    basic("render30 process injection (old helper's point)", process)
    c = mt.compare(Path(physics["run"]), Path(process["run"]))
    check("render30: both injection points give the same motor result", c["max_position_m"] == 0.0 and c["max_yaw_rad"] == 0.0, c)
    keys = [k for r in trace(process) for k in r["keys"]]
    check("render30: process injection applies keys between steps, never inside one", keys and all(not k["in_physics"] for k in keys))
    (evidence / "render30-comparison.json").write_text(json.dumps(c, indent=1))


def g_failure():
    plan = tape("course-strafe-wall-stop-min")
    report = run("failure-course-min", plan)
    basic("retained course failure", report)
    hard = report["movement"]["contact_hard_stops"]
    # reported speed is already 0.0 after tick 97's contact; displacement collapses on tick 98.
    check("retained failure: flow stops dead at the crest deck side wall (displacement, tick 98)",
          [h["tick"] for h in hard] == [98] and hard[0]["approach_m_s"] > 8.5 and hard[0]["after_m_s"] < 0.5, hard)
    full = evidence / "smooth-flow"
    if (full / "evaluator/report.json").exists():
        flagged = json.loads((full / "evaluator/report.json").read_text())["movement"]["contact_hard_stops"]
        check("retained failure: the minimized tape reproduces the full tape's stop tick",
              [h["tick"] for h in flagged] == [h["tick"] for h in hard], [flagged, hard])
    for motor in ("flow", "r12"):
        fx = run(f"failure-fixture-glance-{motor}", tape("fixture-glance-strafe"), fixture="glance", motor=motor)
        basic(f"glance fixture {motor}", fx)
        check(f"glance fixture {motor}: strafing into a plain side wall at run speed stops dead", fx["movement"]["contact_hard_stops"], fx["movement_flags"])
    step = run("failure-step-late-jump", tape("step-late-jump"), fixture="step")
    basic("step late jump", step)
    check("step late jump: approach, contact stop, then recovery onto the ledge",
          step["movement"]["contact_hard_stops"] and step["outcome"]["end_p"][1] > 0.6 and step["outcome"]["end_p"][2] < -20, step["outcome"])


def g_negative():
    plan = tape("flat-strafe-turn")
    clean = run("neg-clean", plan, fixture="flat", headless=True)
    basic("negative baseline", clean)
    check("negative baseline: no movement or integrity flags", not clean["movement_flags"] and not clean["integrity_flags"])
    dropped = run("neg-dropped-release", plan, fixture="flat", headless=True,
                  executor=variant("drop-release", "func _send_key(key: String, pressed: bool) -> void:\n",
                                   "func _send_key(key: String, pressed: bool) -> void:\n\tif not pressed and key == \"a\":\n\t\treturn\n"))
    kinds = {e["kind"] for e in dropped["delivery"]["errors"]}
    check("dropped release: reported as a delivery error from tick 120",
          "held_state_differs_from_plan" in kinds and any(e.get("tick") == 120 for e in dropped["delivery"]["errors"]), dropped["delivery"]["errors"][:4])
    check("dropped release: neutral cleanup found the stuck key", "still_pressed_after_neutral_release" in kinds)
    check("dropped release: not mistaken for a movement failure", not dropped["movement_flags"], dropped["movement_flags"])
    omitted = run("neg-no-screen-relative", plan, fixture="flat", headless=True,
                  executor=variant("no-screen-relative", "\tevent.screen_relative = delta\n", ""))
    kinds = {e["kind"] for e in omitted["delivery"]["errors"]}
    check("omitted screen_relative: event field and camera mismatch both detected",
          {"mouse_screen_relative_differs", "view_did_not_follow_mouse"} <= kinds, sorted(kinds))
    check("omitted screen_relative: not mistaken for a movement failure", not omitted["movement_flags"], omitted["movement_flags"])
    press = tape("step-face-press")
    honest = run("neg-speed-honest", press, fixture="step", headless=True)
    basic("pinned against the step, real motor", honest)
    check("pinned, real motor: stuck is a movement observation, speed report agrees with displacement",
          "stuck_windows" in honest["movement_flags"] and not honest["integrity_flags"], [honest["movement_flags"], honest["integrity_flags"]])
    motor = evidence / "variants/misreport_motor.gd"
    motor.parent.mkdir(parents=True, exist_ok=True)
    motor.write_text('extends "res://scripts/momentum_flow_player.gd"\n'
                     "## disposable negative control: reports throttle target as speed while forward is held.\n"
                     "func get_speed() -> float:\n"
                     "\treturn 9.0 if Input.is_action_pressed(\"move_forward\") else super()\n")
    liar = run("neg-speed-misreport", press, fixture="step", headless=True, motor_script=str(motor))
    check("misreported speed: rejected against real displacement",
          "reported_speed_unsupported" in liar["integrity_flags"] and liar["delivery"]["ok"], [liar["integrity_flags"], liar["movement"]["reported_speed_unsupported"][:1]])
    check("misreported speed: still recorded as stuck, not as progress", "stuck_windows" in liar["movement_flags"])


def g_realtime():
    report = run("realtime-readback", tape("flat-strafe-turn"), fixture="flat", timing="realtime", readback_every=8)
    basic("realtime readback", report)
    pngs = list((Path(report["run"]) / "frames").glob("*.png"))
    check("realtime: frames read back with wall timestamps", len(pngs) > 3, len(pngs))
    check("realtime: wall lag against simulation is reported", report["timing"]["fixed_fps"] is False, report["timing"])


def g_cleanup():
    plan = tape("long-run-for-cleanup")
    timeout = run("cleanup-wall-timeout", plan, fixture="flat", wall_budget=20)
    check("wall budget: executor stops itself with exit 3", timeout["end"] == "wall_timeout" and timeout["cleanup"]["engine_exit"] == 3, timeout["end"])
    check("wall budget: neutral input and no owned process left", timeout["neutral"] is True and timeout["cleanup"]["clean"], timeout["cleanup"])
    out = evidence / "cleanup-sigint"
    wrapper = subprocess.Popen([sys.executable, str(PROJECT / "tools/momentum-tape.py"), "run", str(TAPES / "long-run-for-cleanup.json"),
                                "--out", str(out), "--world", "fixture:flat"], stdout=subprocess.PIPE, text=True)
    trace_file = out / "evaluator/trace.jsonl"
    limit = time.monotonic() + 90
    while time.monotonic() < limit and not (trace_file.exists() and trace_file.stat().st_size > 200000):
        time.sleep(0.5)
    wrapper.send_signal(signal.SIGINT)
    wrapper.communicate(timeout=120)
    cleanup = json.loads((out / "evaluator/cleanup.json").read_text())
    end = json.loads((out / "end.json").read_text())
    check("SIGINT: cancel acknowledged by the executor with neutral input",
          cleanup.get("cancel", {}).get("ack") and end["reason"] == "cancelled" and end["neutral"], [cleanup.get("cancel"), end.get("reason")])
    check("SIGINT: engine exited 4, display stopped, no owned process left", cleanup["engine_exit"] == 4 and cleanup["clean"], cleanup)
    hung = run("cleanup-hang", plan, fixture="flat", hang_after=16, deadline=26, ack_grace=4)
    c = hung["cleanup"]
    check("hang: no ack from a frozen engine, so the owned group is killed",
          c["cancel"]["ack"] is None and c.get("engine_forced", {}).get("signal") == "SIGKILL", c)
    check("hang: display stopped and no owned process left; neutral input not claimed", c["clean"] and c["neutral_input"] == "not observable: engine did not finish", c)


def g_review():
    # disposable motor/game injections reproduce the three independent review faults.
    variants = evidence / "variants"
    variants.mkdir(exist_ok=True)
    reverse = variants / "reverse-vector.gd"
    reverse.write_text('''extends "res://scripts/momentum_flow_player.gd"
var saved := Vector3.ZERO
var restore := false
func _physics_process(delta: float) -> void:
    if restore:
        velocity = saved
    super(delta)
    saved = velocity
    restore = true
    velocity.x = -velocity.x
    velocity.z = -velocity.z
''')
    plan = mt.expand({"format": mt.FORMAT, "version": 1, "name": "reverse-vector",
                      "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 40,
                      "events": [{"tick": 0, "key": "w", "edge": "press"}]})
    control = run("review-vector-control", plan, fixture="flat", headless=True)
    broken = run("review-vector-injection", plan, fixture="flat", headless=True, motor_script=reverse)
    check("vector: injection preserves the control trajectory", [r["post"]["p"] for r in trace(control)] == [r["post"]["p"] for r in trace(broken)])
    check("vector: real motion has no integrity flag", not control["integrity_flags"], control["integrity_flags"])
    check("vector: opposite heading with equal speed is caught", "post_velocity_unsupported" in broken["integrity_flags"] and "reported_speed_unsupported" not in broken["integrity_flags"], broken["integrity_flags"])

    reset = variants / "counted-reset.gd"
    reset.write_text('''extends Node3D
const MAIN := preload("res://scripts/spillway_main.gd")
const FIXTURE := preload("res://tools/momentum-tape-fixture.gd")
var player: CharacterBody3D
var respawn_count := 0
var checkpoint_index := 0
var elapsed := 0.0
var finished := false
var finish_kind := ""
var paused := false
var calls := 0
func _ready() -> void:
    process_physics_priority = 100
    MAIN.bind_inputs()
    var fixture := FIXTURE.new()
    add_child(fixture)
    fixture.build("flat")
    player = preload("res://scripts/momentum_flow_player.gd").new()
    add_child(player)
    player.reset_to(fixture.spawn)
func _physics_process(_delta: float) -> void:
    calls += 1
    if calls == 11:
        player.reset_to(Transform3D(Basis.IDENTITY, Vector3(50, 0.02, 20)))
        respawn_count += 1
''')
    no_input = mt.expand({"format": mt.FORMAT, "version": 1, "name": "counted-reset",
                          "physics_hz": 120, "input_profile": "tick120", "duration_ticks": 24, "events": []})
    report = run("review-reset", no_input, game_script=reset, game_class="", headless=True)
    check("reset: discontinuity is retained in raw samples", len(report["movement"]["discontinuities"]) == 1, report["movement"])
    check("reset: teleport adds no travel or peak speed", report["outcome"]["travel_m"] == 0 and report["outcome"]["max_displacement_m_s"] == 0, report["outcome"])
    meta = json.loads((Path(report["run"]) / "run.json").read_text())
    check("reset: external game variant is hashed", "game_variant" in meta["source"]["manifest"])

    real_engine = mt.GODOT
    fake = variants / "non-executable-engine"
    fake.write_text("#!/bin/sh\nexit 0\n")
    fake.chmod(0o600)
    handlers = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM)}
    try:
        mt.GODOT = fake
        failed = run("review-launch-failure", no_input, display=159, wall_budget=5, deadline=8)
        folder = Path(failed["run"])
        check("launch failure: exception and provenance are recorded", failed["end"].get("reason") == "launch_failed" and (folder / "run.json").exists() and (folder / "evaluator/cleanup.json").exists(), failed)
        check("launch failure: private display and owned processes cleaned", failed["cleanup"]["clean"], failed["cleanup"])
        check("launch failure: signal handlers restored", all(signal.getsignal(s) == h for s, h in handlers.items()))
        check("launch failure: CLI reports failure", mt.execution_exit(failed) == 2)
    finally:
        mt.GODOT = real_engine


GROUPS = {"units": g_units, "audit": g_audit, "smooth": g_smooth, "replay": g_replay, "render30": g_render30,
          "failure": g_failure, "negative": g_negative, "realtime": g_realtime, "cleanup": g_cleanup, "review": g_review}


def main():
    global evidence
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", nargs="*", choices=list(GROUPS))
    parser.add_argument("--evidence", type=Path, default=mt.EVIDENCE / time.strftime("test-%Y%m%d-%H%M%S"))
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
