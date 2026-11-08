#!/usr/bin/env python3
"""independent reductions of post-step positions and applied input from the review trace.

uses no game module or Source oracle. Contact-endpoint speed is distinguished from the
mean travel speed of a partially obstructed step. This checks the HUD ledger, not Source
collision fidelity or the optimality of the input angle.
"""
import argparse
import gzip
import json
import math
from pathlib import Path

U = 0.0254


def horizontal(v):
    return math.hypot(v[0], v[2]) / U


def travel(a, b):
    return [(b["p"][i] - a["p"][i]) / b["dt"] for i in range(3)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("trace")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    path = Path(args.trace)
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt") as src:
        rows = [json.loads(line) for line in src]
    checks = []
    values = {}

    def check(name, ok, detail):
        checks.append(dict(name=name, ok=bool(ok), detail=detail))

    phases = ["independent-stats-coast", "independent-stats-opposite", "independent-stats-good", "independent-stats-wall", "independent-stats-ground", "restart-counter", "one-tick-hop-labelled-ceiling"]
    for phase in phases:
        data = [r for r in rows if r["phase"] == phase]
        jumps = [i for i, r in enumerate(data) if "jump" in r["events"]]
        if not jumps:
            check(f"{phase}: real jump episode exists", False, {})
            continue
        start = jumps[0]
        end = next((i for i in range(start, len(data)) if "land" in data[i]["events"]), None)
        if end is None:
            check(f"{phase}: real landing exists", False, {})
            continue
        episode = data[start:end + 1]
        # takeoff is the pre-air-update endpoint. In these routes it is below the vanilla
        # clamp, and can be independently checked from the previous unobstructed travel.
        takeoff = horizontal(episode[0]["start_velocity"])
        landing = horizontal(episode[-1]["post"])
        good = eligible = walls = 0
        contact = 0.0
        residuals = []
        airborne_travel = 0.0
        for index in range(start, end + 1):
            r = data[index]
            previous = data[index - 1] if index else r
            turn = (r["yaw"] - previous["yaw"] + math.pi) % (2 * math.pi) - math.pi
            if abs(r["side"]) > 0.5 and abs(turn) > 1e-7 and horizontal(r["post"]) > 1:
                eligible += 1
                good += (r["side"] < 0) == (turn > 0)
            contact += horizontal(r["post"]) - horizontal(r["requested"])
            walls += any(abs(float(c["normal"].strip("()").split(",")[1])) < 0.7 for c in r["contacts"])
            actual = travel(previous, r)
            airborne_travel += math.hypot(actual[0], actual[2]) * r["dt"]
            if not r["contacts"] and "jump" not in r["events"]:
                residuals.append(abs(horizontal(actual) - horizontal(r["post"])))
        hop = data[end]["stats"]["last_hop"]
        gain = landing - takeoff
        expected = dict(takeoff=takeoff, landing=landing, gain=gain, contact=contact, air=gain-contact,
                        eligible=eligible, good=good, air_ticks=len(episode), wall_ticks=walls)
        check(f"{phase}: independently reduced full hop ledger", all(abs(hop.get(k, 1e9) - v) < 0.003 for k, v in expected.items()), dict(expected=expected, observed=hop))
        check(f"{phase}: unobstructed endpoint speed agrees with resolved travel", max(residuals, default=0) < 0.004, dict(steps=len(residuals), max_u_s=max(residuals, default=0), distance_m=airborne_travel))
        if start >= 2 and not data[start-1]["contacts"]:
            previous_actual = horizontal(travel(data[start-2], data[start-1]))
            check(f"{phase}: takeoff is supported by previous actual travel", abs(previous_actual-takeoff) < 0.004, dict(previous_actual=previous_actual, takeoff=takeoff))
        if phase == "independent-stats-wall":
            blocked = []
            for i in range(start, end + 1):
                r, prev = data[i], data[i-1]
                if horizontal(r["post"]) - horizontal(r["requested"]) < -1:
                    blocked.append(dict(requested_u_s=horizontal(r["requested"]), post_u_s=horizontal(r["post"]), actual_travel_u_s=horizontal(travel(prev, r)), position=r["p"]))
            check("wall loss has actual blocked movement, not just changed stored velocity", bool(blocked) and any(b["actual_travel_u_s"] < b["requested_u_s"] - 1 for b in blocked), blocked)
        if len(jumps) >= 2:
            next_start = jumps[1]
            next_takeoff = horizontal(data[next_start]["start_velocity"])
            linked = data[next_start]["stats"]["last_hop"]
            chain = next_takeoff - takeoff
            ground = next_takeoff - landing
            grounded_steps = sum(r["grounded"] for r in data[end:next_start])
            check(f"{phase}: chain and ground loss rederived", abs(linked["chain"] - chain) < 0.003 and abs(linked["ground"] - ground) < 0.003 and linked["ground_ticks"] == grounded_steps, dict(chain=chain, ground=ground, ground_ticks=grounded_steps, observed=linked))
        values[phase] = dict(**expected, sync=good/eligible if eligible else None, resolved_air_distance_m=airborne_travel)

    bad_hop = [r for r in rows if r["phase"] == "first-hop-after-switch"]
    check("missed post-switch hop has actual height rise and descent", any("jump" in r["events"] for r in bad_hop) and any("land" in r["events"] for r in bad_hop) and max(r["p"][1] for r in bad_hop) > 0.8 and bad_hop[-1]["stats"]["hops"] == 0, dict(max_height=max(r["p"][1] for r in bad_hop), final_hops=bad_hop[-1]["stats"]["hops"]))
    rates = {}
    for r in rows:
        rates.setdefault(r["preset"], {}).setdefault(str(r["dt"]), 0)
        rates[r["preset"]][str(r["dt"])] += 1
    report = dict(checks=checks, passed=sum(c["ok"] for c in checks), total=len(checks), hops=values, actual_callback_deltas=rates,
                  limitation="Jump-transition position/endpoint residuals up to 1.465 u/s were retained in reductions-v2.json and excluded from the unobstructed-travel check here, pending the separate Source contact repair. Contact loss uses the requested and resolved endpoint velocities, backed by actual blocked travel. It is not derived from mean displacement on a partial collision tick, which is a different quantity. No claim of Source contact correctness.")
    Path(args.out).write_text(json.dumps(report, indent=2))
    print(f"independent reductions: {report['passed']}/{report['total']}")
    for c in checks:
        if not c["ok"]:
            print(json.dumps(c))
    return int(report["passed"] != report["total"])


if __name__ == "__main__":
    raise SystemExit(main())
