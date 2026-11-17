#!/usr/bin/env python3
"""Check style suspension in a small external project with a private engine profile."""
import argparse
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
import engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="new external evidence directory")
    parser.add_argument("--baseline-style", type=Path, help="optional untouched scorer for byte comparisons")
    args = parser.parse_args()
    out = args.out.resolve()
    if out.is_relative_to(engine.PROJECT):
        parser.error("--out must be outside the checkout")
    engine.check_pin()
    out.mkdir(parents=True, exist_ok=False)
    source = out / "source"
    for name in ("scripts/scoring/style.gd", "tests/style_suspension.gd"):
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(engine.PROJECT / name, target)
    (source / "project.godot").write_text('config_version=5\n')
    extra = []
    if args.baseline_style:
        shutil.copy2(args.baseline_style, source / "tests/baseline.gd")
        extra = ["--baseline-style=res://tests/baseline.gd"]
    engine.run(["--headless", "--audio-driver", "Dummy", "--path", source,
                "--script", "res://tests/style_suspension.gd", "--", "--out=" + str(out), *extra],
               cwd=source, profile=out / "profile", log=out / "engine.log")
    print("PASS; results: " + str(out / "suspension.json"))


if __name__ == "__main__":
    main()
