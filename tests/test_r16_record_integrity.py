#!/usr/bin/env python3
"""challenge copied-run selection using hash-consistent mutations of a real clean recording.

python3 -I tests/test_r16_record_integrity.py --record RUN --out DIR --godot BIN
uses a tiny isolated project in RAM; no imports or writes in the shared checkout.
"""
from __future__ import annotations

import argparse
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

PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("analyzer", PROJECT / "tools/analyze-r16-runs.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)


def rewrite(data: bytes, edit) -> bytes:
    header_len = struct.unpack_from("<I", data, 12)[0]
    at = 16 + header_len
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


def seal_edit(fn):
    def edit(kind, _seq, raw):
        if kind != A.CHUNK_SEAL:
            return raw
        value = json.loads(raw)
        fn(value)
        return json.dumps(value, separators=(",", ":"), allow_nan=False).encode()
    return edit


def tick_edit(column, code, value, row=100):
    def edit(kind, seq, raw):
        if kind != A.CHUNK_TICKS or seq != 0:
            return raw
        result = bytearray(raw)
        n = struct.unpack_from("<I", raw)[0]
        assert n > row
        at = 4
        for name, _, size in A.TICK_LAYOUT:
            if name == column:
                struct.pack_into("<" + code, result, at + row * size, value)
                return bytes(result)
            at += n * size
        raise AssertionError(column)
    return edit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    baseline = A.read(args.record)
    assert baseline.ok and baseline.seal["outcome"]["clean"], baseline.errors
    original = args.record.read_bytes()
    mutations = {
        "counts-text": seal_edit(lambda s: s.update(counts="broken")),
        "counts-null": seal_edit(lambda s: s.update(counts=None)),
        "zero-time": seal_edit(lambda s: s["final"].update(elapsed=0)),
        "negative-time": seal_edit(lambda s: s["final"].update(elapsed=-1)),
        "text-time": seal_edit(lambda s: s["final"].update(elapsed="NaN")),
        "wrong-finish-time": seal_edit(lambda s: s["final"].update(elapsed=0.001)),
        "wrong-outcome-time": seal_edit(lambda s: s["outcome"].update(time=0.001)),
        "truthy-outcome": seal_edit(lambda s: s["outcome"].update(clean="yes")),
        "truthy-final": seal_edit(lambda s: s["final"].update(clean="yes")),
        "wrong-finish-tick": seal_edit(lambda s: s.update(finish_tick=s["finish_tick"] - 1)),
        "wrong-start-tick": seal_edit(lambda s: s.update(timer_start_tick=s["timer_start_tick"] + 1)),
        "wrong-final-tick": seal_edit(lambda s: s["final"].update(tick=s["last_tick"] - 1)),
        "wrong-final-position": seal_edit(lambda s: s["final"].update(p=[1, 2, 3])),
        "wrong-final-respawns": seal_edit(lambda s: s["final"].update(respawns="0")),
        "seal-input-count": seal_edit(lambda s: s["counts"].update(inputs=s["counts"]["inputs"] + 1)),
        "nan-position": tick_edit("p", "f", float("nan")),
        "infinite-yaw": tick_edit("yaw", "d", float("inf")),
        "nan-delta": tick_edit("dt", "d", float("nan")),
        "negative-delta": tick_edit("dt", "d", -1),
        "duplicate-tick": tick_edit("tick", "i", 99),
        "missing-tick": tick_edit("tick", "i", 101),
        "wrong-timed-rate": tick_edit("physics_hz", "i", 64),
        "backward-clock": tick_edit("elapsed", "d", -1),
        "unclean-row": tick_edit("flags", "i", 1),
        "respawn-row": tick_edit("respawns", "i", 1),
    }
    checks = []
    with tempfile.TemporaryDirectory(prefix="r16-record-integrity-", dir="/tmp") as scratch:
        scratch = Path(scratch)
        source = scratch / "source"
        (source / "scripts").mkdir(parents=True)
        (source / "tests").mkdir()
        (source / "project.godot").write_text('[application]\nconfig/name="r16 record integrity"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in ["r16_run_reader.gd", "r16_ghost.gd"]:
            shutil.copy2(PROJECT / "scripts" / name, source / "scripts" / name)
        shutil.copy2(PROJECT / "tests/r16_record_integrity_probe.gd", source / "tests")
        folder = scratch / "runs"
        folder.mkdir()
        good = folder / "z-good.r16run"
        good.write_bytes(original)
        cases = [{"name": "baseline", "path": str(good)}]
        for name, edit in mutations.items():
            path = folder / (name + ".r16run")
            path.write_bytes(rewrite(original, edit))
            cases.append({"name": name, "path": str(path)})
            try:
                rec = A.read(path)
                checks.append({"name": "python reader does not throw: " + name, "ok": True,
                               "status": rec.status, "errors": rec.errors})
            except Exception as exc:
                checks.append({"name": "python reader does not throw: " + name, "ok": False, "error": str(exc)})
        manifest = scratch / "cases.json"
        manifest.write_text(json.dumps({"identity": baseline.header["identity"], "folder": str(folder), "cases": cases}))
        env = os.environ.copy()
        for key in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            env[key] = str(scratch / key.lower())
        output = scratch / "godot.json"
        command = [str(args.godot), "--headless", "--audio-driver", "Dummy", "--path", str(source),
                   "--script", "res://tests/r16_record_integrity_probe.gd", "--", "--manifest=" + str(manifest), "--out=" + str(output)]
        run = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        (args.out / "godot.log").write_text(run.stdout)
        if not output.exists():
            raise RuntimeError(run.stdout)
        result = json.loads(output.read_text())
        for row in result["cases"]:
            want = row["name"] == "baseline"
            for channel in ["clean", "ghost"]:
                checks.append({"name": row["name"] + " " + channel, "ok": row[channel].get("ok", False) == want,
                               "observed": row[channel]})
        checks.append({"name": "fastest selector keeps the real complete run", "ok": result["fastest"].get("path") == str(good),
                       "observed": result["fastest"]})
        checks.append({"name": "no engine/script errors", "ok": run.returncode == 0 and not any(k in run.stdout for k in ["SCRIPT ERROR", "ERROR:"]),
                       "exit": run.returncode})
        (args.out / "observations.json").write_text(json.dumps(result, indent=2))
    summary = {"checks": len(checks), "failed": sum(not x["ok"] for x in checks), "results": checks,
               "record_sha256": hashlib.sha256(original).hexdigest(), "scratch_removed": True,
               "source_sha256": {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in [PROJECT / "scripts/r16_run_reader.gd", PROJECT / "scripts/r16_ghost.gd",
                                           PROJECT / "tools/analyze-r16-runs.py", Path(__file__), PROJECT / "tests/r16_record_integrity_probe.gd"]}}
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2))
    print(f"record integrity: {summary['checks']} checks, {summary['failed']} failed")
    for row in checks:
        if not row["ok"]:
            print("FAIL " + row["name"])
    return 1 if summary["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
