# Fall Line

Keep moving across descending decks that give you two visible seconds after support contact, with a wider lower line when a jump goes wrong.

## Access and controls

Parent integration adds `fall-line` to Esc > Experiments. The entry is `r19_fall_line_level.gd.MAP_ENTRY`, kind `experiment`, `experimental=true`, trusted runner `res://scripts/r15_source_player.gd`. Original Movement Lab stays separate. Ordinary F2 controls apply: W/A/S/D, mouse, Space and crouch. R restarts and restores every falling deck; F starts practice at the latest solid checkpoint and restores every deck. Esc pauses the countdown as well as movement and the course clock. L compares the inherited Look C presentation.

The component host subclasses actual `r19_main.gd`, adds only this entry to the inherited base catalog before normal startup, selects it, uses the frozen Source runner, applies the experiment restrictions and hides unrelated Lab loadout toggles. It attaches one practice-palette R17Look only when the production host has not attached one. Production registry, menu, experimental title/HUD, preset restriction and final native/release acceptance remain the parent's work. No custom player is needed.

## World law

`fall-line-1`, level version 1. Ten descending 10 m landings have widths 6, 8 and 10 m, lateral offsets, 3 m gaps and 0.35 m height changes. Seven decks collapse. The other three are solid rests. Two intermediate checkpoint poses are on solid rests. A physical 28 m wide lower court catches misses; its six-metre ramps return to the start or climb to the finish. Both bridge crossings begin beyond the ramps' high ends. Lower-court support advances the same real course sections, so that longer route can finish cleanly without invented checkpoint awards.

An unarmed deck starts its warning only when the runner is grounded and a test-only sweep of its actual hull identifies that body as upward support. The sweep repeats the frozen motor's own ground-probe distance and safe margin, requires normal Y >= 0.7, and never moves the runner. The frozen motor's ordinary ground probes do not appear in its diagnostic contact list, so that list alone cannot drive collapse. There are no proximity areas, invisible route corridors, timed route awards, randomness or wall-clock timers.

The grounded support tick arms a deadline `ceil(2.0 * physics_hz)` steps later. At F2's 128 Hz this is exactly 256 steps. A pre-motor callback after host bookkeeping removes collision layer 1 on that deadline, including when the player waits on the deck. An orange on-deck countdown replaces the resting 2.0 text. Cream tops, dark sides, structural ink and orange edge strips remain on the actual deck; the deck's visual falls eight metres over half a second after collision disappears, then hides. Shared static contours omit these moving deck outlines, so there is no floating ink where a deck vanished. This visual motion exerts no force.

Leaving support never cancels a countdown. A dropped deck stays absent until reset. The inherited R/F hooks call `reset_state()`. A normal fall/respawn count change also resets all platforms before the next motor step. Reset restores collision, visual position/visibility, countdown text and unarmed state. Explicit pausable callbacks freeze the platform clock under Esc even though the host itself processes while paused.

Geometry identity includes full-precision collision vertices, roles/stages/kinds, spawn, checkpoints, finish and kill bounds, progress roles, mechanics label and the complete versioned `LAW` dictionary describing contact, update order, deadline, collision, pause and reset rules. R19 motion identity includes that geometry identity and the actual Source motor/preset/rate. Changes to those rules require a new law/level version. Runtime countdown values stay out of the geometry hash.

## Verification

Run from `projects/foldrunner`:

```sh
python3 -I tests/r19_fall_line_verify.py --out /tmp/r19-fall-line/recheck
```

Use a fresh output directory. The verifier uses the installed pinned Godot 4.7.2, awaits real normal Quit exits, runs headlessly and writes only under `/tmp/r19-fall-line`. It checks /home free space remains at least 15,000,000,000 bytes and total component scratch stays below 250 MiB while each engine runs. Engine import RAM is separate from that scratch count.

The earned upper line measured **23.5625 s**. The wider recovery line measured **28.046875 s**, also clean. These are state-aware input controller routes from the actual host's normal authored spawn, without body, velocity, camera, progress or score writes. The saved upper-line tape replays open loop with identical per-tick body state, platform state, platform clock, support/drop transitions and course observations. Original Godot and Python readers accept the clean recordings; positions, velocities, elapsed clock and checkpoint columns align exactly at a 33-tick settling offset. The source runner, its base, Source motion and presets are byte-identical to delivered R18.

The lifecycle driver deliberately waits on the first deck until collision disappears and lands on the real lower court. It checks pause/resume invariance, F and R restoring all collision/visual state, an earned nonzero checkpoint practice reset, an input-earned walk up the return ramp to the start followed by R, and switching to Breakwater with ordinary pure F2 movement. Collision/manifest checks inspect every prism, require each axis <= 32 m and reject Area triggers. Physical space queries confirm deck collision presence against its advertised state on every retained upper-route sample. No authored scoring is present; inherited gap events fire naturally.

Canonical evidence: `/tmp/r19-fall-line/accepted-v2/AUDIT.json`, with commands, source hashes, original recording paths, budget measurements and per-check results. Its sibling run directories contain tapes, compressed traces, actual recordings, geometry audits and lifecycle observations. Earlier scratch directories contain rejected development runs and are not acceptance evidence.

## Expectation and limits

Model expectation: short, readable time pressure may make ordinary landings more consequential, while solid rests and the lower line allow recovery. The two-second warning is generous for a run-speed crossing; faster bhop players may find the upper line easy. These are design expectations, not a human enjoyment verdict.

Acceptance here is headless component evidence on this Godot/Linux environment. It does not prove native countdown legibility, camera composition, frame rate, Windows execution or cross-platform deterministic replay. Parent native inspection and packaged release gates remain necessary. Mike's eventual taste call is whether this pressure is worth keeping and whether the warning should be tighter.

## Production integration refresh

The R19 production catalog now includes Fall Line under Experiments. The component test host has been reduced to selecting the real registered map; production supplies its trusted pure R15 runner and one Look C layer. The complete verifier was rerun against that host and all35 checks pass, including both earned lines, exact replay, collapse timing, pause, R/F/checkpoint/return and original-map isolation. Native visual and final packed-release acceptance remain separate gates. Proof: /tmp/r19-fall-line/production-integration/AUDIT.json.
