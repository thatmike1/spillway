# FLOW controller review at aba901ab

7 November 2026. FLOW remains an experiment. R12 is preserved. This review does not select a motor or judge fun.

**Fix event-cadence-dependent carve and collision-infeasible landing restoration before choosing FLOW. Also fix or remove the advertised continuous-crest launch rule: its comparison does not retain the previous support's climb rate.** The existing 38 passing checks establish their selected episodes and targets, not these properties. Root reports rerunning those checks; I did not rerun that suite.

## Evidence and limits

Reviewed `scripts/momentum_flow_player.gd`, `scripts/spillway_player.gd`, `tests/momentum_flow_probe.gd`, the local brief and `docs/momentum/research/controller-lab.md`. Added only `tests/momentum_review_probe.gd` and this report. No controller, launcher, existing probe or course edits.

Evidence root, outside Git:

`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-review-sol/`

Use `final/` for the complete traces and `final.log` for the run. Each JSONL row records commands, mouse radians, pre-step state, post-step position/velocity, independently differenced displacement, engine real velocity, contact normals and velocity into each contact. Samples follow physics, with exactly one physics frame between consecutive rows. Measured displacement and `get_real_velocity()` agreed exactly in this run. A second run in `repeat/` produced byte-identical JSONL traces; `repeat-verification.txt` records the comparison. Both runs finished without engine/script errors, and source hashes stayed unchanged.

Pinned runtime from `tools/check-spillway.sh`: Godot **4.7.2-stable**, official `ed1daf0bf`, 120 Hz physics; headless rendering also fixed at 120 fps. `physics/3d/physics_engine` reports `DEFAULT`; this report does not substitute a named backend for that setting. Input accumulation reports enabled, but each injected event is explicitly flushed. This controls delivery cadence rather than measuring a particular operating system, mouse or rendering backend.

Every episode creates a fresh player and calls `reset_to` once before its first step. Cases named `earned` use keys and mouse only after that placement. Cases named `seed` explicitly set initial velocity once, before physics, for matched-state isolation. No pose, velocity, camera or progress writes occur mid-episode. Fixtures are adversarial geometry, not proof of the shipped course's reachability or coverage.

`final-source-manifest.json` records full source/runtime SHA-256 values and verifies that both motors, the original probe and project settings match `aba901ab`. Shared-checkout HEAD had advanced to `a0e2b62e` for documentation while these motor hashes stayed unchanged:

| source | SHA-256 |
|---|---|
| FLOW | `3b954dc827c6919a3a44319ef78bd47b7bc327ce5b72f45b4d0a45027753c0a0` |
| R12 | `b1b119b2e178e5eea56dd1fffcf7b90abffb0e8839a633c24c642adec07c01e9` |
| review probe | `1ca315bf69824ef88c58b49f324b90835684858a4c94a662fa6ecaf911a89358` |

## 1. Confirmed defect: continuous carve depends on mouse delivery cadence

Location: FLOW lines 73–74 and 257–261.

Start on the flat at `(0, 0.02, 10)`, hold W for 96 ticks, hold W+space for six, then hold A while sweeping left at **1.8 rad/s for 60 ticks (0.5 s)**. Entry speed is input-earned **9.000 m/s** in every case. The entire sweep is airborne. All schedules deliver the same **0.9 rad / 51.566°**, using one mouse event every one, two or four physics ticks. Event magnitude increases with the interval. These are continuous sampled sweeps, not single flicks.

| mouse events/s; physics always 120 Hz | earned carve, m/s | final speed, m/s | final actual travel heading | displacement during sweep, x / z metres |
|---|---:|---:|---:|---:|
| 120 | 0.899999 | 9.9000 | 51.566° left | -2.0486 / -4.0861 |
| 60 | 0.487250 | 9.4872 | 51.566° left | -1.9941 / -4.0035 |
| 30 | 0.246841 | 9.2468 | 51.566° left | -1.9663 / -3.9517 |

Actual heading uses the final displacement vector; authoritative velocity agrees. Traces: `final/earned_cadence_{120,60,30}.jsonl`, sweep rows 102–161 inclusive, baseline row 101.

**Cause:** on ticks between events `view_turn` is zero. Heading keeps catching up to the view, but those turns earn nothing. On an event tick, gain is limited to that tick's grip-limited heading turn, discarding most of a multi-tick view update. The complete gesture therefore earns about 73% less at 30 events/s.

A good steering result does **not** require per-physics-tick mouse: all schedules reach the same heading here. The full intended carve reward **does** depend on that delivery. The existing probe sends mouse each physics tick, so it does not test this invariance. The visual helper already distributes its sweep over active 30 fps frames; calling it a single-flick helper would be wrong.

Godot's [Input documentation](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-property-use-accumulated-input) describes default event accumulation and its relationship to rendering FPS. That makes cadence relevant to deployment, but native FPS-dependent severity remains an inference until measured with that pipeline. The controlled event-cadence defect above is reproduced independently of changing physics rate.

Before choosing FLOW, preserve a time-consistent turn gesture across deliveries, rather than paying only on event-bearing ticks. Verify comparable gain and actual paths for these schedules and different event phases. Disabling accumulation alone does not establish that fix.

## 2. Confirmed defect: landing restores motion into a blocked face

Location: FLOW `_catch_landing`, lines 264–271, after collision at lines 158–167.

**Matched fixture isolation:** an ordinary walkable downslope goes from `(0,0,0)` to `(0,-6,-20)` and ends against a vertical wall whose front is `z=-10`. Initial placement `(0,-2.5,-9.1)`, explicit seed `(0,-6,-12) m/s`, then no keys. The wall stops horizontal motion before the floor arrives.

| landing tick 7 | R12 | FLOW |
|---|---:|---:|
| horizontal speed before step | 0 | 0 |
| horizontal speed after step | 0 | 2.018348 m/s |
| actual horizontal displacement speed | 0 | 0 |
| post-step velocity dot wall normal | 0 | -2.018348 m/s |

Both players have identical input, geometry, placement and initial velocity. Traces: `final/{flow,r12}_slope_wall_seed_0.1.jsonl`, rows 6–8. Offsets `0.2` and `0.3` reproduce the same restoration. The `0.0` offset has a simultaneous-contact mismatch in R12 as well; it does not isolate a FLOW regression.

**Input-earned reproduction:** `final/flow_slope_wall_earned_-3.30.jsonl`. Start `(0,0.02,10)`, W for 96 ticks, W+space for six, then W. The approach deck leads onto the same downslope, with wall front `z=-3.3`. No velocity seed. At tick 195 the wall has already stopped horizontal velocity. At tick **196** the floor arrives:

- pre-step velocity `(0,-9.299997,0)`;
- post-step velocity `(0,0,-2.651376)` into the wall;
- actual horizontal displacement speed **0.008097 m/s**, about **0.067 mm** that tick;
- wall normal `(0,0,1)` and post-step dot product **-2.651376 m/s**;
- tick 197 collision returns horizontal velocity to zero.

**Cause:** projecting a fall onto the floor alone creates a horizontal downslope component. A stopped current vector satisfies `caught_h.dot(current) >= 0`, so `_catch_landing` restores that component without checking the wall. The inherited `_clip_air_contacts` returns early on walkable ground; the later hard speed cap does not make the direction feasible.

This is a confirmed one-tick false-speed/stall state, including a reachable input-only fixture. It is **not** evidence of persistent wall penetration, sustained speed farming or a repeatable route exploit. Those remain untested. The seeded R12 comparison isolates the new restoration; the ordinary R12 approach reaches the slope differently and is only a whole-policy comparison.

Before choosing FLOW, constrain any landing restoration against all active blocking planes, including floor and walls. Assert feasible post-contact velocity as well as actual displacement. Keep the seeded isolation and input-earned reproduction. Account separately for inherited floor/wall contact anomalies, rather than attributing every mismatch to FLOW.

Godot documents [`velocity` versus actual movement](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html#class-characterbody3d-method-get-real-velocity). The pinned [CharacterBody3D source](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/character_body_3d.cpp) computes real velocity from position change and clears the vertical component on a grounded arrival. Neither operation validates a script's subsequent horizontal restoration.

## 3. Confirmed comparison error: the continuous-crest launch lacks history

Location: FLOW lines 112–114 and 168.

At the end of a supported tick, `_flow_last_vs` stores `_surface_climb` using the **new** support normal and current horizontal velocity. On the next ordinary uncapped tick, `surface_vy` uses those same values. Their difference is zero, so the required drop of 1.5 m/s cannot be observed. This is a temporal-state error, not a tuning threshold that these fixtures failed to reach.

The probe records both operands before input. Across every supported FLOW sample their maximum difference was **exactly zero**, although computed climb reached **8.807713 m/s**. None of these continuous contacts produced a counted launch or an additional airborne tick after initial settling:

- an 8 m climb gaining 3 m, directly joined to a flat deck;
- the same climb joined to a gentler 0.1-gradient ascent;
- eight exactly joined 2 m ramp segments, each rising 0.5 m;
- twenty steps with 5 cm rise and 30 cm tread.

Each had matched initial velocity fixtures at 16 and 24 m/s for both motors. These seeds are not input-earned speed. A separate W/crouch episode earns speed descending 12 m over 40 m before the 3 m climb. It reaches the continuous crest at roughly **17.3 m/s**, stays grounded and records zero launches. Trace: `final/flow_crest_earned.jsonl`, rows 478–481.

**Unwanted crest pops were not reproduced.** That negative result is not proof of a robust crest policy because the intended comparison is inactive on the ordinary path. Actual ramp-edge carry and jump slope bonuses are separate branches and remain possible. A later cap or an external state writer could break the equal-operands invariant; this review makes no claim about such an altered path.

Fix the temporal comparison or remove this advertised behavior. If enabled, rerun these continuous fixtures before judging false pops: preserving previous support history may expose the exact staircase/seam risks that the present implementation cannot exercise. Large stairs, imperfect seams, oblique contacts and the real course's complete contact sequence remain untested.

## 4. Design tradeoffs: lateral correction and the mastery channel

These use the same input-earned 9 m/s jump and 0.5 s window as the cadence reproduction. At 120 mouse events/s:

| gesture | carve gain | measured result |
|---|---:|---|
| A + continuous left sweep | 0.900 m/s | follows the view 51.566° left |
| W+A + same sweep | 0.900 m/s | same travel as A |
| W + same sweep | 0 | follows the view 51.566° left |
| wrong-side D + same sweep | 0 | same travel as W |
| A/D alternating every 15 ticks during the sweep | 0.450 m/s | follows the view; half the correct-key reward |
| A alone, fixed view | 0 | zero lateral correction; travels 4.5 m straight |
| D alone, fixed view | 0 | same straight line |
| no input, fixed view | 0 | same straight line |
| A + one initial 0.9 rad flick | 0.016667 m/s | heading catches up; almost no carve |

Traces are `final/earned_air_*.jsonl` plus `earned_cadence_120.jsonl`. The flick is an explicit negative control, not a description of the visual helper.

Above 4 m/s, A/D are steering enables and gain gates, not lateral movement commands. Wrong-side D still follows a left-looking view exactly like W. This is **purposeful in the code comments**, so I classify absent lateral correction as a design risk, not an accidental bug. It prevents strafe swaps from reversing the flight but removes ordinary fixed-view side correction. Below 4 m/s a separate branch honors the key wish; that boundary was not exercised here.

The mastery channel distinguishes correct from wrong-side input in **speed**, not in trajectory direction. It rewards overlap between turn direction and the inside key, with no demonstrated need for hop timing or a precise A/D rhythm. Offbeat input earns half credit here. Worse, correct input at 30 events/s earns less than the alternating wrong-side gesture at 120 events/s. Fix cadence before using this channel to argue for a skill ceiling.

A playable comparison should test fixed-view side corrections, camera-led W steering, outside-key turns, recovery after a poor approach, and whether speed gain communicates the intended gesture. The source guard that ignores view changes beyond about 120° is another design question, not tested by these 51.6° sweeps. These measurements cannot establish enjoyment or the right amount of air assistance.

## Rerun, negative trials and remaining work

From `/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner`:

```sh
/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --fixed-fps 120 --path . \
  --script res://tests/momentum_review_probe.gd -- \
  --out=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-review-sol/rerun \
  > /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-review-sol/rerun.log 2>&1
python3 /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-review-sol/analyze.py \
  /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/controller-review-sol/rerun
```

The probe is a characterization recorder: **exit 0 means episodes completed, not that the controller passed these findings**. `summary.json` lists every initial placement/seed; JSONL contains every command. `analysis-final.txt` reports negative trials as well as failures.

Retained unsuccessful or limiting trials:

- `run1.log`: initial harness parse error from a nonexistent timing getter, corrected before any runtime result.
- `run1/`, `run2.log`: initial executed probe. Flat wall seeds at `z=-9.30/-9.45` and the corner cleared normally; the `-9.15` simultaneous arrival left an infeasible velocity in both motors for one tick. No continuous-contact launches.
- `run2/`, `run3.log`, `probe-run2.gd`: added downslope isolation and faster contacts. One-decimal wall filenames collided for `-2.50/-2.45`; the earlier trace survives in `run1/`, both episode summaries/logs survive, and the final probe uses unique two-decimal names. Do not use the overwritten intermediate trace to identify the first wall placement.
- `run3/`, `run4.log`, `probe-run3.gd`: added input-earned downslope/wall arrival; negative wall positions land before the wall and do not reproduce restoration into it.
- `final/`, `final.log`: adds pre-step operands/state, keeps all earlier positive and negative cases, and records the evidence cited above. No script/runtime errors in this run. Earlier snapshots and the final source manifest preserve provenance.

The existing turn, brake and overspeed-hop tables start at different ramp-earned speeds. Their results describe the **whole motor policy**, not equal-speed steering/brake superiority. This review's equal-speed evidence is the cadence experiment and explicit contact seeds; it does not replace an equal-speed ground comparison.

Selection should wait for cadence-independent carve, feasible multi-contact landings, and an explicit decision about continuous crests. Then compare playable input on the same meaningful route. Front-edge slab catches, post-fix seam behavior, native frame/input cadence, full-course recovery, and an exploitable repeated landing loop remain open questions. No engine-selection claim follows from this review.
