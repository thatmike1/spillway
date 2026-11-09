# Line Drive

Carry a clean line into three grounded launches, then carve onto the next deck before the launch house.

This is an explicitly experimental map, `line-drive`, with its own runner and records. Reach it through Esc → Experiments → Line Drive after parent integration. Use the ordinary F2/F5 bhop controls: W to run, A/D plus matching mouse motion to steer in the air, Space to hop, Ctrl/C to crouch, R for a fresh circuit, F for checkpoint practice, Esc to pause. Launches are automatic rewards for speed and alignment. They need no extra button. Each pad fires once until a reset.

## Experimental law

`r19_line_drive_player.gd` extends the unchanged `r15_source_player.gd`. Law `r19-line-launch-2` checks eligibility immediately before the inherited input/motor step. Feet must be within the pad bounds, the runner must already be grounded, and a test-only downward sweep of its actual hull must find that pad's walkable supporting collision body. The sweep uses the inherited 2 u ground probe, about 5.08 cm. Merely passing over the bounds in the air does not count.

Horizontal speed must be at least 300 u/s and horizontal travel alignment must be at least 0.94 against the authored pad direction, about 20 degrees either side. A qualifying unused pad adds 160 u/s in that direction and raises upward velocity to at least 480 u/s. The boost's horizontal ceiling is the greater of 900 u/s and entry speed. An entrant already faster than 900 keeps that speed instead of being slowed. Ordinary subsequent air strafing can exceed the boost ceiling. No view correction, pose teleport, scripted route, special scoring call or hidden trigger supplies the transfer.

The runner seeds the inherited flight-accounting fields on an earned launch, clears launch usage/events on `reset_to`, and exposes launch/support evidence through `get_motion_state().line_drive`. `experiment_status()` supplies a concise experimental status string. Original maps keep the original R15 body; exiting this map must replace the body, not leave a disabled launch runner behind.

## Circuit and motion windows

The course retains the prototype's full three-corner route. Its original narrow four-metre pads could lie entirely between bhop landings. At the measured second approach, support contacts were about twelve metres apart. The west pad spans twelve metres; east and home span sixteen. Run-in decks end exactly where pads begin, so support identifies the real pad rather than an overlapping floor.

| Launch | Pad extent and height, metres | Direction | Departure edge → next landing |
| --- | --- | --- | --- |
| West | x −6…6, z −44…−32, y 6 | −z | z −44 → west landing z −48, y 7 |
| East | x 40…56, z −66…−54, y 7 | +x | x 56 → east landing x 66, y 8 |
| Home | x 72…86, z −24…−8, y 8 | +z | z −8 → finish deck z 2, y 9 |

Turn east after landing on the west deck, then toward +z after the east landing. The finish bounds are x 70…88, y 8.8…13.8, z 7…22. Faster cuts remain possible; checkpoints and finish use the inherited host's ordinary spatial progress. The lower court, y 0, covers x −14…100 and z −82…34. Its return ramp is x −6…6, z 18…30, rising from y 0 at z 30 to y 6 at z 18. Approach it from the far end of the court and walk back onto the start deck.

Map revision 2 hashes explicit numeric arrays for every collision vertex, pad bound/direction, checkpoint basis/origin/bounds, spawn, finish, kill bounds, progress segments, jump edges/landings and the full versioned launch law. It avoids Variant vector/transform strings. Original ghost loading must reject any geometry or motor identity mismatch.

## Headless component proof

The reproducible gate is:

```bash
python3 -I tests/r19_line_drive_audit.py --out /tmp/r19-line-drive/final-current
```

Use a fresh output directory. The helper uses the pinned Godot 4.7.2 runtime, an isolated data root, an explicit profile/recordings directory, a 250 MiB scratch ceiling and at least 15,000,000,000 bytes free on HOME. It runs the actual R19 host/session through the component adapter. It checks a clean input-earned route and fixed saved-input replay, both original recording readers, recorded/observed samples, physical support on all three launches, airborne/standing/walking/wrong-alignment negatives, spent-pad revisit, Esc/F/R/map-exit lifecycle, physical lower-court recovery, numeric identity mutations, incompatible ghost rejection and unchanged protected motor/preset bytes.

The standing/walking negatives use an explicitly labelled checkpoint-fixture start on the actual pad, at zero velocity. Wrong-way hops use ordinary checkpoint practice. Pure response checks supplement these real inputs and do not count as an earned course. The clean route driver and map perform no body, view, velocity or progress writes after the host's authored spawn. Its coordinate-aware input choices demonstrate one executable line, not discovery or imperfect play.

The measured route completes cleanly in 13.1171875 seconds with zero respawns. All 1,705 gameplay samples, including movement, strafe statistics, style and host flags, match saved-input replay exactly. The tape preserves within-tick mouse/key ordering as well as values. Both original Godot and Python readers match the observed body, view, clock and progress after 33 settling ticks. Its three supported launches are approximately 451.6→611.5, 639.6→799.5 and 823.3→900 u/s horizontally, all with 480 u/s initial upward velocity. The lower-court recovery walks back to the starting deck in 28.375 seconds without respawning. The final gate passes 36 aggregate checks and 96 collision/identity checks, with clean logs. The original Python reader also accepts all 15 sealed files from the final route, negatives, recovery and lifecycle probes. Minimum HOME free space was 16.255 GB; total owned scratch peaked below 24 MB. The canonical audit and source hashes are retained under `/tmp/r19-line-drive/final-current`; the parent owns copying final evidence into the round's retained delivery evidence.

## Parent integration and assets

Register `MAP_ENTRY` under the separate Experiments menu, trust only its authored `runner` path, retain the F2/F5 restriction, hide unrelated Movement Lab loadouts, show generic experimental instructions and attach exactly one existing `practice` Look C layer. The component host demonstrates those hooks; it delegates to production behavior when the parent already provides the look. Parent owns `r19_main`, HUD, catalog, final all-map parity, moving native views, final review and release packaging.

Course solids, signs and alignment rails are original procedural primitives. The unchanged `r19_course_geometry.gd` builds collision and meshes; existing `r17_look.gd`/`r17_contours.gd` provide cream tops, dark structures and small orange jump lips. The practice sky and painted wear are existing project assets. Their provenance is in `assets/look/PROVENANCE.md`, `assets/look/MANIFEST.json`, `assets/look/r17/PROVENANCE.md` and `assets/look/r17/MANIFEST.json`. No new external asset is introduced. R18 UI remains inherited.

My model read is that the rising speed and three landing turns give the boosts something to reward. The wide pads let the player arrive through bhop rhythm, rather than demand a single precisely timed landing. That is a design judgment, not evidence of human enjoyment. Native appearance, landing/sign readability, Windows execution and Mike's enjoyment remain untested in this component; parent handles native and release checks.

## Production integration refresh

The production catalog now registers Line Drive under Experiments. Its host adapter only selects the map. All36 component audit checks pass again through production registration, including all three earned launches, saved-input replay, real input negatives, reset/pause/checkpoint/map-exit and physical recovery. Both actual AMD/X11 old/new runs finish in13.1171875s and match all1705 telemetry samples exactly, also matching the headless open-loop replay. The earned controller node index differs from open-loop bookkeeping; the component audit explicitly separates that from gameplay. Six moving native frames per look are retained at1296x736; parent inspected the east-pad approach at637u/s. Source/native proof is outer look/evidence/r19-line-drive-integration/. Final packed-release, Windows and enjoyment remain separate.
