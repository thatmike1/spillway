#!/usr/bin/env python3
"""verify r16 preserves the delivered r15 runtime and its portable comparison."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile

R15_COMMIT = "8a254d16455d69cee6df8ca37f82c53d04e6ab4c"
R15_ZIPS = {
    "spillway-2026.11.08-r15-linux-x86_64-8a254d16.zip": "e7da4896bbe29888382fdf4b29886a811a5c29a4fd99a707c2b3d95d9c943418",
    "spillway-2026.11.08-r15-windows-x86_64-8a254d16.zip": "b41646efd844728adbfa6df934f73b2573c3de6853bea8c1072f00b32336a450",
}
PROJECT = Path(__file__).resolve().parents[1]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def baseline(project: Path) -> dict[str, bytes]:
    # git supplies the immutable comparison; no checkpoint copy is trusted as source.
    prefix = subprocess.check_output(["git", "-C", str(project), "rev-parse", "--show-prefix"], text=True).strip().rstrip("/")
    top = subprocess.check_output(["git", "-C", str(project), "rev-parse", "--show-toplevel"], text=True).strip()
    tree = R15_COMMIT + (":" + prefix if prefix else "")
    data = subprocess.check_output(["git", "-C", top, "archive", "--format=tar", tree,
                                    "scripts", "shaders", "scenes", "assets", "project.godot", "export_presets.cfg"])
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        return {item.name: archive.extractfile(item).read() for item in archive if item.isfile()}


def settings(text: str) -> dict[str, str]:
    section = ""
    out = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif "=" in line:
            key, value = line.split("=", 1)
            name = section + "/" + key.strip()
            if name in out:
                raise ValueError("duplicate setting " + name)
            out[name] = value.strip()
        else:
            raise ValueError("unrecognized settings line: " + line[:80])
    return out


def verify(project: Path, old: dict[str, bytes], *, allow_r15_default: bool = False,
           delivery: Path | None = None) -> dict:
    rows = []

    def record(name, ok, detail=""):
        rows.append({"name": name, "ok": bool(ok), "detail": detail})

    for name, data in sorted(old.items()):
        if name in ("project.godot", "export_presets.cfg"):
            continue
        path = project / name
        current = path.read_bytes() if path.is_file() and not path.is_symlink() else None
        record(name, current == data, {"r15_sha256": sha(data), "actual_sha256": sha(current) if current is not None else None})
    try:
        prior = settings(old["project.godot"].decode())
        now = settings((project / "project.godot").read_text())
        allowed = {"application/config/version", "application/run/main_scene"}
        record("all other project settings remain R15's", {k: v for k, v in prior.items() if k not in allowed}
               == {k: v for k, v in now.items() if k not in allowed})
        expected = {'"res://scenes/r16.tscn"'}
        if allow_r15_default:
            expected.add('"res://scenes/r15.tscn"')
        record("default scene is R16" if not allow_r15_default else "development default is explicitly labelled",
               now.get("application/run/main_scene") in expected, now.get("application/run/main_scene"))
        record("version names R16" if not allow_r15_default else "development version is explicitly labelled",
               allow_r15_default or now.get("application/config/version") == '"2026.11.09-r16"', now.get("application/config/version"))
        exports = settings((project / "export_presets.cfg").read_text())
        exports_old = settings(old["export_presets.cfg"].decode())
        record("all existing export presets remain R15's", all(exports.get(k) == v for k, v in exports_old.items()))
    except (OSError, UnicodeError, ValueError) as error:
        record("project and export metadata parse", False, str(error))
    if delivery is not None:
        for name, digest in R15_ZIPS.items():
            path = delivery / name
            actual = sha(path.read_bytes()) if path.is_file() else None
            record("frozen R15 download: " + name, actual == digest, {"expected": digest, "actual": actual})
    return {"format": "spillway-r16-preservation-1", "r15_source": R15_COMMIT,
            "project": str(project), "development_only": allow_r15_default,
            "downloads_checked": delivery is not None, "checks": len(rows),
            "failed": sum(not r["ok"] for r in rows), "results": rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--r15-delivery", type=Path)
    parser.add_argument("--allow-r15-default", action="store_true", help="development diagnostic only; never release acceptance")
    args = parser.parse_args()
    try:
        report = verify(args.project, baseline(PROJECT), allow_r15_default=args.allow_r15_default, delivery=args.r15_delivery)
    except (OSError, subprocess.CalledProcessError, tarfile.TarError) as error:
        parser.exit(2, "preservation comparison unavailable: %s\n" % error)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print("R15 preservation: %d checks, %d failed%s" % (report["checks"], report["failed"], "; development diagnostic" if args.allow_r15_default else ""))
    for row in report["results"]:
        if not row["ok"]:
            print("FAIL " + row["name"])
    return int(report["failed"] != 0)


if __name__ == "__main__":
    raise SystemExit(main())
