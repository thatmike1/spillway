#!/usr/bin/env python3
"""r16 run analysis: read copied .r16run recordings (one file or folders) with the standard
library only, validate them strictly, recover labelled partial streams, and summarise each run.

python3 -I tools/analyze-r16-runs.py PATH... [--json OUT] [--loss-min 0.75] [--quiet] [--strict]

the byte layout is docs/r16/RECORDINGS.md. a recording is data: JSON sections are parsed with
json, columns with struct; nothing is imported, evaluated or loaded from it. every length is
bounded before it is read, and inflation is capped at the declared size. one malformed file is
reported as such and never stops or alters the analysis of its neighbours.

exit status: 0 when every path was read (whatever the recordings' states), 2 for bad arguments
or an unreadable path; --strict also exits 1 when any recording is not complete.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
import zlib
from pathlib import Path

FORMAT = "foldrunner-r16-run"
VERSION = 1
MAGIC = b"FRR16RUN"
CHUNK_MAGIC = b"CHNK"
CHUNK_TICKS, CHUNK_SEAL, CHUNK_ABORT = 1, 2, 3
CODEC_RAW, CODEC_ZLIB = 0, 1
PREFIX_SIZE = 16
CHUNK_HEAD_SIZE = 28
DIGEST_SIZE = 32
MAX_HEADER = 65536
MAX_CHUNK_RAW = 8 * 1024 * 1024
MAX_FILE = 1024 * 1024 * 1024
SUFFIX = ".r16run"
FLAG_KEYS = ["started", "finished", "clean", "grounded", "ducked"]
# (name, struct code per row, bytes per row); a vector is three float32 x, y, z, read here as
# the columns NAME_x, NAME_y, NAME_z.
TICK_LAYOUT = [("tick", "i", 4), ("flags", "i", 4), ("dt", "d", 8), ("elapsed", "d", 8), ("physics_hz", "i", 4),
               ("checkpoint", "i", 4), ("respawns", "i", 4), ("p", "fff", 12), ("reference_p", "fff", 12), ("v", "fff", 12),
               ("actual_v", "fff", 12), ("yaw", "d", 8), ("pitch", "d", 8), ("held", "q", 8)]
VECTORS = ("p", "reference_p", "v", "actual_v")
COLUMN_NAMES = [n for n, _, _ in TICK_LAYOUT if n not in VECTORS] + [f"{g}_{a}" for g in VECTORS for a in "xyz"]
INPUT_LAYOUT = [("tick", "i", 4), ("kind", "i", 4), ("flags", "i", 4), ("code", "q", 8), ("aux", "q", 8), ("x", "f", 4), ("y", "f", 4), ("x2", "f", 4), ("y2", "f", 4)]
INPUT_ROW = sum(size for _, _, size in INPUT_LAYOUT)
INPUT_KINDS = {1: "key", 2: "mouse_button", 3: "mouse_motion", 4: "action", 5: "joy_button", 6: "joy_motion", 7: "other"}
# godot 4 keycodes for the names a summary prints; any other code prints as its number.
KEY_NAMES = {32: "Space", 65: "A", 67: "C", 68: "D", 69: "E", 70: "F", 81: "Q", 82: "R", 83: "S", 87: "W",
             4194305: "Escape", 4194306: "Tab", 4194325: "Shift", 4194326: "Ctrl", 4194328: "Alt",
             4194332: "F1", 4194333: "F2", 4194334: "F3", 4194335: "F4", 4194336: "F5", 49: "1", 50: "2", 51: "3", 52: "4", 53: "5"}
U = 0.0254
LIFECYCLE_FALLS = {"fall", "respawn", "respawn_count"}
LIFECYCLE_RESTARTS = {"restart", "practice", "map", "preset", "quit", "loadout"}


class Recording:
    def __init__(self, path: Path):
        self.path = path
        self.status = "invalid"
        self.errors: list[str] = []
        self.header: dict = {}
        self.seal: dict = {}
        self.abort: dict = {}
        self.chunks = 0
        self.valid_bytes = 0
        self.size = 0
        self.columns: dict[str, list] = {name: [] for name in COLUMN_NAMES}
        self.inputs: dict[str, list] = {name: [] for name, _, _ in INPUT_LAYOUT}
        self.events: list = []

    @property
    def ok(self) -> bool:
        return self.status == "complete" and not self.errors


def read(path: Path) -> Recording:
    """strict read with labelled partial recovery; never raises for file content."""
    rec = Recording(path)
    try:
        rec.size = path.stat().st_size
        if rec.size > MAX_FILE:
            rec.errors.append(f"file is {rec.size} bytes, above the {MAX_FILE} byte bound")
            return rec
        data = path.read_bytes()
    except OSError as exc:
        rec.errors.append(f"cannot read: {exc}")
        return rec
    parse(data, rec)
    return rec


def parse(data: bytes, rec: Recording) -> Recording:
    if len(data) < PREFIX_SIZE + DIGEST_SIZE or data[:8] != MAGIC:
        rec.errors.append("not an r16 recording (bad magic or shorter than the prefix)")
        return rec
    version, reserved, header_len = struct.unpack_from("<HHI", data, 8)
    if version != VERSION:
        rec.errors.append(f"unsupported format version {version} (this reader knows {VERSION})")
        return rec
    if reserved != 0 or header_len > MAX_HEADER or PREFIX_SIZE + header_len + DIGEST_SIZE > len(data):
        rec.errors.append(f"header length {header_len} is out of bounds or truncated")
        return rec
    chain = hashlib.sha256(data[:PREFIX_SIZE + header_len]).digest()
    if data[PREFIX_SIZE + header_len:PREFIX_SIZE + header_len + DIGEST_SIZE] != chain:
        rec.errors.append("header digest mismatch")
        return rec
    try:
        header = _loads(data[PREFIX_SIZE:PREFIX_SIZE + header_len].decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        rec.errors.append(f"header is not JSON: {exc}")
        return rec
    if not isinstance(header, dict) or header.get("format") != FORMAT or header.get("version") != VERSION:
        rec.errors.append("header JSON is not an r16 run header")
        return rec
    rec.header = header
    rec.status = "partial"
    at = PREFIX_SIZE + header_len + DIGEST_SIZE
    rec.valid_bytes = at
    seq = 0
    ended = ""
    while at < len(data):
        if at + CHUNK_HEAD_SIZE + DIGEST_SIZE > len(data):
            rec.errors.append(f"truncated chunk head at byte {at}")
            break
        head = data[at:at + CHUNK_HEAD_SIZE]
        magic, ctype, codec, reserved, cseq, raw_len, stored_len, first_tick, tick_count = struct.unpack("<4sBBHIIIII", head)
        if (magic != CHUNK_MAGIC or reserved != 0 or cseq != seq or ctype not in (CHUNK_TICKS, CHUNK_SEAL, CHUNK_ABORT)
                or codec not in (CODEC_RAW, CODEC_ZLIB) or raw_len > MAX_CHUNK_RAW or stored_len > MAX_CHUNK_RAW
                or (codec == CODEC_RAW and stored_len != raw_len)):
            rec.errors.append(f"chunk {seq} at byte {at} has an invalid head (magic {magic!r}, type {ctype}, codec {codec}, sequence {cseq})")
            break
        body_at = at + CHUNK_HEAD_SIZE + DIGEST_SIZE
        if body_at + stored_len > len(data):
            rec.errors.append(f"chunk {seq} is truncated ({len(data) - body_at} of {stored_len} stored bytes)")
            break
        stored = data[body_at:body_at + stored_len]
        digest = hashlib.sha256(chain + head + stored).digest()
        if data[at + CHUNK_HEAD_SIZE:body_at] != digest:
            rec.errors.append(f"chunk {seq} digest mismatch")
            break
        raw = stored
        if codec == CODEC_ZLIB:
            try:
                inflater = zlib.decompressobj()
                raw = inflater.decompress(stored, raw_len)
                if len(raw) != raw_len or inflater.unconsumed_tail or not inflater.eof:
                    raise zlib.error("inflated size disagrees with the head")
            except zlib.error as exc:
                rec.errors.append(f"chunk {seq} does not inflate to {raw_len} bytes: {exc}")
                break
        if ctype == CHUNK_TICKS:
            problem = decode_ticks(raw, first_tick, tick_count, rec)
            if problem:
                rec.errors.append(f"chunk {seq}: {problem}")
                break
        else:
            try:
                body = _loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, ValueError) as exc:
                rec.errors.append(f"chunk {seq} end record is not JSON: {exc}")
                break
            if not isinstance(body, dict):
                rec.errors.append(f"chunk {seq} end record is not a JSON object")
                break
            if ctype == CHUNK_SEAL:
                rec.seal = body
                ended = "complete"
            else:
                rec.abort = body
                ended = "aborted"
        chain = digest
        seq += 1
        at = body_at + stored_len
        rec.valid_bytes = at
        if ended:
            break
    rec.chunks = seq
    if not ended:
        if rec.valid_bytes == len(data):
            rec.errors.append("the stream ends without a seal or abort chunk")
        rec.status = "partial"
    elif rec.valid_bytes != len(data):
        rec.errors.append(f"{len(data) - rec.valid_bytes} bytes follow the end chunk")
        rec.status = "partial"
    else:
        rec.status = ended
    name = rec.path.name
    if rec.status == "complete" and name.endswith(SUFFIX + ".part"):
        rec.status = "sealed-unrenamed"
        rec.errors.append("sealed stream still named .part: the rename never happened")
    if rec.status == "complete":
        counts = rec.seal.get("counts")
        if not isinstance(counts, dict):
            rec.errors.append("seal counts is not an object")
            rec.status = "partial"
        else:
            for name, actual in [("ticks", len(rec.columns["tick"])), ("inputs", len(rec.inputs["tick"])), ("events", len(rec.events))]:
                counted = counts.get(name)
                if (isinstance(counted, bool) or not isinstance(counted, (int, float))
                        or not math.isfinite(counted) or counted != actual):
                    rec.errors.append(f"seal counts {counted} {name}, the stream holds {actual}")
                    rec.status = "partial"
    return rec


def decode_ticks(raw: bytes, first_tick: int, tick_count: int, rec: Recording) -> str:
    if len(raw) < 4:
        return "payload shorter than its count"
    (n,) = struct.unpack_from("<I", raw, 0)
    if n != tick_count:
        return f"tick count {n} disagrees with the head ({tick_count})"
    at = 4
    row = sum(size for _, _, size in TICK_LAYOUT)
    if at + n * row + 4 > len(raw):
        return "tick columns are truncated"
    fresh = {}
    for name, code, size in TICK_LAYOUT:
        if name in VECTORS:
            flat = struct.unpack_from(f"<{3 * n}f", raw, at)
            for k, axis in enumerate("xyz"):
                fresh[f"{name}_{axis}"] = list(flat[k::3])
        else:
            fresh[name] = list(struct.unpack_from(f"<{n}{code}", raw, at))
        at += n * size
    if n and fresh["tick"][0] != first_tick:
        return f"first tick {fresh['tick'][0]} disagrees with the head ({first_tick})"
    (m,) = struct.unpack_from("<I", raw, at)
    at += 4
    if at + m * INPUT_ROW + 4 > len(raw):
        return "input columns are truncated"
    inputs = {}
    for name, code, size in INPUT_LAYOUT:
        inputs[name] = list(struct.unpack_from(f"<{m}{code}", raw, at))
        at += m * size
    (j,) = struct.unpack_from("<I", raw, at)
    at += 4
    if at + j != len(raw):
        return f"event section is {j} bytes, the payload leaves {len(raw) - at}"
    try:
        events = _loads(raw[at:at + j].decode("utf-8")) if j else []
    except (UnicodeDecodeError, ValueError) as exc:
        return f"event section is not JSON: {exc}"
    if not isinstance(events, list) or not all(isinstance(e, dict) for e in events):
        return "event section is not a JSON array of objects"
    for name in COLUMN_NAMES:
        rec.columns[name].extend(fresh[name])
    for name, _, _ in INPUT_LAYOUT:
        rec.inputs[name].extend(inputs[name])
    rec.events.extend(events)
    return ""


# --- analysis ---------------------------------------------------------------------------------

def _reject_constant(name: str):
    raise ValueError(f"non-standard JSON constant {name}")


def _loads(text: str):
    """strict JSON: NaN and Infinity tokens are refused, as the writer never emits them."""
    return json.loads(text, parse_constant=_reject_constant)


def _num(value, default=0.0) -> float:
    try:
        out = float(value)
    except (TypeError, ValueError):
        return default
    return out if math.isfinite(out) else default


def _vec(c: dict, group: str, i: int) -> tuple[float, float, float]:
    return (c[f"{group}_x"][i], c[f"{group}_y"][i], c[f"{group}_z"][i])


def _dist(a, b) -> float:
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def _r(value: float, digits: int = 3):
    return round(value, digits) if math.isfinite(value) else None


def held_names(events: list) -> list[list[str]]:
    """names in bit order as announced by held_names events, latest first applied by tick."""
    out = []
    for e in events:
        if e.get("k") == "held_names" and isinstance(e.get("d"), dict):
            out.append((e.get("t", -1), [str(n) for n in e["d"].get("names", [])]))
    return out


def names_for(mask: int, tick: int, table: list) -> list[str]:
    names: list[str] = []
    for at, listed in table:
        if at <= tick:
            names = listed
    return [n for i, n in enumerate(names) if mask >> i & 1]


HULL_LIFT_MAX_M = 0.30  # a source air duck lifts the feet 9 u (0.2286 m); anything hull-related stays below this


def discontinuities(c: dict, events: list, threshold: float = 0.05) -> list[dict]:
    """per-tick position changes that travel (actual_v * dt) does not explain.

    p is the actual feet, reference_p the feet without outstanding duck-origin compensation and
    actual_v the travel without it. a step where either position moves exactly by travel while
    the other does not, or where the duck state or the compensation (p - reference_p) changed by
    no more than a duck lift, is a hull-origin shift: an air duck or stand moving p, or the host
    settling its compensation on the ground moving reference_p. anything larger is a teleport: a
    respawn when the respawn counter rose or a fall/respawn event names that tick, a lifecycle
    move when a restart-type event does, otherwise unexplained. residuals under 1e-4 m are float
    noise and ignored."""
    lifecycle_ticks: dict = {}
    for e in events:
        if e.get("k") in LIFECYCLE_FALLS | LIFECYCLE_RESTARTS:
            lifecycle_ticks.setdefault(e.get("t"), []).append(e.get("k"))
    out = []
    n = len(c["tick"])
    for i in range(1, n):
        dt = c["dt"][i]
        travel = tuple(a * dt for a in _vec(c, "actual_v", i))
        p0, p1 = _vec(c, "p", i - 1), _vec(c, "p", i)
        r0, r1 = _vec(c, "reference_p", i - 1), _vec(c, "reference_p", i)
        res_p = _dist(tuple(a - b for a, b in zip(p1, p0)), travel)
        res_r = _dist(tuple(a - b for a, b in zip(r1, r0)), travel)
        worst = max(res_p, res_r)
        if worst <= 1e-4:
            continue
        ducked_changed = (c["flags"][i] ^ c["flags"][i - 1]) & 16 != 0
        comp_change = _dist(tuple(a - b for a, b in zip(p1, r1)), tuple(a - b for a, b in zip(p0, r0)))
        if worst <= HULL_LIFT_MAX_M and (min(res_p, res_r) <= 1e-4 or ducked_changed or comp_change > 1e-5):
            out.append({"tick": c["tick"][i], "index": i, "kind": "hull_shift", "shift_m": _r(worst, 4), "moved": "reference_p" if res_p <= 1e-4 else "p",
                        "ducked": bool(c["flags"][i] & 16)})
        elif worst > threshold:
            respawned = c["respawns"][i] > c["respawns"][i - 1]
            tags = lifecycle_ticks.get(c["tick"][i], []) + lifecycle_ticks.get(c["tick"][i - 1], [])
            kind = "respawn" if respawned or any(t in LIFECYCLE_FALLS for t in tags) else (
                "lifecycle" if any(t in LIFECYCLE_RESTARTS for t in tags) else "unexplained")
            out.append({"tick": c["tick"][i], "index": i, "kind": kind, "jump_m": _r(_dist(r1, r0)), "residual_m": _r(res_r, 4), "events": tags})
        else:
            out.append({"tick": c["tick"][i], "index": i, "kind": "minor_residual", "residual_m": _r(worst, 5)})
    return out


def speed_losses(c: dict, events: list, breaks: set[int], loss_min: float, table: list) -> list[dict]:
    """drawdowns of horizontal travel speed (|actual_v| on x/z). a section runs from a running
    peak to the lowest speed before the speed recovers by a third of the drop or a discontinuity
    breaks continuity; sections that lose at least loss_min m/s are reported with their context."""
    n = len(c["tick"])
    speed = [math.hypot(c["actual_v_x"][i], c["actual_v_z"][i]) for i in range(n)]
    by_tick: dict[int, list] = {}
    for e in events:
        by_tick.setdefault(e.get("t"), []).append(e)
    sections = []
    peak = trough = 0

    def close(peak: int, trough: int):
        drop = speed[peak] - speed[trough]
        if drop < loss_min or trough <= peak:
            return
        # the section starts where the decline does, not where the peak was first reached.
        while peak + 1 < trough and speed[peak + 1] >= speed[peak] - 0.02:
            peak += 1
        lo, hi = c["tick"][peak], c["tick"][trough]
        grounded = sum(1 for i in range(peak, trough + 1) if c["flags"][i] & 8)
        span = trough - peak + 1
        kinds: dict[str, int] = {}
        motion: dict[str, int] = {}
        for t in range(lo, hi + 1):
            for e in by_tick.get(t, []):
                kinds[e.get("k")] = kinds.get(e.get("k"), 0) + 1
                if e.get("k") == "motion":
                    for name in (e.get("d") or {}).get("events", []):
                        motion[str(name)] = motion.get(str(name), 0) + 1
        yaw_turn = sum(abs(math.remainder(c["yaw"][i] - c["yaw"][i - 1], math.tau)) for i in range(peak + 1, trough + 1))
        vspeed_loss = 0.0
        for i in range(peak + 1, trough + 1):
            vspeed_loss += max(0.0, math.hypot(c["v_x"][i - 1], c["v_z"][i - 1]) - math.hypot(c["v_x"][i], c["v_z"][i]))
        frac = grounded / span
        if frac >= 0.6:
            cause = "mostly grounded: friction, a stop or a slow ground move"
        elif motion.get("land") or motion.get("step"):
            cause = "air section ending on a landing"
        else:
            cause = "airborne: collision, air law or turning"
        sections.append({
            "from_tick": lo, "to_tick": hi, "ticks": span,
            "elapsed_from": _r(c["elapsed"][peak]), "elapsed_to": _r(c["elapsed"][trough]),
            "speed_from_ms": _r(speed[peak]), "speed_to_ms": _r(speed[trough]), "loss_ms": _r(drop), "loss_u": _r(drop / U, 1),
            "at": [_r(v, 2) for v in _vec(c, "reference_p", peak)], "to": [_r(v, 2) for v in _vec(c, "reference_p", trough)],
            "checkpoint": c["checkpoint"][peak], "grounded_fraction": _r(frac, 2), "yaw_turn_rad": _r(yaw_turn),
            "held_at_start": names_for(c["held"][peak], lo, table), "held_at_end": names_for(c["held"][trough], hi, table),
            "event_kinds": kinds, "motion_events": motion, "heuristic": cause,
            "timed": bool(c["flags"][peak] & 1) and not bool(c["flags"][peak] & 2),
        })

    for i in range(1, n):
        if i in breaks:
            close(peak, trough)
            peak = trough = i
            continue
        if speed[i] > speed[peak] and speed[trough] >= speed[peak] - 1e-9:
            peak = trough = i
        elif speed[i] < speed[trough]:
            trough = i
        elif speed[i] > speed[trough] + max(0.25, (speed[peak] - speed[trough]) / 3.0):
            close(peak, trough)
            peak = trough = i
    close(peak, trough)
    sections.sort(key=lambda s: -s["loss_ms"])
    return sections


def analyse(rec: Recording, loss_min: float) -> dict:
    meta = rec.header.get("metadata", {}) if isinstance(rec.header.get("metadata"), dict) else {}
    out = {
        "file": str(rec.path), "name": rec.path.name, "status": rec.status, "ok": rec.ok, "errors": rec.errors,
        "bytes": rec.size, "valid_bytes": rec.valid_bytes, "chunks": rec.chunks,
        "run_id": rec.header.get("run_id"), "created_utc": rec.header.get("created_utc"), "engine": rec.header.get("engine"),
        "map": meta.get("map"), "preset": meta.get("preset"), "identity": rec.header.get("identity"),
        "outcome": rec.seal.get("outcome") if rec.seal else None, "abort": rec.abort or None,
    }
    if not rec.header:
        return out
    if rec.status != "complete":
        out["recovery"] = ("partial: the ticks, inputs and events below are every chunk whose hash chain verified up to "
                           f"byte {rec.valid_bytes} of {rec.size}. there is no seal, so the outcome, the true end of the attempt "
                           "and the totals are unknown" if rec.status in ("partial", "sealed-unrenamed")
                           else "aborted: the stream verified to its abort chunk; the attempt did not end in a seal")
    c = rec.columns
    n = len(c["tick"])
    out["ticks"] = n
    if n == 0:
        return out
    gaps = [(c["tick"][i - 1], c["tick"][i]) for i in range(1, n) if c["tick"][i] != c["tick"][i - 1] + 1]
    started = [i for i in range(n) if c["flags"][i] & 1]
    finished = [i for i in range(n) if c["flags"][i] & 2]
    hz = sorted(set(c["physics_hz"]))
    out.update({
        "first_tick": c["tick"][0], "last_tick": c["tick"][-1], "tick_gaps": gaps[:20], "tick_gap_count": len(gaps),
        "physics_hz": hz, "sim_seconds": _r(sum(c["dt"])),
        "timer_start_tick": c["tick"][started[0]] if started else None,
        "finish_tick": c["tick"][finished[0]] if finished else None,
        "final_elapsed": _r(c["elapsed"][finished[0]] if finished else c["elapsed"][-1], 6),
        "clean_at_end": bool(c["flags"][-1] & 4), "finished": bool(finished),
    })
    table = held_names(rec.events)
    breaks_list = discontinuities(c, rec.events)
    teleports = [d for d in breaks_list if d["kind"] in ("respawn", "lifecycle", "unexplained")]
    breaks = {d["index"] for d in teleports}
    hull = [d for d in breaks_list if d["kind"] == "hull_shift"]
    minor = [d for d in breaks_list if d["kind"] == "minor_residual"]
    travel_h = travel_3d = 0.0
    top = 0.0
    timed_travel = 0.0
    for i in range(n):
        dt = c["dt"][i]
        av = _vec(c, "actual_v", i)
        h = math.hypot(av[0], av[2])
        travel_h += h * dt
        travel_3d += math.sqrt(av[0] ** 2 + av[1] ** 2 + av[2] ** 2) * dt
        top = max(top, h)
        if c["flags"][i] & 1 and not c["flags"][i] & 2:
            timed_travel += h * dt
    out["travel"] = {"horizontal_m": _r(travel_h, 2), "spatial_m": _r(travel_3d, 2), "timed_horizontal_m": _r(timed_travel, 2),
                     "top_speed_ms": _r(top), "top_speed_u": _r(top / U, 1),
                     "note": "integrated from actual_v (travel excluding hull compensation); teleports and hull shifts add nothing"}
    out["discontinuities"] = {"hull_shifts": len(hull), "hull_shift_total_m": _r(sum(d["shift_m"] for d in hull), 4),
                              "teleports": teleports[:50], "teleport_count": len(teleports),
                              "unexplained": sum(1 for d in teleports if d["kind"] == "unexplained"),
                              "minor_residuals": len(minor), "minor_residual_max_m": max((d["residual_m"] for d in minor), default=0.0)}
    # spatial line: reference feet every quarter second, split at teleports.
    step = max(1, round(0.25 / (c["dt"][0] or 1 / 128)))
    lines, line = [], []
    for i in range(n):
        if i in breaks and line:
            lines.append(line)
            line = []
        if i % step == 0 or i == n - 1 or i in breaks:
            line.append([_r(v, 2) for v in _vec(c, "reference_p", i)] + [_r(c["elapsed"][i], 3)])
    if line:
        lines.append(line)
    xs, ys, zs = c["reference_p_x"], c["reference_p_y"], c["reference_p_z"]
    out["line"] = {"segments": lines, "point_format": "[x, y, z, elapsed] m/s, every 0.25 s of ticks and at breaks",
                   "bounds": {"min": [_r(min(xs), 2), _r(min(ys), 2), _r(min(zs), 2)], "max": [_r(max(xs), 2), _r(max(ys), 2), _r(max(zs), 2)]},
                   "lowest_y": _r(min(ys), 2)}
    # checkpoints and segments.
    marks = [e for e in rec.events if e.get("k") == "checkpoint"]
    segs = []
    prev_tick, prev_i = (c["tick"][started[0]] if started else c["tick"][0]), (started[0] if started else 0)
    index_of = {t: i for i, t in enumerate(c["tick"])}
    for e in marks + ([{"t": c["tick"][finished[0]], "d": {"to": "finish"}}] if finished else []):
        i = index_of.get(e.get("t"))
        if i is None:
            continue
        dist = sum(math.hypot(c["actual_v_x"][k], c["actual_v_z"][k]) * c["dt"][k] for k in range(prev_i + 1, i + 1))
        secs = sum(c["dt"][k] for k in range(prev_i + 1, i + 1))
        segs.append({"to": (e.get("d") or {}).get("to"), "tick": e.get("t"), "elapsed": _r(c["elapsed"][i], 6),
                     "segment_s": _r(secs, 4), "segment_m": _r(dist, 2), "average_ms": _r(dist / secs if secs else 0.0)})
        prev_tick, prev_i = e.get("t"), i
    out["checkpoints"] = segs
    # lifecycle, falls, restarts.
    kinds: dict[str, int] = {}
    for e in rec.events:
        kinds[str(e.get("k"))] = kinds.get(str(e.get("k")), 0) + 1
    out["event_counts"] = kinds
    out["lifecycle"] = [{"tick": e.get("t"), "kind": e.get("k"), "data": e.get("d")} for e in rec.events
                        if e.get("s") == "event" or e.get("k") in ("timer_start", "timer_reset", "finish_line", "clean_lost", "respawn_count", "tick_gap", "sample_missing")][:200]
    out["falls"] = sum(1 for e in rec.events if e.get("k") == "respawn_count")
    ends = [e.get("k") for e in rec.events if e.get("s") == "event" and e.get("k") in LIFECYCLE_RESTARTS | {"finish"}]
    out["ended_by"] = (rec.seal.get("outcome") or {}).get("kind") if rec.seal else (ends[-1] if ends else None)
    # style.
    style = [e for e in rec.events if e.get("k") == "style"]
    by_kind: dict[str, dict] = {}
    total = 0
    for e in style:
        d = e.get("d") if isinstance(e.get("d"), dict) else {}
        pts = int(_num(d.get("points"), 0))
        total += pts
        entry = by_kind.setdefault(str(d.get("kind", "?")), {"count": 0, "points": 0})
        entry["count"] += 1
        entry["points"] += pts
    out["style"] = {"events": len(style), "points": total, "by_kind": by_kind,
                    "recent": [{"tick": e.get("t"), **(e.get("d") if isinstance(e.get("d"), dict) else {})} for e in style[-12:]]}
    # hops.
    hops = [e.get("d") for e in rec.events if e.get("k") == "hop" and isinstance(e.get("d"), dict)]
    syncs = [_num(h.get("sync"), -1) for h in hops if h.get("sync") not in (None, "NaN")]
    out["hops"] = {"count": len(hops), "mean_sync": _r(sum(syncs) / len(syncs), 3) if syncs else None,
                   "gain_u_total": _r(sum(_num(h.get("gain")) for h in hops), 1)}
    # inputs.
    ins = rec.inputs
    by: dict[str, int] = {}
    presses: dict[str, int] = {}
    mouse = 0.0
    for i in range(len(ins["tick"])):
        kind = INPUT_KINDS.get(ins["kind"][i], str(ins["kind"][i]))
        by[kind] = by.get(kind, 0) + 1
        if kind == "key" and ins["flags"][i] & 1 and not ins["flags"][i] & 2:
            name = KEY_NAMES.get(ins["code"][i] or ins["aux"][i], str(ins["code"][i] or ins["aux"][i]))
            presses[name] = presses.get(name, 0) + 1
        elif kind == "mouse_motion":
            mouse += math.hypot(ins["x"][i], ins["y"][i])
    out["inputs"] = {"total": len(ins["tick"]), "by_kind": by, "key_presses": presses, "mouse_motion_total": _r(mouse, 1)}
    out["speed_losses"] = speed_losses(c, rec.events, breaks, loss_min, table)[:12]
    return out


def collect(paths: list[str]) -> tuple[list[Path], list[str], list[str]]:
    files, ignored, missing = [], [], []
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            for child in sorted(p.rglob("*")):
                if not child.is_file():
                    continue
                name = child.name
                if name.endswith(SUFFIX) or name.endswith(SUFFIX + ".part") or name.endswith(SUFFIX + ".aborted"):
                    files.append(child)
                else:
                    ignored.append(str(child))
        elif p.is_file():
            files.append(p)
        else:
            missing.append(raw)
    return files, ignored, missing


def human(report: dict) -> str:
    lines = []
    for r in report["runs"]:
        head = f"{r['name']}: {r['status'].upper()}"
        if r.get("map"):
            head += f"  {r['map']} / {r.get('preset')}"
        lines.append(head)
        if r["errors"]:
            lines.append("  ! " + "; ".join(r["errors"])[:300])
        if r.get("recovery"):
            lines.append("  " + r["recovery"])
        if not r.get("ticks"):
            continue
        outcome = r.get("outcome") or {}
        lines.append(f"  outcome {outcome.get('kind', '-')}{' clean' if outcome.get('clean') else ''}; clock {r['final_elapsed']} s; "
                     f"{r['ticks']} ticks at {','.join(map(str, r['physics_hz']))} Hz; finished={r['finished']} clean_at_end={r['clean_at_end']}")
        t = r["travel"]
        d = r["discontinuities"]
        lines.append(f"  travel {t['horizontal_m']} m horizontal, top {t['top_speed_u']} u/s; falls {r['falls']}, ended by {r['ended_by']}; "
                     f"teleports {d['teleport_count']} ({d['unexplained']} unexplained), hull shifts {d['hull_shifts']}")
        if r["checkpoints"]:
            lines.append("  stages " + ", ".join(f"{s['to']}@{s['elapsed']}s ({s['average_ms']} m/s)" for s in r["checkpoints"]))
        s = r["style"]
        if s["events"]:
            lines.append(f"  style {s['points']} pts from {s['events']} events: " + ", ".join(f"{k} x{v['count']}={v['points']}" for k, v in s["by_kind"].items()))
        if r["hops"]["count"]:
            lines.append(f"  hops {r['hops']['count']}, mean sync {r['hops']['mean_sync']}")
        for loss in r["speed_losses"][:3]:
            lines.append(f"  loss {loss['loss_u']} u/s at {loss['elapsed_from']}-{loss['elapsed_to']} s near {loss['at']}: {loss['heuristic']}"
                         f"{'; ' + ','.join(f'{k}x{v}' for k, v in loss['motion_events'].items()) if loss['motion_events'] else ''}")
    totals = report["totals"]
    lines.append(f"{totals['files']} files: " + ", ".join(f"{k} {v}" for k, v in sorted(totals["by_status"].items()))
                 + (f"; {len(report['ignored'])} other files ignored" if report["ignored"] else ""))
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--json", help="write the machine-readable report here")
    parser.add_argument("--loss-min", type=float, default=0.75, help="smallest reported speed loss, m/s")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)
    files, ignored, missing = collect(args.paths)
    if missing:
        print("not found: " + ", ".join(missing), file=sys.stderr)
        return 2
    runs = []
    for path in files:
        try:
            runs.append(analyse(read(path), args.loss_min))
        except Exception as exc:  # an analysis bug on one file must not hide its neighbours
            runs.append({"file": str(path), "name": path.name, "status": "invalid", "ok": False, "errors": [f"analysis failed: {type(exc).__name__}: {exc}"]})
    by_status: dict[str, int] = {}
    for r in runs:
        by_status[r["status"]] = by_status.get(r["status"], 0) + 1
    by_outcome: dict[str, int] = {}
    for r in runs:
        key = str(r.get("ended_by"))
        by_outcome[key] = by_outcome.get(key, 0) + 1
    report = {"format": FORMAT, "reader_version": VERSION, "runs": runs, "ignored": ignored,
              "totals": {"files": len(runs), "by_status": by_status, "by_outcome": by_outcome}}
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=1, allow_nan=False, default=str))
    if not args.quiet:
        print(human(report))
    if args.strict and any(r["status"] != "complete" or not r["ok"] for r in runs):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
