# Spillway R16: style, recorded runs and lab flow

Mike's 9 November feedback is positive: he played R15 Breakwater, Whiteout Relay, Sunken Court and Movement Lab, says it is fun and wants to keep playing. This is his reported verdict on those experiences, not a claim that a new build or every map is fun.

## Requested behavior

1. Add readable style scoring for course speed, close edge landings, large gaps, high-sync strafing with real gain, and fast near misses. A crouch that actually avoided a standing-hull collision gets a large reward. Derive evidence from real geometry/physics where possible. Design combos, brief callouts, running score and per-map style bests beside time bests. Add a few deliberate optional style opportunities without breaking current lines.
2. Record every played attempt compactly in user data: per-tick inputs, yaw/pitch, position, velocity, preset/map, checkpoints, falls/restarts, style events and outcome. Document the format, analyze a folder of copied desktop files, and show the best clean run as a nonphysical ghost. Test our own recordings now; future Mike recordings may guide later tuning but are not a prerequisite.
3. Make lab wall jumps limited and deliberate, working straight from an A/D strafing bhop. The former need to hold W is the concrete defect to reproduce and repair.
4. Make a bhop landing flow into a speed-preserving slide and back into a hop. Choose and explain a separate input from ordinary Ctrl/C crouch. Exercise the full earned-input chain.
5. Preserve grapple unchanged.

## Preservation and round identity

The approved R15 course runner, shared Source law, five course modules/art/assets and legacy maps remain immutable references. New code lives beside them. R16 records use `user://spillway_r16.cfg`; R15 delivery ZIPs and their source commit8a254d16 stay frozen. R16 may read prior look settings once, never overwrite old configs or import comparable records. New lab tuning and scoring rules enter their respective identities. No W/mouse steering assist or course movement retuning is authorized.

Optional style geometry belongs in a separate R16 overlay, with its own deterministic identity. Preserve the existing route surfaces and prove unchanged lines with the same inputs; added obstacles must be optional and off those lines. If preserving a line and placing an opportunity conflict, preserve the line and choose another placement. No unrecorded geometry change.

## Agent design choices to label

Start with one compact style/combo readout and one short callout, preserving the centre view and existing speed/strafe HUD. A style best requires a clean whole-map run and shares no identity with old style rules. Practice can show points but never saves a clean style best. Rewards need cooldown/feature/progress rules so waiting, oscillating at one edge or keeping a standing ghost inside a floor cannot farm points.

Ghost means the fastest clean completed run for the current map/preset/geometry/mechanics identity, independent of style best. It has no collision, cannot trigger progress and can be hidden. Recordings remain local and portable; no automatic upload. Failed/incomplete writes are explicitly labelled rather than silently upgraded into complete recordings.

Exact score weights, combo expiry, wall limits and slide buffering are experimental game choices to be implemented and challenged. Mike is at work; decide these rather than asking for tuning votes. No new time floor or deadline was given.

## Completion evidence

Prove the requested detections with actual collision fixtures and real key/mouse-driven runs, including negative crouch counterfactuals. Preserve approved no-crouch/crouch course traces. Show lifecycle-complete recordings, independent analysis of a folder, malformed/truncated-file handling and a real best ghost with identity separation. Reproduce A/D wall jumping and bhop-slide-hop through the actual R16 host. Compare unchanged grapple on fixed inputs.

Run independent challenges, inspect moving native player views and record what was only source/headless. Final Linux release checks run outside source with exact provenance and current helpers. Windows stays labelled static-only unless executed natively. ZIPs land in outer `delivery/spillway-r16/`; outer REPORT.md then explains style rules, recordings location, ghosts and lab controls. Keep the old R15 report until R16 promotion. Push scoped work on `feat/foldrunner-me-build` using round bead ccChat-general-41fq and its children.

HOME must have at least15GiB before large renders/exports. Reclaim bounded task scratch as we go; retain compact traces/MP4s/selected frames and the pinned Weston dependency at `r14/hardware-render/weston`. User feel is never inferred from a test count.
