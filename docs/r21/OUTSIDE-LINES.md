# The outside line is a landing that prepares the next jump

Mike's Breakwater line is real and already earns generic gap points. R21 leaves Breakwater and the scoring rules unchanged, and applies the same physical pattern to Saltglass.

## The moment in the recordings

The clearest example is `breakwater_server128_20261111-103932_453_d8f49e3b.r16run`, around the **second crane-line stack**, after the container-roof hops and first bend. It is not a bypass of the early roof-row containers. Travelling west, the player's right side is south, over open harbour.

The preceding flight lands at tick 1622 on `s2_quay_b`, physical feet `(-42.289, 0.001, -95.305)`, about 718 u/s. The next jump begins at 1623. At tick 1670 the feet are `(-47.279, 1.648, -99.175)`, beside the stack, below its roof. At 1721 the player lands west of it at `(-54.447, 0.023, -97.365)`, about 733 u/s, and jumps again at 1722. Air time is 0.765625 s. The exact physical Y matters because airborne crouch changes reference feet by 0.2286 m.

Those are real solids from `r15_breakwater_level.gd::_crane_line/_container/_solid`. The four prisms `s2_chicane_2_1_1`, `s2_chicane_2_1_2`, `s2_chicane_2_2_1` and `s2_chicane_2_2_2` occupy x=-50.876..-46, z=-97.432..-88.383, y=0..5.182. The south pair ends at z=-97.432, also the quay edge. The hull spans the stack's X range on ticks 1659–1698 and clears the south side, rather than jumping over the roof. Its closest sampled horizontal clearance is 0.4121 m, with 0.4425 m minimum south-face clearance while spanning X. These are nominal hull/AABB measurements, not recorded engine contacts.

A second clear example is `104452_450_01990cad`, takeoff-ground tick 1648 to landing 1748, with 1.5698 m closest sampled horizontal clearance. The full filenames, positions, input/view windows, actual versus reference feet, solids and measurement limits are in outer `playtest-r20/r21-analysis.json`; the readable interpretation is `ANALYSIS.md` beside it. The source-derived partial stack manifest does not claim to recompute Breakwater's whole geometry identity.

## Does it give style points?

Yes. The first outside flight receives **gap +2328** at tick 1721 and speed +181 at 1676. Its approach landing also receives sync +178 from the preceding flight. The second example receives **gap +2695** at 1748. The same takeoff/landing quay is allowed: the generic gap detector measures actual unsupported flight, not a hand-authored pair of map names.

Neither outside flight receives near-miss points. The existing detector requires at least 380 u/s, clearance at most 8 u (0.2032 m), no scrape, a short passage and open entry/exit, with geometry novelty. The first recorded line stays over twice that clearance away; the second is wider still. A later crouch-save event in the second recording belongs to its next flight and is not a container bonus.

The R21 decision is to **keep generic gap scoring and all existing scorer rules**. No wider detector, new award, route name, checkpoint gate or location trigger was added. These two recordings do not establish that a proposed wider reward could not be farmed.

## A portable geometry pattern

The useful unit is the approach landing, the next takeoff and the receiving landing together:

1. A real tall solid occupies the direct line and reaches the edge of usable ground. Its roof is too high for the intended jump.
2. An inland line provides a readable, more forgiving route around it.
3. An outside line crosses genuine unsupported space. A specific approach landing leaves enough room and heading for the next takeoff and air curve.
4. The receiving patch is small enough that the curve has a consequence, and is placed so the next hop can continue. Missing it falls or costs motion through ordinary collision.
5. Time and retained speed come from distance, landing position and physics. Existing generic style probes may recognize the passage; the map does not know that a secret line was used.

This transfers the reason the moment is exciting, not Breakwater's whole stack or layout. The surface names and coordinates below are evidence for tests, not runtime route logic.

## Saltglass applies it to the salt store

The store is a real convex solid at x=215..220, z=40..54, y=5.3..11.3. The safe quay and its inland necks pass north of it. The outer line passes south of z=54 over water and returns onto `outside_lip_0_0`, x=220..223, z=49..54, y=5, before hopping onto the next pan. There is no walkable support under that outside arc. The small lip was sized against the measured flight and return, not a velocity boost.

The local source fixture starts at rest on the real preceding pan. Both policies earn the same approach through key/mouse input. In the accepted outside proof, first receiving landing is driver tick 587 at `(221.372, 5.031, 53.619)`, about 436 u/s. It takes off again and lands on the next pan. The outside curve clears the store with no store contact and remains below its roof; a straight inside control hits its front face.

From the common fork, outside versus inland takes 1.5234375 versus 3.765625 s to their first receiving landings. At the same downstream x=225 plane it is 1.9921875 versus 3.1875 s. This proves one faster physical outside line against one safe line; it does not prove a fastest route or general human difficulty.

The unchanged recorder logs an additional generic **gap +1007** at recording tick 620 for 7.401 m of clearance (6.5882 m unsupported), and **near-miss +180** at tick 608 for approximately 3.531 u clearance. Recording ticks include the declared 33-step warmup; tick 620 is driver landing tick 587. This Saltglass fixture passes closer than Mike's recorded Breakwater examples, so its near-miss award does not imply his wider line should have earned one. The rules identity is identical on safe and outside trials. No score hook was added.

The full normal-spawn Saltglass proof takes the inland line and finishes in 64.4765625 s. The separate local outside fixture proves the optional move and its continuation, not a completed outside-route course or player enjoyment. Parent owns the native view check and Mike decides whether this particular obstacle, receiving lip and risk feel rewarding.
