# Play Spillway r12

**Spillway r12 is ready to play.** This version makes the dam a bhop and surf course: held hopping, speed-building air strafes, curved concrete banks through three stages and slides that carry speed through water. All tuning and layout decisions are P / game choices.

- [Linux portable ZIP](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r12/spillway-2026.11.06-r12-linux-x86_64-f84e175d.zip)
- [Windows portable ZIP](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r12/spillway-2026.11.06-r12-windows-x86_64-f84e175d.zip)
- [Build identity](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r12/BUILD.json) and [checksums](/home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r12/SHA256SUMS)

Extract the whole ZIP. No engine installation or source checkout is needed. On Linux, open a terminal in `Spillway-linux-x86_64` and run:

```bash
chmod +x play.sh runtime/godot
./play.sh
```

The already extracted, tested copy on this laptop can also be launched with:

```bash
bash "/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/final-verification/Linux play test with spaces/Spillway-linux-x86_64/play.sh"
```

On Windows, open `Spillway-windows-x86_64` and double-click **Play Spillway.cmd**. Keep `runtime/` and `spillway.pck` together. **Debug Spillway.cmd** retains the console. Pause shows **spillway-2026.11.06-r12**. `BUILD.json` records source **f84e175d** and Godot 4.7.2; later documentation commits do not alter these packages. R11 is retained separately.

WASD runs, mouse looks, **Space jumps and holds autohop**, Ctrl/C crouches or slides. Run before the first hop. **In the air, release W, hold A or D and turn the mouse the same way.** On a surf face, strafe into the concrete and look along it. Esc includes autohop, sensitivity, horizontal FOV, volume and comfort settings. R starts a clean attempt; F restarts the current segment for practice. F11 toggles fullscreen; click captures the mouse.

The pump-hall wheel is the destination. Stairs and simple hops offer a beginner line; curved banks, turning bhops and slides offer a faster one. Slide under the yard gate, take the ramp to the filter-house roof, then choose the Outflow banks or outer gantry. After a low terrace miss, the basin ramp climbs toward the yard: approach its foot from open water. At the finish, **walk along the apron outside the yellow wheel fence**. You do not need to jump inside or press a button. Arrival starts the water wheel.

R12 keeps settings and bests in `spillway_r12.cfg` in Godot's Spillway user-data directory. R11 records are separate. Any eligible finish, including a stage-skipping line, can update the open-line best. Only ordered three-stage runs update the full-course best and splits. F and respawns invalidate records until R; shallow-water recovery without a reset stays eligible.

The new motor replaces the old air budget with projection-based air acceleration. Landing-tick hops skip friction; mouse look alone does not change airborne velocity. Steep faces slide instead of becoming floor, and the P horizontal cap is 30 m/s. Valve wheels have continuous convex collision, the gate cap and reachable hardware are solid, the west rail has a deck and the reservoir has banks. Low Yard arrivals, the bank-to-roof join and the crawlspace beneath the terrace are repaired, with a visible basin exit.

The exact packages pass archive, hash, executable and licence checks, eleven isolated suites and six nominal routes. Uninterrupted native movies finish [fast in 13.70 s](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/native-final-2/fast/fast.mp4), [recovery in 30.43 s](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/native-final-2/recovery/recovery.mp4) and [safe in 43.43 s](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/native-final-2/safe/safe.mp4), all ordered with zero respawns. A real saved best and splits survive a separate launch. The normal Linux launcher, keyboard pause/resume and both later-stage F/R checks pass.

Input fixtures show five completed strafe-hop arcs gaining 8.5 → 14.10 m/s, a 90° bhop turn retaining 112%, no air gain from W without a turn, held surf gaining speed and wet-chute retention of 97.655%. Safe's longest plain-running interval is 3.65 s; other ordinary lines are 3.45–3.70 s. A slower beginner can exceed four seconds. W with a mouse turn can also add air speed, more slowly than matched strafing. These are scripted execution results, not predicted first-clear times.

The fixed matrix finishes **31/31 ordinary cases and 8/11 fast cases**. Six fast finishes have no quality flags, including two recoveries; two others have a large speed loss or insufficient Yard contact. Three fast attempts fail. The controller reads exact physics and authored geometry, with initial takeoff/aim variations. Its automatic hops are not a survey of human timing. A [fresh view-only test](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/discovery-final/REVIEW.md) found all three stages and a **practice finish** after 72 decisions, three F uses and one respawn. It did not establish a clean first clear or discover the surf line.

Remaining weaknesses: the wheel fence initially suggests jumping inside, an approach beside the roof ramp needed a hop in fresh play, and the fast line remains demanding. The final demonstration brakes through the existing apron; its optional post-finish head turn is logged mouse input solely to show the wheel. Human camera control is unchanged, and aiming directly at machinery can still end in a collision. One motor fixture logs a duplicate jump event across adjacent ticks with the same measured apex; its conservative five-arc proof excludes count ambiguity.

Captures use Compatibility/llvmpipe software rendering. Native Windows gameplay, desktop GPU pacing, physical controllers, listening quality and human enjoyment/comfort are unverified. Audio is present and numerically unclipped. The bundled full official Godot runtime puts `(DEBUG)` in the window title. Mike decides whether it is fun.

[Surf checkpoint](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/surf.md), [detailed results](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/docs/surf/RESULTS.md), [decision trail](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/docs/reboot/decisions.tsv) and [final Opus review](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/closure-review/REVIEW.md) provide the evidence. The review found no material blocker; its wording and provenance corrections are resolved in the [response](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r12/closure-review/ROOT-RESPONSE.md). Source and delivery documentation are on **feat/foldrunner-me-build**.
