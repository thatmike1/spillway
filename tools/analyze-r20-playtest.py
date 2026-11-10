#!/usr/bin/env python3
"""analyse the fresh R19 cohort for R20, strictly and without changing copied user data.

imports the R16 reader and R19 stop detector. source rules are read from the specified git
baseline, so concurrent gameplay edits cannot change the interpretation of these recordings.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True

BASELINE = "065f7b27993df7ae2511eb34eb665d271dded13c"
EXPECTED = {"saltglass": 34, "tether-yard": 12, "line-drive": 8, "fall-line": 3, "breakwater": 1}
FOCUS_TICKS = {
    "074540_173_ea236da7": [262, 263, 342, 343, 344, 832, 928, 1325, 1434],
    "074742_806_055589f5": [306, 307, 1429],
    "074629_597_7937ff0e": [883, 1270, 1300, 1350, 1400, 1430, 1450, 1472, 1519,
                              2438, 2780, 2820, 2860, 2911, 3055, 4443],
    "074838_850_0fefc868": [1000, 1100, 1150, 1200, 1250, 1300, 1356],
    "075436_677_21937788": [1284, 1400, 1472, 1473, 2107, 2114],
    "075602_219_816651dc": [303, 304, 686, 687, 688],
    "080852_170_834c65b7": [396, 397, 652, 653, 654, 655, 670, 690, 720, 750, 794],
}
SOURCE_NAMES = ["r16_style.gd", "r15_experiment_player.gd", "r19_tether_player.gd",
                "r19_tether_level.gd", "r19_surf_level.gd", "r19_line_drive_player.gd",
                "r19_line_drive_level.gd", "r19_fall_line_level.gd", "r16_run_recorder.gd",
                "r16_run_session.gd", "r16_main.gd"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(directory):
    return {str(p.relative_to(directory)): {"bytes": p.stat().st_size, "sha256": digest(p)}
            for p in sorted(directory.rglob("*")) if p.is_file()}


def module(name):
    path = Path(__file__).with_name(name)
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def partition(fresh, old):
    """hash membership, never filename/date guessing, defines the inherited cohort."""
    old_by_sha = defaultdict(list)
    for name, row in old.items():
        if name.endswith(".r16run"):
            old_by_sha[row["sha256"]].append(name)
    inherited = {name: old_by_sha[row["sha256"]] for name, row in fresh.items()
                 if name.endswith(".r16run") and row["sha256"] in old_by_sha}
    selected = [name for name in fresh if name.endswith(".r16run") and name not in inherited]
    return selected, inherited


def point(c, i):
    return [c[f"reference_p_{a}"][i] for a in "xyz"]


def sample(rec, i, reader):
    c = rec.columns
    i = max(0, min(i, len(c["tick"]) - 1))
    return {"tick": c["tick"][i], "elapsed": c["elapsed"][i], "p_m": point(c, i),
            "v_ms": [c[f"v_{a}"][i] for a in "xyz"],
            "actual_v_ms": [c[f"actual_v_{a}"][i] for a in "xyz"],
            "speed_u": math.hypot(c["actual_v_x"][i], c["actual_v_z"][i]) / reader.U,
            "yaw_rad": c["yaw"][i], "grounded": bool(c["flags"][i] & 8),
            "checkpoint": c["checkpoint"][i],
            "held": reader.names_for(c["held"][i], c["tick"][i], reader.held_names(rec.events))}


def spans(rec, predicate, reader):
    c = rec.columns
    result, begin = [], None
    for i in range(len(c["tick"]) + 1):
        inside = i < len(c["tick"]) and predicate(i)
        if inside and begin is None:
            begin = i
        if begin is not None and not inside:
            result.append({"first": sample(rec, begin, reader), "last": sample(rec, i - 1, reader),
                           "seconds": sum(c["dt"][begin:i]), "samples": i - begin})
            begin = None
    return result


def direction(rec, reader, rules):
    """reconstruct only the recorded-input part of the baseline direction detector.

    float32 samples cannot expose hidden contact/continuity state. validate predictions against
    every actual award; disagreement is evidence of a reconstruction limit, never a game bug.
    """
    c = rec.columns
    by_tick = defaultdict(list)
    for e in rec.events:
        by_tick[e["t"]].append(e)
    breaks = {d["index"] for d in reader.discontinuities(c, rec.events)
              if d["kind"] in {"respawn", "lifecycle", "unexplained"}}
    chain, chain_kind, ground_s, flight, heading = 0, "", 0.0, None, None
    spots, timeline, predictions = [], [], []
    counts = Counter()
    sealed = False
    for i, tick in enumerate(c["tick"]):
        if sealed:
            break
        events = by_tick[tick]
        motion = [n for e in events if e["k"] == "motion" for n in e["d"].get("events", [])]
        vx, vz = c["actual_v_x"][i], c["actual_v_z"][i]
        speed = math.hypot(vx, vz) / reader.U
        yaw = c["yaw"][i]
        dot = (vx * -math.sin(yaw) + vz * -math.cos(yaw)) / (speed * reader.U) if speed else 0
        kind = ("backward_bhop" if dot <= rules["back_dot"] else
                "sideways_bhop" if abs(dot) < rules["side_dot"] else "") if speed >= rules["min_ups"] else ""
        grounded = bool(c["flags"][i] & 8)
        was_grounded = i > 0 and bool(c["flags"][i - 1] & 8)
        reason = ""
        if i in breaks or any(e["k"] == "settings" and e["d"].get("key") in
                              {"source_sensitivity", "source_fov", "r13_sensitivity", "r13_fov"} for e in events):
            reason = "discontinuity"
        elif not c["flags"][i] & 1:
            reason = "inactive"
        elif i == 0:
            reason = "no_previous_sample"
        elif not kind:
            reason = "speed_below_300" if speed < rules["min_ups"] else "facing_outside_direction_bands"
        elif chain_kind and kind != chain_kind:
            reason = "direction_kind_change"
        elif grounded and was_grounded:
            ground_s += c["dt"][i]
            if ground_s > rules["max_ground_s"]:
                reason = "ground_time_over_limit"
            else:
                continue
        else:
            at = point(c, i)
            if was_grounded and not grounded:
                if "jump" not in motion:
                    reason = "departure_without_jump_event"
                else:
                    chain_kind = kind
                    ground_s = 0.0
                    flight = {"from": point(c, i - 1), "from_tick": c["tick"][i - 1],
                              "peak_y": point(c, i - 1)[1], "track_m": 0.0, "air_s": 0.0}
            if not reason and flight is not None:
                flight["air_s"] += c["dt"][i]
                flight["track_m"] += speed * reader.U * c["dt"][i]
                flight["peak_y"] = max(flight["peak_y"], at[1])
                if flight["air_s"] > rules["max_air_s"]:
                    reason = "air_time_over_limit"
                elif grounded:
                    dx, dz = at[0] - flight["from"][0], at[2] - flight["from"][2]
                    progress = math.hypot(dx, dz)
                    next_heading = [dx / progress, dz / progress] if progress else [0, 0]
                    nearest = min((math.hypot(at[0] - p[0], at[2] - p[2]) for p in spots), default=None)
                    checks = {"air_time": flight["air_s"] >= rules["min_air_s"],
                              "track": flight["track_m"] >= rules["min_track_m"],
                              "rise": flight["peak_y"] - flight["from"][1] >= rules["min_rise_m"],
                              "fall": flight["peak_y"] - at[1] >= rules["min_fall_m"],
                              "efficiency": progress >= flight["track_m"] * rules["min_efficiency"],
                              "heading": heading is None or sum(a*b for a,b in zip(heading, next_heading)) >= rules["heading_dot"],
                              "fresh_landing": nearest is None or nearest >= rules["spacing_m"]}
                    valid = all(checks.values())
                    if valid:
                        spots.append(at)
                        heading = next_heading
                        chain += 1
                        ground_s = 0.0
                    row = {"event": "landing", "sample": sample(rec, i, reader), "kind": kind,
                           "checks": checks, "valid": valid, "chain": chain if valid else 0,
                           "flight": dict(flight), "progress_m": progress, "nearest_prior_landing_m": nearest,
                           "rise_m": flight["peak_y"] - flight["from"][1], "fall_m": flight["peak_y"] - at[1]}
                    timeline.append(row)
                    counts["valid_landing" if valid else "invalid_landing"] += 1
                    if valid and chain >= 2:
                        predictions.append({"tick": tick, "kind": kind, "hops": chain})
                    flight = None
                    if not valid:
                        reason = "landing_failed:" + ",".join(k for k,v in checks.items() if not v)
        if reason:
            if chain or flight:
                counts[reason] += 1
                timeline.append({"event": "break", "reason": reason, "chain_before": chain,
                                 "kind_before": chain_kind, "sample": sample(rec, i, reader),
                                 "dot": dot, "flight": flight})
            chain, chain_kind, ground_s, flight, heading = 0, "", 0.0, None, None
        sealed = bool(c["flags"][i] & 2)
    actual = [e["d"] for e in rec.events if e["k"] == "style" and e["d"].get("kind") in
              {"backward_bhop", "sideways_bhop"}]
    actual_keys = [(e["tick"], e["kind"], e["m"]["hops"]) for e in actual]
    predicted_keys = [(e["tick"], e["kind"], e["hops"]) for e in predictions]
    return {"counts": dict(counts), "timeline": timeline, "predictions": predictions,
            "actual_awards": actual, "matches_actual_award_ticks_kinds_hops": predicted_keys == actual_keys,
            "limits": "observational reconstruction from float32 actual_v/reference_p, flags, yaw and motion names; not engine replay or hidden collision state"}


def salt(rec, reader):
    c = rec.columns
    result = {"entry_plane_crossings": [], "spatial_recovery_spans": {}}
    for i in range(1, len(c["tick"])):
        x,y,z = point(c,i)
        px,py,pz = point(c,i-1)
        fin = "west" if pz >= 0 > z and -1 <= x <= 13 else "east" if pz <= -84 < z and 47 <= x <= 61 else None
        if fin:
            result["entry_plane_crossings"].append({"fin": fin, "before": sample(rec,i-1,reader),
                                                      "after": sample(rec,i,reader), "crest_y_m": 18,
                                                      "note": "entry plane crossing, not first proven surf contact"})
    for fin in ["west", "east"]:
        def inside(i):
            x,y,z = point(c,i)
            if fin == "east":
                x,z = 60-x,-84-z
            return bool(c["flags"][i] & 8) and -12.5 <= x <= -1.5 and -84.5 <= z <= -55.5 and -4.1 <= y <= 7.5
        result["spatial_recovery_spans"][fin] = spans(rec,inside,reader)
    result["contact_limit"] = "spatial/grounded overlap only; recorder omits contact body and normal; cannot prove which surface supported or blocked the hull"
    return result


def tether(rec, reader):
    c = rec.columns
    index = {t:i for i,t in enumerate(c["tick"])}
    attaches, releases, misses, active = [], [], [], None
    for e in rec.events:
        if e["k"] != "motion" or e["t"] not in index:
            continue
        i=index[e["t"]]
        for name in e["d"].get("events",[]):
            if name == "grapple":
                active={"attach":sample(rec,i,reader)}
                attaches.append(active)
            elif name == "grapple_release":
                held=sample(rec,i,reader)["held"]
                release={"before":sample(rec,i-1,reader), "at":sample(rec,i,reader),
                         "after":sample(rec,i+1,reader), "held_at_release":"r15_grapple" in held,
                         "recorded_reason":None}
                if active:
                    release["ticks_since_attach"]=e["t"]-active["attach"]["tick"]
                    active["release"]=release
                releases.append(release)
                active=None
            elif name == "grapple_miss":
                misses.append(sample(rec,i,reader))
    return {"attaches":attaches,"releases":releases,"misses":misses,
            "unknown":"anchor, rope length, tension, pull impulse, release reason, target and line-of-sight are absent from recorder payload; hold does not prove pull"}


def experiments(rec, reader, map_id):
    c=rec.columns
    result={}
    if map_id == "line-drive":
        result["pad_grounded_spans"]={}
        pads=[("LaunchWest",-6,6,-44,-32,6,0,-1), ("LaunchEast",40,56,-66,-54,7,1,0),
              ("LaunchHome",72,86,-24,-8,8,0,1)]
        for name,x0,x1,z0,z1,y,dx,dz in pads:
            def on(i):
                x,py,z=point(c,i)
                return bool(c["flags"][i]&8) and x0<=x<=x1 and z0<=z<=z1 and abs(py-y)<=.15
            result["pad_grounded_spans"][name]=spans(rec,on,reader)
            for row in result["pad_grounded_spans"][name]:
                for edge in ["first", "last"]:
                    v = row[edge]["v_ms"]
                    speed = math.hypot(v[0], v[2])
                    row[edge]["pad_alignment_stored_v"] = (v[0]*dx + v[2]*dz)/speed if speed else None
        result["upward_departures_over_350u"]=[{"before":sample(rec,i-1,reader),"after":sample(rec,i,reader)}
            for i in range(1,len(c["tick"])) if c["flags"][i-1]&8 and not c["flags"][i]&8 and c["v_y"][i]/reader.U>350]
        result["unknown"]="line_drive.used/last_launch/support/impulse are not serialized; high upward departures are launch candidates, not direct launch-event proof"
    elif map_id == "fall-line":
        result["deck_grounded_spans"]={}
        for n in range(10):
            if n in [3,6,9]:continue
            ztop=-3-13*n;y=8-.35*(n+1);x=[-1.5,1.5,0][n%3];half=[3,4,5][n%3]
            def on(i):
                px,py,pz=point(c,i)
                return bool(c["flags"][i]&8) and x-half-.41<=px<=x+half+.41 and ztop-10-.41<=pz<=ztop+.41 and abs(py-y)<.08
            result["deck_grounded_spans"][f"fall_{n}"]=spans(rec,on,reader)
        result["unknown"]="grounded feet near authored deck top, not collider identity; support/drop transitions, collision layer, timer state and sound/visual output are not serialized"
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recordings",type=Path)
    parser.add_argument("--exclude",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--manifest",type=Path,required=True)
    parser.add_argument("--baseline",default=BASELINE)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    userdir=args.recordings.resolve().parent
    args.recordings=args.recordings.resolve();args.exclude=args.exclude.resolve()
    for output in [args.output.resolve(),args.manifest.resolve()]:
        if output.is_relative_to(userdir) or output.is_relative_to(args.exclude):
            raise SystemExit("output must be outside both input trees")
    if shutil.disk_usage(Path.home()).free<15_000_000_000:
        raise SystemExit("HOME free bytes below 15,000,000,000; parent owns cleanup")
    before=inventory(userdir);old_before=inventory(args.exclude)
    input_runs={str(Path(n).relative_to(args.recordings.name)):v for n,v in before.items()
                if n.startswith(args.recordings.name + "/")}
    selected,inherited=partition(input_runs,old_before)
    if (len(input_runs)!=90 or len(selected)!=58 or len(inherited)!=32
            or sum(n.endswith(".r16run") for n in old_before)!=32
            or len({input_runs[n]["sha256"] for n in selected})!=58):
        raise SystemExit("unexpected cohort; expected 90 sealed unique inputs, 32 inherited, 58 fresh")
    reader=module("analyze-r16-runs.py");prior=module("analyze-r19-playtest.py")
    sources={}
    for name in SOURCE_NAMES:
        path="projects/foldrunner/scripts/"+name
        raw=subprocess.check_output(["git","show",f"{args.baseline}:{path}"],cwd=root)
        sources[path]={"sha256":hashlib.sha256(raw).hexdigest(),"source":raw.decode()}
    style=sources["projects/foldrunner/scripts/r16_style.gd"]["source"]
    direction_text=re.search(r'"direction":\s*\{([^}]+)\}',style).group(1)
    rules={k:float(v) for k,v in re.findall(r'"([a-z_]+)":\s*(-?\d+(?:\.\d+)?)',direction_text)}
    runs=[]
    strict_counts=Counter()
    for name in sorted(input_runs):
        rec=reader.read(args.recordings/name)
        if not rec.ok:raise SystemExit(f"strict read failed: {name}: {rec.errors}")
        strict_counts["inherited" if name in inherited else "fresh"]+=1
        if name in inherited:continue
        run=reader.analyse(rec,.75)
        run["sha256"]=input_runs[name]["sha256"]
        run["metadata"]=rec.header.get("metadata",{})
        run["stopped_spans"]=prior.stopped_spans(rec,reader)
        run["motion_events"]=dict(Counter(n for e in rec.events if e["k"]=="motion" for n in e["d"].get("events",[])))
        run["checkpoint_events"]=[e for e in rec.events if e["k"]=="checkpoint"]
        run["checkpoint_samples"]=[sample(rec,rec.columns["tick"].index(e["t"]),reader) for e in run["checkpoint_events"]]
        run["last_sample"]=sample(rec,len(rec.columns["tick"])-1,reader)
        run["focus_samples"] = [sample(rec, rec.columns["tick"].index(t), reader)
            for suffix, ticks in FOCUS_TICKS.items() if suffix in name
            for t in ticks if t in rec.columns["tick"]]
        run["direction"]=direction(rec,reader,rules)
        if run["map"]=="saltglass":run["saltglass"]=salt(rec,reader)
        if run["map"]=="tether-yard":run["tether"]=tether(rec,reader)
        if run["map"] in ["line-drive","fall-line"]:run["experiment"]=experiments(rec,reader,run["map"])
        runs.append(run)
    counts=dict(Counter(r["map"] for r in runs));presets=dict(Counter(r["preset"] for r in runs))
    if counts!=EXPECTED or presets!={"server128":58} or any(r["physics_hz"]!=[128] for r in runs):
        raise SystemExit(f"unexpected maps/presets/rates: {counts}, {presets}")
    maps={}
    for map_id in EXPECTED:
        rows=[r for r in runs if r["map"]==map_id]
        awards=defaultdict(lambda:{"count":0,"points":0})
        for r in rows:
            for k,v in r["style"]["by_kind"].items():
                for field in ["count","points"]:awards[k][field]+=v[field]
        maps[map_id]={"attempts":len(rows),"recorded_seconds":round(sum(r["sim_seconds"] for r in rows),3),
                      "ended_by":dict(Counter(r["ended_by"] for r in rows)),"falls":sum(r["falls"] for r in rows),
                      "stalls":sum(len(r["stopped_spans"]) for r in rows),
                      "stall_seconds":sum(s["seconds"] for r in rows for s in r["stopped_spans"]),
                      "style":dict(awards),"finishes":[{"name":r["name"],"outcome":r["outcome"],
                          "checkpoint_events":r["checkpoint_events"],"finish_tick":r["finish_tick"]}
                         for r in rows if r["ended_by"]=="finish"]}
    if shutil.disk_usage(Path.home()).free < 15_000_000_000:
        raise SystemExit("HOME free bytes fell below 15,000,000,000; parent owns cleanup")
    after=inventory(userdir);old_after=inventory(args.exclude)
    if before!=after or old_before!=old_after:raise SystemExit("input trees changed during analysis")
    helpers={p.name:digest(p) for p in [Path(__file__),Path(reader.__file__),Path(prior.__file__)]}
    mismatches = [r["name"] for r in runs if not r["direction"]["matches_actual_award_ticks_kinds_hops"]]
    if mismatches:
        raise SystemExit(f"direction reconstruction disagrees with recorded awards: {mismatches}")
    report={"scope":{"sealed_inventory":90,"inherited":32,"fresh":58,"strict_reads":dict(strict_counts),
                     "expected_maps":EXPECTED,"actual_maps":counts,"presets":presets},
            "baseline":args.baseline,"source_rules":sources,"helper_sha256":helpers,
            "direction_rules":rules,"maps":maps,"runs":runs,
            "method":{"loss_threshold_ms":.75,"loss_limit_per_run":12,"stalls":"actual horizontal <25u/s for >=0.5s while started/unfinished, split at discontinuities",
                      "line":"inherited quarter-second reference-feet trace; full ticks retained in sealed inputs",
                      "direction":"source-rule reconstruction validated against recorded awards; no engine replay",
                      "contact":"not serialized; geometric overlap is inference only"},
            "direction_validation":{"matching_runs":sum(r["direction"]["matches_actual_award_ticks_kinds_hops"] for r in runs),
                                    "total_runs":58},
            "input_hashes_unchanged":True}
    manifest={"recordings":str(args.recordings),"userdata":str(userdir),"exclude":str(args.exclude),
              "before":before,"after":after,"exclude_before":old_before,"exclude_after":old_after,
              "inherited_sha256_matches":inherited,"fresh_names":selected,"helper_sha256":helpers,
              "baseline":args.baseline,"unchanged":True,
              "home_free_bytes_after":shutil.disk_usage(Path.home()).free,
              "source_sha256":{k:v["sha256"] for k,v in sources.items()}}
    for path,data in [(args.output,report),(args.manifest,manifest)]:
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,indent=1,allow_nan=False)+"\n")
    print(json.dumps({"scope":report["scope"],"direction_validation":report["direction_validation"],
                      "unchanged":True,"maps":{k:{f:v[f] for f in ["attempts","recorded_seconds","ended_by","falls","stalls"]} for k,v in maps.items()}},indent=2))


if __name__=="__main__":
    main()
