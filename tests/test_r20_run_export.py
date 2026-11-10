#!/usr/bin/env python3
"""inspect real service ZIPs and challenge offline ingest; negative ZIPs only are authored here."""
from __future__ import annotations
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import stat
import struct
import sys
import zipfile
import zlib

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
import r20_run_bundle as m


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    a = parser.parse_args()
    a.out.mkdir(parents=True, exist_ok=False)
    checks = []
    def check(ok, label):
        checks.append({"ok": bool(ok), "check": label})
        print("PASS" if ok else "FAIL", label, flush=True)
        if not ok:
            raise AssertionError(label)
    fixture = json.loads((a.fixture / "export-checks.json").read_text())
    check(fixture["ok"], "real GUI/physics/settings/path checks passed")
    bundle = Path(fixture["bundles"][0])
    with zipfile.ZipFile(bundle) as z:
        manifest = json.loads(z.read("manifest.json"))
        originals = {i.filename: z.read(i) for i in z.infolist() if not i.is_dir()}
    for entry in manifest["entries"]:
        data = originals[entry["path"]]
        check(len(data) == entry["size"] and hashlib.sha256(data).hexdigest() == entry["sha256"], "independent ZIP member/hash " + entry["path"])
    result = m.ingest(bundle, a.out / "players", "Actual Friend")
    check(result["ok"] and not result["duplicate"], "actual service ZIP imported and analyzed")
    destination = Path(result["path"])
    report = json.loads((destination / "analysis.json").read_text())
    classes = {r["classification"] for r in report["attempts"]}
    check(classes == {"complete", "partial", "aborted", "corrupt", "unsupported"}, "five distinct recording classifications")
    check(any(r["classification"] == "complete" and r["sample_count"] == 0 and r["outcome"]["kind"] == "quit" for r in report["attempts"]), "valid zero-sample quit remains complete data without finished claim")
    check(any(r["classification"] == "partial" and r["sample_count"] == fixture["active_ticks"] for r in report["attempts"]), "Python original strict reader recovers exact active buffered tick count")
    for entry in manifest["entries"]:
        check((destination / entry["path"]).read_bytes() == originals[entry["path"]], "import preserves every original byte " + entry["path"])
    before = {str(p.relative_to(destination)): m.digest(p) for p in destination.rglob("*") if p.is_file()}
    check(m.ingest(bundle, a.out / "players", "Actual Friend")["duplicate"], "duplicate ZIP ingest is idempotent")
    check(before == {str(p.relative_to(destination)): m.digest(p) for p in destination.rglob("*") if p.is_file()}, "duplicate ingest overwrites nothing")
    second = m.ingest(Path(fixture["bundles"][1]), a.out / "players", "Actual Friend")
    check(second["ok"] and second["path"] != result["path"], "second actual service session kept separately")
    third = m.ingest(bundle, a.out / "players", "Different Friend")
    check(third["path"] != result["path"], "explicit collector player separates unauthenticated manifest claims")
    tampered = destination / manifest["entries"][0]["path"]
    tampered.write_bytes(b"collector modified this file")
    try:
        m.ingest(bundle, a.out / "players", "Actual Friend")
        raise AssertionError("changed import accepted")
    except m.BundleError:
        check(tampered.read_bytes() == b"collector modified this file", "changed prior session refused without overwrite")
    tampered.write_bytes(originals[manifest["entries"][0]["path"]])

    def negative(label, *, change_manifest=None, change_members=None, raw_transform=None):
        doc = copy.deepcopy(manifest)
        files = dict(originals)
        if change_manifest:
            change_manifest(doc)
        files["manifest.json"] = json.dumps(doc, sort_keys=True).encode()
        rows = list(files.items())
        if change_members:
            rows = change_members(rows)
        path = a.out / (label + ".zip")
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as z:
            for name, data in rows:
                z.writestr(name, data)
        if raw_transform:
            path.write_bytes(raw_transform(path.read_bytes()))
        dest = a.out / ("reject-" + label)
        try:
            m.ingest(path, dest, "Hostile fixture")
        except (m.BundleError, zipfile.BadZipFile, ValueError, RuntimeError, OSError, EOFError, zlib.error):
            check(not dest.exists() or not any(p.name == "import.json" or p.name.startswith(".import-") for p in dest.rglob("*")), "reject/clean " + label)
        else:
            raise AssertionError("accepted hostile transport: " + label)
        path.unlink()
        if dest.exists():
            shutil.rmtree(dest)

    negative("bad-format", change_manifest=lambda d: d.update(format="wrong"))
    negative("bad-schema", change_manifest=lambda d: d.update(schema=2))
    negative("bool-schema", change_manifest=lambda d: d.update(schema=True))
    negative("unknown-field", change_manifest=lambda d: d.update(exec="never"))
    negative("bad-player", change_manifest=lambda d: d.update(player="bad\nname"))
    negative("bad-time", change_manifest=lambda d: d.update(created_utc="yesterday"))
    negative("bad-profile", change_manifest=lambda d: d.update(current_profile="outside.cfg"))
    negative("size-type", change_manifest=lambda d: d["entries"][0].update(size=True))
    negative("size-mismatch", change_manifest=lambda d: d["entries"][0].update(size=123456))
    negative("bad-sha", change_manifest=lambda d: d["entries"][0].update(sha256="0" * 64))
    negative("missing", change_members=lambda rows: rows[1:])
    negative("extra", change_members=lambda rows: rows + [("recordings/extra.r16run", b"x")])
    negative("extra-dir", change_members=lambda rows: rows + [("unrelated/", b"")])
    negative("duplicate", change_members=lambda rows: rows + [rows[0]])
    negative("case-collision", change_members=lambda rows: rows + [(rows[0][0].upper(), rows[0][1])])
    negative("duplicate-entry", change_manifest=lambda d: d["entries"].append(copy.deepcopy(d["entries"][0])))
    for i, name in enumerate(("../escape", "/absolute", "C:/drive", "C:drive", "recordings\\bad", "recordings/a/../../bad", "recordings/a\x01bad", "recordings/a\x7fbad", "recordings//bad", "recordings/./bad", "recordings/CON.txt", "recordings/name.", "recordings/name ")):
        negative("unsafe-name-" + str(i), change_members=lambda rows, n=name: rows + [(n, b"x")])
    def special(mode):
        def change(rows):
            item = zipfile.ZipInfo("recordings/special")
            item.create_system = 3
            item.external_attr = mode << 16
            return rows + [(item, b"target")]
        return change
    for mode, name in ((stat.S_IFLNK | 0o777, "symlink"), (stat.S_IFIFO | 0o600, "fifo"), (stat.S_IFCHR | 0o600, "device"), (stat.S_IFSOCK | 0o600, "socket")):
        negative(name, change_members=special(mode))
    negative("duplicate-json", change_members=lambda rows: [(n, b'{"format":"a","format":"b"}' if n == "manifest.json" else b) for n, b in rows])
    negative("nonfinite-json", change_members=lambda rows: [(n, b'{"schema":NaN}' if n == "manifest.json" else b) for n, b in rows])
    negative("broken-json", change_members=lambda rows: [(n, b'{' if n == "manifest.json" else b) for n, b in rows])
    negative("missing-manifest", change_members=lambda rows: [(n, b) for n, b in rows if n != "manifest.json"])
    negative("manifest-size", change_members=lambda rows: [(n, b' ' * (m.MAX_MANIFEST + 1) if n == "manifest.json" else b) for n, b in rows])
    def patch_flag(data):
        data = bytearray(data)
        for sig, offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
            pos = data.find(sig)
            flags = struct.unpack_from("<H", data, pos + offset)[0]
            struct.pack_into("<H", data, pos + offset, flags | 1)
        return data
    negative("encryption", raw_transform=patch_flag)
    def end_patch(offset, value, fmt):
        def transform(data):
            data = bytearray(data)
            pos = data.rfind(b"PK\x05\x06")
            struct.pack_into(fmt, data, pos + offset, value)
            return data
        return transform
    negative("excess-count", raw_transform=end_patch(10, 2 * m.MAX_FILES + 2, "<H"))
    negative("central-size", raw_transform=end_patch(12, 4 * m.MAX_MANIFEST + 1, "<I"))
    negative("multidisk", raw_transform=end_patch(4, 1, "<H"))
    negative("truncated-zip", raw_transform=lambda data: data[:-10])
    negative("trailing-zip", raw_transform=lambda data: data + b"junk")
    def oversized(data):
        data = bytearray(data)
        pos = data.find(b"PK\x01\x02")
        struct.pack_into("<I", data, pos + 24, m.MAX_FILE + 1)
        return data
    negative("oversized-member", raw_transform=oversized)
    def crc_corrupt(data):
        data = bytearray(data)
        pos = data.find(b"PK\x03\x04")
        n, extra = struct.unpack_from("<HH", data, pos + 26)
        data[pos + 30 + n + extra] ^= 0x40
        return data
    negative("bad-crc", raw_transform=crc_corrupt)
    negative("too-many-entries", change_manifest=lambda d: d.update(entries=[copy.deepcopy(d["entries"][0])] * (m.MAX_FILES + 1)))
    def total_expansion(data):
        data = bytearray(data)
        pos = 0
        while True:
            pos = data.find(b"PK\x01\x02", pos)
            if pos < 0:
                break
            n = struct.unpack_from("<H", data, pos + 28)[0]
            name = bytes(data[pos + 46:pos + 46 + n]).decode()
            if name != "manifest.json":
                struct.pack_into("<I", data, pos + 24, m.MAX_FILE)
            pos += 46 + n
        return data
    negative("total-expansion", raw_transform=total_expansion)
    negative("empty-archive", raw_transform=lambda data: b"")
    reader, _ = m.load_reader()
    for ticks, label in (([0, 2147483647], "huge-tick-loop"), ([4, 1], "nonmonotonic-ticks")):
        rec = reader.Recording(Path("generated-boundary.r16run"))
        rec.columns["tick"] = ticks
        try:
            m.sample_safety(rec)
        except m.BundleError:
            check(True, "bound original analysis " + label)
        else:
            raise AssertionError(label)
    print(f"{len(checks)} transport/content checks passed")
    m.save_json(a.out / "summary.json", {"ok": True, "checks": checks, "attempt_classifications": {k: sum(r['classification'] == k for r in report['attempts']) for k in classes}, "limits": {k: getattr(m, k) for k in ("MAX_FILES", "MAX_FILE", "MAX_TOTAL", "MAX_ARCHIVE", "MAX_MANIFEST", "MAX_DECODED_FILE", "MAX_DECODED_TOTAL", "MAX_TICKS", "MAX_INPUTS")}})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
