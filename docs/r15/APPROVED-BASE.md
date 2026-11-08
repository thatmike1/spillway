# Approved movement reference for R15

The reference is the delivered R14 Source server movement Mike liked, not a newly tuned law. In a clean frozen copy of commit e667cf9c, root reran three original input tapes at their original 128 Hz physics, fixed-fps128 replay cadence, sensitivity and warmup.

| Route | Clean time | Equal input/position/velocity/view/game-state ticks |
| --- | ---: | ---: |
| F2 Penstock advanced |28.609375 s|3814|
| F2 Overflow |45.9609375 s|6271|
| F5 Overflow |45.9609375 s|6271|

Each finishes clean with zero respawns, successful input delivery, rate/order proof, neutral end and clean cleanup. All 16,356 rows equal the delivered R14 source goldens; actual evaluator engine logs are error-free. These are headless approved-base replays. They do not prove R15 crouch, new maps or human feel.

Permanent receipt: outer `checkpoints/spillway/r15/approved-base/locked128/RESULTS.json`, with `GAME-STATE-EQUALITY.json` and compressed original traces. Original tapes and R14 source receipts remain in the frozen R14 delivery. Source/profile/import scratch was removed after completion.

The first replay pass used default fixed-fps30. It kept input, velocity, view and finish time, but Overflow began after 11 rest steps rather than 8 and showed a 0.0000514984 m resting-height offset from tick0. That initial cadence control is retained at `approved-base/`; the locked set matches the original128 cadence. No movement or comparison tolerance was changed. Future regressions should match setup before diagnosing physics.

Large render/export work continues to require 15 GiB free on HOME. Root removed inactive regenerable R14 cache files and shared byte-identical textures in inactive old worktrees using independent copy-on-write extents. Actual free-space observations and hashes are in `checkpoints/spillway/r15/storage/`; no space saving is inferred from logical file sizes. User source contents, profiles, delivered packages and active worktrees were preserved.
