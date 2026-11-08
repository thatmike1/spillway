#!/usr/bin/env python3
"""exercise the actual evaluator on a fresh r15 crouch tape and corrupt capture controls.

the input run must contain an air duck and stand. mutation controls affect in-memory copies
of its captured trace, never the actor or retained evidence. no pass is claimed without a
real run supplied with --run.
"""

import argparse
import copy
import importlib.util
import json
from pathlib import Path
from unittest.mock import patch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / "tools/momentum-tape.py"
    spec = importlib.util.spec_from_file_location("r15_tape", source)
    tape = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tape)
    result = tape.evaluate(args.run)
    rows = tape.read_jsonl(args.run / "evaluator/trace.jsonl")
    compensated = result["order"]["hull_origin_compensations"]
    assert result["delivery"]["ok"] and result["order"]["ok"] and result["rate"]["ok"]
    assert result["neutral"] and not result["integrity_flags"]
    assert len(compensated) >= 2 and all(r["valid"] for r in compensated)
    assert any(r["shift_m"][1] > 0 for r in compensated) and any(r["shift_m"][1] < 0 for r in compensated)
    first_tick = next(r["tick"] for r in compensated if r["shift_m"][1] > 0)
    index = next(i for i, r in enumerate(rows) if r["phase"] == "tape" and r["tick"] == first_tick)
    assert rows[index]["order"]["motor_prev_matches_pre"] is False
    assert result["order"]["counter_verified_ticks"] == result["outcome"]["ticks"]
    controls = {
        "skipped motor": lambda r: r["order"].update(step_count_delta=0),
        "double motor": lambda r: r["order"].update(step_count_delta=2),
        "missing counter": lambda r: r["order"].update(step_count_delta=None),
        "wrong frame": lambda r: r["order"].update(same_physics_frame=False),
        "body not current": lambda r: r["order"].update(motor_cur_matches_body=False),
        "ground claims air shift": lambda r: r["pre"].update(grounded=True),
        "missing crouch input": lambda r: r["post"].update(actions=[k for k in r["post"]["actions"] if k != "ctrl"]),
        "missing duck event": lambda r: r["post"]["motion_state"]["duck"].update(events=[]),
        "missing observed hull": lambda r: r.pop("hull_origin"),
        "unchanged hull": lambda r: r["hull_origin"]["after"].update(ducked=False),
        "wrong anchor": lambda r: r["hull_origin"]["before"].update(anchor="feet"),
        "bad horizontal shift": lambda r: r["post"]["motion_state"].update(duck_shift=[0.1, 0.2286, 0.0]),
        "bad vertical shift": lambda r: r["post"]["motion_state"].update(duck_shift=[0.0, 0.5, 0.0]),
        "nonfinite shift": lambda r: r["post"]["motion_state"].update(duck_shift=[0.0, float("nan"), 0.0]),
        "unexplained old origin": lambda r: r["hull_origin"].update(motor_previous=[0.0, 100.0, 0.0]),
        "bad observed box": lambda r: r["hull_origin"]["after"].update(box_size_m=[0.8128, 1.8288, 0.8128]),
        "bad observed centre": lambda r: r["hull_origin"]["after"].update(box_center_m=[0.0, 0.5, 0.0]),
        "overflow pre-position": lambda r: r["pre"].update(p=[0.0, 1e308, 0.0]),
        "overflow observed origin": lambda r: r["hull_origin"]["before"].update(interp_current=[0.0, 1e308, 0.0]),
        "false zero shift": lambda r: r["post"]["motion_state"].update(duck_shift=[0.0, 0.0, 0.0]),
    }
    original_reader = tape.read_jsonl
    rejected = []
    for name, mutate in controls.items():
        changed = copy.deepcopy(rows)
        mutate(changed[index])

        def read(path, *pos, **kw):
            if Path(path).name == "trace.jsonl":
                return changed
            return original_reader(path, *pos, **kw)

        with patch.object(tape, "read_jsonl", side_effect=read):
            verdict = tape.evaluate(args.run)
        assert verdict["order"]["ok"] is False, name
        rejected.append(name)
    output = {"run": str(args.run.resolve()), "positive": "air duck and stand accepted with raw mismatches retained",
              "ticks": result["outcome"]["ticks"], "compensations": compensated,
              "negative_capture_controls_rejected": rejected, "passed": True}
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(output, indent=2, allow_nan=False) + "\n")
    print("air-duck replay passes; %d/%d corrupt-capture controls rejected" % (len(rejected), len(controls)))


if __name__ == "__main__":
    main()
