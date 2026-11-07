#!/usr/bin/env bash
# exact-pack check of published r13 zips: the shipped linux release runtime and pack, run from
# empty directories on a private display, plus static windows checks. see docs/momentum/DELIVERY.md.
# tools/check-overflow-pack.sh PACKAGE_DIR --evidence NEW_DIR --stages "A,B,Finish" [--tape EXPANDED --reference TRACE]
set -euo pipefail
exec python3 -I "$(cd "$(dirname "$0")" && pwd)/package-overflow.py" check "$@"
