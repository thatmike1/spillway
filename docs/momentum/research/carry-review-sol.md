# First CARRY: independent Sol review

**One new P1 defect: a descending takeoff can keep stale support and fire another held hop on the next tick.** Fix this before using CARRY contact behavior to choose a course or air policy. No default-game or backend change is recommended. CARRY remains an experimental comparison.

Reviewed frozen HEAD `390cb022d733a46669b25baa96e9047f1d449df4`, not the concurrent air challenger or Overflow work. All experiments, source snapshots, plans, rejected trials and logs are outside Git at:

`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/carry-review-sol/`

## P1: downhill takeoff is incorrectly treated as another support arrival

Source: `scripts/momentum_carry_player.gd:210–216`. The suppression predicate uses world `velocity.y > 0`. On a descending support, a real separating hop can still travel downward in world space. A stale floor survives, resets air time, and permits held autohop again. The second hop also converts horizontal air velocity as though it were still encoded surface speed.

**Direct observation, earned episode.** Start from rest on a 30° descending ramp, yaw −0.12 rad, beside a vertical rail. Hold W from tick 0 and Space from tick 300. No subsequent state writes. `final-v3/traces/earned_rail_broad_right_0.jsonl` records:

- tick 387: land on the ramp, caught control surface speed 29.4335 m/s;
- tick 388: hop with requested `(0.1010, −7.5167, −25.4900)` m/s. Its dot product with support normal `(0, 0.8660254, −0.5)` is **+6.2354 m/s**, so it is separating. Nevertheless `grounded=true`;
- tick 389: another hop without a new landing or jump press. Horizontal forward command drops to 22.0746 m/s, while vertical command changes to −5.5448 m/s.

This is a duplicate event and a changed physical trajectory, not merely a ledger discrepancy. Every ledger residual in the three-tick reproduction is zero. It does **not** establish an energy-farming exploit.

**Reduced physics-only fixture.** One labelled setup places feet at `(1.45108294487, 3.48476290703, −53.3626708984)`, yaw −0.12, with velocity `(0, −20.0365810394, −22.3228416443)`. The ramp top passes through `(0,40,10)` and `(0,40−120·tan(30°),−110)`, width 8 m. Its box is 1 m thick. The rail is a box centered `(2,0,−30)`, size `(0.5,200,200)`. Press W and Space at tick 0, simulate **three ticks**. Tick 0 lands; ticks 1 and 2 both hop. This setup preserves a state extracted from the earned run: its feet are 6.72 cm vertically above the ramp plane, and its capsule overlaps the rail by about 1.08 mm. The earned run establishes that ordinary engine motion reaches this recovery state without a fixture teleport.

Repeatability and controls:

| Trial | Observation |
| --- | --- |
| Reduced repro, broad/narrow × left/right reflection × three repeats | all 12 reproduce; repeated positions match exactly |
| Earned repro, broad and narrow, twice each | right-hand cases reproduce at ticks 388/389; repeats match exactly |
| Earned left-hand reflection | no duplicate in this timing; retained negative result |
| Remove rail, or remove W, in reduced setup | one hop; no stale supported departure |
| Release Space at tick 2 after the buffered first hop | stale support remains, but no second hop |
| Ten additional read-only motion reports before each step | position traces remain bit-identical |
| Same reduced inputs and geometry under Jolt | no duplicate in all 12 cases |

The negative removals establish which elements trigger this reduced repro, not that every downhill hop needs those elements. Earlier straight descents at 20°, 30° and 40°, including negative-world-vertical takeoffs, did not duplicate. A separate 40° descent with valid 2.3 m overhead clearance also reproduced the stale-support pattern in exploration (`contact-v1`, `corridor_40_2.30_true`).

**Causal diagnostic, outside Git only.** Changing just the predicate to `if hop:` in `variant-clear-hop/` removes the duplicate and supported departure in all 12 reduced and eight earned checks. In the reduced broad/right case, tick 2 actual forward travel speed becomes **25.5034 rather than 22.0908 m/s**, a 3.4126 m/s difference. Tick 1 displacement is identical between variants. The scratch change also clears inward rail velocity on that takeoff. This is evidence against the predicate, not validation of an unconditional-clear production fix across every possible same-tick contact.

**Root must fix:** determine separation relative to the departed support, prevent stale takeoff contacts from rearming autohop or reinterpreting air speed, and retain feasible wall/ceiling resolution. Rerun the reduced and earned cases, including buffering, headroom and both backends. Keep the first profiles frozen for the air comparison.

## Other observations and confirmed strengths

The final suite has 96 cases: 12 reduced, eight earned rail runs, 16 controls, 32 imperfect approach trials, four overhead cases, 18 ledge-side/off-centre cases and six intersecting-slope cases. It exits 1 with **36 failed gates arising from the P1 repro and its repetitions/controls**, and zero ordering, step-count, interpolation, ledger-residual or finite-difference reporting violations. The additional grounded rail diagnostics are nonblocking.

- **Ordinary inputs retain useful meaning in these trials.** The approach fixture earns about 21.35 m/s naturally down a 12 m descent before a flat launch and 8 m gap to an offset landing. Both profiles, mirrored left/right, miss the offset with straight W and reach it with pre-aim, late side-key/mouse correction, small mouse wobble, countersteering, and jump timing shifted ±8 ticks. All are finite open-loop input tapes, not trajectory writes.
- **Landing is not completion.** The pre-aim, wobble and countersteer tapes reach the target, then run off its side because they never correct again. The broad late-side tape ends supported near x ±4.86 m; narrow ends drifting beyond the edge. This is a useful approach distinction, not evidence that all corrections are forgiving or that either profile is enjoyable.
- **Braking changes the outcome.** Thirty ticks of S before takeoff reduces measured takeoff forward speed from 20.63 to 12.63 m/s. The same scheduled jump fails to reach the landing; by tick 569 it has travelled about 17 m less forward. It does not reverse during that braking segment.
- **No new ledge-side jump or crease exploit was demonstrated.** Below-top side approaches, off-centre landings and 10°/25°/40° opposing cross-slopes were exercised in mirrored pairs. Valid overhead geometry was also exercised. These are bounded negative results.
- **Actual motion reporting holds up.** All final cases report exactly the finite-difference vector measured around the motor. No instrumented motor subclass was needed; the extra-report controls also verify that observation did not move the body.

Grounded floor-plus-rail contacts sometimes retain an inward next-command component even after reconstructing the declared surface tangent: peak 1.7287 m/s at first rail contact, then roughly 0.144 m/s on intermittent supported ticks. This also occurs before any hop and survives the scratch predicate change. Actual side displacement remains bounded near the rail, and no sustained penetration or speed inflation was demonstrated. It is retained as a contact diagnostic, **not counted as a second confirmed movement defect**. See `earned_rail_broad_right_0`, ticks 157–299. Raw horizontal ground commands were never compared directly to world slope travel.

Rejected invalid trials are retained: `contact-v1` clearance 1.82 m on inclined floors is too small for the standing capsule's geometry. Their rapid hop counts and overlap behavior are not findings. The first seeded minimization attempts (`minimal-v1`) also failed to reproduce; `minimal-v2/v3` document the successful reduction. Known broad/cadence/lip/landing-tick/course faults were not rediscovered as new findings.

## Reproduction and evidence identity

```sh
G=/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
E=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/carry-review-sol
XDG_CONFIG_HOME="$E/profile/config" XDG_DATA_HOME="$E/profile/data" XDG_CACHE_HOME="$E/profile/cache" \
  timeout 90 "$G" --headless --audio-driver Dummy --fixed-fps 120 --path "$E/frozen" \
  --script res://tests/test_momentum_carry_review.gd -- \
  --fixtures="$E/review-fixtures.gd" --only=minimal_broad_right_0 --out="$E/repro-one"
```

Expected: two failed support/hop gates, exit 1. Omit `--only` for the 96-case suite, or use `--only=earned_rail_broad_right_0` for the earned run. The new repository test is a runner over the external fixtures; `--fixtures` makes that dependency explicit. It is not a standalone fresh-clone fixture pack.

Godot 4.7.2 `ed1daf0bf`, 120 Hz, source-mode headless physics. SHA-256:

- engine: `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`
- frozen CARRY: `280be87c5144377018f7637dea9accd421d1c5efe1192a3dfcfebe03565e306a`
- inherited player: `b1b119b2e178e5eea56dd1fffcf7b90abffb0e8839a633c24c642adec07c01e9`
- final review runner: `7cac201a89df69916b2926d68f5d065529e215d5cf8f9d49d2f0f2a4617d330c`
- final fixtures: `e7781913e7089b7f32921342864e16eeb7bd71f3141d4408e8d19442e1ae5b47`

`provenance.json` records the frozen core hashes and matching live sources. `final-runs.json` records the final 96-case run, 12 reduced diagnostic-fix checks, eight earned diagnostic-fix checks and 12 Jolt checks, with engine/project/motor/test/fixture hashes. `evidence-sha256.json` indexes retained artifacts. `sources/` retains helper revisions; `frozen/` is the base commit snapshot, plus the new review runner. Earlier discovery batches remain beside the final runs.

No native view was needed to establish this physics defect. Real mouse hardware, GPU/display pacing, native Windows, the actual authored course and enjoyment remain unverified here. No existing motor, game, lab, level, settings, active Overflow or air-challenger file was edited. Only the new review test and this report are left uncommitted.
