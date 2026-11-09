# F2 surf feasibility, before course authoring

The unchanged R15 source body, with R15 `server128` settings, starts at rest on a labelled six-metre-high run-up. Fixed input actions hold W from tick 8, then release W and hold D from tick 440. There are no body, velocity or progress writes after the single spawn setup.

The ramp is five adjoining 24 m convex prisms, slope 56.3099 degrees, normal.y 0.5547002 below the existing 0.7 walkable threshold. It is collision geometry only, with no surf helper, floor-normal override or trigger.

Observed positive: 1,293 ramp-contact ticks, 62.06 m along the ramp, actual speed 239.85 to 240.72 u/s; never grounded on the contacted ramp. The release control has only 26 ramp-contact ticks and falls away. This demonstrates controlled steep-plane sliding in faithful F2. It does not establish a complete course, a 40–70 s completion, readability or enjoyment.

`tests/r19_surf_proof.gd` is the source. Run the pinned Godot 4.7.2 editor with `--headless --audio-driver Dummy --fixed-fps 128 --path . --script res://tests/r19_surf_proof.gd -- --out=/tmp/r19-surf-proof`. Trace names `strafe.json` and `released.json` contain every actual post-step position, velocity, speed, grounded flag and ramp-contact flag. `RESULT.json` is the gate receipt.

The first run had a GDScript local type-inference error and did not execute. The next run passed over the first prism; automatic duplicate node naming hid later prism contacts from its name-based observer. Giving each prism a unique name corrected the observer only; the new full run records contact across all traversed segments. No motor edits were made for either correction.
