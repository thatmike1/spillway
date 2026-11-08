# Play Spillway R14

R14 replaces R13's assisted air steering with a Source-style baseline. **Release W in the air, hold A or D and turn the mouse the same way.** Matching strafes build speed; releasing movement keys keeps the flight line. Five movement presets switch in the same game, with speed, hop gain and directional strafe sync on screen. Whether it feels right is Mike's verdict.

The candidate is built from `5484f10d`, with official Godot 4.7.2 release runtimes. Its Linux and Windows ZIPs are verified; final promotion and independent review are pending. The intended delivery is outer `delivery/spillway-r14/`.

## Start with the straight

Extract the whole ZIP. On Linux, run `./SpillwayR14.x86_64` inside `SpillwayR14-linux-x86_64`; the executable bit is preserved. On Windows, open `SpillwayR14-windows-x86_64` and double-click `SpillwayR14.exe`. Keep the `.pck` beside it. No engine installation or source checkout is needed. Windows contents are checked, but native Windows play is unverified.

The default is **Penstock Yard, F2 bhop server**. For an immediate movement comparison, press **Esc**, choose **3 Penstock straight**, then **Practise here**. This is a 128 m runway. Run with W, hold Space, release W during the hop and alternate A/left mouse turn with D/right mouse turn. Turn gently at first. Release all movement keys in the air to coast. The settings menu has Source mouse sensitivity, initially 2.5. This turns less than half as far per count as R13; **5.73** approximately matches R13’s original turn rate. R13 keeps its own sensitivity and camera.

| Key | Movement | Jump policy |
| --- | --- | --- |
| F1 | CS:GO vanilla cvars, AA 12, 64 Hz | fresh Space press or wheel for each hop; stamina and speed clamps reconstructed |
| F2 | CS:GO bhop server, AA 100, 128 Hz | hold Space; no stamina or takeoff clamp |
| F3 | original R13 Overflow runner, 120 Hz | original autohop, assisted flight steering and camera |
| F4 | Quake III-inspired, AA 1, full 320 u air wish, 128 Hz | hold Space; use W+A/D and gentle matching turns; Source contacts, not Quake/CPMA |
| F5 | configured AA 1000 server comparison, 128 Hz | as F2; its difference depends on the input angle and speed |

F1 is timing-sensitive: late hops expose friction and reconstructed stamina loss. In the preset tour, six tapped hops fell from 250 to 161 u/s despite positive air gain. That reconstruction is not a measured matchmaking match. F2 is the no-stamina bhop comparison.

Switching keeps position, speed and view. A used attempt becomes practice, so mixed physics cannot set a record. **R** starts clean, **F** practises the last stage, **Esc** opens presets/maps/settings and the stage picker, **F11** toggles fullscreen. The menu switches between Penstock Yard and the original Overflow course. Every preset has a clean input-driven Overflow finish on the shipped pack.

Penstock Yard has opening blocks, two bends, widening speed gauges and the long straight. Missed gaps have physical return paths to retry. Red pads mark a takeoff zone calibrated for a 250 u/s flat jump; pale landing noses and dark faces distinguish a deck from its front wall. Jump near the pad’s far yellow edge for longer gaps. Pads are not calibrated for R13, and the advanced line is not available to vanilla at its speed clamps.

## Read the strafe HUD

Speed is measured travel in u/s, with m/s below. The last-hop panel separates air gain from contact loss and shows the next takeoff's ground loss. Sync is the percentage of eligible air ticks where the mouse turn agrees with A or D. A tick is eligible only with exactly one of A/D held and a nonzero view turn; holding a key without turning is not counted. **100% sync does not mean an optimal turn rate.** A dash means there were no eligible samples. This is directional sync, not a strafe-efficiency score.

Records are separate by map, preset, physics and timing version in `spillway_r14.cfg`. Exact integer ticks keep equal runs equal after reload. Stage practice, respawns and mixed-preset attempts do not save bests. R12 and R13 profiles are untouched.

## What is backed by evidence

The baseline implements ground acceleration, friction with stopspeed, Source's 30 u air wishspeed cap, uncapped-wish acceleration budget, gravity 800 and jump impulse 301.993377. **1 Source unit = 0.0254 m.** The written public-rule reference and independent oracle check known numbers rather than only this motor's own targets: an optimal full-cap update from 250 reaches 251.793566 u/s; the ideal AA100/128 Hz five-hop model after a run-up from rest reaches 703.20694 u/s. These are calculated references, not measurements from a running CS:GO binary. Real collision has separately checked landing-tick counts. There is no resolved vanilla multi-hop maximum because stamina and landing order need binary validation; the five-hop number above is for AA100 without stamina.

The exact portable candidate passes **204/204 package checks**. Ten clean ordered runs have zero respawns, save and reload complete records in new processes, and match their fresh source traces exactly. These include Penstock's F2 basic (**56.35 s**), earned-speed advanced (**28.61 s**), deliberate final-gap miss/return (**67.03 s**), F1 basic (**57.78 s**), F3 basic (**42.88 s**) and all five Overflow presets. Inputs are scripted key/mouse events, not position or velocity rescue. Native packed checks use a private AMD/X11 display. They prove rendering and exact execution on this laptop, not physical input latency or feel.

Two screenshot-driven discovery attempts did not finish. The latest compared F1/F2/F3 on the straight and landed four opening gaps after a clean restart. It used frequent pauses and read more documentation than its controls-only brief allowed. Neither discovery result establishes that the whole practice map is easy to learn. Failed approaches and uncertainty remain in the evidence.

## Limits to know

Vanilla stamina, its 275 u/s takeoff clamp and grounded speed restriction are labelled reconstructions, not binary fidelity. Source contacts are independently implemented on Godot casts with an 18 u step and a conservative missed-floor guard. There is no crouched hull, crouch jump, ladder or faithful water model. Rising-air surface friction (“deadstrafe”) is modelled on the Source presets and reduces AA12 gain in its rising-speed window. F4/F5 have no full Penstock route proof. Some landings are tight; two tested inward-angle return approaches still stall until a sideways input escapes.

Forced private Wayland can hang during Godot engine teardown. The release checks use X11 and every tested Quit exits cleanly. If Quit leaves a process running, end it; finished records are already saved. This is not a claim that every desktop display path is fixed. A historical initialization difference of up to 1.697 cm remains unexplained between the old R13 product and its R14 host; current packed references match exactly.

Native Windows play, real-device gamepad use, audio listening, physical latency and human enjoyment remain unverified. Source equations, variants, failures, scripts and evidence are indexed in `docs/r14/RESULTS.md`. Final delivery and review status will replace this draft's pending wording before handoff.
