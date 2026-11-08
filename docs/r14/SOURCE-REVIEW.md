# Independent Source review

8 November 2026. Reviewed `fc96e753a145dbbda54be0ae5aa79ee489f63c34`, including the
server ground-clamp correction. **The air law passes independent vectors through the
real adapter, but the collision solver is not yet a faithful public-Source baseline.**
Vanilla stamina remains a material, honestly documented reconstruction.

This review changed only this document and `tests/r14_source_review.gd` / its UID.
Production, existing tests, frozen vectors, oracle, maps and tools were untouched.
No commit, push, child agent, CS runtime, native capture, Windows run or human play test.

## Findings that need action

### P1: the second collision discards momentum from the first collision

`scripts/r14_source_player.gd:305`, especially line 328, projects the tick's **primal**
velocity onto the accumulated contact cone on every bump. This reuses R13's helper.
The published [Source2013 TryPlayerMove](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/shared/gamemovement.cpp)
updates its working original velocity after the first airborne plane clip and after
positive trace travel. It also resets the plane set after positive travel. A closest
projection of the initial velocity is a different collision rule.

Minimal reproduced case in the dedicated review fixture:

1. The 50° ramp ends at y=0, z=0, with a flat floor beyond it. Its normal is
   `(0, cos(50°), sin(50°))`. Hull width is 32 u, axis aligned.
2. **Labelled seed:** feet `(5000, 1.3, 15)` u; velocity `(0, -400, 250)` u/s;
   airborne. The expanded ramp's top at this center is 1.19175 u, so the seed is
   clear by 0.10825 u, greater than the 0.03937 u safe margin.
3. At 128 Hz press D for one tick, then release. No pose, velocity or state writes
   follow setup. The first move requests `(30, -403.125, 250)` u/s and contacts the
   ramp at bump 0, then the floor at bump 1.
4. Two chronological overbounce-1 projections preserve z=301.7943 u/s. The live
   adapter finishes with z=250.0000 u/s. Its actual first-tick z travel is 2.144607 u
   (274.5096 u/s), and its next released-ground tick travels 1.873779 u
   (239.84375 u/s). The retained speed error therefore affects subsequent travel.

Repeated twice at both rates. At 64 Hz the sequential result is 303.3331, actual
250. The higher-speed valid seed `(5000,20,0)`, `(0,-3000,2000)` loses approximately
305–307 u/s in the same way, also twice per rate. Both seeds use a D press/release.
The expected results are original plane-projection calculations against public SDK
behavior, **not measurements of CS:GO**. This is a public-Source algorithm mismatch;
the exact CS:GO binary's trace and crease quirks remain unmeasured.

Evidence: `final-2/traces/valid_slope_flat_{64,128}_speed{250,2000}_trial{1,2}.jsonl.gz`.
The input-earned descent and its eight height variants did **not** produce both planes
in one tick. They are retained, not counted as reproductions. The ordinary input-earned
right-angle corner stops and reverses successfully, aside from the small jitter below.

### P2: final half gravity breaks the advertised per-axis velocity limit

`scripts/r14_source_motion.gd:265` clamps before travel, but line 295 subtracts the
last half gravity without another check. The public SDK's FinishGravity checks velocity.
After a terminal fall, state and node velocity settle at -3503.125 u/s at 128 Hz or
-3506.25 at 64, beyond `sv_maxvelocity=3500`.

Input-earned reproduction, twice per rate: labelled high spawn `(0,10000,0)` u,
**zero initial velocity**, airborne; D for three ticks, release, fall for 4.6 s.
The final feet are approximately y=1578.13 u, so this is still free flight. Actual
finite-difference downward travel is capped at -3500 u/s, while stored velocity exceeds
it. This is a state/limit defect, not evidence that terminal travel exceeds 3500.
Seeded all-axis limit probes reproduce it too.

Evidence: `final-2/traces/earned_terminal_fall_{64,128}_trial{1,2}.jsonl.gz`.

### P3: successful steps lose their event

`scripts/r14_source_player.gd:261` appends `step` to `s.events`, but the shared tick
overwrites that array with its local `events` at `r14_source_motion.gd:300`.

Twice, from rest at `(1000,0.5,150)` u, hold W at 128 Hz into the fixture's 18 u step.
At zero-based input tick 191, feet rise exactly 18 u and advance 1.953125 u;
`step_ups` becomes 1, but `events=[]` on that tick and no step event appears later.
The step itself works. This breaks the promised per-tick event report.

Evidence: `final-2/traces/step_1000_trial{1,2}.jsonl.gz`.

### P3: resting contacts and takeoff include small unreported travel

Twice, from rest at `(3500,0.5,0)` u, hold W+D for 400 ticks at 128 Hz into the
review fixture's inner corner, then S+A to recover. At tick 395, stored velocity is
zero but actual travel is approximately `(-0.01318,-0.07031,-0.02097)` u. Across
ticks 350–399 the position spans 0.04663 u in x, 0.07227 u in z and 0.07031 u in y;
the maximum horizontal finite-difference speed is 9.70 u/s. It stays bounded and
recovery succeeds. This is small contact jitter, not accumulating velocity or escape.

Likewise, the first earned jump can have an empty contact list while travelling
0.01156–0.02001 u farther horizontally than `requested_velocity * dt`. The strict
free-travel gate fails on these takeoff rows. Free airborne motion away from those
boundaries has only float-position error within the review's 0.015 u/s tolerance.
Godot margin/recovery is the likely cause; this review did not instrument inside the
physics server. Do not call an empty contact list proof of perfectly collision-free
travel. The documented 0.014–0.084 u resting heights already signal this limitation.

Evidence: `final-2/traces/corner_earned_recovery_trial{1,2}.jsonl.gz` and `earned_*`.

## What passed independently

- All 80 frozen air vectors through **M.step**, including its real order, plus actual
  shared-world displacement. All 80 also pass through keyboard/mouse events, the real
  Source player and Godot physics. The live run uses a labelled airborne velocity seed,
  one neutral tick to earn the required surface classification, then D and a mouse
  event. No production wish or yaw helper computes the test's expected direction.
- The 30 frozen friction cases through the live adapter. At both rates, live shared
  ground ticks at 750 u/s match friction with released, aligned, opposite, side and
  cancelling A+D input. In particular server release gives 719.53125 at 128 Hz and
  689.0625 at 64; aligned W adds nothing at overspeed, opposite S subtracts the ground
  acceleration budget, side A adds the perpendicular budget. No auxiliary server cap.
- Cap 30 versus the **uncapped** 250 budget through the shared tick for AA12/100,
  64/128 Hz, F1/F0.25, with capped-budget negative comparisons. Air speed is not capped
  to 30, 250 or 275. At 250 speed, a perpendicular legacy AA12/128 step adds 23.4375,
  whereas capped-budget adds 2.8125. Frozen vectors include reverse and bad projections.
- Deadstrafe boundaries at negative, zero, just-positive, 140 and above-140 vertical
  categorization speeds. The next air update consumes the prior categorization's
  surface, before that next tick's gravity. This verifies the implemented public-SDK
  order, not the exact late-legacy CS:GO categorization timing.
- Standing jump integration matches `J*n*dt - 400*n*(n+1)*dt²`. This is the labelled Source2013
  standing-order case, not a measured CS:GO jump. The oracle's four self-test groups pass.
- Real input-earned W approaches, imperfect sinusoidal mouse deltas, alternating A/D,
  wrong turns, reversed keys, eight-tick mouse delays and three-tick key overlaps.
  Each airborne horizontal velocity update matches an independent event-derived
  projection/budget calculation within 0.002 u/s. At 128 Hz the first two landing speeds
  are 279.37/307.32 for the chosen synced curve and 210.16/153.15 for wrong turns.
  These are fixture results, not optimal curves, gameplay measurements or a feel verdict.
- Release-to-coast keeps airborne horizontal velocity while the mouse continues moving.
  Manual held jump fires once; repeated wheel events and release/repress jump again.
  A press just before landing held through contact does not buffer a manual jump:
  land ticks 46/94 at 64/128, jump only after release/repress at 51/99.
  Server autohop jumps on the tick after landing, before ground friction: 128 Hz
  jumps 80/175/271, lands 174/270; 64 Hz jumps 40/87/135, lands 86/134.
- Box shape is 32×72×32 u, body yaw stays zero under mouse turns. An 18 u step passes,
  19 u blocks, wall approach stops and jump/backward input recovers, corner approach
  stops and reverse input recovers. One motor update per actual physics step; every
  observed delta equals 1/64 or 1/128 as declared. No silent 120 Hz test.

## The 50° W climb is not established as a defect

The independently authored short ramp reproduces uphill travel with an input-earned
W approach. Over 5 s, peak feet heights are 113.94 u at AA100/128 and 82.25 at AA100/64;
AA12 reaches 30.74 and 29.05 respectively. No sampled support on the steep face.
Geometry and approach differ from the implementer's reported 86 u, so these heights
are not a repeat of that exact trial.

Horizontal wish acceleration followed by a steep-plane projection can make upward
velocity. Repeatedly refilling that projection can counter gravity even when the
normal is below the walkable threshold. That is compatible with the public rules;
surprise alone does not distinguish a game defect from a Source consequence. Exact
CS:GO collision/trace behavior here is still unknown. Do not add an arbitrary steep-face
slowdown to make this observation disappear.

## Vanilla fidelity is still an acceptance gap

The current `gokz_fit` is labelled accurately in the implementation document. The
[GOKZ authors' mode documentation](https://github.com/KZGlobalTeam/gokz/wiki/Modes)
supports the cvars and their observations: landcost .05 produces about 183.05 u/s
from 250 and about 40 u next-jump height; .02 produces 221.97 and about 49 u. The
[vanilla plugin](https://github.com/KZGlobalTeam/gokz/blob/master/addons/sourcemod/scripting/gokz-mode-vanilla.sp)
also supplies precise cvars and a maximum-speed hook. Neither source specifies
`f=1-S/100`, the walking `f²` clamp, or recovery-before-pending-land-cost order.
Fitting two observations does not establish those equations.

Supported equations in this review are friction/stopspeed, projection acceleration,
legacy cap/budget separation, gravity integration under the chosen standing order,
and the stated Source2013 surface categorization. Unresolved binary details include
vanilla stamina, exact jump/landing penalty order, the late-legacy takeoff/grounded
speed restriction and collision trace quirks. The 275 takeoff clamp and auxiliary
vanilla ground clamp remain reconstructions. Exact vanilla N-hop speed is unresolved.
An unqualified in-game "CS:GO vanilla" label overstates what has been established.

CS2 claims do not resolve these gaps. The previously cited CS2 286 clamp uses 260;
it cannot establish legacy CS:GO's 275 reconstruction for this 250 fixture. The
[deadstrafe research](https://gist.github.com/zer0k-z/808bc8bfc494e0bbb5a423c2b1ca6685)
discusses both games, but supplies no complete vanilla stamina equation. No new
primary binary measurement was found or performed. This review read the cached
primary SDK/GOKZ evidence and freshly fetched the vanilla plugin; it used no leaked code.

Known scope exclusions also remain: duck has no shrinking hull or duck-jump behavior;
there are no ladders, water movement, moving ground or base velocity. The passing
standing, fixed-250, normal-material cases do not cover those CS mechanics.

## Reproduction and evidence accounting

From `projects/foldrunner`:

```sh
/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --audio-driver Dummy --fixed-fps 128 --path . \
  --script res://tests/r14_source_review.gd -- --out=EVIDENCE_DIRECTORY
python3 tests/r14_source_oracle.py --self-test
```

Review suite result: **559 checks, 517 pass, 42 fail**, 212 archived episodes. Exit 1
is intentional while findings remain. Failures are not 42 distinct game bugs:

| Failed checks | Count | Meaning |
| --- | ---: | --- |
| chronological contact momentum | 8 | P1, two seeds × two rates × two trials |
| final maximum velocity | 8 | P2, seeded and input-earned, two rates × two trials |
| missing step event | 2 | P3, two input-earned trials |
| corner exact-rest condition | 2 | bounded contact jitter, two input-earned trials |
| strict no-contact free-travel equality | 12 | takeoff recovery discrepancy, six curves × two rates |
| earned slope/flat target not reached | 10 | unsuccessful reproduction variants, **not game defects** |

Evidence root:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-review/`.
`final-3/summary.json` and gzip traces are the authoritative last run; `provenance.json`
and `SHA256SUMS` identify the reviewed code, frozen inputs and archived evidence.

Every trial is retained: initial compile failure (`after` needed an explicit type),
first 498-check run, round 3's 516 checks, round 4's 534, final's 542, final-2's 559,
and final-3's 559 with explicit engine-rate/time-scale assertions. The `final-2` trace
links above refer to the measured reproductions; `final-3` repeats the same findings.
The first 32 slope-transition variants include starts embedded in the expanded ramp
and others moving away from it; they are exploratory data, **not valid repros**. The
valid clear-start cases were added separately. Both initial earned descents and all
eight altered-height approaches missed a same-tick two-plane contact. No failure was
turned into a pass by changing production or the oracle, and the strict travel gates
were not relaxed after observing the takeoff discrepancies.

The first provenance query ran from the project subdirectory and returned an empty
path list; it was corrected to run from the repository root and require a nonempty list.

All runs were headless with Dummy audio. No display/profile was opened, no movie was
made, and the native-capture free-space gate was never needed. Evidence remains below
100 MiB. No owned Godot/oc process remains. Existing R13 motor/course scripts are identical
to the pre-Source tree; provenance records the comparison and source hashes.
