#!/usr/bin/env python3
"""Challenge a retained mail capture comparator with identity and finish-state mutations."""
import argparse
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import tempfile


def run(expected_path, frames_path, startup_path):
    capture = json.loads((frames_path.parent / "capture.json").read_text())
    roof = capture["map"] == "mail-roofs"
    module_path = Path(__file__).with_name("mail_roofs_match.py" if roof else "mail_capture_match.py")
    spec = importlib.util.spec_from_file_location("mail_matcher", module_path)
    matcher = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(matcher)
    native = json.loads(expected_path.read_text())
    frames = [json.loads(line) for line in frames_path.read_text().splitlines()]
    baseline = matcher.verify(expected_path, frames_path, startup_path)
    tails = [i for i, row in enumerate(frames) if round(row["time"] * 128) > native["observations"][-1]["tick"]]
    assert tails, "fixture needs a post-native-end observation"
    synthetic = len(tails) == 1
    if synthetic:
        frames.append(deepcopy(frames[-1]))
        frames[-1]["time"] += 1.0
    tail = tails[0]
    cases = []
    if roof:
        cases.append(("native identity differs from startup", "native", "course_key", "0000000000000000"))
    for field, value in [("active", True), ("delivered", []), ("finished", False), ("finish_kind", "practice")]:
        cases.append(("post-finish " + field, "frame", field, value))
    rejected = []
    with tempfile.TemporaryDirectory(prefix="mail-match-") as scratch:
        folder = Path(scratch)
        for name in ["capture.json", "engine.log"]:
            (folder / name).write_bytes((frames_path.parent / name).read_bytes())
        challenge_expected = folder / expected_path.name
        challenge_expected.write_text(json.dumps(native))
        challenge_frames = folder / "frames.jsonl"
        challenge_frames.write_text("".join(json.dumps(row) + "\n" for row in frames))
        matcher.verify(challenge_expected, challenge_frames, startup_path)
        for description, target, field, value in cases:
            changed_native, changed_frames = deepcopy(native), deepcopy(frames)
            if target == "native":
                changed_native[field] = value
            else:
                row = changed_frames[tail]
                (row["motion"]["mail"] if field in ["active", "delivered"] else row)[field] = value
            changed_expected = folder / expected_path.name
            changed_expected.write_text(json.dumps(changed_native))
            changed_capture = folder / "frames.jsonl"
            changed_capture.write_text("".join(json.dumps(row) + "\n" for row in changed_frames))
            try:
                matcher.verify(changed_expected, changed_capture, startup_path)
            except AssertionError as error:
                rejected.append({"case": description, "reason": str(error)})
            else:
                raise AssertionError("accepted invalid evidence: " + description)
    return {"ok": True, "map": capture["map"], "baseline": baseline, "synthetic_extra_tail_for_mutations": synthetic, "rejected": rejected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected", required=True, type=Path)
    parser.add_argument("--frames", required=True, type=Path)
    parser.add_argument("--startup-expected", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    result = run(args.expected, args.frames, args.startup_expected)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
