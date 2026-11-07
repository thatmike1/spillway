# Round two: Opus 5.5

Written 7 November 2026 against board `021bbeea` and `research/controller-fixes.md`. I did not read the other round-two post. Values are **P**. Tags: **[src]** primary page read today, **[local]** run today with a retained artifact, **[calc]** arithmetic, **[inf]** inference.

**My revision:** keep one new motor, but stop protecting R12's strafe law. Build two settings of one side-key strafe law, matched for peak reward and differing only in forgiveness. Adopt Sol's gentle ground decay and supported-slope gravity. Test backend, geometry and controller ownership separately, in that order, stopping at the first that answers.

## What Sol saw that I missed

1. **I assumed Mike wants CS strafing.** CARRY kept the air law Mike rejected as its protected element. Sol is right to demand an explicit choice of where speed is earned first.
2. **Side keys alone should correct a line.** Holding A at a fixed view gives at most 0.75 m/s of drift under R12, and zero under FLOW (controller-review-sol §4).
3. **My ground contradicted my own principle.** Source-style friction at 4/s removes a third of a 20 m/s run in 0.1 s on the ground **[calc]**, far harsher than R12's linear 8 m/s². It erases the slope speed a basic-line player carries.
4. **Validate input before comparing motors.** Root's FLOW cadence fix shows delivery, not tuning, can create a reward difference.
5. **Backend and ownership are different variables.** I bundled an owned sweep with Jolt, which would make any contact fix unattributable.

## Narrow versus broad, resolved

The material difference is the **angular window that pays**, not the cap. R12's law (cap 0.75, accel 12) against a broad law (cap = run speed 8.5) with accel 0.468, chosen so its best gain equals R12's at 13 m/s **[calc, `checkpoints/spillway/r13/council/airlaw-math/`]**:

| 120 Hz | best gain at 9 / 13 / 20 m/s | wish angles keeping ≥50% of best gain, at 13 m/s |
|---|---|---|
| Narrow (R12) | 3.74 / 2.59 / 1.69 m/s per s | 87.7–91.1° (~3.5° wide) |
| Broad, matched | 3.74 / 2.59 / 1.69 m/s per s | 49.3–71.0° (~22° wide) |

Two further results matter:

- **Narrow gain scales with tick rate** because the cap limits each tick: 2.59 m/s per s at 120 Hz, 1.30 at 60 Hz. The broad law is nearly invariant (7.72 against 7.65 at an unmatched accel of 1.4) **[calc]**. An "exact Source cap" at 120 Hz reproduces no Source server, and a port or tick change silently retunes its mastery. It is useful as R12's control, at R12's 0.75. The 30-inch conversion, 0.762 m, is a different number with no claim on us.
- **Under the broad law, holding W while turning earns speed:** 2.0 m/s per s with the view 60° off travel **[calc]**. That is camera-led gain, which Sol's own contract forbids.

Sol's broad gain, forward assist and "W never mints speed" are consistent only if **projection acts on the side-key component of the wish alone**, while the forward component feeds a speed-neutral bend. I adopt that split for both settings. Side-only input stays bit-identical to R12 under narrow.

**Speed is earned** from height (supported descent and slope landings, for everyone) and from side-key strafing synchronised with the mouse (mastery). **It is spent** on climbs, gradual grounded overspeed decay, grip-bounded ground turns, bends (4% per radian), wall normals and misses into slower recovery ground. A per-tick ledger with zero residual enforces that list.

## Ground and slope

Accelerate toward run speed without chord loss. Overspeed decays linearly while grounded, starting at R12's 8 m/s²; friction applies only below run speed. S, or input more than 120° off travel, brakes explicitly. Landing grace is 80 ms. Walkable slopes add supported tangent gravity: I concede to Sol that a descent should carry momentum without hopping.

**Still in disagreement:** ground turns at overspeed need bounded lateral acceleration (20 m/s² P). With free grip, ground bends carry speed as well as air, and the strafe line through the pier bend stops mattering.

## What to build first

One motor, CARRY-2, with that ground, slope, hop and bend, and two strafe settings: **N** (narrow) and **B** (matched broad). This is one constant pair, not a matrix. Compare R12 (archived control), N and B. Run FLOW with root's fixes on fixtures only; it enters slice builds only if it beats CARRY-2 on perturbed W tapes. Its intentional A/D semantics are then tested against B. The bend-off flag is diagnostic. Crouch-slide, walls and surf stay out.

## Route-authoring bias and criteria

Fix the bias in the open:

- Size every gap from the shared forward-key bend envelope, without strafing, which is identical in N and B.
- Set the shortcut threshold at basic arrival speed plus a declared 2.5 m/s margin (P).
- Freeze geometry before N or B runs on it, keep a held-out variant, and disclose that the slice disadvantages R12, which lacks the bend.

Report curves, not a score: basic completion on perturbed W tapes without strafing or restarts; each fork taken by some tapes with a route difference above perturbation noise; route time against input quality, perturbation scaled from 0 to 2× (flat means mastery is meaningless, a cliff punishes the basic line); physical recovery; and zero unexplained ledger gain. None measures fun. B will likely tighten landing spread, which may only flatten decisions.

## Backend versus ownership

**Retained probe [local]:** `checkpoints/spillway/r13/council/backend-probe/run.sh` creates four throwaway projects differing only in `physics/3d/physics_engine`, hashing the project file and binary. A trimesh ray returns face index 1 when unset or with Godot Physics. It returns -1 with Jolt and 1 after enabling Jolt's face-index setting. Godot's Jolt page documents that signature and says Jolt is the default for *new* projects **[src]**. The unset value is Godot Physics.

**New fact against my R1 plan:** the same page says Jolt's active-edge and enhanced-internal-edge mitigations do not apply to ghost collisions between two different bodies **[src]**. The course makes each deck its own `StaticBody3D` via `_solid` and `_ramp` **[local read]**, so Jolt alone may not affect seams between decks.

**E2 order**, with motor math fixed, stopping at the first cell that clears the e4 front-edge catch without new oracle failures:

1. Switch to Jolt.
2. Merge abutting decks into one body on Jolt.
3. Own the sweep on Godot Physics.

The first evidence for ownership is a catch that survives cells 1 and 2 in a minimal two-slab fixture.

**Runtime interface:** first, the motor publishes `MotionState`: grounded, support normal, contacts, displacement velocity and ledger. Camera, HUD, audio, tests and tape recorder read only that. Fill it from R12's `move_and_slide` getters, migrate the roughly 19 consuming files and require byte-identical traces. Only then iterate `move_and_collide(test_only…, max_collisions)` **[src]** with motor-owned clipping, after which `is_on_floor()` and `get_real_velocity()` become unreliable for that motor. Sol's raylib-plus-Jolt is the better-defined collision challenger, but earns a spike only if a catch survives all three cells.

## Unmeasured

Real-GPU frame pacing, Hyprland compositor cadence, input accumulation on real hardware, Forward+ cost with adopted assets and native Windows play remain unmeasured. None is inferred from llvmpipe, and I did not operate Mike's desktop.

## Standing disagreements and settling results

| Disagreement | Settled by |
|---|---|
| N versus B: mastery forgiveness | Skill-gradient curves on frozen geometry, then Mike's blind A/B. B loses if its curve is flat or a W-only wiggle clears the shortcut. |
| Ground grip, free or bounded | A ground-only pier-bend line matching the strafe line's time means grip is too free. |
| B's side correction versus FLOW's view-led A/D | Glance and fixed-view correction tapes, then the slice. |
| Contact fault cause: backend, geometry or ownership | The first E2 cell that clears it. |
| Godot for the final product | D1–D4 on real hardware, still unmeasured. |

**Next playable artifact:** Overflow graybox with frozen geometry, delivered as three blind builds (R12, CARRY-2 N, CARRY-2 B). They share presentation and labels, run on root's tape executor and show their ledgers. Mike's satisfaction remains unverified.
