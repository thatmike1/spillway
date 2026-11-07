# Overflow ordinary-input challenge

Overflow is playable with W, held Space and coarse mouse input on the committed course. This challenge found real missed-line stops, including a long stop against the west berm's end wall, but did not establish a motor fault. The stop has an ordinary lateral-input recovery. Continuous hopping can retain a useful tail-race advantage through the arrival climb. This is an unblinded behavior/course review, not final acceptance, fresh discovery or an enjoyment verdict.

## Evidence and scope

Evidence root, abbreviated **E** below:

`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/casual-review/`

- `frozen/` is a diagnostic `git archive` of `bc040f5be44349fa0dc61f6cb7d44216eda2eb34`, not a Git worktree. `SOURCE-MANIFEST.json` verifies all 323 committed files byte for byte. The added review probe is the only executable addition. New art and package helpers are excluded.
- The course script matches revised level commit `cc0147b69b6e07334bd65f3a565752fbd41a5307`. Default scene is `scenes/momentum_overflow.tscn`. Runs instantiate its real `momentum_overflow_main.gd` product factory, with the same default settings and normal spawn, persistence off. The scene's persistence switch is not under test.
- Read: `AGENTS.md`, `BRIEF.md`, `BUILD.md`, `TAPE.md`, `PLAYABLE.md`. R12 is a retained comparison, not this review's acceptance.
- `tapes/NAME.json` is the exact submitted input. `runs/NAME/evaluator/plan.json` is the expanded input actually executed. Every episode retains its full `trace.jsonl.gz`, `casual.contacts.jsonl.gz`, `casual.summary.json`, original evaluator `report.json`, engine metadata, logs, source copies and cleanup record.
- `results.json` and `results.tsv` enumerate all 35 distinct episodes. `contact-extracts.json` retains selected full trace rows. `challenge.py`, `extra.py`, `independent.py` and `recovery.py` retain generation provenance. They are small evidence scripts, not production helpers.

All inputs follow normal spawn. No position, velocity, finish, progress or checkpoint writes are used by the probe. There is no fixture. The probe extends the existing frozen tape executor only to observe progression, displacement and collision manifolds. It never reads state to select an input. All prerecorded mouse paths derived from the final authored tapes are explicitly unblinded. The three hand-authored held-hop routes use two finite smooth mouse strokes, informed offline by a straight calibration run. They are also unblinded, not view-only discovery.

The finite challenge has 35 distinct input episodes, including five render30 episodes, plus three native replays of existing episodes. Failures are retained. Four references are controls; the remainder challenge inputs or recover a reproduced miss. This is a diagnostic selection, not a probability sample of players: **23/35 finish cleanly without respawning; 12 remain unfinished at the fixed budget**. All 35 pass input-delivery and ordering checks, with no evaluator integrity flags. The exact motor counter verifies every non-reset step. Ten game-controlled respawn steps across eight episodes have only state/priority consistency, as the unchanged evaluator explicitly reports. Neither failure budgets nor evaluator thresholds were changed to improve the count.

## Findings, in material order

### 1. Held autohop works across the actual course without precise jump edges

`tapes/hand-held-turn-1720.json` holds W and Space from tick 0. Its only mouse input is:

- Tick 1720, a smooth left 90-degree stroke over 144 ticks.
- Tick 2200, a smooth right 90-degree stroke over 144 ticks.

At sensitivity 1, each stroke totals 713.99833 relative pixels. There is no braking, side key, waypoint controller or state-triggered jump. This run finishes **clean, 22.666667 s, zero respawns, 29 jumps**. Ordered stage ticks are Pier 934, Chute 1352, Tail race 1735, Finish 2730. Finish feet are `(-60.73243, 0.71660, -189.61330)`, actual horizontal displacement speed **11.51001 m/s**.

This is a bay-recovery line, not proof of an unearned wide-gap clear. It contacts `bay_apron` at tick 1343, feet `(0, 3.26362, -81.29039)`, normal `(0, 0.940127, 0.340823)`, and jumps back onto the chute. Its close overall time to the reference mastery route combines a slower prefix with a faster tail.

`hand-held-turn-1720-render30.json` batches mouse counts at four-tick boundaries. It has the same finish tick and time, zero respawns and 11.51001 m/s finish speed. Its maximum pre-finish position difference from tick120 is 0.31387 m, not bit-identical cadence behavior. Finish x differs by 1.33 cm.

The additional independently authored first turns at ticks 1660 and 1780, each followed by the second turn 480 ticks later, also finish cleanly, at 23.516667 and 22.666667 s. This is a useful tolerance demonstration within this particular route, not a universal correction envelope. The first turn at 1660 takes a less efficient western approach and arrives at the ramp at 6.67 m/s, versus 13.73 for the other two.

The straight calibration, `hand-held-straight.json`, reaches all three intermediate stages without respawning while holding W and Space and sending no mouse input. It then runs into the south berm because it never turns. Its 24 s budget is deliberately a calibration, not a promised whole-course finish.

### 2. A missed outer line can stop physically, but the west berm is recoverable

`ordinary-no-brake.json` preserves the ordinary reference mouse/jump path but removes its S interval. This is a deliberately imperfect combination of higher speed and unchanged turns. It reaches the west berm and stops against its south end wall, **before finish**, at tick 2579:

`p = (-68.69680, -0.60220, -169.68918)`

Approach horizontal displacement was 8.48785 m/s; at contact it is 0.0. Post-contact horizontal motor velocity is also zero. The manifold has two `berm_w_s` points at z = -170 with normal `(0, 0, 1)`, plus `berm_w` support with normal `(0.393968, 0.919124, 0)`. Reported penetration depth is 0.002228 m. Solver travel is `(-0.000627, -0.000501, -0.010624)` and remainder `(-0.003545, -0.002833, -0.060087)`. Net measured horizontal displacement is zero; solver travel alone would misdescribe the outcome.

It remains at approximately `(-68.69212, -0.60519, -169.69838)` with W held. The original evaluator records a stuck window from ticks 2586 to 4319. This is a real contact stop, not an expired tape releasing W or a false speed display.

`ordinary-no-brake-recover.json` changes only one thing: D is held during ticks 2640 through 2839 while W continues. It leaves the corner and finishes **clean, 25.625 s, zero respawns**, at `(-57.05984, 0.42338, -189.57874)`. The baseline stop and recovery input are reproducible in the same run. No practice, checkpoint reset, pose correction or automatic rescue is involved.

Classification: an over-wide input line meeting an authored guard wall, with a usable lateral recovery. The measurements do not support blaming the motor. The wall is a deliberate boundary; whether its presentation communicates the exit needs the moving view. The existing hint already says to come off the berm toward the sluice house. No geometry or control change is justified by this evidence alone.

### 3. The tail and arrival do not force every useful line to the same run speed

The reference ordinary line spends 11.200 s between reaching Tail race and finish. It enters the arrival ramp at 8.384 m/s and finishes at 8.329 m/s. Those numbers reproduce the known evidence, but depend on that line's pool braking and subsequent ground running.

| Input episode | Tail race to finish | Ramp entry speed | Finish speed |
| --- | ---: | ---: | ---: |
| `ref-ordinary` | 11.200 s | 8.384 m/s | 8.329 m/s |
| `ref-mastery` | 10.342 s | 8.340 m/s | 8.331 m/s |
| `tail-hop-fast` | 9.383 s | 10.648 m/s | 8.925 m/s |
| `hand-held-turn-1720` | 8.292 s | 13.733 m/s | 11.510 m/s |

Ramp entry is the first pre-finish crossing of world z = -170, measured from actual displacement. Stage-to-finish intervals use actual recorded stage ticks, not authored route nodes.

`tail-hop-fast.json` keeps the ordinary prefix and pool brake, holds Space from tick 1760 and compresses the later mouse schedule by 0.8, after replacing fine steering with smooth 24-tick strokes. It finishes cleanly in 23.083333 s. `tail-hop.json` makes the same held-hop change without advancing those turns and spends time against the western end wall, finishing only at 33.350 s. The timings are behavior probes, not player skill estimates.

Thus speed retention and earlier/wider turning have a real reward, and a poor high-speed approach can cost a line. The uphill arrival still spends some retained speed. Many grounded lines converge to ordinary run speed, which is a movement/layout tradeoff, not evidence that every line does. These comparisons do not isolate the air law from ground policy or establish fun. Whole-course times also confound prefix and tail choices.

### 4. Imperfect ordinary jumps and corrections are tolerated; replay timing remains consequential

| Episode | Clean time | Challenge |
| --- | ---: | --- |
| `ordinary-jumps-18` | 24.983333 s | All jump edges 150 ms early |
| `ordinary-jumps+18` | 25.966667 s | All jump edges 150 ms late |
| `ordinary-smooth-0.94` | 24.150 s | Smooth 200 ms mouse strokes, 6% less turn |
| `ordinary-smooth-1.06` | 25.550 s | Smooth 200 ms mouse strokes, 6% more turn |
| `ordinary-coarse` | 24.833333 s | Smooth 400 ms strokes discard fine steering |
| `ordinary-independent-edges` | 24.058333 s | Each jump press/release and each brake edge jittered separately, smooth mouse wobble |
| `ordinary-independent-edges-render30` | 24.041667 s | Same imperfect plan, four-tick input cadence |
| `miss-imperfect-24` | 25.225 s | Bay-miss reference, jumps 200 ms early, 3% less turn |
| `miss-imperfect+24` | 25.700 s | Bay-miss reference, jumps 200 ms late, 3% less turn |
| `pool-runoff-unbraked` | 27.933333 s | No pool brake, no bucket jump, 2% more smooth turn |

Every row has zero respawns and all stages in order. `miss-imperfect+24` actually contacts `bay_apron` at tick 1264, feet `(0, 3.08562, -80.79939)`, normal `(0, 0.940127, 0.340823)`, then physically climbs to the chute. `pool-runoff-unbraked` actually contacts `pool_apron` at tick 1820, feet `(4.45669, -5.22554, -119.84261)`, normal `(0, 0.967614, 0.252433)`, then reaches Tail race at tick 1919 and finishes. These are observed recoveries, not inferred from the finish flag.

Replacing the ordinary reference's jump edges with held Space while keeping its original mouse timing fails in both tested cadences. In tick120, the first hard catch is tick 941 at `(-4.69894, 8.25299, -31.20032)`, against `pier` and `slot_2_end_l`. Later it reaches `slot_2_outer`, loses its line and respawns twice. The render30 version respawns once and ends caught by the slot's side geometry. Starting the hold only at tick 442 also gets out of synchronization and respawns once.

The tick120 run does physically climb out of the slot before its first respawn: at tick 1883 it reaches Pier at `(4.95257, 8.72846, -35.22237)`. Its first reset is tick 2279 after leaving the next platform. Thus even this failed whole-course episode is not a permanent slot wedge. The native failure clip retains only its first 1800 ticks, including both contacts, and does not show that later escape; the complete 4320-tick headless trace does.

These failures are retained and are not refuted by the successful coarse held route. Their scope is the combination of held-hop timing with an unchanged prerecorded mouse schedule. They do not prove that the HUD's held-hop control is broken: the independent straight approach clears both slots, and two-stroke held-hop routes complete the course. They do show why precise replays alone are insufficient.

In particular, the ordinary schedule starts its left turn at tick 773. The straight held-hop approach reaches Pier only at tick 934, versus tick 816 on the ordinary reference. The changed jump/start behavior makes that same turn premature. A person reacting to the view might delay it; that human response was not tested.

## Failure accounting and limits

The 12 unfinished episodes are `hand-held-straight`, `ordinary-held-0`, `ordinary-held-0-render30`, `ordinary-held-442`, `ordinary-no-brake`, `ordinary-no-jumps`, `tail-unbraked-fast`, `tail-unbraked-hop`, `tail-unbraked-hop-fast`, `tail-unbraked-hop-fast-render30`, `mastery-tail-held-0.75` and `mastery-tail-held-0.9`. Their exact endpoints, respawns and pre-finish contact windows are in `results.json`. Most combine faster/slower travel with turns still tied to the reference schedule. Do not turn those observations into a motor-fault count or hide them behind the successful routes.

All main episode budgets are 4320 ticks (36 s), except the 2880-tick straight calibration. W is held through the budget, apart from explicit in-run braking intervals. There is no inherited terminal W release. A finite unfinished episode is not proof it can never finish. A respawn changes the run to practice, so those episodes do not count as clean recovery.

The original evaluator flags are unchanged. Most completed extended-W runs eventually hit the wheel plinth or house after finish. Those contacts remain in the raw reports but are excluded from the report's **pre-finish** stop interpretation. This does not alter course outcomes or evaluator thresholds.

Reference replays reproduce ordinary 24.891667 s, mastery 22.475 s, bay miss 25.591667 s and pool miss 27.766667 s exactly. The supplied final open-loop 30/42 versus W-extended 42/42 evidence was a comparison claim, not this review's sample or acceptance target. The two candidate ramp-side catches on frozen block holdouts were not reproduced on this revised course, nor tested as block fixtures here.

This review made no production changes or commits. Implementation and delivery decisions remain with root. No small motor or geometry change is supported strongly enough to recommend from this challenge alone.

## Native verification and remaining uncertainty

Three actual native recordings are retained under `E/native/`, each with an MP4, sampled frames, contact sheet, full telemetry and the exact command:

| Episode | Captured input ticks | Native observation |
| --- | ---: | --- |
| `hand-held-turn-1720-render30` | 2820 | Held-hop course completion and finish card at 22.67 s |
| `ordinary-held-0` | 1800 | Premature turn, pier-face catch, traversal toward the slot's outer side |
| `ordinary-no-brake-recover` | 3180 | West end-wall stop, lateral escape, clean finish at 25.625 s |

`native-comparison.json` compares every captured tick against the corresponding complete headless episode: **0.0 m position difference and 0.0 m/s actual-velocity difference on all 7800 compared ticks**. All native motor steps are counter-verified. This is same-machine replay evidence.

I inspected the whole sampled course sequences and denser event sequences in `inspection/held-finish-sequence.png`, `inspection/slot-catch-sequence.png` and `inspection/berm-recovery-sequence.png`. The held route shows the slot approaches, bay catch, bucket/pool, two tail turns and uphill finish. The failed slot view becomes mostly close concrete; the right-ramp hint remains visible. The berm view similarly fills with its end wall until lateral movement reveals the arrival ramp. This supports physical collision/recovery interpretation, but does not establish that a new player would recognize and execute either exit.

Native runs use private Xvfb **:168**, isolated XDG profiles, Dummy audio and forced **llvmpipe software rendering**, Godot Compatibility. The command requests an 854×480 window; the project retains a roughly 1280×720 viewport (engine metadata reports 1281×720), and movies are 1280×720 at fixed 30 fps. These are not smaller-resolution performance tests. The three H.264 movies total about 36 MB; raw AVIs were removed only after compression and validation. Software movie wall time is not pacing, latency or desktop-GPU evidence. Windows execution, hardware input/focus, listened audio, fresh view-only discovery and enjoyment remain unverified. New art and finish-water work are excluded.

Every one of the 38 game processes ends with `completed`, exit 0 and neutral input. Headless wrapper cleanup reports clean; all three native display cleanup records show socket and lock removal. Final process inspection found no owned engine, capture process or Xvfb :168, and no :168 socket/lock. One outer native exec session reported status 143 when reaped after all three results were written; its cause is unverified. `native-runner-status.txt` records this separately rather than presenting it as a verified normal runner exit. It does not replace the actual per-engine exit, movie or cleanup evidence.

## Actual hashes

`SOURCE-MANIFEST.json` records every committed source/asset hash; verification after all runs finds no changes to those 323 files. `IMPORT-CACHE-MANIFEST.json` records the generated imported-asset cache. `HASHES.json` records every submitted tape and expanded executed plan, the frozen Python/GDScript helpers, the review probe versions, evidence scripts, reference tapes, movies, Godot and capture-tool executable hashes. `submitted-tape-stability.json` verifies that none of the 35 submitted tape files changed after execution. Per-run `run.json` and `casual.summary.json` independently retain their actual source/helper identities. A diagnostic archive has no Git HEAD of its own; use the explicit archive commit and source manifest, not the wrapper's empty Git field.

Key SHA-256 identities:

```text
godot 4.7.2     8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e
revised level   56aaa0cbf318f32b8a82c06f814f179e3f73af195c187345be0466369042d03b
candidate air   aceb14e519b0fad44ab8443c6ece4f4262d6fb92e21ee8881c4fc30119576b25
shared body     1c3a4f9d4687c62c53fc4ec10efbbf09cf31fc43ba34d3cc7850ff13011276b9
tape wrapper    f8cc2e2dc1745ff5b10bfc1754bc6a99946bdca048560b25565395742ad9106e
tape executor   4a5250233348f7eef40285347f7a426d0ad1e2a1abc83d19ae9212d2515b19fb
delivered probe df8c9cfed1a030e37d9388638a583ea49d1db21689ab29c77e7bebedd4ef2767
headless probe  e3c6b14cee0a9df0cc4c63ad50e4e3ac57bb4d1db5e902d5c5aac345338dc313
```

The headless probe differs only in one usage-comment correction, preserved as `probe-headless.gd` and `PROBE-COMMENT-ONLY.diff`. The delivered probe ran in all three native replays. No runtime behavior changed between those probe versions. `verification.json` retains all 38 delivery/order/neutral/cleanup results and native comparisons.

## Rerun one retained episode

The frozen wrapper owns engine/profile cleanup. Run it from any directory; use a fresh output outside `frozen/`:

```sh
E=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/casual-review
python3 "$E/frozen/tools/momentum-tape.py" run \
  "$E/tapes/hand-held-turn-1720-render30.json" \
  --out "$E/replay-held-new" --headless --render-fps 30 \
  --executor "$E/frozen/tests/test_overflow_casual_review.gd" \
  --game-script res://scripts/momentum_overflow_main.gd --game-class '' \
  --motor candidate
```

Swap the tape path for the recorded failure or recovery. The probe is also usable in the main project with its existing `tools/momentum-tape.py`; the frozen copy is required to reproduce this review's exact source. Uncompress a retained trace before asking the existing wrapper to re-evaluate it, since that wrapper expects `.jsonl`, not `.gz`.

To rerun a captured native prefix, use its `native/NAME/evaluator/plan.json` as the tape, a fresh output, omit `--headless` and add `--display 168 --wall-budget 600 --deadline 660 --actor-every 60`. Confirm :168 is free first: the stock wrapper otherwise picks another private display. This reproduces the native input episode at the project's default viewport; `native/NAME/run.json` preserves the exact original command and smaller window request. Neither option changes the course or motor.
