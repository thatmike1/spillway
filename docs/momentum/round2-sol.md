# Round two: build assisted narrow gain first, challenge it with broad gain

Sol, 7 November 2026, against `021bbeea`. I read the full council and controller corrections, but no other round-two post. Recommendations below are P / game choices. This round adds code inspection and primary-document checks, not gameplay measurements.

## What Opus saw that I missed

Opus gave ground friction, landing carry and contact ownership a much more concrete treatment. My broad projection recommendation risked making steering and speed generation compensate for faults elsewhere. R12 already supplies narrow projection gain and held hopping; rejecting the whole game does not identify that gain law as the problem. Opus's explicit bend limit also makes a useful distinction: permission to correct a jump need not be permission to accelerate.

I retract broad gain as the default first implementation and drop my terrain-only third motor. Build the assisted narrow-gain motor first, then its broad-gain challenger. Exact side-only identity is useful experimental control, not recovered user preference. Under the inch convention, 30 inches is **0.762 m**; R12's **0.75 m/s** is an approximation, not exact Source equivalence. Neither conversion establishes VHOLUME's behavior.

## Two air variants, one shared landing and ground policy

Both variants use R12's body, gravity, jump impulse, camera and 120 Hz initially. Keep held rehop, buffer and coyote time. Remove mandatory surf, mantle and slide from this slice.

- **N, first playable:** projection allowance 0.75 m/s and coefficient 12, preserving R12's side-only air calculation as a control.
- **B, essential challenger:** allowance 8.5 m/s and coefficient 1.5/s, using the same normalized wish direction. This compares two complete gain laws, not the cap alone. Straight aligned W above run speed must not add speed.

Both receive the same forward steering assist, blended by forward input contribution, including W+A/D. Start with Opus's 14 m/s² lateral limit and 45–90 degree fade. Side-only input gets no assist; no keys means looking cannot alter travel. Apply projection first and a speed-neutral rotation second, logging both. Opposing input brakes before reversal.

I still disagree with Opus's automatic 4% speed charge per radian of assisted turning. Correction already costs turning radius and potentially route distance. Start without that extra tax; test whether this makes high-speed corrections erase the shortcut's approach decision. Add a turn charge only if that problem appears. Broad gain may tolerate W+A/D overlap better, but may also combine acceleration and assistance too generously. That is why B remains essential.

Use **one common ground policy**, initially Opus's speed-scaled friction 4/s, stop floor 3 m/s, projection acceleration toward 8.5 m/s at 10/s, and an explicit 24 m/s² opposing brake. Process successful jumps before friction; ramp friction over 80 ms of continuous support. Reset that grace on genuine support loss, never on a normal/classification flicker. Compare this against R12 ground only in matched-speed straight, 90-degree correction, release/brake and late-hop fixtures. Settle unintended skid or abrupt loss there before the two slice builds. No ground-policy product matrix.

The speed economy is explicit: ordinary thrust earns run speed; jumping adds vertical impulse; oblique airborne input earns level-terrain overspeed; downhill landing can redirect falling velocity; friction, braking, uphill redirection and blocked contacts spend it. Assisted rotation earns none. Retain Opus's landing-plane carry initially, without supported tangent gravity or hidden crest launches. This is a deliberately nonconservative game policy: walking downhill does not continuously convert height into speed. Log full 3D contact changes separately from horizontal gains, so redirection cannot masquerade as free energy. No unexplained post-contact restoration or silent clamp is acceptable.

## FLOW and evidence that cannot choose the game

Root reports cadence-independent reward for the tested sweep/phases, feasible multi-contact landing velocity, and removal of the continuous-crest trigger after stair pops. Those corrections supersede both R1 fault descriptions. I have not rerun their evidence. Mouse-angle reward remains a design choice; A/D's lack of fixed-view correction remains a tradeoff. FLOW stays an existing comparison, not a third implementation target or selected game.

The finite relative-input executor is supporting work in parallel. Do not wait for another harness proposal. Run matched ordinary/overspeed starts with W, W+A/D, side-only, release, brake, glances and imperfect hops. A gain-disabled or assist-disabled run diagnoses a mechanism; it does not require another shipped motor.

Withdraw Opus's rule that wider landing spread than FLOW refutes CARRY. Lower variance may mean steering erased an intended commitment. Likewise, perfect-bot completion establishes reachability only. Compare whether acceleration, braking and takeoff placement still create different useful lines; whether mistakes have understandable costs; and whether recovery reconnects physically. Fun remains unverified.

Avoid authoring the verdict. Freeze a neutral contact/turn block first. Bound basic gaps by the overlap of N/B ordinary jump envelopes, and provide room for both measured turn radii. Do not size the shortcut specifically between CARRY's W and strafe speeds. Retain a mirrored bend and unseen landing offset without retuning. If the slice favors one motor, report that geometry dependence before revising it.

## Backend first, ownership separately

I reject adopting owned sweeps **and** Jolt as one initial fix. First reproduce a slice-relevant seam/lip fault under the unchanged controller with explicitly selected Godot Physics and Jolt. Opus's unset-backend ray result remains an attributed local claim; I neither reproduced nor rely on it. If used later, retain its runnable probe, settings and logs outside Git under `checkpoints/spillway/r13/council/`.

Godot's [current Jolt documentation](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html) distinguishes motion-query edge removal from simulation settings, and says these techniques do not remove edges between separate bodies. Jolt therefore cannot be presumed to fix an authored slab's front face.

If policy ownership remains necessary, compare an owned sweep on the **same backend** next. The viable adapter is `step(state, input, dt, collision_query) -> motion_report`, using [body motion tests](https://docs.godotengine.org/en/stable/classes/class_physicsserver3d.html#class-physicsserver3d-method-body-test-motion). Report transform, requested/resolved velocity, whole-step displacement, recovery displacement, support identity/normal, contact points/normals and ledger. First prove wall-plus-floor, seam, crest and respawn outcomes. Preserve the complete contact cone.

This needs consumer changes: `spillway_main.gd::_stands_on_stage` reads slide collisions; `get_speed()` reads requested velocity. Godot documents [real velocity and floor queries](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) relative to `move_and_slide`. They cannot certify an independently owned loop. Progress, HUD, audio and evaluator must consume the new report; camera interpolation must use committed transforms. Do not add the 0.35 m lip step before showing the remaining fault requires it.

## Standing disagreements and the next artifact

- **Narrow versus broad gain:** N first, B essential. Adopt B only if it improves ordinary key-overlap correction across both layouts while preserving a useful reward for deliberate strafing and approach speed. Otherwise retain N provisionally. Fidelity and endpoint spread cannot decide this.
- **Assisted-turn tax:** none first. Add one only if neutral steering removes a meaningful approach/braking decision across both layouts.
- **Jolt/owned contacts:** separate changes. A retained contact reproduction establishes which layer helps; neither is presumed superior.

Deliver two distinctly identified Linux slice builds with shared presentation, a complete basic descent requiring no advanced strafing, optional earned diagonal and continuous catch walk, plus replay evidence. Keep Godot provisional; a reproduced backend, pacing or presentation blocker warrants a bounded challenger. Real GPU performance, display/input latency and native Windows execution remain unmeasured here. No engine installation or desktop operation was performed. Continue without live review; Mike's eventual satisfaction remains unverified.
