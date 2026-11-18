#!/usr/bin/env python3
"""Compare canonical rendered mail tapes with their native input-driven observations."""
import argparse
import json
import math
from pathlib import Path
import re


def verify(expected_path, frames_path, startup_path):
    source = json.loads(expected_path.read_text())
    startup = json.loads(startup_path.read_text())
    expected = {row["tick"]: row for row in source["observations"]}
    assert len(expected) == len(source["observations"]), "duplicate native ticks"
    frames = [json.loads(line) for line in frames_path.read_text().splitlines()]
    assert frames, "no rendered observations"
    folder = frames_path.parent
    capture = json.loads((folder / "capture.json").read_text())
    assert capture["mode"] == "tape" and capture["map"] == "mail-run", "requires a live mail input tape"
    header = re.search(r"course_key=([0-9a-f]+)", (folder / "engine.log").read_text())
    assert header and header[1] == startup["course_key"], "startup geometry/identity differs from native proof"
    name = expected_path.name.removesuffix(".expected.json")
    body, view = name.split("-", 1)
    post_finish = 0
    checked = 0
    worst = 0.0
    for row in frames:
        assert row["error"] == 0 and row["mode"] == "tape", "invalid capture"
        mail = row["motion"]["mail"]
        assert (mail["body"], mail["view"], mail["goal"]) == (body, view, "deliver"), "wrong playback variant"
        assert row["respawns"] == 0, "rendered run fell or respawned"
        tick = round(row["time"] * 128)
        assert abs(row["time"] * 128 - tick) < 1e-8, "capture is not on the 128 Hz timeline"
        if tick not in expected:
            assert tick > max(expected) and source["observations"][-1]["finished"], "missing native observation"
            final = source["observations"][-1]
            assert row["finished"] and row["finish_kind"] == "clean", "post-finish capture lost clean finish"
            assert mail["delivered"] == final["delivered"], "post-finish delivery state differs"
            assert mail["active"] == final["active"], "post-finish flight state differs"
            post_finish += 1
            continue
        native = expected[tick]
        distance = math.dist(native["position"], row["position"])
        worst = max(worst, distance)
        assert distance <= 1e-6, f"body mismatch at tick {tick}: {distance}m"
        assert native["delivered"] == mail["delivered"], f"delivery mismatch at tick {tick}"
        assert native["active"] == mail["active"], f"flight mismatch at tick {tick}"
        assert native["finished"] == row["finished"], f"finish mismatch at tick {tick}"
        checked += 1
    assert checked >= 3, "too few matched physical observations"
    last = frames[-1]
    assert last["finished"] and last["finish_kind"] == "clean", "capture does not prove clean completion"
    assert len(last["motion"]["mail"]["delivered"]) == 3, "capture does not prove all deliveries"
    return {"ok": True, "body": body, "view": view, "matched_samples": checked, "post_finish_state_samples": post_finish,
            "worst_position_difference_m": worst, "source_course_key": source["course_key"],
            "startup_course_key": startup["course_key"], "finished": True, "deliveries": 3,
            "expected": str(expected_path), "frames": str(frames_path)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected", type=Path, required=True)
    parser.add_argument("--frames", type=Path, required=True)
    parser.add_argument("--startup-expected", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    report = verify(args.expected, args.frames, args.startup_expected)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
