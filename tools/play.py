#!/usr/bin/env python3
"""Open Spillway with the pinned editor and shared engine lock."""
import argparse
import subprocess
import engine

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--editor", action="store_true")
args, extra = parser.parse_known_args()
engine.check_pin()
with engine.locked():
    raise SystemExit(subprocess.call([str(engine.GODOT), "--path", str(engine.PROJECT), *(["--editor"] if args.editor else []), *extra]))
