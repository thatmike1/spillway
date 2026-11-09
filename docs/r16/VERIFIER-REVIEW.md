# R16 verifier review

Root repair: the original findings below remain the pre-repair evidence. The delivery audit now requires a version-2 independent raw-input receipt, validates every motion input including both mouse coordinate fields and lifecycle tails, and reconciles each recorded style event with per-tick live scoring observations and totals. Unknown or unconsumed input observations fail. Source and packed comparisons include pitch; unsupported canvas materials are refused by the structural glyph predicate. The new review CLI accepts `--helper-commit` so repaired committed helpers can be pinned explicitly. Final repaired recheck and portable execution remain separate.

Two P2 acceptance gaps reproduce against the exact `a26d94c0` helpers: the source feature audit can accept changed recorded mouse input, and the style audit can accept an impossible reward. There are also two P3 limits in source pitch comparison and glyph visibility. These are verifier counterexamples, not demonstrated defects in the shipped movement or style-2 detector, and not release approval.

## What changed

Only new `tests/r16_verifier_review.py`, `tests/r16_verifier_review.gd`, its UID, and this report. No production/helper changes, commits, pushes, child agents, native displays or exports. Evidence is in outer `checkpoints/spillway/r16/verifier-review/`.

The Python driver copies and hashes the executing helpers before testing. It copies a quiescent feature receipt/profile into its own temporary directory, exercises the real `audit_profile` and comparators, and runs the copied Godot reader/probe in a tiny headless project. Hash-consistent binary mutations simulate serialization or attribution faults; they do not claim cryptographic authentication of recordings. The production reader receives actual mutated file bytes. Its column/input hex, events and seals are then compared by the production profile auditor against the independent Python reader.

The reused receipt is explicitly older development evidence: `delivery-tools/source-final/SOURCE.json` names worktree HEAD `8aa99caddd6f72b20ad954675866fa6eba4ebefa`, with `development_only: true`. Its packager, probe and reader hashes equal the reviewed `a26d94c0` bytes; its style implementation predates style-2. It supplies component control samples only. This review does not use it to approve current style behavior or a final candidate.

Read the local BRIEF, INTERFACES, DELIVERY, STYLE, RECORDINGS and HOST-REVIEW contracts, the packager/probe, wrapper, reader, recorder, session, ghost and relevant existing controls. The shared backlog confirms `ccChat-general-41fq.4` is the integration/delivery child. Its status was not changed.

## Does it work

Final `trial-3/summary.json`: 42 checks, eight deliberately red safety assertions grouped into the four findings below; zero failed controls. The existing delivery component suite independently passes 28 checks, including owned acquisition cancellation, deadline descendants, profile negatives and immutable template pins. The existing reader/selector/ghost suite independently passes 79 checks. A separate read-only preservation execution passes 458 checks.

### 1. P2: source feature acceptance does not verify delivered mouse input

**Reproduction:** take the first copied actual-host attempt, with 112 observed body ticks and 104 recorded inputs. Change the first mouse event's `x2` column from 3 to 13, preserving motion, held keys and all independently observed body samples. Recompress/rechain the file. Both real readers accept the same altered input bytes. With the original source-feature report, `audit_profile` still returns `ok: true`.

**Control:** the identical altered file is rejected when given a labelled complete tape-input receipt reconstructed from the original recording. A wrong mouse expectation is also rejected when its observation is present. Missing body ticks, wrong observed velocity, wrong boundaries and a missing engine reader are all rejected.

**Cause:** `package-r16.py:1557` treats `recorded_tape_inputs` as optional, filters out unknown attempts and negative ticks, and skips ticks beyond the seal. `_source_features()` in `r16-pack-probe.gd` sends 100 explicit `[3,-0.2]` mouse events but does not populate the tape trace; `_end()` therefore supplies an empty tape receipt. The current source feature gate can establish body columns, held state and agreement between readers, but cannot establish that those mouse counts are the ones delivered to the host. Both readers decoding a wrong serialized value does not establish that value's input provenance.

**Related counterexamples:** in a labelled `mode: play` receipt, deleting or emptying all tape observations, moving them beyond the seal, or assigning them to an unknown attempt each hides an otherwise rejected mouse mismatch. These are component fail-closed gaps. No claim is made that the current packed probe actually emits those malformed receipts. Packed `packed_input_audit` independently checks the tape against the motion trace, but it does not itself bind every recorded input column to that trace if recording evidence disappears.

**Repair direction:** capture independently expected source-feature edges/mouse with attempt-local ticks, require tape coverage in packed play mode, and reject unconsumed/unknown input observations. Retain the positive source-feature mode and legitimate input events at lifecycle boundaries.

Evidence: `trial-3/wrong-mouse.r16run.gz`, the two mouse assertions in `summary.json`, `frozen/tools/package-r16.py` and `frozen/tools/r16-pack-probe.gd`.

### 2. P2: style acceptance checks arithmetic without event attribution

**Reproduction:** append a `capture` style event with `kind: nonexistent-reward`, `points: 123456`, outer and inner tick 1,000,000, and sequence 1,000,000 to that same 112-tick recording. Increase its event count and sealed style score by the corresponding amounts and rechain. Both readers execute successfully. The profile audit returns `ok: true`, records score 123456, and reports `both_readers: true`.

**Cause:** `package-r16.py:1571` sums integer-coerced points from every event whose source is `capture`. Neither that check nor the generic readers validate the style kind, event tick/sequence, required measurements, or attribution to a corresponding observed sample. The audit also does not bind that sealed sum to independently observed live style events or the reported best. The probe's best check at `r16-pack-probe.gd:1315` compares two values from the game's own scorer, `style_best` and `finish_style.score`; it does not independently validate the scored event stream.

**Scope:** this proves impossible recorded style evidence can pass delivery auditing. It does not prove the current style service generates it, that any candidate has an incorrect best, or that a checksum-consistent fabricated recording should be authenticated. The explicit impossible tick is an internal inconsistency the validator can detect without replaying geometry. The current first-finished-sample and later-contact cancellation rules remain accepted requirements, not findings reopened by this test.

**Repair direction:** validate style-event schema and dense lifecycle attribution, and reconcile the final sealed event total with observed scoring and saved/reloaded style bests. Geometry detection still needs its separate actual-host controls.

Evidence: `trial-3/fabricated-reward.r16run.gz`, `mutations.json`, and the corresponding red assertion in `summary.json`.

### 3. P3: source exact-motion comparison omits pitch

Three identical source rows pass. Changing one position by `1e-10`, velocity direction, or yaw by `1e-6` fails. Changing only pitch by one radian passes `compare_traces`. The function does not validate or compare pitch. The explicit game-state exception still cannot waive a velocity change.

This limits the source/external-reference equality claim. Packed input auditing separately checks pitch against the planned mouse movement, so this is not evidence that packed input auditing accepts a pitch mismatch. Either include pitch in the source comparison or describe the comparison as position/velocity/yaw/progress only.

Evidence: `trial-3/summary.json`, source comparator assertions; `package-r16.py:614`.

### 4. P3: the glyph predicate accepts a shader that hides every glyph

Ordinary, fully laid-out text passes. Transparent modulation, partial characters and offscreen placement fail. A `ShaderMaterial` with `fragment() { COLOR.a = 0.0; }` applied to the otherwise valid label still passes `_drawn_label`.

This is a constructed structural-predicate limitation, not a native rendering observation or evidence that production currently uses that material. The checked shader's explicit zero alpha establishes why the predicate alone cannot prove visible pixels. Preserve native visual acceptance, or refuse unsupported material/inherited-material configurations when making a full glyph-drawing claim.

Evidence: `trial-3/reader-visibility.log`, visibility assertions in `summary.json`; `r16-pack-probe.gd:482`.

### Controls, preservation and limits

- The reused 79-check suite exercises malformed counts, false final/outcome times and booleans, invalid start/finish ticks, wrong final pose, duplicate/missing ticks, nonfinite motion, rate/clock faults and clean/respawn flags through the production clean selector and ghost. Only the genuine clean finish remains selectable.
- The reused 28-check suite's cancellation tests signal their own running test process while launch is guarded, then terminate only process groups created by their own `Popen` calls. No name-wide kill, root wrapper signal, desktop or Weston operation occurs. The deadline control confirms its owned descendant exits.
- Arbitrary new profile paths and an R15 profile overwrite are refused. A stale analyzer hash is refused. All frozen committed helper hashes match `a26d94c0`; full helper/source identity comparison in `verify_source_manifest` was read, but no completed candidate manifest or ZIP was independently rechecked here.
- The before/after manifest covers 1,030 preexisting tracked project and R15-delivery files, including both original R15 ZIPs. No protected hash changed. The standalone preservation helper reports 458 checks, zero failed. All temporary source/profile directories are deleted; final sampled scratch was 530,574 bytes, below 300 MiB. No native/export ran, so no storage-floor exception was taken.
- Trial 1 retained one test setup failure: a SceneTree viewport did not have the intended dimensions. Explicit 1280x720 size and five layout frames fix its ordinary-label control. Trial 2 has zero failed controls. Trial 3 adds the physical mouse-column mutation and is the final result. All trials remain available.
- The first root export was reported interrupted before packed execution. Neither that interruption nor this review approves a Linux candidate. After root's restart instruction, this review did not read, modify or poll either active candidate/clone path. Full new style routes, current clean style-best behavior, native moving views, complete portable execution and Windows execution remain outside this component result.

## What I decide

Return findings 1 and 2 for integration before treating these delivery gates as independent input/style acceptance. Findings 3 and 4 can be fixed or carried as explicit comparison/visibility limits. No production scoring change is requested on the strength of these synthetic verifier counterexamples. Root owns changes, candidate verification and promotion; this review neither closes the bead nor commits files.

## Where

From the worktree, the final executed command was:

```sh
python3 -B -I projects/foldrunner/tests/r16_verifier_review.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/verifier-review/trial-3 --feature-run /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/verifier-review/input-feature --clean-record /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/recordings/headless-final/runs/host/fixture_server128_20261109-090826_084_482aebdd.r16run
```

Exit 1 is the intentional finding result. Reproduction needs a new `--out` directory because evidence is never overwritten. The retained input is a copy, not an active root candidate. `trial-3/commands.json` contains every executed child argv, cwd and log destination, including the exact headless reader/probe and the two existing control suites. `trial-3-command.log` retains the full driver output. The frozen test scripts and tools are retained per trial.

The additional preservation command was:

```sh
python3 -B -I /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/verifier-review/trial-2/frozen/tools/check-r16-preservation.py --project /home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner --git-project /home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner --r15-delivery /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r15 --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/verifier-review/preservation.json
```

Executed SHA-256 values:

| File | SHA-256 |
|---|---|
| `tools/package-r16.py` | `ea90d32ed9d9abf3fdd090fb63095a1c28be3e81c57771119e078df20b5cb00d` |
| `tools/r16-pack-probe.gd` | `74ce4c01edd577e06ae1cb95bc9e6d3ea23fcb40cf63b3ae857f0a8165ef069d` |
| `scripts/r16_run_reader.gd` | `76f2f2b728d006e19ba11c1fbb99ad8b018526a8b838f954f8672278c1602d5f` |
| `tools/analyze-r16-runs.py` | `d4dac3dd0e1c55f50317041f4c63ed399f7188d9c4b23fd4f4487e7bf751a261` |
| `tests/r16_verifier_review.py` | `52e95069bf1f28e7fd413bffb2719028ccaec329b5099c335b6d5da49d7a0459` |
| `tests/r16_verifier_review.gd` | `e4600b2a396b42f4e920de62f8a8176adaa7f8c3cbf734f1106064a0455779eb` |
| Godot editor | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |

`trial-3/provenance.json` has every frozen/executed source hash, the full HEAD at review start, receipt and clean-record hashes, and the independently computed committed hashes. `protected-before.json`, `summary.json`, `existing-integrity/summary.json`, `existing-delivery.json` and outer `preservation.json` contain the controls and preservation receipts. Outer `cleanup.json` confirms zero owned processes, zero remaining scratch directories and zero protected changes. Final evidence files total 6,397,537 bytes, below 8 MiB, including the failed trial and mutation bytes.
