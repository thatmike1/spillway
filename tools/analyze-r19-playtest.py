#!/usr/bin/env python3
"""summarise copied playtests with the project's strict recording reader, without editing inputs."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import importlib.util
import json
import math
from pathlib import Path


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stopped_spans(rec, reader) -> list[dict]:
    """low actual travel while the course clock runs; input is evidence, not an intent claim."""
    c = rec.columns
    table = reader.held_names(rec.events)
    breaks = {d["index"] for d in reader.discontinuities(c, rec.events)
              if d["kind"] in {"respawn", "lifecycle", "unexplained"}}
    spans = []
    begin = None
    n = len(c["tick"])
    for i in range(n + 1):
        low = (i < n and bool(c["flags"][i] & 1) and not bool(c["flags"][i] & 2)
               and math.hypot(c["actual_v_x"][i], c["actual_v_z"][i]) / reader.U < 25
               and i not in breaks)
        if low and begin is None:
            begin = i
        if begin is not None and not low:
            seconds = sum(c["dt"][begin:i])
            if seconds >= 0.5:
                movement = 0
                for j in range(begin, i):
                    held = reader.names_for(c["held"][j], c["tick"][j], table)
                    movement += any(k in held for k in ("move_forward", "move_back", "move_left", "move_right"))
                spans.append({"from_tick": c["tick"][begin], "to_tick": c["tick"][i - 1],
                              "elapsed_from": c["elapsed"][begin], "seconds": round(seconds, 4),
                              "at_m": [round(c[f"reference_p_{a}"][begin], 3) for a in "xyz"],
                              "movement_held_fraction": round(movement / (i - begin), 3),
                              "checkpoint": c["checkpoint"][begin]})
            begin = None
    return spans


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recordings", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    source = Path(__file__).with_name("analyze-r16-runs.py")
    spec = importlib.util.spec_from_file_location("spillway_run_reader", source)
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    files = sorted(args.recordings.glob("*.r16run"))
    if not files:
        raise SystemExit("no sealed recordings found")
    before = {p.name: sha(p) for p in files}
    runs = []
    grouped = {}
    for path in files:
        rec = reader.read(path)
        if not rec.ok:
            raise SystemExit(f"invalid recording {path.name}: {rec.errors}")
        run = reader.analyse(rec, 0.75)
        run["sha256"] = before[path.name]
        run["stopped_spans"] = stopped_spans(rec, reader)
        run["motion_events"] = dict(Counter(name for event in rec.events if event.get("k") == "motion"
                                           for name in (event.get("d") or {}).get("events", [])))
        runs.append(run)
        grouped.setdefault(run["map"], []).append(run)
    after = {p.name: sha(p) for p in files}
    if before != after:
        raise SystemExit("input files changed during analysis")
    maps = {}
    for name, rows in grouped.items():
        style = {}
        for row in rows:
            for kind, values in row["style"]["by_kind"].items():
                entry = style.setdefault(kind, {"count": 0, "points": 0})
                entry["count"] += values["count"]
                entry["points"] += values["points"]
        finished = [r for r in rows if (r.get("outcome") or {}).get("kind") == "finish"]
        maps[name] = {"runs": len(rows), "presets": dict(Counter(r["preset"] for r in rows)),
                      "ended_by": dict(Counter(r["ended_by"] for r in rows)),
                      "recorded_seconds": round(sum(r["sim_seconds"] for r in rows), 3),
                      "falls": sum(r["falls"] for r in rows), "style": style,
                      "finished": [{"file": r["name"], "seconds": r["outcome"].get("time", r["final_elapsed"]),
                                    "score": r["outcome"].get("style", {}).get("score"),
                                    "preset": r["preset"], "clean": r["outcome"].get("clean"),
                                    "checkpoints": len(r["checkpoints"]) - 1} for r in finished],
                      "stopped_spans": [{"file": r["name"], "preset": r["preset"], **span}
                                        for r in rows for span in r["stopped_spans"]],
                      "motion_events": dict(sum((Counter(r["motion_events"]) for r in rows), Counter()))}
    report = {"reader": str(source), "reader_sha256": sha(source), "analysis_sha256": sha(Path(__file__)),
              "recordings": str(args.recordings.resolve()), "input_hashes_unchanged": before == after,
              "files": len(files), "presets": dict(Counter(r["preset"] for r in runs)), "maps": maps, "runs": runs,
              "method": "strict R16 hash-chain reader; actual_v speed; <25 u/s spans >=0.5 s while started and unfinished; no causation inferred from slow spans"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=1, allow_nan=False) + "\n")
    print(json.dumps({"files": len(files), "presets": report["presets"], "unchanged": before == after,
                      "maps": {k: {a: v[a] for a in ("runs", "ended_by", "recorded_seconds", "falls")} for k, v in maps.items()}}, indent=2))


if __name__ == "__main__":
    main()
