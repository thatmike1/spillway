#!/usr/bin/env python3
"""independent component counterexamples; a finding exits 1, never release approval.

--feature-run must be a quiescent copied feature folder, never an active candidate.
the runner freezes tools, copies receipts, uses an isolated headless project, and removes
only its own TemporaryDirectory. no native display, export, production edit or git write.
"""
from __future__ import annotations

import argparse
import copy
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")


def rewrite(data, analyzer, edit):
    at = 16 + struct.unpack_from("<I", data, 12)[0]
    out = bytearray(data[:at])
    chain = hashlib.sha256(out).digest()
    out.extend(chain)
    at += 32
    while at < len(data):
        head = list(struct.unpack_from("<4sBBHIIIII", data, at))
        stored = data[at + 60:at + 60 + head[6]]
        raw = zlib.decompress(stored) if head[2] == 1 else stored
        raw = edit(head[1], head[4], raw)
        stored = zlib.compress(raw)
        head[2], head[5], head[6] = 1, len(raw), len(stored)
        packed = struct.pack("<4sBBHIIIII", *head)
        chain = hashlib.sha256(chain + packed + stored).digest()
        out.extend(packed + chain + stored)
        at += 60 + struct.unpack_from("<I", data, at + 16)[0]
    return bytes(out)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--feature-run", required=True, type=Path)
    p.add_argument("--clean-record", required=True, type=Path)
    p.add_argument("--helper-commit", default="a26d94c0", help="exact committed helpers under review")
    a = p.parse_args()
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    checks = []
    commands = []

    def check(name, ok, detail=None, category="control", severity=None):
        checks.append(dict(name=name, ok=bool(ok), detail=detail, category=category, severity=severity))
        print(("PASS " if ok else "FAIL ") + name, flush=True)

    def command(argv, cwd, log, env=None):
        commands.append(dict(argv=list(map(str, argv)), cwd=str(cwd), log=str(log)))
        r = subprocess.run(list(map(str, argv)), cwd=cwd, env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=65, text=True)
        log.write_text(r.stdout)
        return r

    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=PROJECT).split(b"\0")
    protected = {str(PROJECT / os.fsdecode(n)): sha(PROJECT / os.fsdecode(n)) for n in tracked if n}
    old_delivery = PROJECT.parents[2] / "delivery/spillway-r15"
    if old_delivery.is_dir():
        protected.update({str(f): sha(f) for f in old_delivery.iterdir() if f.is_file()})
    write(out / "protected-before.json", protected)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip()
    frozen = out / "frozen"
    names = ["tools/package-r16.py", "tools/package-r15.py", "tools/r14_native_display.py",
             "tools/check-r16-pack.sh", "tools/r16-pack-probe.gd", "tools/momentum-tape.py",
             "tools/momentum-tape.gd", "tools/analyze-r16-runs.py", "tools/check-r16-preservation.py",
             "tools/check-r16.sh", "scripts/r16_run_reader.gd", "scripts/r16_ghost.gd",
             "tests/test_r16_delivery.py", "tests/test_r16_record_integrity.py",
             "tests/r16_record_integrity_probe.gd", "tests/r16_verifier_review.gd",
             "tests/r16_verifier_review.gd.uid", "tests/r16_verifier_review.py"]
    for name in names:
        dst = frozen / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PROJECT / name, dst)
    hashes = {n: sha(frozen / n) for n in names}
    committed = {}
    for name in names:
        r = subprocess.run(["git", "show", a.helper_commit + ":projects/foldrunner/" + name],
                           cwd=PROJECT, capture_output=True)
        if r.returncode == 0:
            committed[name] = hashlib.sha256(r.stdout).hexdigest()
    check("frozen production/helper bytes equal " + a.helper_commit, all(hashes[n] == h for n, h in committed.items()), committed)
    m = load("verifier_frozen_package", frozen / "tools/package-r16.py")
    analyzer = load("verifier_frozen_analyzer", frozen / "tools/analyze-r16-runs.py")
    check("pinned editor bytes", m.EDITOR.is_file() and sha(m.EDITOR) == m.EDITOR_SHA256)
    write(out / "provenance.json", dict(head_at_start=head, runtime_helper_commit=a.helper_commit,
          source_sha256=hashes, committed_sha256=committed, editor_sha256=sha(m.EDITOR),
          feature_receipt_sha256=sha(a.feature_run / "result.json"), clean_record_sha256=sha(a.clean_record),
          scope="source fixtures and copied receipts only; no final release approval"))
    with tempfile.TemporaryDirectory(prefix="r16-verifier-review-", dir="/tmp") as scratch_name:
        scratch = Path(scratch_name)
        source = scratch / "source"
        (source / "scripts").mkdir(parents=True)
        (source / "tools").mkdir()
        (source / "tests").mkdir()
        (source / "project.godot").write_text('[application]\nconfig/name="r16 verifier review"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in ("scripts/r16_run_reader.gd", "tools/r16-pack-probe.gd", "tests/r16_verifier_review.gd"):
            shutil.copyfile(frozen / name, source / name)
        feature = json.loads((a.feature_run / "result.json").read_text())
        profile = scratch / "profile"
        root = m.profile_root(profile)
        root.mkdir(parents=True)
        shutil.copytree(a.feature_run / "profile/data/godot/app_userdata/Spillway", root, dirs_exist_ok=True)
        remap = {}
        for attempt in feature["recordings"]["attempts"]:
            old = attempt["path"]
            attempt["path"] = str(root / "r16_runs" / Path(old).name)
            remap[old] = attempt["path"]
        feature["reader_runs"] = {remap[k]: v for k, v in feature["reader_runs"].items()}
        after = m.profile_files(profile)
        before = {k: v for k, v in after.items() if not k.endswith(".r16run")}
        helpers = m.helper_hashes()

        def audit(report=feature, b=before, after_override=None, hs=helpers):
            return m.audit_profile(profile, b, m.profile_files(profile) if after_override is None else after_override, report, hs)

        baseline = audit()
        check("copied genuine feature receipts pass audit", baseline["ok"], baseline["errors"])
        planned = copy.deepcopy(feature)
        planned["mode"] = "play"
        codes = {87: "w", 65: "a", 83: "s", 68: "d", 32: "space", 4194326: "ctrl", 4194325: "shift", 69: "e"}
        planned["recorded_tape_inputs"] = []
        first = planned["recordings"]["attempts"][0]
        rec = analyzer.read(Path(first["path"]))
        by_tick = {}
        for j, tick in enumerate(rec.inputs["tick"]):
            row = by_tick.setdefault(tick, dict(run_id=first["run_id"], recording_tick=tick, keys=[], mouse={}))
            if rec.inputs["kind"][j] == 1:
                code = rec.inputs["aux"][j] or rec.inputs["code"][j]
                if code in codes:
                    row["keys"].append(dict(key=codes[code], edge="press" if rec.inputs["flags"][j] & 1 else "release"))
            elif rec.inputs["kind"][j] == 3:
                row["mouse"] = dict(screen_relative=[rec.inputs["x"][j], rec.inputs["y"][j]])
        planned["recorded_tape_inputs"] = list(by_tick.values())
        planned["recorded_tape_tick_count"] = len(by_tick)
        for tape_tick, row in enumerate(planned["recorded_tape_inputs"]):
            row["tape_tick"] = tape_tick
        check("labelled input predicate control passes", audit(planned)["ok"] and any(r["mouse"] for r in by_tick.values()))
        changed = copy.deepcopy(planned)
        mouse = next(r for r in changed["recorded_tape_inputs"] if r["mouse"])
        mouse["mouse"]["screen_relative"][0] += 10
        check("wrong mouse payload is refused when observation exists", not audit(changed)["ok"])
        for name, change in [
            ("all tape observations missing", lambda r: r.pop("recorded_tape_inputs")),
            ("all tape observations empty", lambda r: r.update(recorded_tape_inputs=[])),
            ("wrong input hidden beyond seal", lambda r: [x.update(recording_tick=10**6) for x in r["recorded_tape_inputs"]]),
            ("wrong input hidden in unknown attempt", lambda r: [x.update(run_id="unobserved") for x in r["recorded_tape_inputs"]]),
        ]:
            bad = copy.deepcopy(changed)
            change(bad)
            observed = audit(bad)
            check(name + " must fail closed", not observed["ok"], observed, "counterexample", "P2")
        for name, change in [
            ("missing body tick", lambda r: r["recordings"]["observed"].pop(0)),
            ("wrong actual velocity", lambda r: r["recordings"]["observed"][0]["v"].__setitem__(0, 123)),
            ("wrong attempt boundary", lambda r: r["recordings"]["attempts"][0].update(kind="finish")),
            ("missing current reader", lambda r: r.pop("reader_runs")),
        ]:
            bad = copy.deepcopy(feature)
            change(bad)
            check(name + " refused", not audit(bad)["ok"])
        for name in ["Spillway/spillway_r15.cfg", "OtherApp/rogue.cfg", "Spillway/r16_runs/rogue.r16run"]:
            bad_after = dict(after)
            bad_after[name] = "0" * 64
            check("unobserved write refused " + name, not audit(after_override=bad_after)["ok"])
        bad_helpers = dict(helpers)
        bad_helpers["tools/analyze-r16-runs.py"] = "0" * 64
        check("stale independent analyzer refused", not audit(hs=bad_helpers)["ok"])
        target = Path(first["path"])
        original = target.read_bytes()
        mutated = []
        def event_edit(kind, seq, raw):
            if kind == analyzer.CHUNK_TICKS and seq == 0:
                n = struct.unpack_from("<I", raw)[0]
                at = 4 + n * sum(s for _, _, s in analyzer.TICK_LAYOUT)
                count = struct.unpack_from("<I", raw, at)[0]
                at += 4 + count * analyzer.INPUT_ROW
                events = json.loads(raw[at + 4:])
                events.append(dict(k="style", s="capture", t=10**6, q=10**6,
                                   d=dict(kind="nonexistent-reward", points=123456, tick=10**6)))
                blob = json.dumps(events, separators=(",", ":")).encode()
                return raw[:at] + struct.pack("<I", len(blob)) + blob
            if kind == analyzer.CHUNK_SEAL:
                value = json.loads(raw)
                value["counts"]["events"] += 1
                value["outcome"]["style"]["score"] += 123456
                return json.dumps(value, separators=(",", ":")).encode()
            return raw
        target.write_bytes(rewrite(original, analyzer, event_edit))
        mutated.append(dict(path=str(target), name="fabricated reward at nonexistent tick", sha256=sha(target)))
        mouse_index = next(i for i, kind in enumerate(rec.inputs["kind"]) if kind == 3)
        def mouse_edit(kind, seq, raw):
            if kind != analyzer.CHUNK_TICKS or seq != 0:
                return raw
            result = bytearray(raw)
            n = struct.unpack_from("<I", raw)[0]
            at = 4 + n * sum(size for _, _, size in analyzer.TICK_LAYOUT)
            count = struct.unpack_from("<I", raw, at)[0]
            assert mouse_index < count
            at += 4
            for field, fmt, size in analyzer.INPUT_LAYOUT:
                if field == "x2":
                    struct.pack_into("<f", result, at + mouse_index * size, rec.inputs["x2"][mouse_index] + 10)
                    return bytes(result)
                at += count * size
            raise AssertionError("missing x2 input column")
        mouse_bytes = rewrite(original, analyzer, mouse_edit)
        mouse_path = scratch / "wrong-mouse.r16run"
        mouse_path.write_bytes(mouse_bytes)
        write(scratch / "manifest.json", dict(paths=[str(target), str(mouse_path)]))
        env = m.engine_env(scratch / "engine-profile")
        r = command([m.EDITOR, "--headless", "--audio-driver", "Dummy", "--path", source, "--script",
                     "res://tests/r16_verifier_review.gd", "--", "--manifest=" + str(scratch / "manifest.json"),
                     "--out=" + str(scratch / "decoded.json")], source, out / "reader-visibility.log", env)
        check("headless copied reader/probe execute without errors", r.returncode == 0 and not m.ERRORS.search(r.stdout), r.returncode)
        if (scratch / "decoded.json").exists():
            decoded = json.loads((scratch / "decoded.json").read_text())
            altered = copy.deepcopy(feature)
            altered["reader_runs"][str(target)] = decoded["reader_runs"][str(target)]
            got = audit(altered)
            check("fabricated style reward at nonexistent tick must be refused", not got["ok"], got,
                  "counterexample", "P2")
            with gzip.open(out / "fabricated-reward.r16run.gz", "wb") as f:
                f.write(target.read_bytes())
            write(out / "mutations.json", mutated)
            for row in decoded["visibility"]:
                check(row["name"], row["accepted"] == row["expected"], row,
                      "counterexample" if row["expected"] is False and row["accepted"] else "control",
                      "P3" if row["expected"] is False and row["accepted"] else None)
            target.write_bytes(mouse_bytes)
            altered = copy.deepcopy(feature)
            altered["reader_runs"][str(target)] = decoded["reader_runs"][str(mouse_path)]
            got = audit(altered)
            check("actual corrupted recorded mouse must be refused by source feature audit", not got["ok"], got,
                  "counterexample", "P2")
            explicit = copy.deepcopy(planned)
            explicit["reader_runs"][str(target)] = decoded["reader_runs"][str(mouse_path)]
            check("same corrupted file refused with complete labelled tape evidence", not audit(explicit)["ok"])
            with gzip.open(out / "wrong-mouse.r16run.gz", "wb") as f:
                f.write(mouse_bytes)
        target.write_bytes(original)
        rows = [dict(phase="tape", tick=i, post=dict(p=[0., 0., float(i)], v=[0., 0., 1.], yaw=0., pitch=0.),
                     game=dict(checkpoint=0, elapsed=i / 128, finished=False, finish_kind="", respawns=0)) for i in range(3)]
        check("identical motion accepted", m.compare_traces(rows, copy.deepcopy(rows))["ok"])
        for name, field, val in [("position", "p", [1e-10, 0., 0.]), ("velocity", "v", [0., 0., -1.]),
                                 ("yaw", "yaw", 1e-6), ("pitch", "pitch", 1.)]:
            bad = copy.deepcopy(rows)
            bad[0]["post"][field] = val
            result = m.compare_traces(rows, bad)
            check("source comparison refuses changed " + name, not result["ok"], result,
                  "counterexample" if name == "pitch" else "control", "P3" if name == "pitch" else None)
        bad = copy.deepcopy(rows)
        bad[1]["game"]["checkpoint"] = 1
        check("explicit progress exception accepts its exact ticks", m.compare_traces(rows, bad, [1])["ok"])
        bad[1]["post"]["v"][0] = 1
        check("progress exception cannot waive motion", not m.compare_traces(rows, bad, [1])["ok"])
        for marker in ["SCRIPT ERROR:", "ERROR:", "Parse Error:", "Failed to load"]:
            check("engine errors caught: " + marker, m.ERRORS.search(marker + " deliberate control") is not None)
        # the existing suite signals only itself while acquisition is guarded, and only
        # releases Popen objects it created. it never scans or signals a named root job.
        r = command([sys.executable, "-B", "-I", frozen / "tests/test_r16_delivery.py", "--out", out / "existing-delivery.json"],
                    frozen, out / "existing-delivery.log")
        check("existing acquisition, deadline, profile, template and error controls", r.returncode == 0, r.stdout[-500:])
        r = command([sys.executable, "-B", "-I", frozen / "tests/test_r16_record_integrity.py", "--record", a.clean_record,
                     "--out", out / "existing-integrity", "--godot", m.EDITOR], frozen, out / "existing-integrity.log")
        check("existing clean-finish reader, selector and ghost counterexamples", r.returncode == 0, r.stdout[-500:])
        scratch_bytes = sum(f.stat().st_size for f in scratch.rglob("*") if f.is_file())
        check("scratch below 300 MiB", scratch_bytes < 300 * 2**20, scratch_bytes)
    check("owned scratch removed", not scratch.exists())
    differences = [path for path, h in protected.items() if not Path(path).is_file() or sha(Path(path)) != h]
    check("preexisting tracked files and delivered R15 bytes unchanged", not differences, differences)
    write(out / "commands.json", commands)
    write(out / "summary.json", dict(checks=checks, failed=sum(not r["ok"] for r in checks),
          counterexamples=sum(not r["ok"] and r["category"] == "counterexample" for r in checks),
          controls_failed=sum(not r["ok"] and r["category"] == "control" for r in checks),
          protected_files=len(protected), protected_changes=differences, scratch_removed=not scratch.exists()))
    return int(any(not r["ok"] for r in checks))


if __name__ == "__main__":
    raise SystemExit(main())
