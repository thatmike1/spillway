# Spillway r12: bhop and surf

Mike played Spillway r11. His verdict: plain running is boring. Sliding is fun. The best part was **bunny hopping**, which already half-works by accident because landings keep speed. He loved bhop and surf maps in Counter-Strike and wants the game to lean into that. Where it breaks today: you cannot turn while hopping without bleeding speed, so the first stage was a bhop until the first corner and then nothing. The left-hand stair route ends in a long walk with no movement to do.

So this round changes the movement model from "run and parkour" to **Source-style air strafing**: bhop, surf ramps and slides, with the dam as the playground. The setting, art direction and three-stage structure from `wt/projects/foldrunner/docs/reboot/BRIEF.md` stay. Its movement rules that forbid air speed gain ("without unlimited air pumping", the `_air_budget` ceiling) are superseded by this brief. Mike's screenshots from the playtest are in `playtest-r11/` beside this file.

## Movement

The current motor is `scripts/spillway_player.gd`. The air code clamps speed to `_air_budget` and pushes velocity toward the wish direction, which is why a turn costs speed. Replace it with the classic Quake/Source air-acceleration model, reimplemented from its well-known description (do not paste GPL engine code into the repo):

- **Air strafing.** In the air, acceleration only adds speed along the wish direction up to a small per-axis wish cap (Source uses about 30 units/s, roughly 0.75 m/s), measured as the current velocity's projection on the wish direction. Holding a strafe key while turning the mouse the same way curves the path and gains speed. Holding W alone does not gain speed. Mouse look with no keys held does not change velocity.
- **Bhop.** A jump on the landing tick (buffered or held) skips ground friction for that tick, so a well-timed hop keeps all its speed. Holding jump rehops on landing (autohop, on by default, a setting to turn it off). Ground friction applies normally after you stay on the ground. A generous top speed (P, around 30 m/s) keeps it sane.
- **Surf.** Slopes between roughly 45° and 75° are not floor: the player slides on them, gravity pulls along the slope, and air strafing into the ramp holds the line and trades height for speed. Leaving the bottom of a ramp carries the speed into the next jump or hop.
- **Slides stay.** Crouch at speed still slides, downhill still adds speed, and a jump out of a slide keeps its speed. A slide through shallow water must not stall: the water drag that stops walking should barely touch a slide or a hop.
- **Ground running** can stay as it is, but nothing in the course should require a long stretch of plain running.

Every value is P, a tuning choice. Record what you chose and why in the decisions file.

## The course

Re-author the course for this movement, keeping the dam, the pump tower and the three stages:

- **The spillway faces become surf ramps.** A dam has angled concrete chute faces; use them. At least one full surf section per stage, with real curves that need strafing to hold.
- **The flats become bhop lines with turns.** Corners, a switchback and a gap or two that a good bhop clears and a plain run doesn't. No stretch of more than about 4 seconds where the only thing to do is hold W, including the safe route down the stairs.
- **Routes reward skill.** A beginner can finish by running, sliding and simple hops. A skilled player chains surf, bhop and slides into a much faster time. Shortcuts should come out of the movement (a hop that clears a gap because you carried enough speed), not hidden doors. A huge skip like a 5-second finish is fine if it falls out of the physics; do not add authored secret paths.
- Keep R restart, F segment practice, splits and bests.

## Bugs from the playtest

1. **Stuck in the horizontal valve wheels.** The player snags between the wheel's spoke and rim colliders and needs force to get out. Give wheels simple convex collision (or a flat disc on top) so you either stand on them or slide off.
2. **The half-open gate.** Its top beam has no collision but the round supports do, so he jumped onto it from the wheel and fell through. Make collision match what looks solid: if it looks walkable, it is.
3. **Water stalls the slide** down the spillway chute (see Movement).
4. **A floating railing** on the left of the gantry walkway, hanging in the air with nothing under it (`playtest-r11/` fifth image).
5. **The reservoir is a flat sheet** ending in mid air above the crest (sixth image). Give it banks or a dam face so it reads as held water.

Sweep the rest of the course for the same classes: collision that doesn't match what you see, things floating, water edges with no banks.

## Done means

Work autonomously until at least **18:00 Europe/Prague today, 6 Nov 2026**, and do not stop at a plan or a test count. Make every decision yourself and label it.

- Scripted input traces (keys plus mouse yaw, not teleports) show: synced strafe and turn gains speed over 5 hops; a 90° turn while bhopping keeps at least 90% of speed; W alone in the air gains nothing; a surf ramp held with strafe keeps the player on it and ends faster than it started; a slide through the shallow chute water keeps at least 80% of the speed it would have dry.
- A bot or recorded input run completes each stage on a fast line using surf and bhop, and a rendered video or frame strip of it exists, so a reader can see the movement working.
- Every bug above is fixed with a before and after frame.
- The no-walk rule is checked by tracing the safe route and reporting the longest plain-running stretch.
- A new delivery `delivery/spillway-r12/` with the Linux and Windows ZIPs, checksums and a pause menu that says r12. REPORT.md is updated with what changed, how to play and what's still weak. Coherent commits pushed to `feat/foldrunner-me-build`, subjects ending with `(ccChat-general-rowb)`.

Do not claim it is fun. Mike decides that when he plays it.
