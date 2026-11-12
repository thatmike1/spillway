#!/usr/bin/env python3
"""Export the current source and prove the packed Linux build starts outside the checkout."""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("linux", "windows"), default="linux")
    parser.add_argument("--out", required=True, type=Path, help="new output directory")
    args = parser.parse_args()
    engine.check_pin()
    output = args.out.resolve()
    if output.exists():
        raise RuntimeError("Choose a new --out directory.")
    template = "linux_release.x86_64" if args.platform == "linux" else "windows_release_x86_64.exe"
    if engine.sha(engine.TEMPLATES / template) != engine.TEMPLATE_HASHES[template]:
        raise RuntimeError("The official Godot 4.7.2 release template hash differs.")
    if engine.temporary_headroom() < 600 * 2**20:
        raise RuntimeError("Need 600 MiB temporary/quota headroom.")
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="spillway-export-") as temporary:
        work = Path(temporary)
        sys.path.insert(0, str(engine.PROJECT / "verification"))
        import parity
        source = work / "source"
        source_files = parity.snapshot(source)
        profile = work / "profile"
        profile.mkdir()
        engine.run(["--headless", "--editor", "--path", source, "--import"], cwd=source,
                   profile=profile, log=output / "import.log")
        pack = output / "Spillway.pck"
        engine.run(["--headless", "--path", source, "--export-pack", "Repository Pack", pack],
                   cwd=source, profile=profile, log=output / "export.log", timeout=300)
        executable = output / ("Spillway.x86_64" if args.platform == "linux" else "Spillway.exe")
        shutil.copy2(engine.TEMPLATES / template, executable)
        if args.platform == "linux":
            executable.chmod(0o755)
        for name in ("LICENSE.txt", "COPYRIGHT.txt"):
            shutil.copy2(engine.PROJECT / "licenses" / ("GODOT-" + name), output / ("GODOT-" + name))
        for notice in (engine.PROJECT / "assets").rglob("*"):
            if notice.is_file() and any(word in notice.name.lower() for word in ("license", "licence", "copyright", "manifest", "provenance")):
                target = output / "notices" / notice.relative_to(engine.PROJECT / "assets")
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(notice, target)
        result = {"source_files": source_files, "platform": args.platform, "pack_sha256": engine.sha(pack),
                  "template_sha256": engine.sha(executable), "startup": "not executed on this platform"}
        if args.platform == "linux":
            empty = work / "empty"
            empty.mkdir()
            with engine.locked(), (output / "startup.log").open("w") as log:
                import subprocess
                launch = subprocess.run([str(executable), "--headless", "--audio-driver", "Dummy",
                                         "--quit-after", "120", "--", "--no-records", "--no-run-recordings"],
                                        cwd=empty, env=engine.environment(work / "startup-profile"),
                                        stdout=log, stderr=subprocess.STDOUT, timeout=90)
            text = (output / "startup.log").read_text()
            if launch.returncode or "r21:" not in text or any(t in text for t in ("ERROR:", "Parse Error")):
                raise RuntimeError("Packed startup failed; read " + str(output / "startup.log"))
            result["startup"] = {"exit": launch.returncode, "outside_checkout": True,
                                 "log_sha256": engine.sha(output / "startup.log")}
        (output / "BUILD.json").write_text(json.dumps(result, indent=1) + "\n")
        print("Exported " + str(executable), flush=True)


if __name__ == "__main__":
    main()
