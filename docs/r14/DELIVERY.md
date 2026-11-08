# R14 delivery protocol

8 November 2026. R14 has its own packager and verifier. R13's tools are unchanged.
Final release results are recorded in RESULTS.md and the outer delivery's VERIFICATION.json.
A diagnostic source run or an older rejected package does not establish release acceptance.

| Tool | Responsibility |
| --- | --- |
| `tools/package-r14.py package` | freeze committed HEAD, import/export outside Git, run source goldens, create both portable ZIPs, verify, then publish |
| `tools/package-r14.py check` | verify the ZIPs and run their Linux release runtime outside the checkout |
| `tools/r14-pack-probe.gd` | inspect source identity; drive packed controls, input tapes, exact records and reload |
| `tools/check-r14.sh` | frozen source suites, exact retained-failure sets and current Overflow references |
| `tests/test_r14_delivery.py` | deliberately broken provenance, packages, runtime, cancellation and wrapper gates |
| `tools/r14_native_display.py` | optional pinned private AMD/X11 backend; refuses software fallback |

## Commands

From `projects/foldrunner`, with new output directories outside Git:

```sh
./tools/check-r14.sh --out NEW_DIR --controls --root-routes
python3 tests/test_r14_delivery.py --only ownership gates integrity preflight --evidence NEW_DIR
python3 tools/package-r14.py package --output NEW_DIR --native-backend amd --route SPEC
./tools/check-r14-pack.sh PACKAGE_DIR --evidence NEW_DIR --native-backend amd --route SPEC
python3 tests/test_r14_delivery.py --package PACKAGE_DIR --evidence NEW_DIR --only contents runtime cancel
```

Repeat `--route` for each line. Its format is
`map=ID,preset=ID,tape=PATH[,name=N][,sensitivity=S][,warmup=W][,reference=TRACE]`.
Source-only comparisons also allow `fps=F` and an explicit historical
`game_diff=A-B+C` set. Packed routes reject `fps=` and render one frame per physics tick.
The input tape declares 64, 120 or 128 Hz. No events are retimed.

Source tapes for the practice and Overflow Source runners use sensitivity
**5.729577951308232** Source units. This is a recorded replay setting, not the player's
2.5 default. R13 retains its original sensitivity. `warmup` defaults to eight neutral
steps. Historical 30 fps practice references used 32. The final one-frame-per-tick
practice goldens use 33 for F2, 32 for F1 and 34 for F3, matching the reference's
actual initial motor counter. No input events are shifted. The executor arms on a drawn-frame boundary, so a
reference recorded at another cadence can have a different settled initial state.
Fresh frozen-source goldens are generated for packed runs at the packed cadence.

`--scratch RAMDIR` moves transient source/runtime copies there. It needs at least 1 GiB
free on that separate filesystem. Before every export or native run, **/home itself must
have at least 15 GiB free**, regardless of output location. Profiles are isolated. Own
shader caches are removed after each run; traces are verified and gzipped, and sparse
movies retain selected frames instead of full PNG dumps.

## Source gates

The source wrapper extracts committed HEAD outside Git. `--source worktree` is an
explicitly labelled diagnostic snapshot including uncommitted files. The wrapper runs
startup, independent oracle, pure Source law, live collision, chronological repair,
landing guard, live loop, F4 vectors, stage practice, integer record persistence,
independent record ranking, Penstock geometry, tail return and Overflow geometry.
With `--root-routes`, all five current actual-R14-main Overflow tapes must match their
reference position, view and game state. Historical Source-2 routes remain failed
experiments, not references for the repaired runner.

Three retained sets must match exactly: the Source review's ten unsuccessful two-plane
reproductions, the loop review's deliberate manual-wheel negative, and its one analysis
negative. Their expected nonzero child exits are checked too. A new failure, a missing
artifact, an engine error or an unexpectedly passing retained case fails the wrapper.
The small gate tests exercise those refusal paths using the actual shell functions.
`--controls` also runs the original R13 candidate and lifecycle suites. These are
reported separately from Source acceptance.

## Freeze and portable contents

Packaging refuses dirty or untracked project changes, another default scene/build/save
path, a missing export preset, uncommitted helpers, an `override.cfg`, and runtimes or
licences that differ from independent pins. Fixed identity is R14, default Penstock
Yard/F2, scene `r14.tscn`, records `user://spillway_r14.cfg`, profile format 1 and user
data folder `Spillway`. The registry, family versions, rates, cvars, record keys, map
geometry, stage titles/practice poses, drawn meshes, materials and required resources
are read from the frozen source rather than copied from old reports.

Both ZIPs contain the same exported pack, an official Godot 4.7.2 release template,
README, BUILD.json and licences. Windows also has the console executable and CRLF
instructions. Linux retains mode 0755. No editor binary, loose source, harness override,
tests or tools ship. BUILD.json identifies commit/tree, canonical source archive and
per-file manifest hashes, helper hashes, runtime archive/member pins, pack, registry
and input provenance. SHA256SUMS lists exactly the two ZIPs.

The static checker reconciles embedded/external manifests with the actual Git source,
checks licences/resources/runtime bytes and verifies identical packs across platforms.
**Windows execution remains unverified.** Static ZIP checks do not imply Windows play.

## Exact Linux runtime checks

The shipped release executable starts from an empty directory beside its pack. A
separate harness copy adds an override naming the frozen probe; its runtime and pack
must be byte-identical to the ZIP. There is no source fallback.

- Startup must identify the R14 map, preset, rate, record key and runner without errors.
- Controls use actual key/mouse/menu events: all F1–F5 presets on both maps, map buttons,
  stage picker and Practise here, early-motion switch purity, F and R, pause and Quit.
  Identity, rate, HUD, hull family and window title follow the selected preset. Stage
  practice is unrecorded and R returns to a clean normal spawn.
- Drawn course meshes need vertices, visibility, camera-frustum presence and a drawn
  walkable surface at a camera ray hit. Loaded modules/materials must match the freeze.
- Each normal-spawn input tape must finish clean, ordered, zero-respawn, with exactly
  one motor step and the declared delta per tick. The packed trace must equal its fresh
  source golden at **0.0 m** position difference. The Python comparison also requires
  exact yaw, clock and progress; no old initialization discrepancy is waived.
- First best, every split and every segment are independently converted to physics
  ticks. The profile must contain those exact integer fields and their encoding/rate.
  Human-readable float summaries may round through ConfigFile, but they are never the
  authority for ranking or reload. A second process must restore the canonical seconds
  from all integer values exactly and leave the profile unchanged.
- Earlier profile sentinels stay untouched. A replay sensitivity override is not saved.
  Pause displays the actual best; its Quit button exits zero. Owned processes/displays
  must be gone afterward.

The probe puts its live clock through Godot's JSON reader before its reference compare:
that reader rounds some 1/120 values differently from Python. The independent Python
comparison then checks both written traces exactly. This corrects a parser mismatch
without widening movement or timing tolerances.

`--native-backend amd` uses pinned Weston with explicit private Xwayland displays
190–199. Each game must hold amdgpu renderD128, accumulate kernel GPU drawing time and
log an AMD device. The verifier records this evidence and refuses fallback. Default
`xvfb` remains a software-rendered alternative. Neither backend measures physical
input latency or Mike's desktop pacing. Both use engine-injected inputs and Dummy audio.

## Results and limits

The interrupted worker's older diagnostic packages were incomplete and were stopped;
root took ownership of its seven tool files. Their preserved logs are under outer
`checkpoints/spillway/r14/delivery-takeover/obsolete-diagnostic/`. The old float-rounding
allowance was replaced with exact integer checks, current Source-3 traces replaced old
routes, stage-picker checks were added, and a retained-review exit bug was repaired.
Current source/package results must be read from their own summaries, never those old
packages. Root ownership/gate regressions initially pass 12/12.

A tape establishes one execution on one source and machine, not forgiving discovery,
binary CS fidelity or enjoyment. See SOURCE-IMPLEMENTATION.md for reconstructed vanilla
stamina/clamps and contact limits. See QUIT-REVIEW.md for the engine's private-Wayland
shutdown race. Later GPU checks use X11; a clean bounded series is not universal proof.

## Independent verifier challenge and repairs

DELIVERY-REVIEW.md records reproduced false acceptance in the earlier helper functions,
not a whole-package exploit. The repaired comparisons validate nonempty duration,
ordered unique tick identities, three finite coordinates, finite yaw and typed game
fields before numeric equality. Source runs also require successful delivery/order,
neutral completion, clean cleanup, no integrity flags and error-free logs. A supplied
external mismatch now rejects before any package/recheck proceeds. The shell suites
use bounded Python owners, with cancellation forwarded even when only the shell is
signalled. Packed drawn-frame HUD checks cover label visibility/bounds, measured speed,
last jump gain and directional-sync counts. Root's asserting regressions are
`tests/test_r14_verifier_hardening.py`; the original review script remains an honest
observational reproduction, not a pass/fail release gate.
