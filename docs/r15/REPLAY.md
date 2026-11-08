# R15 replay and airborne crouch

The shared rate-aware executor still requires one motor step per sample and strict version-2 tape headers. Airborne crouching changes the runner's feet reference without adding velocity. R15 also shifts its previous interpolation origin by that hull adjustment. The original executor correctly recorded the raw mismatch, then incorrectly classified it as a missing motor step.

The capture now observes the actual `CollisionShape3D` box before and after the motor. The evaluator accepts this specific origin change only when the motor counter advances exactly once, both samples belong to the same physics frame, the current body matches, the observed air-duck transition agrees with input and its event, and the configured hull, anchor and actual interpolation origin explain the exact float32 shift. Raw positions, displacement, order booleans and motion remain in the trace. A ground duck has no exception. A missing or inconsistent explanation still fails ordering.

This is an observer contract, not a defence against a wholly forged capture. It does not establish Source binary fidelity, human feel or vertical movement correctness merely from reported compensation.

## Evidence

Outer `checkpoints/spillway/r15/crouch-harness/` retains the original rejection (`before/`), the first repair with a float32 cancellation mismatch (`after/`), and the fresh corrected run (`after-final/`). At ticks 35 and 70 the runner air-ducks and stands. All 256 motor steps are counter-verified; delivery, rate, neutral input and cleanup pass. All 264 raw rows, including warmup, have identical position, velocity and yaw before and after this observer change (`MOTION-EQUALITY.json`).

`negative-final-20.json` rejects 20 corrupt-capture controls through the real evaluator, including skipped/doubled/missing counters, wrong frame, absent input/event, wrong hull/anchor/shift/origin, NaN and float32 overflow. `legacy-units/` passes the 11 original expansion checks.

`approved-routes/RESULTS.json` checks the real R15 host and crouch motor version 2 against the approved R14 F2/F5 runs. All 16,356 ticks agree exactly in position, velocity, yaw, applied input and complete game state. Penstock advanced finishes at 28.609375 s; F2 and F5 Overflow each finish at 45.9609375 s. All are clean, zero-respawn runs. This is source-mode headless evidence on the pinned engine, not portable-package or human acceptance.

## Recheck

From `projects/foldrunner`, the checked-in mutation probe consumes a fresh executor run containing an airborne crouch and stand:

```sh
python3 tests/test_r15_tape_crouch.py --run RUN --out RESULT.json
```

The strict tape header does not accept arbitrary annotations such as `radians_per_count`. Put explanatory metadata in `description` or a sidecar. Never relabel a tape's rate or silently retime events. Look sensitivity and warmup remain explicit run inputs.
