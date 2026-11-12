# Spillway R15: keep the bhop, build worlds around it

## Mike's feedback and request, 8 November 2026

Mike gave tentatively positive feedback after playing R14: both the CS:GO bhop-server preset and the fifth AA1000 mode were nice. He rejected the vanilla64 experience and does not want fidelity to bad tickrate or feel. This changes the goal from finding movement to making more game around the server movement he liked.

He asks for five more maps with checkpoints and different themes, substantial sourced assets, and the ability to crouch in the air and crouch hop. Sliding is a possible addition. He is open to a separate prototyping map with wall jumps, grappling and other movement types. Those experiments are permission to explore, not permission to silently replace the approved bhop model.

No new deadline, minimum run time or cost limit was specified. The earlier R14 time floor has elapsed and is not carried into this round.

## Settled foundation

- Preserve F2's AA100/128 Hz ground and air behavior when not crouching. Keep the AA1000 comparison. No W/mouse turn assist, surprise overspeed tax or new landing friction in the approved path.
- Remove vanilla64 from the main R15 player experience. Keep the delivered R14 build immutable for historical comparisons. No claim that 64 Hz alone caused his dislike.
- Implement actual crouched collision and eye height on the floor and in flight. The player must fit through crouch-only space, crouch jump, land crouched and safely defer standing beneath a ceiling. The policy for airborne hull anchoring is an explicit game decision backed by input trials, not an invisible teleport or jump impulse.
- Five new original themed maps sit beside Penstock Yard and Overflow. Each has multiple useful checkpoints, discoverable progress, repeatable starts and an actual route through its geometry. A reskin of the same layout does not count as a different map.
- Redistributable external meshes and textures, with retained provenance, must materially establish each setting. Scene readability at running speed matters more than asset counts.
- A sixth, clearly separate movement playground compares optional sliding, wall jumps and a bounded grapple. It does not count toward the five finished maps. Experiments remain labelled and get their own timing/records identity.

## First concrete direction (agent proposal)

1. **Breakwater:** container port at dusk. Broad deck-to-container hop lines, cranes and a lighthouse, a sheltered first checkpoint and forgiving catch routes.
2. **Whiteout Relay:** snowy radar station. Antennae and service buildings, an exposed ridge strafe and warm interiors; snow does not change traction by surprise.
3. **Sunken Court:** sunlit overgrown ruin. Arches, courtyards and aqueduct crossings, with alternating low crouch passages and broad air curves.
4. **Rainline:** rainy rooftop district. Vents, ducts, scaffolds and wet streets below; low clearances reward an intentional crouch hop.
5. **Night Shift:** neon transit works. Station architecture, trains and maintenance bays, a long speed line and two distinct corner rhythms.

These names, themes and layouts are proposals chosen by the agent. The first finished slice is Breakwater plus a crouch fixture. Mike can steer either without losing the frozen R14 movement reference. Do not start by building five grey corridors and decorating them after completion.

## Play and feedback decisions (agent choices)

Default to the approved server profile. Give AA1000 a plainly named comparison. Existing experimental families may remain in an advanced comparison area rather than dominating the main controls. Keep speed, per-hop gain/contact loss and directional sync honest.

Each new course targets about 45–120 seconds for its basic authored route, with at least 3 useful checkpoint sections and a speed-earned alternative. This is a design target, not a human completion promise. Basic stages must not demand the very edge of a 250 u/s jump; progressively teach speed before making speed mandatory. A failed hop should present a visible checkpoint retry or physical return rather than an unexplained wall.

Keep restart and checkpoint practice immediate. Clean whole-map records and checkpoint/practice attempts remain separate; exact integer ticks and complete split payloads survive process reload. R15 writes only its own profile. A changed hull/mechanic/map invalidates comparable records by identity.

## Done means

Five new maps and the movement playground are selectable in the real game. Approved server movement still has independent no-crouch regression evidence. Real midair crouch/crouch-hop proofs use only key and mouse input after a labelled setup. Each new map has a clean normal-spawn route on the standard bhop profile, an authored checkpoint recovery and inspected moving native views. The approved AA1000 comparison remains usable, and Penstock Yard/Overflow still run.

No test count establishes fun. Keep exact-state checks, imperfect input, screenshot discovery, actual OS input, private GPU evidence and Mike's reaction distinct. Challenge new contacts, unsafe stand-up, checkpoint purity, records and asset collisions independently. State unfinished or failed play honestly.

Portable Linux and Windows ZIPs land in outer `delivery/spillway-r15/`, with source/runtime/asset identities and licences. Final packed Linux checks run outside the source checkout and exercise new courses, checkpoint recovery, crouch, records and Quit. Label Windows static-only if native play is unavailable. Outer REPORT.md explains the new game and what remains experimental. Commit and push coherent work on `feat/foldrunner-me-build`.

HOME must have at least 15 GiB free before every large render/export. Keep full MP4s only for final representative runs, selected JPEG frames and compressed traces. Bound per-experiment evidence and remove scratch after verification. Final R12/R13/R14 downloads remain frozen; don't recreate historical game files or touch the desktop display/socket workaround.
