#!/usr/bin/env bash
# spillway supersedes source fidelity; see docs/reboot/VERIFICATION.md for retired suites.
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./tools/check-spillway.sh "$@"
