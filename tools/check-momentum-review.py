#!/usr/bin/env python3
"""check the actual input/contact traces from momentum_review_probe.gd."""

import argparse
import json
import math
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    failures = []
    cases = {}
    for path in sorted(args.evidence.glob("*.jsonl")):
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        cases[path.stem] = rows
        for index, row in enumerate(rows):
            if not all(math.isfinite(x) for key in ["p", "v", "real_v", "disp_v"] for x in row[key]):
                failures.append(f"{path.stem}:{index}: non-finite state")
            if index and row["physics_frame"] != rows[index - 1]["physics_frame"] + 1:
                failures.append(f"{path.stem}:{index}: skipped physics sample")
            if max(abs(a - b) for a, b in zip(row["real_v"], row["disp_v"])) > 0.001:
                failures.append(f"{path.stem}:{index}: displacement/get_real_velocity mismatch")

    cadence = {}
    for name, rows in cases.items():
        if name.startswith("earned_cadence_"):
            cadence[name] = rows[-1]["carve"] - rows[101]["carve"]
            if abs(sum(row["mouse_rad"] for row in rows) - 0.9) > 0.000001:
                failures.append(f"{name}: the input gesture did not deliver 0.9 radians")
    required = {f"earned_cadence_{hz}" for hz in [120, 60, 30]}
    required |= {f"earned_cadence_{hz}_phase_{phase}" for hz in [60, 30] for phase in range(120 // hz)}
    if required - cadence.keys():
        failures.append(f"missing cadence cases: {sorted(required - cadence.keys())}")
    if cadence and (max(cadence.values()) - min(cadence.values()) > 0.0001 or min(cadence.values()) < 0.899):
        failures.append("same yaw gesture earns different or incomplete carve across deliveries")

    wall_cases = [name for name in cases if name.startswith("flow_") and ("wall" in name or "corner" in name)]
    if "flow_slope_wall_earned_-3.30" not in wall_cases:
        failures.append("missing input-earned wall landing")
    for name in wall_cases:
        for row in cases[name]:
            if any(c["body"] in ["wall", "sidewall"] and c["v_dot_normal"] < -0.01 for c in row["contacts"]):
                failures.append(f"{name}:{row['tick']}: velocity restored into active wall")

    for kind in ["crest", "seam", "stair", "slope_change"]:
        for suffix in ["seed", "fast_seed"]:
            name = f"flow_{kind}_{suffix}"
            if name not in cases:
                failures.append(f"missing continuous support case: {name}")
                continue
            supported = False
            for row in cases[name]:
                if row["grounded"]:
                    supported = True
                elif supported:
                    failures.append(f"{name}:{row['tick']}: unrequested launch from continuous support")
                    break
    for name in ["earned_air_none", "earned_air_a_static", "earned_air_d_static", "earned_air_d", "earned_air_w"]:
        if name not in cases or abs(cases[name][-1]["carve"]) > 0.0001:
            failures.append(f"{name}: ineligible input earns carve")

    result = {"method": "root analysis of post-physics characterization traces", "passed": not failures,
              "episodes": len(cases), "carve_by_delivery": cadence, "wall_cases": wall_cases,
              "failures": failures}
    print(json.dumps(result, indent=2))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
