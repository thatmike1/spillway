#!/usr/bin/env python3
"""Check sampled native carry motion, traversal coverage and capture provenance."""
import argparse
import copy
import hashlib
import json
from pathlib import Path


def runtime_status(rows):
    return sorted(row for row in rows if row[3:].startswith(("scripts/", "assets/", "shaders/", "scenes/")) or row[3:] in ("project.godot", "export_presets.cfg"))


def check(expected, frames, capture, source, events):
    if not expected or not frames:
        raise ValueError("both traces must be nonempty")
    errors = []
    every = capture.get("every", 0)
    seconds = source["finish_tick"] / 128
    coverage_ok = (0 < every <= .25 and 0 < frames[0]["time"] <= 1 / 128
                   and seconds + .5 <= frames[-1]["time"] <= len(expected) / 128)
    provenance_ok = (capture.get("mode") == "tape" and capture.get("map") == "foundry"
                     and capture.get("events") == events
                     and capture.get("source_commit") == source["source_commit"]
                     and runtime_status(capture.get("source_status", [])) == source["runtime_status"]
                     and capture.get("engine_sha256") == source["engine_sha256"])
    previous_time = 0.0
    previous_checkpoint = 0
    transitions = [0]
    prefinish_samples = 0
    finished_seen = False
    for index, row in enumerate(frames):
        stamp = row["time"]
        coverage_ok = coverage_ok and (stamp > previous_time and stamp - previous_time <= every + 1 / 128
                                        and row["frame"] == index and row.get("error") == 0 and row.get("mode") == "tape")
        previous_time = stamp
        tick = round(stamp * 128)
        if not 1 <= tick <= len(expected):
            raise ValueError("capture sample is outside the full expected traversal/stopping trace")
        reference = expected[tick - 1]
        motion = row["motion"]
        if row["position"] != reference["position"]:
            errors.append({"frame": index, "tick": tick, "field": "position", "expected": reference["position"], "actual": row["position"]})
        if motion["velocity_u"] != reference["motion"]["velocity_u"]:
            errors.append({"frame": index, "tick": tick, "field": "velocity_u", "expected": reference["motion"]["velocity_u"], "actual": motion["velocity_u"]})
        # server128 is the menu ID; observations retain the underlying source preset ID.
        settings_ok = (motion["preset"] == reference["motion"]["preset"] == "csgo_server"
                       and motion["cvars"] == reference["motion"]["cvars"]
                       and motion["physics_hz"] == motion["tickrate"] == 128
                       and motion["experiment"]["tether"]["model"] == "elastic-arc")
        if row["respawns"] != 0 or not settings_ok:
            errors.append({"frame": index, "field": "respawn_or_settings"})
        checkpoint = row["checkpoint"]
        if checkpoint != previous_checkpoint:
            transitions.append(checkpoint)
        if checkpoint < previous_checkpoint or checkpoint > previous_checkpoint + 1:
            errors.append({"frame": index, "field": "checkpoint_order"})
        previous_checkpoint = checkpoint
        if stamp < seconds:
            prefinish_samples += 1
            if row["finished"]:
                errors.append({"frame": index, "field": "early_finish"})
        if finished_seen and not row["finished"]:
            errors.append({"frame": index, "field": "finish_reversed"})
        finished_seen = finished_seen or row["finished"]
    if every > 0:
        coverage_ok = coverage_ok and prefinish_samples >= int(seconds / every)
    else:
        coverage_ok = False
    last = frames[-1]
    finish_ok = last["finished"] and last["finish_kind"] == "clean" and last["checkpoint"] == 2
    one_hook = last["motion"]["experiment"]["counts"]["grapple"] == 1
    stopped_on_catch = last["motion"]["grounded"] and last["motion"]["actual_speed_u"] == 0
    return {"ok": not errors and coverage_ok and provenance_ok and finish_ok and one_hook and stopped_on_catch and transitions == [0, 1, 2],
            "scope": "every captured body position and serialized velocity; not unsampled ticks, view angles or cumulative motor counters",
            "samples": len(frames), "expected_ticks": len(expected), "prefinish_samples": prefinish_samples,
            "coverage_ok": coverage_ok, "provenance_ok": provenance_ok, "checkpoint_transitions": transitions,
            "clean_finish": finish_ok, "one_hook": one_hook, "stopped_on_catch": stopped_on_catch, "errors": errors}


def challenge(expected, frames, capture, source, events):
    probes = {}
    wrong = copy.deepcopy(frames)
    wrong[0]["motion"]["preset"] = "server128"
    probes["menu_id_is_not_serialized_preset"] = not check(expected, wrong, capture, source, events)["ok"]
    sparse = copy.deepcopy(frames[-3:])
    for index, row in enumerate(sparse):
        row["frame"] = index
        row["checkpoint"] = index
        row["finished"] = index == 2
    probes["late_finish_samples_cannot_replace_traversal"] = not check(expected, sparse, capture, source, events)["ok"]
    wrong_capture = copy.deepcopy(capture)
    wrong_capture["source_commit"] = "0" * 40
    probes["wrong_source_rejected"] = not check(expected, frames, wrong_capture, source, events)["ok"]
    wrong_capture = copy.deepcopy(capture)
    wrong_capture["events"][0]["time"] += .01
    probes["different_input_tape_rejected"] = not check(expected, frames, wrong_capture, source, events)["ok"]
    wrong = copy.deepcopy(frames)
    wrong[1]["motion"]["experiment"]["tether"]["model"] = "linear"
    probes["wrong_rope_law_rejected"] = not check(expected, wrong, capture, source, events)["ok"]
    wrong = copy.deepcopy(frames)
    wrong[7]["position"][0] += .01
    probes["body_mutation_rejected"] = not check(expected, wrong, capture, source, events)["ok"]
    wrong = copy.deepcopy(frames)
    wrong[-1]["respawns"] = 1
    probes["respawn_rejected"] = not check(expected, wrong, capture, source, events)["ok"]
    wrong = copy.deepcopy(frames)
    wrong[-1]["motion"]["grounded"] = False
    probes["airborne_tail_rejected"] = not check(expected, wrong, capture, source, events)["ok"]
    return probes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected", type=Path, required=True)
    parser.add_argument("--frames", type=Path, required=True)
    parser.add_argument("--capture", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--events", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--challenge", action="store_true", help="mutate this real capture to challenge acceptance guards")
    args = parser.parse_args()
    expected = json.loads(args.expected.read_text())
    frames = [json.loads(line) for line in args.frames.read_text().splitlines()]
    source = json.loads(args.source.read_text())
    if "runtime_inventory_sha256" in source:
        inventory = args.source.parent / source["runtime_inventory"]
        if hashlib.sha256(inventory.read_bytes()).hexdigest() != source["runtime_inventory_sha256"]:
            raise ValueError("frozen runtime inventory changed after the source receipt")
    expected_sha = hashlib.sha256(args.expected.read_bytes()).hexdigest()
    events_sha = hashlib.sha256(args.events.read_bytes()).hexdigest()
    if expected_sha != source["expected_sha256"] or events_sha != source["events_sha256"]:
        raise ValueError("earned trace or input tape does not match the source receipt")
    capture = json.loads(args.capture.read_text())
    events = json.loads(args.events.read_text())
    result = check(expected, frames, capture, source, events)
    if args.challenge:
        probes = challenge(expected, frames, capture, source, events)
        result["negative_controls"] = probes
        result["ok"] = result["ok"] and all(probes.values())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))
    raise SystemExit(0 if result["ok"] else 1)


if __name__ == "__main__":
    main()
