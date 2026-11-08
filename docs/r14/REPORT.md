# Play Spillway R14

**Start with F2 on the Penstock straight.** R14 has a Source-style bhop baseline, five live movement presets, a strafe HUD and an original practice yard beside Overflow. Release W in the air, hold A or D and turn the mouse the same way. Well-timed matching strafes build speed; releasing movement keys keeps the flight line. Whether it feels right is yours to decide.

- [Linux ZIP](../../../../../delivery/spillway-r14/spillway-2026.11.08-r14-linux-x86_64-65d205be.zip)
- [Windows ZIP](../../../../../delivery/spillway-r14/spillway-2026.11.08-r14-windows-x86_64-65d205be.zip)
- [Build identity](../../../../../delivery/spillway-r14/BUILD.json), [checksums](../../../../../delivery/spillway-r14/SHA256SUMS), [204 release checks](../../../../../delivery/spillway-r14/VERIFICATION.json)

## Start playing

Extract the entire ZIP. On Linux, run `./SpillwayR14.x86_64` inside `SpillwayR14-linux-x86_64`. Its executable bit is preserved. On Windows, open `SpillwayR14-windows-x86_64` and double-click `SpillwayR14.exe`. Keep the `.pck` beside it. No engine installation or source checkout is needed. Windows is packaged and checked statically; native Windows play is unverified.

The default is **Penstock Yard, F2 bhop server**. Press **Esc**, choose **3 Penstock straight**, then **Practise here** to reach the 128 m runway directly. Run with W before jumping, hold Space, then release W in the air. Alternate A with a left mouse turn and D with a right turn. No movement keys coasts on the current line.

Source sensitivity starts at **2.5**. This turns less than half as far per mouse count as R13; **5.73** approximately matches R13's original radians per count. Each family keeps its own sensitivity and FOV settings.

| Key | Preset | Jump and air controls |
| --- | --- | --- |
| F1 | CS:GO vanilla cvars, AA 12, 64 Hz | fresh Space press or wheel each hop; release W, use A/D with matching turns |
| F2 | CS:GO bhop server, AA 100, 128 Hz | hold Space; no stamina or takeoff clamp; A/D with matching turns |
| F3 | original R13 Overflow runner, 120 Hz | original autohop, assisted steering and camera |
| F4 | Quake III-inspired, AA 1, full 320 u air wish, 128 Hz | hold Space, use W+A/D with gentle matching turns; Source contacts, not Quake/CPMA |
| F5 | configured AA 1000 server comparison, 128 Hz | as F2; its difference depends on input angle and speed |

F1 is timing-sensitive. Late hops expose friction and reconstructed stamina loss: the preset tour fell from 250 to 161 u/s over six tapped hops despite positive air gain. Its stamina and clamps are labelled reconstructions, not a measured matchmaking match. F2 is the no-stamina comparison.

Switching keeps position, speed and view; a used attempt becomes practice. **R** starts clean, **F** practises the last stage, **Esc** opens presets, maps, settings and stage practice, and **F11** toggles fullscreen. The map buttons switch between Penstock Yard and Overflow.

Penstock has opening blocks, two bends and widening speed gauges. Missed gaps have return paths to retry. Red pads mark a takeoff zone calibrated for a flat 250 u/s jump. Jump near the pad's far yellow edge for longer gaps; pale noses and dark faces distinguish landings from front walls. Pads are not calibrated for R13. The advanced line is unavailable to vanilla at its clamps.

## Read the HUD

Speed is measured travel in u/s, with m/s below. Hop feedback separates air gain, contact loss and loss between takeoffs. Sync counts air ticks with exactly one of A/D held and a nonzero mouse turn, then reports how often their directions agree. Holding a key without turning is not counted. **100% sync does not mean an optimal turn rate.** A dash means no eligible samples.

Records live in `spillway_r14.cfg`, separated by map, preset and physics/timing version. Exact integer ticks keep equal runs equal after reload. Practice, respawns and mixed-preset attempts never save bests. R12/R13 profiles are untouched.

## What was checked

The delivered source is **65d205be**, with official Godot 4.7.2 release runtimes. All **204 package checks** pass. Ten clean ordered runs have zero respawns and match fresh source traces exactly, including Penstock F2 basic (**56.35 s**), earned-speed advanced (**28.61 s**), final-gap miss/return (**67.03 s**), F1 basic (**57.78 s**), F3 basic (**42.88 s**) and all five Overflow presets. Each saves and reloads complete records in a new process.

The movement equations are an original implementation of public Source rules. The independent oracle checks acceleration, stopspeed friction, the 30 u air cap, gravity 800 and jump impulse 301.993377. **1 Source unit = 0.0254 m.** The ideal AA100/128 Hz five-hop reference reaches 703.20694 u/s after a run-up from rest. This is calculated from public rules, not a CS:GO binary measurement. No exact vanilla multi-hop maximum is claimed.

A separate X11 keyboard/mouse test on this exact pack passes **22/22**: Space, wheel, all preset keys, stage practice, both A/D strafes, no-key coasting and Quit. A delivered 100-pixel mouse delta turns exactly 5.5 degrees. Native checks use verified AMD rendering on a private display. XTest is synthetic OS input, not physical-device latency or feel.

## Remaining limits

- Source contacts are independently implemented on Godot casts, with an 18 u step and a conservative missed-floor guard. There is no crouched hull, crouch jump, ladder or faithful water model. Rising-air surface friction is modelled and reduces AA12 gain in its window.
- Some landings are tight. Two tested inward-angle return approaches still stall until a sideways input escapes. F4/F5 have no full Penstock route proof; all five presets do have clean Overflow proofs.
- The first two screenshot-driven discovery attempts did not finish. The second landed four opening gaps, but used frequent pauses and read more documentation than allowed. Scripted finishes do not prove that the practice route is easy to learn.
- Forced private Wayland can hang in Godot teardown. The final X11 runs quit cleanly. If Quit leaves a process running, end it; finished records are already saved. A historical initialization difference up to 1.697 cm remains unexplained between the old R13 product and its R14 host, without changing tested finish times. Current packed references match exactly.
- Native Windows play, physical gamepad use, audio listening, physical latency and human enjoyment remain unverified.

[Detailed results, retained failures and independent reviews](RESULTS.md) include the equations, inputs and evidence. Final R12/R13 downloads remain local as separate comparisons.
