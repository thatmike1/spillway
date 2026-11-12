#!/usr/bin/env python3
"""manually import a friend's bounded, offline Spillway run bundle."""
import argparse
import json
from pathlib import Path
import sys
import zipfile
import zlib

sys.dont_write_bytecode = True

# isolated mode deliberately excludes cwd; load only the sibling implementation shipped with this script.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_bundle import BundleError, ingest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--player", required=True, help="collector-assigned player label (unauthenticated)")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = ingest(args.bundle, args.output, args.player)
    except (ValueError, OSError, zipfile.BadZipFile, RuntimeError, EOFError, OverflowError, zlib.error) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}), file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
