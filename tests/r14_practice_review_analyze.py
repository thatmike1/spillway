#!/usr/bin/env python3
"""summarize review evidence without treating a missed raw cast as a player fall."""
import argparse
from collections import Counter
import gzip
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text())


def rows(path):
    with gzip.open(path, "rt") as stream:
        return [json.loads(line) for line in stream]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    report = {"routes": {}}
    for path in sorted(out.glob("*/summary.json")):
        data = read(path)
        if "information_access" in data:
            report["routes"][path.parent.name] = {key: data[key] for key in ["reason", "route", "seed", "noise_deg_bounded", "feedback_hz", "bank_deg", "physics_hz", "finished", "elapsed", "respawns", "stages", "min_y", "max_speed_ups", "sinks", "edge_observation"] if key in data}
    control = read(out / "raw-control/cast_probe.json")
    report["raw_control"] = {"misses": sum(control["total_misses"].values()), "casts": sum(r["samples"] for r in control["rows"]) * len(control["motions_u_per_tick"]), "runway_misses": sum(sum(r["misses"].values()) for r in control["rows"] if r["piece"].startswith("s3_runway_"))}
    diagnostic = out / "all-cast-production-validated"
    data = read(diagnostic / "summary.json")
    valid = [e for e in data["episodes"] if not e["setup"]["setup_overlaps"]]
    invalid = [e for e in data["episodes"] if e["setup"]["setup_overlaps"]]
    report["seeded_production"] = {"selected": len(data["episodes"]), "clear_setups": len(valid), "invalid_setups": invalid, "rates": {}}
    counts = Counter()
    resolved = 0
    for episode in valid:
        trace = rows(diagnostic / (episode["name"] + ".jsonl.gz"))
        first_top = trace[0]["top"]
        counts[sum(r["top"] is not None and r["p"][1] < r["top"] - .005 for r in trace)] += 1
        resolved += int(trace[1]["p"][1] >= first_top - .005)
    report["seeded_production"]["penetrating_tick_counts"] = dict(counts)
    report["seeded_production"]["recovered_height_next_tick"] = resolved
    for hz in [64, 128]:
        group = [e for e in valid if e["setup"]["hz"] == hz]
        report["seeded_production"]["rates"][hz] = {"cases": len(group), "max_sink_m": max(e["peak_sink_m"] for e in group)}
    for name in ["earned-floor", "local-input", "valve-curved-return", "tail-validated", "weir-validated"]:
        folder = out / name
        data = read(folder / "summary.json")
        episodes = data["episodes"]
        lands = wall_ticks = observed = 0
        max_rate_error = max_speed = 0.0
        for episode in episodes:
            for row in rows(folder / (episode["name"] + ".jsonl.gz")):
                lands += int("land" in row["e"])
                wall_ticks += int(any(abs(c["normal"][1]) < .7 for c in row["contacts"]))
                max_speed = max(max_speed, (row["v"][0]**2 + row["v"][2]**2)**.5)
                # fd was written from the callback's actual delta. recover it for older traces.
                difference = [row["p"][i] - row["before"][i] for i in range(3)]
                axis = max(range(3), key=lambda i: abs(difference[i]))
                if abs(difference[axis]) > .00001 and abs(row["fd"][axis]) > .00001:
                    actual = difference[axis] / (row["fd"][axis] * .0254)
                    max_rate_error = max(max_rate_error, abs(actual - 1 / episode["setup"]["hz"]))
                    observed += 1
        report[name] = {"episodes": len(episodes), "land_events": lands, "wall_ticks": wall_ticks, "max_speed_ups": max_speed, "max_sink_m": max(e["peak_sink_m"] for e in episodes), "full_goal_completions": sum(e["goals_reached"] == len(e["setup"].get("goals", [])) for e in episodes if "goals" in e["setup"]), "clear_setups": sum(not e["setup"]["setup_overlaps"] for e in episodes) if all("setup_overlaps" in e["setup"] for e in episodes) else None, "rate_observations": observed, "max_recovered_delta_error_s": max_rate_error}
    for name in ["native-tail-edge", "native-product-edge"]:
        report[name] = read(out / name / "native.json")
    (out / "review-results.json").write_text(json.dumps(report, indent=2))
    print(json.dumps({k: v for k, v in report.items() if k not in ["routes", "native-tail-edge", "native-product-edge"]}, indent=2))


if __name__ == "__main__":
    main()
