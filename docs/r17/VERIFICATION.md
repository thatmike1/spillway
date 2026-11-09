# R17 visual verification

The delivered runtime is frozen at `b406e2d2ad62e7353861b6aefdc9534702d1a4eb`, built on delivered R16 `7261ba593`. Later documentation and verification-tool commits do not change its runtime assets. The original R16 sources, controls, recordings and identities remain the comparison contract.

Local evidence and private references are outside Git under `/home/thatmike1/foldrunner-build-2026-11-05/look/`. Delivery is under the sibling `delivery/spillway-r17/`. Keep at least 15,000,000,000 bytes free on HOME. The native helper uses explicitly owned private displays and bounded RAM scratch; it must preserve desktop :0.

## Native views and motion

Run from the project. The pinned Godot 4.7.2 editor and retained R16 input routes must be installed at the paths declared by the helpers.

```sh
python3 tools/look-native.py --out /absolute/new/views --script res://tools/r17-views.gd -- --map=breakwater
python3 tools/r17-films.py breakwater --evidence-root /absolute/new/movie-evidence --movie-dir /absolute/new/movies
python3 tools/r17-films.py overflow --preset quake3_inspired128 --seconds 10 --evidence-root /absolute/new/movie-evidence --movie-dir /absolute/new/movies
python3 tools/r17-gallery.py
```

The view helper captures matched old/new cameras while paused. Actual PNGs in this private display setup are 1296×736, independently checked rather than inferred from the requested window size. Movies are 1280×720 at60fps, using real input and the player camera. The clip helper trims from the first actual draw, compresses trace evidence and removes its full scratch movie. Inspect every clip opening and motion sequence. A contact-sheet blank tile can be padding; it is not proof of a blank game frame.

The gallery reads the retained outer media summaries and GPU analysis. It labels GPU results final only when the parent's audit source and PCK match delivery BUILD.json; otherwise it explicitly shows the older baseline. It does not grant visual approval.

## Physics, recordings and ghosts

The committed full-matrix driver and independent reader audit are:

```sh
python3 tools/check-r17-parity.py --r17 b406e2d2ad62e7353861b6aefdc9534702d1a4eb --out /absolute/new/full-parity
python3 tests/r17_parity_audit.py /absolute/completed/full-parity
```

Those commands define a fresh full16route run; they are not a claim that a second full16run was executed on this commit. The retained full16proof measures earlier source7c82e0877. Final b406 evidence measures24fresh R17 plays across all8maps (old/new/real moving-and-paused L), against16independently validated R16 baseline plays. Its exact external driver, unchanged comparators, single audit matrix-size adaptation, mutation tests, source hashes and reuse receipts are retained in outer `evidence/r17-b406-parity/`. Follow its README to reproduce into a fresh output directory. Never reuse earlier R17 plays after a runtime change.

## Exact packages and GPU

The package interface, tested on the frozen source, is:

```sh
python3 -I tools/package-r17.py package --output /absolute/new/delivery --scratch /tmp --display 198 --deadline 600
```

It composes delivered R16 acceptance, verifies official release templates and source manifests, and runs packed controls, a clean course, recording/ghost reload and negative pack controls from outside source. Final additive no-probe OS input and all-frame label observers are retained under the delivery evidence. Missing/malformed packs must refuse with nonzero exit; a missing required sky exits3 before the host, including old look.

`tools/r17-gpu-probe.gd` is an external autoload for a separate copy of the official release executable plus the exact delivered PCK. Never put its override.cfg in the playable extraction. It rejects editor/debug execution, wrong executable/PCK hashes and wrong viewport dimensions. The paused-camera protocol is two alternating look orders,40warmup and120measured frames per look/view/order. All8maps at720p and the primary1440p resolution produce16,320samples. Keep raw GPU/CPU/frame timings, independently recompute pooled medians/p95 and report every increase. Fixed views do not establish moving frame pacing or physical latency.

Desktop harnesses, hardware/device proofs, cleanup receipts and exact executed helper hashes are in outer `evidence/r17-desktop-gpu-final/` for the accepted final run. The earlier `r17-desktop-gpu/` is a separate5e1004fd baseline. Windows ZIP structure/runtime/CRC/licence checks are distinct from native Windows execution, which remains unverified when no Windows environment is available.
