# R15 first-two-map input and contact review

No runtime defect confirmed on `962ab0217ccc39254f511362897920f84454ddd6`. This is an independent challenge of Breakwater and Whiteout Relay, not final release acceptance. Two evidence limitations remain below.

Evidence root, outside Git:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/maps-review/`

`CHECKS.json`: **113 checks, zero failures; 19 selected fresh episodes, 86,927 observed ticks**. Twelve finish: six clean, six practice. Seven are deliberately bounded diagnostics/negative controls. Separately, `retained-audit.json` rereads **12 existing standard-executor tapes, 86,250 ticks**; these are retained root evidence, not new runs. Repeated paths across these groups are not independent human attempts.

## Findings, ordered by severity

### P2 validation gap: Breakwater's F5 earned breach remains unproven

The known AA1000 earned controller and its later takeoff variant failed; the held-out F2 earned tape also did not finish under F5. None establishes a motor defect. This review did not tune another earned controller or obtain a new normal-spawn F5 breach completion.

Negative controls remain useful: retained F2 earned finishes clean in 35.8203125 s, and a fresh actual-F5 ordinary route finishes clean in 44.6015625 s. F5 is usable on the basic map. Its earned branch still needs an input line that reaches and clears the breach; do not promote the existing failures to either a successful route or a physics fault.

Source evidence: `breakwater-r15-host/f5-f2-earned-tape/RESULTS.json`, the failed worker attempts documented in `BREAKWATER.md`, and this review's `routes05/breakwater-ordinary-server128_aa1000/`.

### P3 evidence limitation: wall-role counts omit real side contacts

`tests/r14_practice_driver.gd::_observe()` counts bodies with `surface == "wall"`. A platform front or stair riser can block the runner while its body is `route` or `recovery`. The minimal counterexample is the matched standing gantry jump: at tick **240**, `s4_gantry_a`, role `route`, reports blocking normal **[0, 0, -1]**, while the inherited wall-role counter remains zero. Requested forward speed is **220.86 u/s**, post-contact forward speed **0**; the sideways component is preserved. The paired crouch jump has zero side contacts and lands on the gantry.

Counting distinct ticks with any actual motor contact normal satisfying `abs(normal.y) < 0.7` gives:

| retained tape | side-contact ticks | wall-role ticks in inherited summaries |
|---|---:|---:|
| Whiteout basin miss/return | 10 | 0 |
| Breakwater alley miss/return | 18 | 0 |
| other six Whiteout tapes | 0 | 0 |
| other four Breakwater tapes | 0 | 0 |

Whiteout's ten are the missed pylon face plus nine stair risers. Breakwater's eighteen include the missed block face and continued approach against it. Both recover physically and finish clean. All 28 ticks contain blocking side normals, but stair probes are not necessarily net speed losses: the chosen step-up path can preserve horizontal velocity. These are expected contacts during deliberate misses, not evidence of snagging on ordinary clean routes. The independent fresh recoveries reproduce 10 and 18 respectively. Use normals and velocity changes when describing contacts; keep the old metric labelled as a body-role count.

Reproduce the counter audit with `tests/r15_maps_review_evidence.py` below. No shared helper or production code was changed.

## What fresh input established

All episodes run the actual `scripts/r15_main.gd` and `scripts/r15_source_player.gd`, motor `r15-source-crouch-2`, at **128 Hz**, **32×72 u standing / 32×54 u crouched**, centred 9 u airborne anchor, sensitivity **2.5**. F2 and F5 are delivered as actual `InputEventKey` presses through the host's handlers; the running settings confirm AA100 and AA1000. Movement uses physical-key events and relative mouse events delivered through Godot's input system, not physical hardware or XTest. The inherited controller reads state and can make mistakes. This is not a discovery trial.

| selected episode | start and outcome | contacts / records |
|---|---|---|
| Whiteout gantry | normal spawn; clean 61.984375 s | zero side ticks; ducked landing, then free stand |
| gantry positive / standing negative | authored Cable works practice; identical states through takeoff at tick 191, 224.4 u/s, 2.558 m from face | crouch lands at y 2.54 m and finishes practice in 16.9296875 s; standing hits face and lands below; no interior overlap |
| Whiteout basin miss | normal spawn; clean 71.3828125 s | all nine physical stair faces reached; 10 side ticks, zero respawns |
| Whiteout missed chasm | normal spawn, walks off Saddle; practice 65.3515625 s | exactly one respawn, tick 3902, checkpoint 2/Saddle; then catwalk and finish; no saved record |
| Whiteout cloud fall | normal spawn; practice 67.71875 s | exactly one respawn, tick 5167, checkpoint 3/Receiver; no saved record |
| Cable works ordinary practice | authored checkpoint 4; practice 16.203125 s | no clean or open record |
| F2 → F5 → F2 during run | normal spawn; practice 62.296875 s | first switch at Ridge invalidates clean eligibility; switching back never restores it; no record in either identity |
| practice → map change → return | after reaching Ridge, actual F starts practice; menu `select_map` changes to Breakwater and back | each map change increments attempt, zeros timer/checkpoint/splits and changes record identity; full new Whiteout run then legitimately records clean 62.296875 s |
| Whiteout actual F5 ordinary | untouched normal spawn; clean 62.296875 s | complete clean record persisted under F5 identity |
| Breakwater alley miss | normal spawn; clean 55.4765625 s | physical catch and return ramp, 18 side ticks, zero respawns |
| Breakwater harbour fall | normal spawn; practice 58.640625 s | exactly one return to checkpoint 2/Crane line; no record |
| Breakwater actual F5 ordinary | untouched normal spawn; clean 44.6015625 s | zero side ticks; complete clean record persisted |

Map selection is a new run, not a continuation of the old practice attempt. The map-change check verifies that prior splits/progress cannot carry into that fresh record. It does not require legitimate restarts to stay permanently practice.

### Labelled diagnostic poses, not route proofs

Four Whiteout episodes seed **one** pose/velocity after warmup: feet `(1, -2.5, -129)` m below pylon 1's overhang but outside its support pier, velocity `(0, 150, 0)` u/s. The open controls change only x to 7 m. After setup they use crouch key input only, with no position/velocity rescue.

- Release at tick 18 below the slab: stand is refused for **24 ticks**, then succeeds at tick 42 as the falling body clears it. Standing landing follows at tick 74. Open-space release succeeds immediately at tick 18.
- Hold through landing: both land crouched at tick 78 with the real 54 u hull. No blocked release is claimed in these held-input episodes.
- No sampled hull overlaps a solid's interior after shrinking the query by **6 mm per face** to exclude contact margins. This does not exclude shallower penetrations or unsampled within-tick states.

The gantry itself has 4.5 m overhead clearance. It proves the crouch-jump ledge and safe free standing, not a low-ceiling blocked landing. Blocked standing and crouched landing are separate tests above; this review did not find a naturally crouch-only landing tunnel in these maps.

Two Breakwater episodes seed feet `(-81, 0.6, -150)` or open control `(-75, 0.6, -150)` m, velocity `(-300, 0, -400)` u/s, after warmup, then give no movement input. Crown contact occurs at tick **38** after landing. Normal x speed becomes zero; tangential z retains **-275.3947 u/s**, the requested post-friction value. The open control retains its x component and has no side contact. Do not compare that z speed directly with the original -400: ordinary ground friction has already acted.

These diagnostic attempts can show `clean_eligible` internally because a test seeded the body without changing host state. None reaches finish or saves a record; they are excluded from clean route claims.

## Evidence, reproducibility and hashes

Run from `projects/foldrunner`. The supervisor uses the pinned engine, a frozen external project copy and `tools/package-r15.py::run_engine` for process groups, deadlines and signal cleanup. It does not render or export. Use a separate empty evidence root for a fresh reproduction of the selected set:

```bash
E=/absolute/path/outside/git/maps-review-reproduction
python3 -I tests/r15_maps_review_run.py --out "$E/attempt02" --only under_pylon
python3 -I tests/r15_maps_review_run.py --out "$E/full03" --only whiteout-relay-gantry-server128,basin_recovery
python3 -I tests/r15_maps_review_run.py --out "$E/gantry04" --only gantry_stand,gantry_practice
python3 -I tests/r15_maps_review_run.py --out "$E/routes05" --only chasm_miss,cloud_recovery,practice_finish,preset_taint,map_reset,ordinary,alley_recovery,harbour_recovery,crown_
python3 -I tests/r15_maps_review_check.py --evidence "$E" --seal-profiles
python3 -I tests/r15_maps_review_evidence.py --out "$E/retained-audit.json"
```

Each fresh case retains `summary.json`, `input.json` and full-precision `trace.jsonl.gz`; utility-key/setup/menu actions are explicitly labelled. `input.json` is not advertised as a strict standard-executor tape: setup ticks and menu operations lie outside that schema. Root's twelve retained tapes supply the separate standard delivery/order/rate/neutral/cleanup evidence, checked by the audit. Fresh finish traces stop at route completion; they do not claim that extra strict-executor neutral tail tick.

Persistent record checks read the generated isolated CFG files, retain their SHA-256 and course-section payloads in `record-evidence.json`, then delete those test profiles. Six clean finishes have complete persisted records; all six practice finishes have neither clean nor open records. No real player profile is read or written.

All **825 pre-existing tracked project files** hash identically before/after every batch. The ten main/motor/map/preset/art files also match the retained Whiteout root source manifest. Full manifests and per-trace hashes are in each batch's `RESULTS.json`; `HANDOFF.json` records final owned-file hashes and live source comparison.

| source | SHA-256 |
|---|---|
| pinned Godot 4.7.2 | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
| `r15_main.gd` | `dc5621ffcf08fa35324ef1e063aedc85031b583903a35a9336960628619d32ef` |
| `r15_source_player.gd` | `e06a545d610da0c3bb35f61d14d8f3f24d9ddf4e36e1b87743060a5c48157019` |
| `r15_presets.gd` | `44a70c76f2cbf9002b3f9c5f4887754b81b454af6254cab0fff19f63e104b939` |
| `r15_maps.gd` | `7888262ccf92e25f6cf53d92f45b6fc90a157456440089bda54e86be66bea187` |
| `r15_whiteout_level.gd` | `9af9d87e5d54d6585175900fb3c750c426de8e20c19c0c24196234290acdafa2` |
| `r15_breakwater_level.gd` | `e27bccfad68480dbbf40e9e63bb09e583d629f9c2ef0b32eefc136dedc4b2631` |
| final review GDScript, smoke06 | `e7e892100a925b200d653868dfe0e25eb7834f984d81335585626f636eeba076` |
| review GDScript, gantry04/routes05 | `ed5de981a0544405dc4b2d6c23695eb7ce542b2853b56da43eb1f6ac9b0a7f30` |
| review GDScript, attempt02/full03 | `2c4e1e082191a09da0c44482e5f87450d7fb973d13ef2544b11c11d7260ae015` |

The final harness has a trailing-space cleanup after gantry04/routes05. Six short smoke06 repeats (860 ticks) match the earlier observed fields exactly, excluding the old unused mouse field. This adds no new route claim.

The older review script differs only in controller waypoint-origin initialization and an unused trace mouse field. Its selected normal-spawn gantry, basin and no-horizontal-input diagnostic episodes remain valid; the current script's waypoint-origin repair matters for checkpoint-start gantry trials.

## Failed approaches and observation limits

- `attempt01`: the seeded probe began inside the pylon's support pier and was seeded before warmup. It depenetrated sideways and never tested the desired release refusal. All four traces remain excluded. `attempt02` moves outside the pier and seeds immediately before tick zero, with matched open controls.
- `full03` checkpoint gantry attempts: the inherited controller's waypoint origin was world zero rather than the checkpoint. It skipped the approach waypoint, jumped off line, and the positive attempt later pushed a drum until its 14,000-tick budget. This is a failed controller path, not a gantry/motor defect. Both remain excluded. The supervisor was signalled to stop an obsolete follow-on run; it released its engine and removed scratch. Selected gantry04 episodes repair only controller bookkeeping and match through takeoff.
- `CHECKS-attempt1.json`: two crown assertions incorrectly expected the initial seeded speed after ordinary ground friction. The final judge compares requested post-friction velocity with post-contact velocity and the matched open control. No physics or route was changed to turn those assertions green.
- Two pre-existing Whiteout JPEGs were inspected: `whiteout/native/gantry/frame-047.0s.jpg` and `whiteout-integration/native-review/basin_recovery-30.jpg`. They show the raised gantry and ridge layout, not independent discovery, complete new native play, or enjoyment. No new native process, display, movie, export or desktop configuration change was needed; the pinned Weston dependency remains present and untouched.
- Evidence is about **18.8 MiB**, below the **25 MiB** ceiling, including excluded attempts. Scratch copies, import caches, owned local Python caches and generated profiles are removed. Process cleanup and source comparisons are recorded in `HANDOFF.json`.
- This does not establish human enjoyment/discovery, CS binary fidelity, Windows execution, device latency, frame pacing or feel. Penstock and Overflow were not rerun here. Remaining new maps, traversal lab, complete-registry checks and packed-game acceptance belong to the lead and other workers. No ticket is closed, and no commit or push is made by this review.
