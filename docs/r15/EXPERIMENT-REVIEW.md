# R15 experiment and host review

No new actionable defect reproduced on **f3f234525ea01d53c3cedf818530621d24dc0bd1**. The final independent challenge passed **102 checks across 34 episodes and 10,116 sampled ticks**, with no engine errors. This is a source review, not final R15 exported-release acceptance.

The reviewed code is the committed parent, frozen outside the checkout. The harness adds no runtime hooks. After each episode's labelled setup, it sends only physical key events, relative mouse events and viewport clicks/scrolls. Two kinds of evidence stay separate: normal-spawn complete routes and explicitly seeded contact/state diagnostics. It never restores motion during an episode.

## Reproductions and controls

| severity | reproduction | control | outcome |
|---|---|---|---|
| none reproduced | `wall_near`, `wall_far`, `floor_only`, `slide_ceiling_space`: fresh Space against authored housing, floor and rack contacts | the same hull just outside reach; ceiling-only contacts; ordinary grounded jump | near wall accepts; distant wall, floor and ceiling do not emit a wall impulse |
| none reproduced | `wall_flight_limit`: alternate chamber faces four times in one flight; toggle wall jump off/on and change F5 after the second impulse | real landing after the third impulse; `wall_corner_cooldown` presents another face before cooldown expires | exactly three wall jumps; fourth refuses `limit this flight`; toggles/preset preserve quota, landing resets it, corner press refuses `cooldown` |
| none reproduced | `line_released`, `line_disabled`, `line_pause`, `line_time`, `line_restart`, `line_checkpoint`, `line_preset` interrupt a real acquired A1 line | fresh E after disabling/re-enabling; release E while paused; keep E held through forced release | no residual pull after release; disabling releases immediately, held E cannot reacquire after forced release; fresh E works; pause freezes rope time and position; R/F clear state; F5 preserves the line and changes identity/practice eligibility |
| none reproduced | `line_break_real_column`: acquire A2 from the pit and strafe behind the real column; `target_blocked`/`target_far` press E at invalid targets | acquire before entering obstruction, then keep E held after line breaks | column breaks the line as `obstructed`, no automatic reacquisition; blocked/far targets do not acquire |
| diagnostic only | `line_overrange_seed`: initial feet `(0,10,-45)` and an explicitly preattached A1 line beyond 1261 u | unlatched far-target episode; failed transverse-overspeed trial retained | range branch releases without impulse or held-key reacquisition; this does **not** show ordinary input earning an overrange line |
| none reproduced | `slide_edge`, `slide_disable_roof`, `slide_f5_roof`, `slide_pause_release`, `slide_ceiling_space`: input-earned run-up from one station seed | release/disable beneath the 60 u rack, pause/release Shift, F5 while sliding, run off the trench edge without jumping | slide ends on leaving ground; its duck stays through the fall without air-origin compensation and releases after landing; low roof safely defers standing; pause freezes slide ticks; F5 keeps active slide and hull |
| none reproduced | `host_live_transitions`, `f5_course_to_lab`: leave an active grapple via viewport map card; hold lab inputs on the course; enter lab from F3/F4/F5 | real Penstock and Breakwater course bodies, Rainline entry, all four course comparisons | old lab body freed; approved runner, audio target and stats target restored; course mechanics remain empty; all four course comparisons work; F3/F4 entry becomes F2 with notice; F5 stays F5; re-entry starts all moves on |
| none reproduced | `pending_map`, `pending_f`, `pending_r`, `pending_f2`: one labelled ducked setup in Rainline's real plant duct, Ctrl then F3 | F, R, active F2, or viewport map change | F3 genuinely waits beneath the roof; F/map/active key cancel; R applies F3 at the open spawn; no pending course preset leaks into lab |
| none reproduced, normal spawn | `records_control`, `records_mixed`, `records_roundtrip`, `records_preset_roundtrip`: complete the combined lab line, with late grapple-off, off/on, or F5/F2 changes | unchanged all-on route; enumerate all eight loadouts with actual number keys after the clean finish | control finishes clean at **15.03125 s**, stores **1924 integer ticks**; all three mixed lines finish practice and create no profile; returning to the original identity cannot launder the run; all eight loadout keys differ and only all-on restores its own best |

The route actor reads state to time its keys and aim, just as the earlier actor did. A reproducible state-driven actor is not an imperfect human run or a feel verdict.

## Displacement and rejected objections

Every sampled consecutive Source motor step, excluding legitimate host placements, reconciles:

`current feet - previous feet - this tick's duck shift == reported physical displacement`

Maximum error was **0.0 m**. Stored Source state versus body position/velocity differed by at most **0.000003824** in metre/metre-per-second values after unit conversion. The four complete routes also use their actual resulting body state, never a restored route state. The final gzip was independently decoded: all 10,116 rows are present, and each episode's row count matches its summary.

Two apparent issues were rejected with controls:

- **Shallow wall recovery is inherited.** The zero-motion hull query returned recovery up to **1.126409 mm** on the normal combined lab line and **1.109838 mm** in the wall-pressure episode. Replaying the same pressure/jump events with the approved runner on the same level produced **1.145124 mm**. This does not justify a new lab defect. The final 2 mm smoke bound is deliberately above that measured control, not a zero-penetration or general collision-acceptance claim. Raw normals, body names and recovery distances are retained.
- **A pre-pause press remains buffered.** Space pressed immediately before Esc, then released while paused, produces its pending wall impulse on resume. The inherited runner explicitly buffers a press released before the next physics command too. No new press was generated while disabled; this was not classified as an input leak or a new lab bug.

The known wall-side acceleration cancellation, crouch-hop alternative, impulse-only grapple cap and body-name/normal face identity were not refiled as findings.

## Source inspection

Read the project instructions and `BRIEF.md`, `INTERFACES.md`, `PLAYABLE.md`, `EXPERIMENT.md`, the dedicated experiment suite, loop/crouch review helpers, tape/observer interfaces, and the lab-only host/HUD paths. Inspected the experiment runner's impulse ordering, inherited duck request, cooldown/flight bookkeeping, forced-release latch, target/LOS checks and loadout tuning identity. Inspected level/art ownership of collision prisms, anchor hash, prop proxies, decoration, tether and HUD/menu wiring. No new render or visual-quality judgment was made from source inspection.

## Run and evidence

From the project root, this exact command produced the final result:

```bash
python3 tests/r15_experiment_review_run.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/experiment-review/final
```

Use a **new output directory** to reproduce. The wrapper is intentionally pinned to the reviewed parent; it does not test later root fixes silently. It archives from the repository root, copies only its own harness into external scratch, imports with pinned Godot 4.7.2, then runs:

```text
Godot_v4.7.2-stable_linux.x86_64 --headless --audio-driver Dummy --path SCRATCH/source --import
Godot_v4.7.2-stable_linux.x86_64 --headless --audio-driver Dummy --path SCRATCH/source --fixed-fps 128 --script res://tests/r15_experiment_review.gd -- --out=SCRATCH/results
```

Both commands have 90-second wall deadlines and owned process-group cleanup. Exact expanded commands, engine hash, complete before/after actor/helper hashes, generated-UID list and record payload are in `final/receipt.json`. Final logs contain no `ERROR`, `SCRIPT ERROR` or parse failure. Import and review returned 0. The final check execution took 19.31 seconds; this is a measurement, not a human task estimate.

Evidence root:

`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/experiment-review/`

- `final/summary.json`, `final/trace.jsonl.gz`, logs and receipt hold the final result.
- `final/harness/` retains the exact final harness source.
- `trial-01` retains the empty-archive/cwd failure before engine launch.
- `trial-02` retains the review harness's Variant inference parse error. It made no gameplay finding.
- `trial-03` retains the wrong displacement accounting across R/F and missing R13 duck field, plus the original overly strict hull-query classification.
- `trial-04` retains the remaining shallow-wall classification before the approved-runner control.
- `trial-05` retains the transverse-overspeed diagnostic that did not earn a range release. The rope and inherited velocity handling kept it attached; the final range-branch check uses an honestly preattached seed instead.
- `removed-profile-payloads.json` retains old trial record contents/hashes after deleting their standalone `.cfg` profiles.
- `OWNED-SHA256.txt` hashes the four owned checkout files, including this report. `AUDIT.json` records gzip row counts, final outcomes, size and cleanup.

All tracked actor/helper hashes were unchanged before/after every completed freeze. All pre-existing files in the frozen source were unchanged by import/checks; three absent UIDs were generated only in scratch. Owned imports, XDG profiles, scratch trees and engine processes were removed. No native/render/export run, display connection, Weston change, commit, push or delegate occurred. Total retained evidence stays below 10 MiB.

Harness SHA-256:

```text
32c47a2974908201a2ab6fa39756ff1ca64ef8f6649fd98e95eac7502261e508  tests/r15_experiment_review.gd
6fd10fd2a9eb1fbdbb86b52b7a0600cbd51d4d0fb04189f500a8910cf72d1546  tests/r15_experiment_review.gd.uid
643a9bd761ea85c8e8fb691e7e17bf0fd9832fa93168a60a6d646761248e5f01  tests/r15_experiment_review_run.py
```

## Limits

No new actionable finding is not approval of final R15. This run does not accept exported Linux/Windows packages, hardware frame pacing, native audio/rendering, visual readability, every map's routes, general arbitrary geometry or human enjoyment. Earlier parent results remain separately attributed evidence. Root owns any fixes and final release verification.
