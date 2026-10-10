"""Install only official web templates from an already downloaded release archive.

No engine launch, graphics or browser. zipfile checks member CRC while reading.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import zipfile


def install(archive: Path, destination: Path) -> list[Path]:
    installed = []
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as templates:
        for name in ("web_debug.zip", "web_release.zip", "web_nothreads_debug.zip", "web_nothreads_release.zip"):
            member = next((info for info in templates.infolist()
                           if Path(info.filename).name == name), None)
            if member is None:
                raise RuntimeError(f"Official archive missing {name}")
            target = destination / name
            pending = target.with_suffix(".tmp")
            with templates.open(member) as source, pending.open("wb") as output:
                shutil.copyfileobj(source, output, length=1024 * 1024)
            pending.replace(target)
            installed.append(target)
    return installed


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--destination", type=Path, default=Path(os.environ["APPDATA"]) /
                        "Godot/export_templates/4.7.2.stable")
    args = parser.parse_args()
    for path in install(args.archive, args.destination):
        print(f"Installed {path.name}: {path.stat().st_size:,} bytes")
