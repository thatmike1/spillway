# R15 packed input observer: independent review

Scope: commit f023d40e, `packed_input_audit()` in `tools/package-r15.py`, the capture added to `tools/r15-pack-probe.gd` and its `check_runs` caller. This is a component review in source mode. It is not R15 release acceptance. No export, release runtime or native render ran, and the missing course modules were not counted.

## Verdict

No finding survived in which a capture or input regression passes the audit. The audit rejects every real injection regression tried and every broken record tried. It accepts every real crouch timing tried. Two low findings and two scope notes remain for root.

## Method

`python3 -I tests/r15_pack_observer_review.py --out DIR --scratch TMP --retained <packed-observer/final> --course-run <whiteout-integration/replays/gantry>`

The script freezes committed HEAD with `git archive` into scratch, adds the review harness (`tests/r15_pack_observer_review.gd`) and imports the snapshot with the pinned editor. It plays labelled cases through a subclass of the exact probe, then judges each capture with the frozen `packed_input_audit()`. Expectations are fixed in `build_cases()` before any engine output. The harness changes only how it injects input. Game, motor and probe bytes stay frozen. Their hashes were checked before and after the run, and the snapshot matched the checkout.

Executed sources: package-r15.py `0dddd2a9…`, r15-pack-probe.gd `5aab9d14…` (both equal root's EXECUTED-SOURCES), momentum-tape.py `ec7544ee…`, r15_source_player.gd `e06a545d…`, r15_main.gd `dc5621ff…`. Review harness hashes are in outer `checkpoints/spillway/r15/pack-observer-review/EXECUTED-REVIEW-SOURCES.json`.

Result: `final/RESULTS.json` meets all 377 fixed expectations, with engine exit 0, no engine errors, scratch removed and frozen files unchanged.

| group | cases | expected | result |
|---|---|---|---|
| injection regressions: dropped release, ctrl one tick late, ctrl one tick early, keycode-only event, `action_press` only, mouse after the motor, pack sensitivity 2.0 against source 2.5 | 7 | refuse | all refused, each for the matching input or view reason |
| forced respawn via the game's `respawn()` before the motor (labelled) | 1 | refuse | refused: unexplained previous origin, view changed |
| baselines F2/F5, R13 at 120 Hz holding ctrl | 3 | pass | pass |
| crouch press sweep 6..103, release sweep 36..111, taps, duck-jump releases, F5 presses | 230 | pass | pass |
| roof hops, release in flight under the slab, stand at the first clear tick | 20 | pass | pass: 5 stand in air, 15 on the floor |
| broken records/settings on the review baseline plus root's retained air-f2, r13-control and Whiteout captures | 113 | refuse | all refused |
| root's retained captures as recorded, Whiteout judged with the executor's own `engine.json` settings | 3 | pass | pass |

Across the sweeps there were 210 air ducks, 218 air stands, 49 ground ducks, 40 ground stands and 28 blocked stands. Those include air stands blocked by floor proximity just before landing, and releases on the landing tick and the tick before it. Every air transition had exactly one valid hull compensation. An independent check that the observed box matches the `ducked` flag on every tick found no mismatch.

Broken-data controls cover:
- missing, None, zero, NaN, text and +1e-6 relative sensitivity
- a missing pitch limit
- a plan relabelled from 128 to 120 Hz, and from 120 to 128
- dropped, duplicated and swapped rows
- missing `keys`/`physical` fields, string or duplicate actions, an extra held key
- bool and float counters, nonfinite yaw or mouse, a tick-0 edge claimed in physics, a physics frame mismatch
- on the shift tick: a grounded air duck, a removed hull observation, a 1 mm origin offset, a missing duck event, ctrl missing from the actions, an unknown anchor, a scaled box

## Findings

### 1. Low: the audit's hull judge is neither frozen nor recorded

Reproduction: `provenance()` in the review script. It copies the same `package-r15.py` bytes beside a `momentum-tape.py` whose `hull_origin_compensation()` always says valid. It then audits a capture whose motor previous origin is 5 cm wrong on the air-duck tick.

- **Actual:** the frozen helper refuses the capture. The altered sibling accepts it, with `package-r15.py` sha256 unchanged.
- **Expected:** the verdict depends only on recorded, frozen bytes.

`packed_input_audit()` loads `PROJECT / 'tools/momentum-tape.py'` (`tools/package-r15.py:411`) lazily on each call, after the export and native runs. In `check` mode, `recheck_routes()` runs the executor and probe from the package commit's frozen stage. The audit's judge still comes from the live checkout, and the check result names only `tool_sha256` and `probe_sha256`.

Suggested fix: load the function from the frozen source (the package-mode `source`, or the recheck stage), or hash the loaded file and require it to equal `build['helpers_sha256']['tools/momentum-tape.py']`. Record that hash either way.

Limitation: this needs the checkout's file to differ. A clean committed checkout in package mode gives the right verdict today.

### 2. Low: the box is judged only when the motor reports a nonzero duck shift

Reproduction: `gaps()` in the review script, on the real baseline capture. Both of these are accepted:
- a standing 72 u box on a steady ducked tick;
- an airborne ctrl press with no duck at all: zero shift, no event, unchanged box.

Expected: either the audit checks every hull observation's box against its `ducked` flag, and every airborne press against a duck transition, or the docs say the box is checked only at air transitions. The first rule had no false positive on the 261 real cases here.

Caught elsewhere: a motor that ignores crouch changes position, so exact motion equality catches it, and the release UI coroutine checks the 54/72 u box for ground C and air Ctrl. A collision box that stops resizing while `ducked` stays true leaves open-ground motion unchanged. Only that coroutine would catch it, on its one course and timing.

## Scope notes

- **Respawn:** the audit has no discontinuity rule, while the standard executor exempts respawn ticks. Source routes must already be clean with zero respawns (`source_route`), so no current packed route reaches this case. It does mean recovery routes such as Whiteout `cloud_recovery` (1 respawn, practice finish) cannot become packed play proofs. DELIVERY-PLAN's per-course "deliberate recovery" in a pack needs either a narrow, separately challenged respawn rule or an explicit controls-only label.
- **Sensitivity in the reproducer:** `tests/test_r15_pack_observer.py` takes its sensitivity from the same game after the run. It is not independently captured, so the DELIVERY.md wording holds for `check_runs`, not for the reproducer. This review closed the gap for the retained Whiteout capture: the gantry executor's `engine.json` gives identical values (0.0009599310885968812 rad per count, pitch limit 1.553343) and the capture passes. The `check_runs` wiring itself was not run end to end.

## Checked without a finding

- **Caller:** `check_runs` records the audit, and the package/check result is `all(checks)`. Audit errors return `ok: False`, and other exceptions exit non-zero with no success line. Tape expansion refuses unpaired key edges, so the audit's strict `held.remove` cannot falsely refuse a valid tape.
- **Hull rule:** narrow enough. It rejected every single-field change to a valid compensation that was tried, and accepted every real air duck/stand, landing-tick release and blocked stand.
- **Docs and decision row:** the counts match the retained evidence: 39/39, 14 coroutine assertions, 15 negatives and 9,661 ticks. Both say source-only and make no claim about rendering, export or a pack. The F5 control capture does not assert airborne itself. Flight is implied by the following `air-stand` capture (grounded false, jump released).

## Not covered

Native drawing, the exported runtime and packed deployment, OS or physical-device input, Windows, the missing course and lab modules, and a hostile game that forges every channel consistently.
