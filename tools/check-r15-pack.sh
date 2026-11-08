#!/usr/bin/env bash
# exact-pack check of published r15 zips: the shipped linux release runtime and pack, run from
# empty directories on a private display, plus static windows checks. see docs/r15/DELIVERY.md.
# tools/check-r15-pack.sh PACKAGE_DIR --evidence NEW_DIR [--route map=ID,preset=ID,tape=PATH[,sensitivity=S]]...
set -euo pipefail
exec python3 -I "$(cd "$(dirname "$0")" && pwd)/package-r15.py" check "$@"
