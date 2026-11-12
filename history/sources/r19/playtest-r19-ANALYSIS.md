# Mike's R19 playtest, read for R20

All **58 fresh recordings pass the strict reader**, all F2 (`server128`) at 128 Hz. The copied folder contains 90 sealed files: 32 match R18 bytes by SHA256 and are excluded from every session total below. None of the 90 inputs, five copied settings files, or other copied user-data files changed during analysis. `r20-input-integrity.json` contains before/after hashes for all 173 files in the copied user-data tree and the 32-file comparison tree. `r20-analysis-base.json` remains the parent's raw 90-file inventory, not this session's report.

The new helper imports `tools/analyze-r16-runs.py` for strict decoding and analysis and `tools/analyze-r19-playtest.py` for low-speed spans. Source-rule interpretation is pinned to baseline `065f7b27993df7ae2511eb34eb665d271dded13c`, independently of concurrent R20 edits. This is analysis before feature changes, with no engine or native launch.

## What he played

| Map | Attempts | Recorded time | Restarts | Finishes / clean / open | Falls | Low-speed spans / time |
|---|---:|---:|---:|---:|---:|---:|
| saltglass | 34 | 649.046 s | 28 | 5 / 3 / 2 | 2 | 16 / 57.453 s |
| tether-yard | 12 | 123.999 s | 9 | 3 / 2 / 1 | 0 | 1 / 1.344 s |
| line-drive | 8 | 151.335 s | 7 | 1 / 1 / 0 | 0 | 0 / 0.000 s |
| fall-line | 3 | 46.492 s | 0 | 2 / 2 / 0 | 0 | 1 / 2.742 s |
| breakwater | 1 | 4.133 s | 0 | 0 / 0 / 0 | 0 | 0 / 0.000 s |

All coordinates below are reference feet in metres, with temporary airborne duck-origin compensation excluded; raw position columns remain in the recordings. Ticks are attempt-local.

Total recorded time is 975.005 s, about 16.25 minutes. Recorded time sums physics deltas, includes unpaused waiting, and excludes paused wall-clock time. Finish times below come from the sealed outcome and exclude waiting before the timer starts. Low-speed spans mean actual horizontal travel under 25 u/s for at least 0.5 s while started and unfinished, split at discontinuities. They are measurements, not evidence of frustration. A restart or quit names an action, not its motive. The falls count records respawn-count increments, not every descent onto recovery geometry.

## 1. Saltglass

34 attempts, 28 restarts, five finishes and one map change. Three clean finishes take **35.71875, 30.5546875 and 31.2109375 s**; two open finishes take **9.15625 and 9.3984375 s**. The clean R19 lines are already shorter than R20's requested 40–70 s F2 band. Timing the rebuilt route remains an implementation acceptance check, not something this analysis can certify.

### The turn-around shortcut is a short connection to stage 3

`saltglass_server128_20261110-074540_173_ea236da7.r16run` starts at (2, 6.04, 16). At timer-start tick **263**, feet are (2.039, 6.001, 16.537), with `move_back` held. At tick **343** the crouched runner is grounded at (2.317, 7.311, 19.982). At **344**, checkpoint jumps directly **0 → 3**, feet (2.320, 7.599, 20.026), at 222.56 u/s with back/jump/crouch held. The run stays at positive z, traverses the salt steps westward, and finishes at **1434**, (-59.135, 4.636, 34.489), in **9.15625 s**. It never crosses either fin's entry plane or records checkpoints 1 and 2.

The second shortcut, `saltglass_server128_20261110-074742_806_055589f5.r16run`, records **0 → 3 at tick 307**, grounded at (1.403, 7.501, 19.801), 173.04 u/s; it finishes at **1429**, (-59.131, 5.779, 35.678), in **9.3984375 s**. Held forward at that later sample is compatible with the recorded yaw of 2.801 rad. Held keys alone do not define travel direction.

The authored headrace ends at z=18, y=6. `salt_step_2` spans x=-6..16, z=20..42, y=7.5 and carries stage 3. This is a 2 m gap and 1.5 m rise directly behind spawn. The above samples spatially support that shortcut. The recorder does not name the support body, so contact with `salt_step_2` is inferred, not directly recorded. In baseline `scripts/r16_main.gd`, `_collect_checkpoints()` accepts either the checkpoint volume or `_stands_on_stage(stage)`, searches the highest stage first, and permits jumps in stage number. `_finish()` leaves an incomplete stage-time array as an **open** finish. Both sealed shortcut outcomes correctly say `clean=false`, `finish_kind=open`; the tick flags and final sample's `clean=true` only mean no practice/respawn disqualification, not complete checkpoint coverage. Count clean finishes from the outcome.

The observations support closing or earning the physical spawn-to-step connection. Merely tightening the finish volume would leave the early stage-3 connection intact. The recordings do not choose the R20 speed requirement or prove any redesign demanding.

### Entries are low relative to the 18 m crest

Baseline `scripts/r19_surf_level.gd` builds four 21 m prisms per fin. West rises from x=0,y=0 to x=12,y=18; east is its rotated counterpart around (60,0,-84). The headraces are at y=6. The crescent decks descend **8.5 → 7.5 → 6.5 m**, returning to an east headrace at 6 m. Those are source facts.

Across these recordings, 21 west entry-plane crossings occur at **6.001–7.431 m**, and four east crossings at **6.274–7.390 m**. These are feet crossing z=0 toward the west fin, or z=-84 toward the east fin, within each fin's width. They include airborne/crouched states and repeated crossings; they are not a count of proven first contacts. The samples place entry around a third to two fifths of the 18 m crest height, below the requested near-top entry.

A representative clean line is `saltglass_server128_20261110-074629_597_7937ff0e.r16run`:

| Tick | Feet (m) | Observation |
|---:|---|---|
| 883 | (3.711, 7.413, -0.052) | west entry-plane crossing |
| 1270 | (0.582, 1.442, -46.888) | low alongside west fin, 755.8 u/s stored z component |
| 1350 | (0.925, 1.957, -58.960) | still close to west face |
| 1400 | (0.147, 3.395, -65.204) | moving away toward negative x, with positive vertical velocity |
| 1472 | (-2.790, 2.067, -72.580) | recorded grounded, spatially consistent with west return ramp |
| 1519 | (-2.774, 3.485, -76.467) | another grounded sample higher along that return |
| 2438 | (57.918, 6.718, -83.989) | east entry-plane crossing |
| 2820 | (57.914, 4.661, -28.830) | departed toward the east recovery side |
| 2911 | (63.499, -0.318, -17.474) | grounded/crouched, spatially consistent with east return ramp |
| 3055 | (64.985, 5.801, -0.969) | grounded farther up that return |
| 4443 | (-59.169, 4.771, 33.022) | clean finish, 30.5546875 s |

Motion events and held jump samples show repeated hops on the recovery climb. The return ramp is authored between local z=-56,y=-4 and z=-84,y=6. The source has catch decks at y=-4 below the low side of each fin. This clean line uses positions consistent with leaving both fins before their ends and climbing those returns. **Collider identities and normals are absent**, so this is a spatial route reconstruction, not direct contact attribution. The helper exports all grounded recovery-envelope spans, exact checkpoint samples, selected full-rate samples and quarter-second lines.

By contrast, the west part of `saltglass_server128_20261110-074838_850_0fefc868.r16run` stays close to the face to about (4.57,7.41,-83.8) before reaching the west exit; it has no grounded samples in the helper's west return-ramp envelope. It finishes in 31.2109375 s but uses the east recovery side. The 30.55 s mixed recovery line being faster than this 31.21 s mixed line does **not** isolate surfing versus recovery speed: entries, steering and all later sections differ. Mike's report that bailing is faster is design input; these recordings show the available bailout and its use, not a controlled causal comparison.

Baseline landings `west_landing` and `east_landing` are flat y=10 decks; they have inclined exit mouths rising y=6→10 before them. Recovery courts also exist under the crescent and salt steps. The first catch after a fin is therefore an inclined mouth, followed by a flat deck. R20 asks to make the fin landing flat, raise the connector and remove under-fin safety.

### Losses, waiting and falls

The largest inherited-detector loss is **766.3 u/s**, ticks **3116–3425**, `saltglass_server128_20261110-074417_466_bc38af51.r16run`, from (59.81,0.85,-28.35) to (57.88,3.73,-0.41). It includes four land/jump cycles and 4.024 rad of accumulated yaw turn. No collider is recorded; it cannot be assigned to one wall or fin seam. `saltglass_server128_20261110-074918_534_c753cccd.r16run` loses **752.1 u/s**, ticks 1969–2244, ending near (6.41,10.17,-83.59), with no motion event. That also lacks collision attribution.

There are 16 low-speed spans totalling 57.453 s. Examples include a 13.3125 s span at (-0.586,1.501,-83.331), ticks **1448–3151** in `saltglass_server128_20261110-074604_965_46312eb2.r16run`, with no movement held, and 12.0078 s at (-1.008,6.001,-0.021), ticks **748–2284**, `saltglass_server128_20261110-075105_095_8015f2b1.r16run`, also with no movement held.

The two recorded respawns are in `saltglass_server128_20261110-075213_386_bccec2ad.r16run` at lifecycle tick **2412**, from (85.078,-14.503,-97.123), and `saltglass_server128_20261110-075301_589_92a28f7b.r16run` at **2721**, from (80.463,-14.477,-104.682). Both return to checkpoint 1; the next samples record `practice_reason=respawn`. Recovery landings elsewhere are not counted as falls.

## 2. Backwards chains: a strict continuity rule, not a universal one-award lock

There are **12 backwards awards in six Saltglass attempts, 2,760 points**, and **no sideways awards** anywhere in the fresh cohort. The Python reconstruction follows baseline `_travel_kind()` and `_direction_step()` from recorded actual travel, yaw, grounded flags, jump events, dt and reference feet. It matches **every recorded award tick, kind and hop count across all 58 attempts**. It is an observational reconstruction, not engine replay; float32 samples and unrecorded internal continuity state remain limits.

In the 9.156 s shortcut attempt `saltglass_server128_20261110-074540_173_ea236da7.r16run`, valid backwards landings occur at ticks **832, 928, 1024, 1119, 1230, 1325**. The first only arms the chain. The next five awards are **160, 200, 240, 280, 320 points**, corresponding to chains of **2–6 hops** and direction multipliers **2, 2.5, 3, 3.5, 4**. This directly disproves a general once-only detector lock. R19 already grows a capped multiplier and immediately adds each award to score; it has no pending bank to lose on a later stall. R20 asks for a different score lifecycle.

The clearest one-award example is `saltglass_server128_20261110-075138_718_fe5043e8.r16run`:

| Tick | Reconstructed result | Recorded evidence |
|---:|---|---|
| 676 | valid hop 1, no award yet | landing (-7.463,-3.961,-17.465) |
| 772 | valid hop 2, **160 points** | landing (-9.023,-3.983,-25.993); recorded award agrees |
| 868 | chain breaks on efficiency | 8.381 m straight progress / 10.546 m tracked travel = **0.795**, below **0.85**; speed 575.61 u/s; facing still qualifies |
| 963 | efficiency fails again | 8.287 / 10.779 = **0.769** |
| 1171 | fall-height test fails uphill | peak and landing both y=-1.721, so fall=0 m, below 0.20 m |
| 1643 | valid hop 1 after climb | landing (-8.601,10.048,-96.965), so the detector can re-arm |
| 1739 | heading continuity fails | landing (-0.861,10.026,-98.972), with other landing tests passing |

This matches a tight straightness/continuity policy during curved backwards strafing and uphill recovery. It is not evidence of exhausted novelty or a missing re-press. No input re-press is required for this award. The exact tests and failed checks are in each run's `direction.timeline`.

Other observed award sequences are ticks **1045/1133** (160/200) in `saltglass_server128_20261110-075154_194_734c9b8a.r16run`; **2175** (480, including combo multiplier 3) in `saltglass_server128_20261110-075213_386_bccec2ad.r16run`; **726/822** (160/200) in `saltglass_server128_20261110-075301_589_92a28f7b.r16run`; and **4146** (200, including combo multiplier 1.25) in `saltglass_server128_20261110-075324_874_7ef4950d.r16run`.

The baseline rules require speed ≥300 u/s and facing dot ≤-0.75 for backwards, |dot|<0.75 for sideways. Every tick must remain in the same qualifying band. A supported departure must contain an actual motor `jump`; walking off is insufficient. Each flight needs 0.18–1.2 s, ≥3 m travel, ≥0.25 m rise, ≥0.20 m fall, straight progress ≥85% of tracked travel and successive landing headings with dot ≥0.5. Ground dwell >0.06 s breaks continuity. Every valid landing, including hop 1, reserves a 4 m novelty radius for the whole attempt; discontinuities clear chain state but preserve those reserved spots. These anti-farm rules must be considered separately from how the new pending stack grows and banks. No sideways awards means this playtest cannot establish how the smaller sideways stack will feel.

## 3. Tether Yard

12 attempts, nine restarts, three finishes, no recorded respawns. Clean runs are **12.3984375 s** (`tether-yard_server128_20261110-075454_795_d73c2888.r16run`) and **13.265625 s** (`tether-yard_server128_20261110-075637_303_bf4b054d.r16run`). The **18.28125 s** run `tether-yard_server128_20261110-075856_474_1c3fad66.r16run` records 0→1→3, omits checkpoint 2 and seals as open. The lines travel the three anchor/deck transfers; lower court and return ramps remain available in the source.

The recordings contain **18 attaches, 18 releases and eight misses**. Seventeen releases coincide with grapple no longer held. One occurs with grapple still held exactly **384 ticks / 3 s after attach**: `tether-yard_server128_20261110-075602_219_816651dc.r16run` attaches at **303** near (0.116,5.418,0.090), releases at **687** near (0.165,8.514,-8.113). This is consistent with the source timeout. The release reason itself is unrecorded, so do not present it as a recorded `time` diagnostic.

A ground-pull sequence appears in `tether-yard_server128_20261110-075436_677_21937788.r16run`: attach **1284** at (0,4.001,12), held grapple with no movement keys; at **1400** feet remain y=4.001, z=8.521; at **1472**, y=4.001,z=5.408. At **1473** grapple is released, feet (0,4.001,5.367). Grounded flags persist while horizontal position changes. The later attach **2107** is airborne with jump held. This supports Mike's described ground pull without automatic lift for this observed sequence, not a proof for every geometry or grapple model.

The largest horizontal speed loss is **577.7 u/s**, ticks **404–493** of the 3 s hold attempt, from (0.08,3.70,-8.43) to (-0.11,8.38,-14.47), with grapple held and no motion events. Rising height and changing horizontal speed are recorded; exact rope forces or collision causes are not. There is one 1.3438 s low-speed span across this map's attempts; it is not an enjoyment measure.

Baseline `scripts/r19_tether_player.gd` inherits the frozen R15 grapple; `scripts/r15_experiment_player.gd` defines these rules:

- Acquisition: an anchor within **1181 u = 29.9974 m**, nearest the view centre within **9°**, with a clear eye-to-anchor ray. A hit within **0.3 m** of the anchor counts clear.
- While attached: hold E, automatically reel **260 u/s**, rest length clamped to **96 u = 2.4384 m**. The rope cancels outward radial motion and adds bounded inward pull. Minimum length is **not** an automatic detach condition.
- Detach priority: move disabled, E released, **3 s** elapsed, centre distance beyond **1261 u = 32.0294 m**, then obstructed centre-to-anchor ray. The attachment cone is not re-tested while attached. Auto-detach requires a new press before reattachment; ordinary button release clears that latch.
- Grounded state is passed to `_grapple_step` but not used inside its force law. Full ground behavior also includes the inherited motor. The observed no-lift sequence must not be generalized into a claim about an explicit grapple no-lift branch.

The recorder retains event names and `lab_enabled`, but **omits anchor selection, rope length, distance, tension, pull impulse, release reason and line-of-sight results**. Exact reasons for other apparent detachments are unknown. Mouse attachment/reel separation, automatic-reel preference, cues and alternative models are R20 requirements; R19 runs cannot validate them or rank their feel. Preserve the inherited force law for the requested both-buttons equivalence check.

## 4. Line Drive and Fall Line

### Line Drive

Eight attempts, seven restarts, one **35.6875 s clean finish**, no recorded respawns or ≥0.5 s low-speed spans. `line-drive_server128_20261110-080315_892_a4ead80d.r16run` reaches checkpoints **1/2/3 at ticks 1016/2142/4546**, then finishes at **4578**. The quarter-second line includes revisits and the lower route; completing it does not show the pads were legible.

The baseline launch needs grounded pad support, ≥300 u/s stored horizontal speed and dot ≥0.94 with the pad direction. Each pad fires once per attempt. It adds 160 u/s along that direction up to max(900 u/s, entry speed), sets vertical speed to at least 480 u/s, and then runs the inherited motor. It does not repeatedly boost a spent pad or cut a faster entry down to 900.

In the clean finish, at **1430**, (47.942,7.001,-54.253) on the east pad footprint, recorded speed is **730.52 u/s** and stored-velocity alignment is **0.9764**. Tick **1431** leaves ground with stored vertical speed **12.03325 m/s = 473.75 u/s**, consistent with the authored 480 u/s launch followed by gravity. This is inferred from samples, not an exported launch event. At **1966**, on the same pad footprint (41.459,7.039,-55.090), actual horizontal speed reaches **995.69 u/s**. That supports Mike's statement that he can build speed beyond the pad's nominal ceiling; it does not establish which route is fastest.

Speed alone does not fire the pad. `line-drive_server128_20261110-080208_473_5b807507.r16run` has a grounded west-pad-footprint sample at **856**, (0.429,6.017,-37.558), **408.28 u/s**, but alignment **0.8280** is below 0.94, and there is no >350 u/s upward departure in that attempt. This is consistent with the alignment rule. The needed support collider, pre-step phase and used-pad state are not recorded, so do not call every unboosted pad passage a bug.

The largest loss is **621.5 u/s**, ticks **1710–1933**, `line-drive_server128_20261110-080251_567_d32e7d95.r16run`, near (74.47,11.51,-12.06) to (71.62,5.44,-9.37), with an 8.084 rad accumulated view turn and a landing/jump. No collider attribution is possible. Pad identifiers, impulses and support queries exist in live `get_motion_state().line_drive`, but `_derive()` does not serialize that dictionary. The helper labels high upward departures as candidates; one such departure can also come from a recovery incline, so it does not total them as launches.

Mike's stated shelving reasons remain authoritative: flat line pads, insufficient feedback, unclear landing spot, and his built speed beating them. Position/speed data support parts of that account but cannot measure audible or visual legibility.

### Fall Line

Three attempts, **19.1640625 and 13.046875 s clean finishes**, then a 6.2109375 s recorded attempt ending with quit. Both finishes collect checkpoints 1 and 2. No recorded respawns. The lines cross the falling deck sequence and solid rests; the helper exports grounded samples within each authored deck's top/footprint envelope.

Repeated landings within the same falling-deck footprint are visible. In `fall-line_server128_20261110-080711_094_bbdc5fc4.r16run`, `fall_0` has grounded samples at ticks **1353/1449** (0.75 s apart), `fall_1` at **1550/1646**, and `fall_7` at **2732/2828/2923**. Those last three landings span **191 ticks = 1.4921875 s**, below the source's 2 s warning. Feet are (0.001,5.216,-94.471), (3.532,5.201,-102.319), (2.315,5.239,-103.515). These are grounded positions spatially consistent with the same top, not named support contacts.

A stationary sequence also tests the timer observationally: `fall-line_server128_20261110-080852_170_834c65b7.r16run` first grounds on the `fall_0` footprint at **397**, (-1.816,7.681,-3.841). It stays grounded through **652**, then becomes airborne at **653**, exactly **256 ticks / 2 s** after that first support sample, with no jump or movement held. By **720** it is at (-1.808,4.826,-4.954); at **794** it is grounded on the lower court at y=-1.999. This is consistent with timed support removal and subsequent falling, rather than evidence that the countdown never works. The 2.7422 s low-speed span and 277.5 u/s largest loss belong to this input-released wait/descent sequence.

Baseline `scripts/r19_fall_line_level.gd` arms via a grounded test-only hull support sweep, drops collision on the first pre-step at `ceil(2*physics_hz)` age (256 ticks at F2), and never re-arms a platform until reset. It has a countdown label, orange warning and a mesh falling 8 m over 0.5 s. The source is not evidence that Mike noticed those visuals, and this recording has no frame/audio output. **Support/drop transition logs and timer state are not serialized**, so the exact drop event remains inferred. Mike's shelving reasons are his feedback: no perceived contact/drop cues, a timer too long for his two or three hops, and a future theme such as lily pads or scaffolding to explain collapse. The recordings support multiple hops fitting inside the timer; do not rewrite his taste verdict into a claim that no visual code exists.

### Breakwater

The one fresh `breakwater_server128_20261110-074105_196_0c524ba5.r16run` is **4.1328125 s**, ends on map change, and has no checkpoint, finish, fall, low-speed span or award. Its line stays near spawn. The 15 older Breakwater attempts in the same folder belong to R18 and are excluded.

## 5. Through Line: evidence for launch design, no evidence of seamlessness yet

There is **no Through Line recording** in this cohort. The Line Drive observations above show earned speeds approaching/exceeding its 900 u/s boost ceiling and launch-like upward departures, while its fixed upward impulse is a source fact. They support preserving horizontal momentum and testing readable landing predictions in the prototype. They cannot select the height conversion, compare trajectory readability or establish that a transition feels seamless.

Each finished R19 recording seals at its own map's finish, and map selections are lifecycle boundaries. No fresh run spans a transition between levels. R20 needs a new Through Line recording and presentation evidence across the segment boundary, including before/after horizontal velocity, launch cue, trajectory and landing. Human feel remains a later verdict. None of this analysis changes the original maps' finishes or F2 physics.

## 6. Collecting friends' runs

The copied inventory is **90 sealed `.r16run` files and five cfg files** (`spillway_r12.cfg`, `spillway_r13.cfg`, `spillway_r15.cfg`, `spillway_r16.cfg`, `spillway_v1.cfg`), plus logs and shader cache. No `.part` or `.aborted` recordings appear in this copied recording folder. Old data remains present across a new session: an export of every local attempt should retain it; an analyst must define the session separately, as this hash exclusion does.

R19's settings section in `spillway_r16.cfg` records source sensitivity **2.45**, source FOV **91**, R13 sensitivity **0.95**, R13 FOV **90**, volume **0.7**, `show_ms=true`, `ghost=true`. That cfg also contains earlier records and absolute Linux ghost paths. Per-run metadata independently records map/preset/geometry/motor identities, FOV/sensitivity, build and time; a copied cfg alone is not the authoritative settings history for every run. No player identity is stored in the sampled headers, so per-player import provenance must come from the collection process rather than guessing a player from a filename.

The scope needs are therefore concrete: zip **all local recording states plus settings**, preserve filenames and bytes, include the current export's inventory/hash manifest, retain each player's input separately, validate sealed runs strictly, and label partial/aborted reads separately. The existing strict reader can do the latter. Keep settings/recordings; cache is not needed for this analysis. A friend sends the ZIP manually; there is no upload in this task.

Baseline `project.godot` names the app **Spillway** and has no custom user-directory override. The Windows player README should name `%APPDATA%\Godot\app_userdata\Spillway\r16_runs\`; settings sit alongside `r16_runs` in that same `Spillway` directory. This is a source-derived Windows location, not a native Windows execution claim.

## What style actually fired

These are fresh-session awards, including restarts and open/incomplete attempts. They are R19 immediate scoring, not R20 pending stacks.

| Map | Recorded awards (count / points) |
|---|---|
| saltglass | sync: 188 / 25501, speed: 99 / 9067, edge: 45 / 13089, gap: 48 / 12753, near_miss: 3 / 821, crouch_save: 4 / 4500, backward_bhop: 12 / 2760 |
| tether-yard | sync: 47 / 5026, gap: 11 / 11475, speed: 8 / 430, edge: 2 / 751 |
| line-drive | sync: 129 / 17439, speed: 53 / 8314, gap: 15 / 16382, edge: 2 / 849, near_miss: 1 / 439, crouch_save: 3 / 8625 |
| fall-line | sync: 33 / 5590, gap: 24 / 14653, speed: 12 / 1824 |
| breakwater | none |

## Reproduction and evidence limits

From `/home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner`:

```bash
python3 -I tools/analyze-r20-playtest.py /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/userdata-spillway/r16_runs --exclude /home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/userdata-spillway/r16_runs --baseline 065f7b27993df7ae2511eb34eb665d271dded13c --output /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/r20-analysis.json --manifest /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/r20-input-integrity.json
```

The helper fails on unexpected cohort sizes, duplicate fresh hashes, map/preset/rate mismatch, any strict-read error, direction-award disagreement, changed input-tree bytes, or HOME below 15,000,000,000 free bytes. It strict-reads all 90 files but computes gameplay totals from only the 58 fresh ones. Hash-based membership also catches inherited files renamed after copying. Outputs must be outside both input trees.

`r20-analysis.json` keeps per-run metadata and quarter-second feet lines, the strict reader's top 12 speed-loss sections per run (threshold 0.75 m/s), checkpoint events/samples, all low-speed spans, all reconstructed directional landings/breaks and actual awards, every grapple attach/release/miss with neighboring samples, experiment spatial envelopes and selected full-rate focus samples. Baseline source snapshots and SHA256 hashes of the strict reader, inherited analyzer and new helper are embedded. `r20-input-integrity.json` keeps the exact before/after files/settings hash manifest, inherited hash matches, 58 selected names, helper/source hashes and free-space reading. The original full-rate samples remain in the preserved sealed inputs.

No engine, replay, collision query, native rendering, Windows build or gameplay implementation ran in this research task. Contact identity, rope forces, release reasons, launch support/used-state, collapse transitions and sensory feedback are absent from the recording format. Spatial overlap, rule consistency and event names are kept separate throughout. No motive, enjoyment or collision causation is inferred from retries, speed loss or waiting.
