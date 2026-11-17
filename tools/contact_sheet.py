#!/usr/bin/env python3
"""Assemble native PNG captures without changing the source frames."""
import argparse
from pathlib import Path
import subprocess


def create(frames, output):
    frames = [Path(p) for p in frames]
    if not frames:
        raise ValueError("no PNG frames to assemble")
    subprocess.run(["montage", *map(str, frames), "-thumbnail", "320x180", "-tile", "4x",
                    "-geometry", "+4+4", "-background", "#202020", str(output)], check=True, timeout=120)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames", type=Path, nargs="+")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    create(args.frames, args.out)
