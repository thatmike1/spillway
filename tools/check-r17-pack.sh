#!/usr/bin/env bash
# check the exact r17 portable zips with isolated profiles and a private amd display.
set -euo pipefail
exec python3 -I "$(cd "$(dirname "$0")" && pwd)/package-r17.py" check "$@"
