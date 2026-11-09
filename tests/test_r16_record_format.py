#!/usr/bin/env python3
"""r16 recordings, independent of godot's reader: the stdlib reader and analyzer against files
the godot suite (tests/test_r16_record.gd) wrote, plus mutations, a mixed folder and a real OS
write failure.

python3 -I tests/test_r16_record_format.py --run GODOT_OUT --out RESULT.json [--log GODOT_LOG] [--godot BIN --project SRC]

GODOT_OUT is the --out of a full tests/test_r16_record.gd run. with --godot and --project the
OS write-failure case runs the godot suite's rlimit phase under RLIMIT_FSIZE with SIGXFSZ ignored,
so the kernel refuses the write (EFBIG) instead of killing the engine.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import random
import resource
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("r16_analyze", HERE.parent / "tools" / "analyze-r16-runs.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)

results: list[dict] = []


def check(name: str, ok: bool, detail="") -> bool:
    results.append({"name": name, "ok": bool(ok), "detail": str(detail)[:600]})
    if not ok:
        print(f"  fail: {name} ({str(detail)[:300]})", file=sys.stderr)
    return bool(ok)


def parse_bytes(data: bytes, name: str) -> "A.Recording":
    return A.parse(data, A.Recording(Path(name)))


def chunk_offsets(data: bytes) -> list[tuple[int, int, int]]:
    """(start, body_start, end) of each chunk of a valid file."""
    (header_len,) = struct.unpack_from("<I", data, 12)
    at = A.PREFIX_SIZE + header_len + A.DIGEST_SIZE
    out = []
    while at < len(data):
        stored_len = struct.unpack_from("<I", data, at + 16)[0]
        body = at + A.CHUNK_HEAD_SIZE + A.DIGEST_SIZE
        out.append((at, body, body + stored_len))
        at = body + stored_len
    return out


def rechain(data: bytearray) -> bytes:
    """recompute every digest after a deliberate edit: the forged-but-consistent case."""
    (header_len,) = struct.unpack_from("<I", data, 12)
    chain = hashlib.sha256(bytes(data[:A.PREFIX_SIZE + header_len])).digest()
    data[A.PREFIX_SIZE + header_len:A.PREFIX_SIZE + header_len + 32] = chain
    for start, body, end in chunk_offsets(bytes(data)):
        head = bytes(data[start:start + A.CHUNK_HEAD_SIZE])
        chain = hashlib.sha256(chain + head + bytes(data[body:end])).digest()
        data[start + A.CHUNK_HEAD_SIZE:body] = chain
    return bytes(data)


def cross_reader(run: Path) -> None:
    fmt = run / "format"
    expected = json.loads((fmt / "expected.json").read_text())
    rec = A.read(fmt / expected["file"])
    check("python strict read of the godot file: complete", rec.ok and rec.status == "complete", [rec.status, rec.errors])
    c = rec.columns
    codes = {"tick": "i", "flags": "i", "dt": "d", "elapsed": "d", "physics_hz": "i", "checkpoint": "i", "respawns": "i", "yaw": "d", "pitch": "d", "held": "q"}
    bad = []
    for name, hexed in expected["columns_hex"].items():
        if name in A.VECTORS:
            flat = [v for i in range(len(c["tick"])) for v in (c[f"{name}_x"][i], c[f"{name}_y"][i], c[f"{name}_z"][i])]
            mine = struct.pack(f"<{len(flat)}f", *flat)
        else:
            mine = struct.pack(f"<{len(c[name])}{codes[name]}", *c[name])
        if mine.hex() != hexed:
            bad.append(name)
    check("every tick column decodes to the bytes godot read (both readers agree exactly)", not bad and len(expected["columns_hex"]) == 14, bad)
    in_codes = {"tick": "i", "kind": "i", "flags": "i", "code": "q", "aux": "q", "x": "f", "y": "f", "x2": "f", "y2": "f"}
    bad = [n for n, h in expected["inputs_hex"].items() if struct.pack(f"<{len(rec.inputs[n])}{in_codes[n]}", *rec.inputs[n]).hex() != h]
    check("every input column agrees with godot", not bad and len(expected["inputs_hex"]) == 9, bad)
    check("event count and header identity agree", len(rec.events) == expected["event_count"] and rec.header.get("identity") == expected["header_identity"], [len(rec.events), expected["event_count"]])
    # the zlib bytes godot wrote are plain zlib streams: inflate one independently.
    data = (fmt / expected["file"]).read_bytes()
    start, body, end = chunk_offsets(data)[0]
    raw_len = struct.unpack_from("<I", data, start + 12)[0]
    check("godot COMPRESSION_DEFLATE chunks are standard zlib streams", data[body:body + 2] in (b"\x78\x9c", b"\x78\x01", b"\x78\xda", b"\x78\x5e") and len(zlib.decompress(data[body:end])) == raw_len)


def states(run: Path) -> None:
    by_name = {p.name: A.read(p) for p in (run / "states").iterdir()}
    aborted = [r for n, r in by_name.items() if n.endswith(".r16run.aborted")]
    crashed = by_name.get("crashed.r16run.part")
    complete = [r for n, r in by_name.items() if n.endswith(".r16run")]
    check("python: the aborted file reads as aborted with its reason", len(aborted) == 1 and aborted[0].status == "aborted" and aborted[0].abort.get("reason") == "test abort" and len(aborted[0].columns["tick"]) == 300)
    check("python: the crashed .part recovers its 256 flushed ticks, labelled partial", crashed is not None and crashed.status == "partial" and len(crashed.columns["tick"]) == 256 and not crashed.ok,
          [crashed.status, crashed.errors] if crashed else None)
    check("python: an empty sealed attempt is complete", len(complete) == 1 and complete[0].ok)
    disk = list((run / "disk").iterdir())
    check("python: the disk-error file is partial, never complete", len(disk) == 1 and disk[0].name.endswith(".part") and A.read(disk[0]).status == "partial", [p.name for p in disk])


def mutations(run: Path) -> None:
    fmt = run / "format"
    name = json.loads((fmt / "expected.json").read_text())["file"]
    data = (fmt / name).read_bytes()
    full = parse_bytes(data, name)
    chunks = chunk_offsets(data)
    ticks_before = [0]
    for start, body, end in chunks:
        ticks_before.append(ticks_before[-1] + struct.unpack_from("<I", data, start + 24)[0])
    # every truncation point at and around chunk edges, plus a spread through the file.
    cuts = sorted({0, 7, 8, 15, 16, 40} | {x + d for s, b, e in chunks for x in (s, b, e) for d in (-1, 0, 1)} | set(range(0, len(data), max(1, len(data) // 97))))
    wrong = []
    for cut in cuts:
        if cut >= len(data):
            continue
        rec = parse_bytes(data[:cut], name)
        whole = sum(1 for s, b, e in chunks if e <= cut)
        want = ticks_before[min(whole, len(chunks) - 1)] if whole < len(chunks) else None
        if rec.status == "complete" or rec.ok:
            wrong.append((cut, "complete"))
        elif rec.header and len(rec.columns["tick"]) != want:
            wrong.append((cut, len(rec.columns["tick"]), want))
        elif rec.header and rec.columns["p_x"] != full.columns["p_x"][:len(rec.columns["p_x"])]:
            wrong.append((cut, "prefix differs"))
    check(f"{len(cuts)} truncations: never complete, recovery is exactly the whole verified chunks", not wrong, wrong[:5])
    rng = random.Random(16)
    flips = sorted(rng.sample(range(len(data)), 300))
    wrong = []
    for at in flips:
        mutated = bytearray(data)
        mutated[at] ^= 1 << rng.randrange(8)
        rec = parse_bytes(bytes(mutated), name)
        if rec.ok or rec.status == "complete":
            wrong.append(at)
        elif rec.header and rec.columns["p_x"] != full.columns["p_x"][:len(rec.columns["p_x"])]:
            wrong.append((at, "garbage accepted"))
    check("300 single-bit flips: never complete, never a changed value", not wrong, wrong[:5])
    bumped = bytearray(data)
    bumped[8] = 2
    rec = parse_bytes(bytes(bumped), name)
    check("a newer format version is refused by name", rec.status == "invalid" and any("unsupported format version 2" in e for e in rec.errors), rec.errors)
    rec = parse_bytes(b"NOTARUN!" + data[8:], name)
    check("wrong magic is refused", rec.status == "invalid", rec.errors)
    rec = parse_bytes(data + b"junk", name)
    check("bytes after the seal make it partial", rec.status == "partial" and any("follow the end chunk" in e for e in rec.errors), rec.errors)
    s0, s1 = chunks[0], chunks[1]
    swapped = data[:s0[0]] + data[s1[0]:s1[2]] + data[s0[0]:s0[2]] + data[s1[2]:]
    rec = parse_bytes(swapped, name)
    check("swapped chunks are refused at the first out-of-sequence chunk", rec.status == "partial" and len(rec.columns["tick"]) == 0, rec.errors)
    rec = parse_bytes(data, name + ".part")
    check("a sealed stream still named .part is labelled sealed-unrenamed", rec.status == "sealed-unrenamed" and not rec.ok, rec.errors)
    for label, blob in (("empty", b""), ("text", b"hello\n" * 40), ("random", bytes(rng.randrange(256) for _ in range(5000)))):
        rec = parse_bytes(blob, name)
        check(f"{label} file is invalid", rec.status == "invalid" and not rec.header, rec.errors)
    # consistent forgeries: digests recomputed after the edit, so only the bounds can refuse them.
    forged = bytearray(data)
    struct.pack_into("<I", forged, chunks[0][0] + 12, A.MAX_CHUNK_RAW + 1)
    rec = parse_bytes(rechain(forged), name)
    check("a chunk claiming more than the raw bound is refused before inflating", rec.status == "partial" and "invalid head" in " ".join(rec.errors), rec.errors)
    forged = bytearray(data)
    struct.pack_into("<I", forged, chunks[0][0] + 12, struct.unpack_from("<I", data, chunks[0][0] + 12)[0] - 1)
    rec = parse_bytes(rechain(forged), name)
    check("a chunk whose inflated size disagrees is refused", rec.status == "partial" and "inflate" in " ".join(rec.errors), rec.errors)
    seal_start, seal_body, seal_end = chunks[-1]
    nan_seal = b'{"outcome":{"kind":"finish"},"counts":{"ticks":NaN}}'
    forged = bytearray(data[:seal_start]) + data[seal_start:seal_start + 12] + struct.pack("<II", len(nan_seal), len(nan_seal)) + data[seal_start + 20:seal_body] + nan_seal
    rec = parse_bytes(rechain(forged), name)
    check("a NaN token in JSON is refused, not parsed", rec.status == "partial" and "non-standard JSON constant" in " ".join(rec.errors), rec.errors)


def analysis(run: Path, out_dir: Path) -> None:
    host = run / "host" / "runs"
    reports = {}
    for path in sorted(host.iterdir()):
        r = A.analyse(A.read(path), 0.75)
        reports[r["ended_by"] + ("-clean" if (r.get("outcome") or {}).get("clean") else "") + ("-fall" if r.get("falls") else "")] = r
    clean = reports.get("finish-clean")
    check("the clean finish: three stage marks, no teleports, timer and finish ticks", clean is not None and len(clean["checkpoints"]) == 3 and clean["discontinuities"]["teleport_count"] == 0
          and clean["timer_start_tick"] is not None and clean["finish_tick"] is not None and clean["finished"], clean and clean["checkpoints"])
    check("the clean finish separates its air-duck hull shifts from travel", clean is not None and clean["discontinuities"]["hull_shifts"] >= 1 and clean["discontinuities"]["unexplained"] == 0,
          clean and clean["discontinuities"])
    fall = reports.get("practice-fall")
    check("the fall attempt: one fall, its teleport classified as a respawn, ended by practice", fall is not None and fall["falls"] == 1 and [t["kind"] for t in fall["discontinuities"]["teleports"]] == ["respawn"],
          fall and fall["discontinuities"])
    loss = fall["speed_losses"][0] if fall and fall["speed_losses"] else {}
    check("the fall's speed loss is located at the bay wall with airborne context", loss.get("at", [0])[0] > 13.0 and loss.get("grounded_fraction", 1) < 0.5 and "move_right" in loss.get("held_at_start", []), loss)
    check("the respawn breaks the spatial line into two segments", fall is not None and len(fall["line"]["segments"]) == 2, fall and len(fall["line"]["segments"]))
    check("the practice finish is a finish, not clean", "finish" in reports and not (reports["finish"].get("outcome") or {}).get("clean"), list(reports))
    bw = [A.analyse(A.read(p), 0.75) for p in sorted((run / "breakwater" / "runs").iterdir())]
    check("breakwater: hull shifts separated, nothing unexplained, inputs and hops present", bw and bw[0]["discontinuities"]["hull_shifts"] >= 1 and all(r["discontinuities"]["unexplained"] == 0 for r in bw)
          and bw[0]["inputs"]["by_kind"].get("mouse_motion", 0) > 100 and bw[0]["hops"]["count"] >= 3, bw and [bw[0]["discontinuities"], bw[0]["hops"], bw[0]["inputs"]["by_kind"]])
    (out_dir / "host-analysis.json").write_text(json.dumps({k: v for k, v in reports.items()}, indent=1, default=str))


def mixed_folder(run: Path, out_dir: Path) -> None:
    folder = out_dir / "mixed"
    if folder.exists():
        shutil.rmtree(folder)
    (folder / "desktop" / "nested").mkdir(parents=True)
    valid = sorted((run / "host" / "runs").iterdir()) + sorted((run / "breakwater" / "runs").iterdir())
    for p in valid:
        shutil.copy2(p, folder / "desktop" / p.name)
    good = valid[0].read_bytes()
    (folder / "desktop" / "truncated.r16run").write_bytes(good[:len(good) // 2])
    flipped = bytearray(good)
    flipped[len(good) // 3] ^= 0x40
    (folder / "desktop" / "nested" / "flipped.r16run").write_bytes(bytes(flipped))
    (folder / "desktop" / "future.r16run").write_bytes(good[:8] + b"\x09\x00" + good[10:])
    (folder / "desktop" / "empty.r16run.part").write_bytes(b"")
    (folder / "desktop" / "notes.txt").write_text("not a recording")
    shutil.copy2(next((run / "states").glob("*.aborted")), folder / "desktop")
    shutil.copy2(run / "states" / "crashed.r16run.part", folder / "desktop")
    report_path = out_dir / "mixed-report.json"
    tool = HERE.parent / "tools" / "analyze-r16-runs.py"
    proc = subprocess.run([sys.executable, "-I", str(tool), str(folder), "--json", str(report_path)], capture_output=True, text=True, timeout=120)
    report = json.loads(report_path.read_text())
    (out_dir / "mixed-summary.txt").write_text(proc.stdout)
    check("the folder analysis exits 0 and names every recording", proc.returncode == 0 and report["totals"]["files"] == len(valid) + 6, [proc.returncode, report["totals"], proc.stderr[-300:]])
    by = {Path(r["file"]).name: r for r in report["runs"]}
    alone_same = all(json.dumps(A.analyse(A.read(p), 0.75), sort_keys=True, default=str) == json.dumps({**by[p.name], "file": str(p)}, sort_keys=True, default=str) for p in valid)
    check("every valid neighbour is complete and analysed exactly as it is alone", all(by[p.name]["ok"] for p in valid) and alone_same)
    check("the bad files are each labelled", by["truncated.r16run"]["status"] == "partial" and by["flipped.r16run"]["status"] == "partial" and by["future.r16run"]["status"] == "invalid"
          and by["empty.r16run.part"]["status"] == "invalid" and by["crashed.r16run.part"]["status"] == "partial", {k: by[k]["status"] for k in by if not by[k]["ok"]})
    check("the aborted copy is labelled aborted", any(r["status"] == "aborted" for r in report["runs"]))
    check("other files are listed as ignored", any(p.endswith("notes.txt") for p in report["ignored"]))
    strict = subprocess.run([sys.executable, "-I", str(tool), str(folder), "--quiet", "--strict"], capture_output=True, text=True, timeout=120)
    check("--strict exits 1 when any file is not complete", strict.returncode == 1, strict.returncode)
    single = subprocess.run([sys.executable, "-I", str(tool), str(valid[0]), "--quiet", "--strict"], capture_output=True, text=True, timeout=60)
    check("one complete file passes --strict", single.returncode == 0, single.stderr[-300:])


def rlimit(godot: str, project: str, out_dir: Path) -> None:
    scratch = Path(tempfile.mkdtemp(prefix="r16-rlimit-", dir=os.environ.get("R16_SCRATCH", "/dev/shm")))
    limit = 48 * 1024

    def child() -> None:
        signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
        resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))

    env = dict(os.environ, XDG_DATA_HOME=str(scratch / "data"), XDG_CONFIG_HOME=str(scratch / "config"), XDG_CACHE_HOME=str(scratch / "cache"))
    proc = subprocess.run([godot, "--headless", "--audio-driver", "Dummy", "--path", project, "--script", "res://tests/test_r16_record.gd", "--", f"--out={scratch}", "--phase=rlimit"],
                          capture_output=True, text=True, timeout=180, preexec_fn=child, env=env)
    line = next((l for l in proc.stdout.splitlines() if l.startswith("RLIMIT ")), "")
    got = json.loads(line[7:]) if line else {}
    part = Path(got.get("path", "/nonexistent"))
    rec = A.read(part) if part.exists() else None
    ok = (got.get("opened") is True and got.get("status") == "disk-error" and "failed" in got.get("error", "") and got.get("dropped", 0) > 0 and got.get("finish_ok") is False
          and part.name.endswith(".r16run.part") and rec is not None and rec.status == "partial" and part.stat().st_size <= limit)
    check(f"a real OS write failure (RLIMIT_FSIZE {limit} bytes, EFBIG) surfaces as disk-error with an identifiable partial .part", ok,
          [got, proc.returncode, rec and rec.status, rec and len(rec.columns["tick"]), proc.stderr[-400:]])
    (out_dir / "rlimit.json").write_text(json.dumps({"reported": got, "exit": proc.returncode, "python_status": rec and rec.status,
                                                      "recovered_ticks": rec and len(rec.columns["tick"]), "bytes": part.stat().st_size if part.exists() else None,
                                                      "stderr_tail": proc.stderr[-1500:]}, indent=1))
    shutil.rmtree(scratch, ignore_errors=True)


# the deliberate negatives of tests/test_r16_record.gd, each exactly once; any other engine error fails.
EXPECTED_LOG = [
    r"ERROR: r16 recorder: header metadata is \d+ bytes, above the 65536 byte bound",
    r"ERROR: r16 recorder: test hook: write refused after 3000 bytes",
    r"ERROR: Could not create directory: '.*/locked/inner'\.",
    r"ERROR: r16 recorder: cannot create recording directory .*/locked/inner \(Can't create\)",
    r"ERROR: r16 recorder: cannot open .*/locked/locked_x_[0-9_-]+_[0-9a-f]{8}\.r16run\.part for writing \(Can't open file\)",
]


def log_audit(log: Path) -> None:
    import re
    lines = [l for l in log.read_text(errors="replace").splitlines() if re.search(r"SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load script", l)]
    unmatched = [l for l in lines if not any(re.fullmatch(p, l) for p in EXPECTED_LOG)]
    counts = [sum(1 for l in lines if re.fullmatch(p, l)) for p in EXPECTED_LOG]
    check("the godot log holds exactly the five deliberate refusals and no other error", not unmatched and counts == [1] * len(EXPECTED_LOG), [unmatched[:5], counts])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--godot")
    parser.add_argument("--project")
    parser.add_argument("--log", help="the godot suite's log, audited for unexpected errors")
    args = parser.parse_args()
    run = Path(args.run)
    out = Path(args.out)
    out_dir = out.parent
    out_dir.mkdir(parents=True, exist_ok=True)
    for step in (lambda: cross_reader(run), lambda: states(run), lambda: mutations(run), lambda: analysis(run, out_dir), lambda: mixed_folder(run, out_dir)):
        try:
            step()
        except Exception as exc:  # a crash is a failed check, never a silent pass
            check(f"step raised {type(exc).__name__}", False, exc)
    if args.log:
        log_audit(Path(args.log))
    if args.godot and args.project:
        rlimit(args.godot, args.project, out_dir)
    else:
        results.append({"name": "real OS write failure", "ok": None, "detail": "skipped: --godot and --project not given"})
    failed = [r for r in results if r["ok"] is False]
    out.write_text(json.dumps({"checks": len(results), "failed": len(failed), "results": results}, indent=1))
    print(f"r16 record format: {len(results)} checks, {len(failed)} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
