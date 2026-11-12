"""bounded, data-only transport and original-reader analysis for manual run imports."""
from __future__ import annotations

import collections
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import struct
import tempfile
import zipfile

FORMAT = "spillway-run-bundle"
SCHEMA = 1
MAX_FILES = 4096
MAX_FILE = 64 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024
MAX_MANIFEST = 1024 * 1024
MAX_ARCHIVE = MAX_TOTAL + 8 * 1024 * 1024
CHUNK = 64 * 1024
RESERVE = 15_000_000_000
# decoded recording expansion is independently bounded before the old reader allocates columns.
MAX_DECODED_FILE = 64 * 1024 * 1024
MAX_DECODED_TOTAL = 512 * 1024 * 1024
MAX_TICKS = 131072
MAX_INPUTS = 524288
MAX_CHUNKS = 8192


class BundleError(ValueError):
    pass


class AnalysisLimit(BundleError):
    pass


def limit(condition, reason):
    if not condition:
        raise AnalysisLimit(reason)


def require(condition, reason):
    if not condition:
        raise BundleError(reason)


def safe_name(name):
    require(isinstance(name, str) and 0 < len(name.encode("utf-8")) <= 240, "invalid member name")
    require(not name.startswith("/") and not any(ord(c) < 32 or 127 <= ord(c) <= 159 or c in '\\:<>"|?*' for c in name), "unsafe member name")
    for part in name.split("/"):
        require(part not in ("", ".", "..") and not part.endswith((".", " ")), "unsafe member component")
        require(part.split(".")[0].upper() not in {"CON", "PRN", "AUX", "NUL", *(f"COM{i}" for i in range(1, 10)), *(f"LPT{i}" for i in range(1, 10))}, "reserved member component")
    return name


def strict_json(data):
    def pairs(rows):
        out = {}
        for k, v in rows:
            require(k not in out, "duplicate JSON key")
            out[k] = v
        return out
    def constant(value):
        raise BundleError("nonfinite JSON number")
    try:
        return json.loads(data, object_pairs_hook=pairs, parse_constant=constant)
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise BundleError(f"invalid JSON: {exc}") from exc


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(CHUNK), b""):
            h.update(block)
    return h.hexdigest()


def save_json(path, value):
    with path.open("x", encoding="utf8") as f:
        json.dump(value, f, indent=2, sort_keys=True, allow_nan=False)
        f.write("\n")


def check_zip_header(f):
    # bound central-directory parsing before ZipFile constructs an object for every member.
    f.seek(0, 2)
    size = f.tell()
    require(22 <= size <= MAX_ARCHIVE, "archive size exceeds transport bound")
    f.seek(max(0, size - 65557))
    tail = f.read(65557)
    pos = tail.rfind(b"PK\x05\x06")
    require(pos >= 0 and pos + 22 <= len(tail), "missing ZIP end record")
    disk, cd_disk, local_count, count, cd_size, cd_at, comment = struct.unpack_from("<4H2IH", tail, pos + 4)
    require(disk == cd_disk == 0 and local_count == count and count <= 2 * MAX_FILES + 1, "multi-disk/ZIP64 or excessive member count")
    require(cd_size <= 4 * MAX_MANIFEST and cd_at + cd_size == size - len(tail) + pos and pos + 22 + comment == len(tail), "invalid/excessive ZIP central directory")
    f.seek(0)
    return size


def manifest_from(z):
    members = z.infolist()
    require(len(members) <= 2 * MAX_FILES + 1, "excessive members")
    names, folded, directories = {}, set(), set()
    total = 0
    for member in members:
        is_dir = member.is_dir()
        name = member.filename
        safe_name(name[:-1] if is_dir else name)
        require(member.orig_filename == name, "NUL/truncated name")
        require(name not in names and name.lower() not in folded, "duplicate/colliding member names")
        names[name] = member
        folded.add(name.lower())
        mode = member.external_attr >> 16
        if is_dir:
            require(stat.S_IFMT(mode) in (0, stat.S_IFDIR) and member.file_size == 0 and member.compress_size <= 8, "invalid ZIP directory")
            require(member.CRC == 0, "invalid directory CRC")
            with z.open(member) as stream:
                require(stream.read(1) == b"", "directory has payload")
            directories.add(name)
        else:
            require(stat.S_IFMT(mode) in (0, stat.S_IFREG) and not member.external_attr & 0x10, "special ZIP member")
        require(not member.flag_bits & (1 | 64), "encrypted ZIP member")
        require(member.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), "unsupported ZIP compression")
        bound = MAX_MANIFEST if name == "manifest.json" else MAX_FILE
        require(0 <= member.file_size <= bound and 0 <= member.compress_size <= MAX_ARCHIVE, "member exceeds size bound")
        total += member.file_size
    require(total <= MAX_TOTAL + MAX_MANIFEST, "bundle expansion exceeds 512 MiB")
    require("manifest.json" in names, "missing manifest")
    with z.open(names["manifest.json"]) as f:
        raw = f.read(MAX_MANIFEST + 1)
    require(len(raw) <= MAX_MANIFEST, "excessive manifest")
    m = strict_json(raw)
    require(isinstance(m, dict) and set(m) == {"format", "schema", "player", "build", "created_utc", "current_profile", "entries"}, "invalid manifest fields")
    require(m["format"] == FORMAT and type(m["schema"]) is int and m["schema"] == SCHEMA, "unsupported transport schema")
    for field, limit in (("player", 64), ("build", 128), ("created_utc", 32)):
        require(isinstance(m[field], str) and 0 < len(m[field].strip()) <= limit and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in m[field]), f"invalid {field}")
    require(re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", m["created_utc"]) is not None, "invalid timestamp")
    entries = m["entries"]
    require(isinstance(entries, list) and 1 <= len(entries) <= MAX_FILES, "invalid entry count")
    seen, data_total = set(), 0
    for entry in entries:
        require(isinstance(entry, dict) and set(entry) == {"path", "size", "sha256"}, "invalid entry fields")
        name = safe_name(entry["path"])
        require(name.startswith(("recordings/", "settings/")) and name not in seen and name in names, "duplicate/missing/out-of-root manifest entry")
        require(type(entry["size"]) is int and 0 <= entry["size"] <= MAX_FILE and entry["size"] == names[name].file_size, "manifest size mismatch")
        require(isinstance(entry["sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", entry["sha256"]), "invalid SHA256")
        seen.add(name)
        data_total += entry["size"]
    require(data_total <= MAX_TOTAL, "data expansion exceeds 512 MiB")
    implied = {str(parent).replace("\\", "/") + "/" for name in seen for parent in Path(name).parents if str(parent) != "."}
    require(directories <= implied, "missing/extra structural ZIP directory")
    require(set(names) == seen | directories | {"manifest.json"}, "extra ZIP member")
    require(m["current_profile"] == "" or (isinstance(m["current_profile"], str) and m["current_profile"] in seen and m["current_profile"].startswith("settings/")), "invalid current profile member")
    return m, raw, names, data_total


def decoded_budget(path):
    """scan trusted-length envelopes only; original reader still validates all hashes and data."""
    total = ticks = chunks = inputs_bound = 0
    with path.open("rb") as f:
        prefix = f.read(16)
        if len(prefix) != 16 or prefix[:8] != b"FRR16RUN" or struct.unpack_from("<H", prefix, 8)[0] != 1:
            return 0
        header_len = struct.unpack_from("<I", prefix, 12)[0]
        if header_len > 65536:
            return 0
        f.seek(16 + header_len + 32)
        while head := f.read(28):
            if len(head) != 28:
                break
            magic, kind, codec, reserved, seq, raw, stored, first, n = struct.unpack("<4sBBHIIIII", head)
            if magic != b"CHNK" or kind not in (1, 2, 3) or raw > 8 * 1024 * 1024 or stored > 8 * 1024 * 1024:
                break
            # zlib max_length=0 means unlimited, so never pass that declaration to the old reader.
            require(codec != 1 or raw > 0, "compressed recording chunk declares zero decoded length")
            total += raw
            ticks += n
            chunks += 1
            # raw length also bounds input/event expansion; no unbounded decompression here.
            inputs_bound += raw // 44
            limit(total <= MAX_DECODED_FILE and ticks <= MAX_TICKS and chunks <= MAX_CHUNKS and inputs_bound <= 2 * MAX_INPUTS, "recording decoded analysis bound exceeded")
            f.seek(32 + stored, 1)
    return total


def finite_data(value, depth=0):
    limit(depth <= 48, "recording JSON nesting bound exceeded")
    if isinstance(value, float):
        require(math.isfinite(value), "nonfinite recording JSON")
    elif isinstance(value, str):
        try:
            value.encode("utf-8", "strict")
        except UnicodeError as exc:
            raise BundleError("malformed recording Unicode scalar") from exc
    elif isinstance(value, dict):
        for key, child in value.items():
            finite_data(key, depth + 1)
            finite_data(child, depth + 1)
    elif isinstance(value, list):
        for child in value:
            finite_data(child, depth + 1)


def sample_safety(rec):
    ticks = rec.columns["tick"]
    if ticks:
        require(0 <= ticks[0] <= ticks[-1] and ticks[-1] - ticks[0] <= MAX_TICKS, "unsafe recording tick span")
        require(all(a < b for a, b in zip(ticks, ticks[1:])), "nonmonotonic recording ticks")
    finite_data(rec.columns)


def load_reader():
    path = Path(__file__).resolve().parents[1] / "verification/lib/run_reader.py"
    spec = importlib.util.spec_from_file_location("original_r16_reader", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, digest(path)


def analyse_folder(folder, manifest):
    reader, reader_hash = load_reader()
    attempts, groups, seen_hashes = [], {}, {}
    decoded = 0
    for entry in manifest["entries"]:
        if not entry["path"].startswith("recordings/"):
            continue
        path = folder / entry["path"]
        limited = False
        try:
            budget = decoded_budget(path)
            limit(decoded + budget <= MAX_DECODED_TOTAL, "total decoded recording analysis exceeds 512 MiB")
            decoded += budget
            rec = reader.read(path)
            limit(len(rec.inputs["tick"]) <= MAX_INPUTS, "recording inputs exceed analysis bound")
            finite_data(rec.header)
            finite_data(rec.seal)
            finite_data(rec.events)
            sample_safety(rec)
            outcome = rec.seal.get("outcome", {})
            require(isinstance(outcome, dict), "malformed recording outcome")
            outcome_kind = outcome.get("kind", "unknown")
            require(isinstance(outcome_kind, str) and 0 < len(outcome_kind) <= 128
                and not any(ord(c) < 32 or 127 <= ord(c) <= 159 for c in outcome_kind),
                "malformed recording outcome kind")
            report = reader.analyse(rec, 0.75)
            finite_data(report)
            require(isinstance(rec.header.get("metadata", {}), dict) and isinstance(rec.header.get("identity", {}), dict), "malformed recording metadata")
        except (BundleError, ValueError, TypeError, AttributeError, KeyError, IndexError, RecursionError, OverflowError) as exc:
            limited = isinstance(exc, AnalysisLimit)
            rec = reader.Recording(path)
            rec.size = path.stat().st_size
            rec.errors = [f"analysis limited: {exc}" if limited else f"malformed recording data: {exc}"]
            report = {"file": entry["path"], "name": path.name, "status": "invalid", "ok": False, "errors": rec.errors, "bytes": rec.size}
        report["file"] = entry["path"]
        if limited:
            classification = "unsupported"
        elif not rec.header:
            classification = "unsupported" if any("unsupported format" in e for e in rec.errors) else "corrupt"
        elif rec.status == "complete" and not rec.errors:
            classification = "complete"
        elif rec.status == "aborted" and not rec.errors:
            classification = "aborted"
        elif rec.status in ("partial", "sealed-unrenamed") and all("truncated" in e or "without a seal" in e or "rename never happened" in e for e in rec.errors):
            classification = "partial"
        else:
            classification = "corrupt"
        meta = rec.header.get("metadata", {})
        # full identity, not map display name, defines comparability; all fields remain inspectable.
        identity = {"source_build": {"build": meta.get("build", "unknown"), "build_label": meta.get("build_label", "unknown")}, "map": meta.get("map", "unknown"), "preset": meta.get("preset", "unknown"), "identity": rec.header.get("identity", {})}
        key = hashlib.sha256(json.dumps(identity, sort_keys=True, ensure_ascii=True).encode()).hexdigest()
        group = groups.setdefault(key, {**identity, "attempts": 0, "files": 0, "statuses": {}, "outcomes": {}, "exposure_s": 0.0, "restarts": 0, "respawns": 0, "speed_loss_sections": 0, "observed_speed_loss_ms": 0.0, "stall_s": 0.0, "style_points_observed": 0, "style_by_kind": {}})
        group["files"] += 1
        duplicate_of = seen_hashes.get(entry["sha256"])
        if duplicate_of:
            attempts.append({**report, "classification": classification, "group": key, "sha256": entry["sha256"], "duplicate_of": duplicate_of, "sample_count": len(rec.columns["tick"]), "exposure_s": sum(rec.columns["dt"]), "aggregate_note": "identical payload already counted; original file preserved"})
            del rec
            continue
        seen_hashes[entry["sha256"]] = entry["path"]
        group["attempts"] += 1
        group["statuses"][classification] = group["statuses"].get(classification, 0) + 1
        outcome = (rec.seal.get("outcome") or {}).get("kind", "unknown")
        group["outcomes"][outcome] = group["outcomes"].get(outcome, 0) + 1
        exposure = sum(rec.columns["dt"])
        stall = sum(dt for dt, vx, vz in zip(rec.columns["dt"], rec.columns["actual_v_x"], rec.columns["actual_v_z"]) if math.hypot(vx, vz) < 1.0)
        group["exposure_s"] += exposure
        group["stall_s"] += stall
        group["restarts"] += int(outcome == "restart")
        group["respawns"] += max(rec.columns["respawns"], default=0)
        losses = report.get("speed_losses", [])
        group["speed_loss_sections"] += len(losses)
        group["observed_speed_loss_ms"] += sum(x.get("loss_ms", 0) for x in losses)
        group["style_points_observed"] += report.get("style", {}).get("points", 0)
        for kind, values in report.get("style", {}).get("by_kind", {}).items():
            agg = group["style_by_kind"].setdefault(kind, {"count": 0, "points": 0})
            for field in agg:
                agg[field] += values[field]
        attempts.append({**report, "classification": classification, "group": key, "sha256": entry["sha256"], "exposure_s": exposure, "stall_s": stall, "sample_count": len(rec.columns["tick"])})
        del rec
    result = {"format": "spillway-import-analysis", "schema": 1, "reader_sha256": reader_hash, "player_claim": manifest["player"], "attempts": attempts, "groups": groups, "uncertainty": ["player labels are unauthenticated collection claims", "identical payload SHA256s inside this bundle are linked with duplicate_of and counted once in group exposure/outcomes, while every original file and per-file classification remains preserved", "complete means sealed transport, not successful gameplay; inspect outcome", "partial/aborted/corrupt totals describe only verified recovered samples; missing tails/outcomes are unknown", "stall means observed horizontal actual speed below 1 m/s, including idle spawn; pause wall time is unobserved", "speed-loss sections use the original analyzer's top 12 per attempt, not all losses; causal attribution is unknown", "build/full motion identity/preset groups are separate; no cross-version leaderboard", "timing and style describe observations, not enjoyment or player intent"]}
    save_json(folder / "analysis.json", result)
    counts = dict(collections.Counter(a["classification"] for a in attempts))
    lines = ["# Imported runs", "", f"{len(attempts)} recording files preserved ({len(seen_hashes)} distinct byte payloads). Status counts: {json.dumps(counts, sort_keys=True)}.", "", "Player label is a claim, not authenticated identity. No upload occurs.", "", "## Separate recorded identities", ""]
    for key, g in groups.items():
        lines.append(f"- {g['map']} / {g['preset']} / {g['source_build']} ({key[:12]}): {g['attempts']} distinct payloads in {g['files']} files, {g['exposure_s']:.2f} observed seconds, {g['restarts']} restarts, {g['respawns']} respawns, {g['stall_s']:.2f} s below 1 m/s, {g['speed_loss_sections']} reported loss sections, {g['style_points_observed']} observed style points. Outcomes: {json.dumps(g['outcomes'], sort_keys=True)}.")
    lines += ["", "## Limits and uncertainty", ""] + [f"- {s}." for s in result["uncertainty"]]
    lines += ["", "Per-attempt timing, outcomes, errors, zero-sample runs, identities, recovered samples, inputs, style, and speed-loss sections are in analysis.json. Original recording/settings bytes remain beneath recordings/ and settings/.", ""]
    (folder / "ANALYSIS.md").write_text("\n".join(lines), encoding="utf8")
    return result


def ingest(bundle, destination, player):
    require(isinstance(player, str) and 0 < len(player.strip()) <= 64 and not any(ord(c) < 32 for c in player), "explicit player label required (1–64 characters)")
    bundle, destination = Path(bundle), Path(destination)
    require(bundle.is_file() and not bundle.is_symlink(), "bundle must be a regular file")
    require(shutil.disk_usage(Path.home()).free >= RESERVE, "HOME must retain 15 GB free")
    with bundle.open("rb") as f:
        before = os.fstat(f.fileno())
        check_zip_header(f)
        bundle_hash = hashlib.file_digest(f, "sha256").hexdigest()
        f.seek(0)
        with zipfile.ZipFile(f) as z:
            manifest, raw_manifest, members, total = manifest_from(z)
            require(shutil.disk_usage(Path.home()).free >= RESERVE + total + 8 * MAX_MANIFEST, "import estimate would reduce HOME below 15 GB")
            slug = re.sub("[^a-z0-9]+", "-", player.lower()).strip("-")[:40] or "player"
            player_folder = destination / (slug + "-" + hashlib.sha256(player.encode()).hexdigest()[:12])
            volume = destination
            while not volume.exists():
                volume = volume.parent
            require(shutil.disk_usage(volume).free >= total + 8 * MAX_MANIFEST, "not enough space on import volume")
            player_folder.mkdir(parents=True, exist_ok=True)
            require(not player_folder.is_symlink(), "linked player destination refused")
            target = player_folder / bundle_hash
            if target.exists():
                require(not target.is_symlink(), "linked session destination refused")
                previous = strict_json((target / "import.json").read_bytes())
                require(previous.get("bundle_sha256") == bundle_hash and previous.get("collector_player") == player, "different existing session refused")
                for entry in manifest["entries"]:
                    path = target / entry["path"]
                    require(path.is_file() and not path.is_symlink() and path.stat().st_size == entry["size"] and digest(path) == entry["sha256"], "existing import changed; refusing overwrite")
                # duplicates still verify the supplied ZIP's CRC, sizes and hashes below.
            temporary = Path(tempfile.mkdtemp(prefix=".import-", dir=player_folder))
            try:
                for entry in manifest["entries"]:
                    path = temporary / entry["path"]
                    path.parent.mkdir(parents=True, exist_ok=True)
                    count = 0
                    h = hashlib.sha256()
                    with z.open(members[entry["path"]]) as src, path.open("xb") as dst:
                        while data := src.read(CHUNK):
                            count += len(data)
                            require(count <= entry["size"], "expanded member exceeds manifest")
                            h.update(data)
                            require(dst.write(data) == len(data), "short import write")
                        dst.flush()
                        os.fsync(dst.fileno())
                    require(count == entry["size"] and h.hexdigest() == entry["sha256"], "member size/hash mismatch")
                (temporary / "manifest.json").write_bytes(raw_manifest)
                analyse_folder(temporary, manifest)
                f.seek(0)
                require(hashlib.file_digest(f, "sha256").hexdigest() == bundle_hash and all(getattr(os.fstat(f.fileno()), k) == getattr(before, k) for k in ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")), "bundle changed during import")
                provenance = {"format": "spillway-manual-import", "schema": 1, "collector_player": player, "manifest_player_claim": manifest["player"], "bundle_sha256": bundle_hash, "manifest_sha256": hashlib.sha256(raw_manifest).hexdigest(), "original_entries": manifest["entries"], "analysis_sha256": digest(temporary / "analysis.json"), "identity_note": "labels are claims, not authentication"}
                provenance["import_sha256"] = hashlib.sha256(json.dumps(provenance, sort_keys=True).encode()).hexdigest()
                save_json(temporary / "import.json", provenance)
                if target.exists():
                    return {"ok": True, "duplicate": True, "path": str(target), "bundle_sha256": bundle_hash}
                temporary.rename(target)
                return {"ok": True, "duplicate": False, "path": str(target), "bundle_sha256": bundle_hash}
            finally:
                if temporary.exists():
                    shutil.rmtree(temporary)
