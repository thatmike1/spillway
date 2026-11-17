#!/usr/bin/env python3
"""check a folder or ZIP in isolation; Windows is statically checked, never executed."""
import argparse
from contextlib import contextmanager
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

sys.dont_write_bytecode = True
import engine

@contextmanager
def package_folder(path):
    path = Path(path).resolve()
    if path.is_dir():
        yield path
        return
    with tempfile.TemporaryDirectory(prefix="spillway-unzip-") as tmp:
        root = Path(tmp)
        with zipfile.ZipFile(path) as archive:
            total = 0
            for item in archive.infolist():
                target = (root / item.filename).resolve()
                if not target.is_relative_to(root) or (item.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError("Unsafe ZIP member: " + item.filename)
                total += item.file_size
                if total > 2 * 1024**3:
                    raise ValueError("Package exceeds 2 GiB extraction limit")
            archive.extractall(root)
        packs = list(root.rglob("Spillway.pck"))
        if len(packs) != 1:
            raise ValueError("Expected exactly one Spillway.pck")
        yield packs[0].parent


def static_check(folder, platform, linux_pack=None):
    template = "linux_release.x86_64" if platform == "linux" else "windows_release_x86_64.exe"
    executable = folder / ("Spillway.x86_64" if platform == "linux" else "Spillway.exe")
    for name in (executable.name, "Spillway.pck", "GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt", "BUILD.json"):
        if not (folder / name).is_file():
            raise ValueError("Missing package file: " + name)
    if engine.sha(executable) != engine.TEMPLATE_HASHES[template]:
        raise ValueError("Release template hash differs")
    pack = folder / "Spillway.pck"
    with pack.open("rb") as stream:
        magic = stream.read(4)
    if magic != b"GDPC":
        raise ValueError("Not a Godot pack")
    build = json.loads((folder / "BUILD.json").read_text())
    if build.get("platform") != platform or build.get("pack_sha256") != engine.sha(pack) or build.get("template_sha256") != engine.sha(executable):
        raise ValueError("BUILD.json does not describe these bytes")
    for source_name, digest in build.get("source_files", {}).items():
        source = Path(source_name)
        if not source_name.startswith("assets/") or not any(word in source.name.lower() for word in ("license", "licence", "copyright", "manifest", "provenance")):
            continue
        notice = (folder / "notices" / source.relative_to("assets")).resolve()
        if not notice.is_relative_to(folder.resolve()) or not notice.is_file() or engine.sha(notice) != digest:
            raise ValueError("Missing or changed package notice: " + source_name)
    if platform == "linux" and "scripts/persistence/package_probe.gd" not in build.get("source_files", {}):
        raise ValueError("Export lacks the opt-in package probe; build the integrated r22 source first")
    result = {"platform": platform, "pack_sha256": engine.sha(pack), "executable_sha256": engine.sha(executable)}
    if platform == "windows":
        if linux_pack is None or engine.sha(pack) != engine.sha(linux_pack):
            raise ValueError("Windows pack must be byte-identical to the checked Linux pack (resources included)")
        result.update(executed=False, resources="byte-identical to Linux pack", limitation="Windows was not executed")
    return result


def check_linux(folder, out):
    empty = out / "empty"
    empty.mkdir()
    private = out / "private-profile"
    profile = out / "spillway_r16.cfg"
    executable = folder / "Spillway.x86_64"
    # zip permission bits are not portable; execute a private copy of the exact pinned bytes.
    runtime = out / executable.name
    shutil.copyfile(executable, runtime)
    runtime.chmod(0o700)
    shutil.copyfile(folder / "Spillway.pck", out / "Spillway.pck")
    result = {}
    for phase in ("first", "reload"):
        log = out / (phase + ".log")
        command = [str(runtime), "--headless", "--audio-driver", "Dummy", "--", "--r16-profile=" + str(profile), "--no-run-recordings", "--r22-package-check=" + str(out / (phase + ".json"))]
        if phase == "reload":
            command.append("--package-reload")
        with engine.locked(), log.open("w") as stream:
            launch = subprocess.run(command, cwd=empty, env=engine.environment(private), stdout=stream, stderr=subprocess.STDOUT, timeout=180)
        text = log.read_text(errors="replace")
        receipt_path = out / (phase + ".json")
        receipt = json.loads(receipt_path.read_text()) if receipt_path.is_file() else {}
        if launch.returncode or not receipt.get("ok") or "PACKAGE RESULT " not in text or any(x in text for x in ("ERROR:", "Parse Error", "PACKAGE FAILURE:")):
            raise RuntimeError("Package probe failed: " + str(log) + "\n" + text[-3000:])
        result[phase] = {"exit": launch.returncode, "log_sha256": engine.sha(log)}
        if phase == "first":
            result["maps"] = receipt["maps"]
    result.update(executed=True, outside_checkout=True, private_profile=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--platform", choices=("linux", "windows"), default="linux")
    parser.add_argument("--linux-pack", type=Path, help="required identical checked Linux PCK for Windows")
    parser.add_argument("--out", required=True, type=Path, help="new external evidence directory")
    args = parser.parse_args()
    out = args.out.resolve()
    if out.is_relative_to(engine.PROJECT):
        raise ValueError("Evidence must be outside the checkout")
    out.mkdir(parents=True, exist_ok=False)
    result = {"ok": False}
    try:
        with package_folder(args.package) as folder:
            result.update(static_check(folder, args.platform, args.linux_pack))
            if args.package.is_file():
                result["artifact_sha256"] = engine.sha(args.package)
            if args.platform == "linux":
                result.update(check_linux(folder, out))
            result["ok"] = True
    except Exception as error:
        result["error"] = str(error)
        raise
    finally:
        (out / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
        # retain logs and receipts, not duplicate packs, runtime or private caches.
        for name in ("Spillway.pck", "Spillway.x86_64"):
            (out / name).unlink(missing_ok=True)
        shutil.rmtree(out / "private-profile", ignore_errors=True)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
