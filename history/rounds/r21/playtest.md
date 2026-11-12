# R20 playtest evidence for Spillway R21

All **33 fresh recordings pass the unchanged strict R16 reader**: 14 Breakwater, 2 Saltglass, 16 Tether Yard and 1 Through Line. All identify R20, F2 (`server128`), 128 Hz. All 38 input files (33 sealed recordings and five settings files) have identical before/after SHA256 hashes. The previous R19 recording tree is also unchanged. There are **zero inherited matches** against all 90 R19-folder recordings by exact SHA256; nothing was excluded by date or name. No partial/aborted file or strict-read failure was found.

This is analysis only, completed before any R21 runtime change in this checkout. No Godot, display, replay, captures, delivery operation or gameplay change ran here. R21 gameplay, public grapple research, packages, tests of the new runtime and branch promotion belong to the parent. Measurements do not prove enjoyment or visual quality.

## Session outcomes and lines

Recorded simulation includes untimed pre-start waiting and excludes pause time. Course elapsed is the authoritative run clock. A restart means the sealed outcome `restart`; loadout changes are counted separately. Respawns occur within attempts. Stalls below mean actual horizontal travel below 25 u/s for at least 0.5 s while started and unfinished, split at discontinuities. These are observations, not intent or collision diagnoses.

| Map | Attempts | Recorded seconds | Outcomes | Respawns | Stalls / seconds |
|---|---:|---:|---|---:|---:|
| breakwater | 14 | 168.478 | 10 restart, 3 finish, 1 map | 1 | 2 / 2.3047 |
| saltglass | 2 | 41.078 | 1 restart, 1 finish | 0 | 0 / 0.0000 |
| tether-yard | 16 | 126.353 | 8 restart, 3 finish, 4 loadout, 1 map | 0 | 1 / 1.0078 |
| through-line | 1 | 11.836 | 1 quit | 0 | 1 / 4.3281 |

Tether Yard is most played by attempt count (16/33); Breakwater is most played by recorded time (168.478 s) and most restarted (10/14). Elastic accounts for 10/16 Tether attempts including automatic reel, Classic 3 and Pendulum 3. This does not infer a preference from retries: Mike's explicit preference for Elastic and the Breakwater outside line comes from R21-SPEC.md. The session order is Breakwater, Saltglass, tether comparison, another Breakwater block, further tether comparison, Through Line.

The JSON retains every run's quarter-second reference-feet line, split at discontinuities, checkpoint/time events, full style events, largest twelve drawdowns >=0.75 m/s, all >=100 u/s single-tick horizontal losses, stalls and flight takeoff/landing samples. Full-rate fin exits, outside-line windows, grapple miss windows and abrupt-loss windows give the parent reproduction positions and inputs without launching the game. `v_ms` is stored velocity, `actual_v_ms` is physical travel excluding duck-origin compensation. Actual `p_m` must be used for hull clearance; `reference_p_m` can differ by 0.2286 m during airborne crouch.

Run names below omit only their shared date/map/preset prefix: `103932_453_d8f49e3b` identifies `breakwater_server128_20261111-103932_453_d8f49e3b.r16run`. Seconds are course elapsed / recorded simulation. Loss is the strict reader's largest section, not the sum of all speed changes; a dash means none >=0.75 m/s. CP is the highest checkpoint recorded. Each row's full metadata and hash is in the JSON/manifest.

| Map / run | Outcome | Seconds course / sim | CP | Respawns | Stalls | Peak u/s | Largest loss u/s | Style points |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| breakwater / 103825_937_0812f060 | restart | 13.359 / 15.078 | 2 | 0 | 1 | 618.3 | 618.3 | 3370 |
| breakwater / 103841_532_f77403c4 | restart | 0.867 / 16.883 | 0 | 0 | 0 | 250.2 | — | 0 |
| breakwater / 103858_397_b26d6ebd | restart | 0.000 / 2.055 | 0 | 0 | 0 | 0.0 | — | 0 |
| breakwater / 103900_455_74dd09d1 | finish | 23.336 / 26.891 | 4 | 0 | 0 | 982.1 | 148.4 | 9176 |
| breakwater / 103932_453_d8f49e3b | finish | 26.953 / 28.055 | 4 | 0 | 0 | 919.7 | 782.0 | 17393 |
| breakwater / 104006_994_a8082702 | restart | 5.305 / 6.586 | 0 | 0 | 0 | 495.7 | 465.7 | 220 |
| breakwater / 104013_579_5a067499 | restart | 12.719 / 14.547 | 2 | 1 | 0 | 693.4 | 40.3 | 6700 |
| breakwater / 104028_102_c7a1ca2d | restart | 1.648 / 1.734 | 0 | 0 | 1 | 242.8 | — | 0 |
| breakwater / 104029_853_9f34724b | restart | 0.000 / 0.938 | 0 | 0 | 0 | 60.0 | 60.0 | 0 |
| breakwater / 104030_787_1e5f5c56 | restart | 8.773 / 11.312 | 1 | 0 | 0 | 517.8 | 517.8 | 507 |
| breakwater / 104043_775_cd1ebf58 | map | 0.000 / 0.914 | 0 | 0 | 0 | 0.0 | — | 0 |
| breakwater / 104431_733_b982ede3 | restart | 6.703 / 7.758 | 1 | 0 | 0 | 499.4 | 476.1 | 1111 |
| breakwater / 104439_417_650c4388 | restart | 12.617 / 13.047 | 2 | 0 | 0 | 718.3 | 494.4 | 4423 |
| breakwater / 104452_450_01990cad | finish | 21.977 / 22.680 | 4 | 0 | 0 | 984.9 | 62.3 | 22791 |
| saltglass / 104051_036_14c2d18d | restart | 3.328 / 6.117 | 0 | 0 | 0 | 374.7 | 334.7 | 308 |
| saltglass / 104057_050_d1951cf9 | finish | 34.312 / 34.961 | 3 | 0 | 0 | 1199.1 | 605.5 | 6154 |
| tether-yard / 104145_842_299c6988 | restart | 3.766 / 9.656 | 0 | 0 | 0 | 373.5 | 75.6 | 66 |
| tether-yard / 104155_408_f8ae4215 | finish | 13.117 / 13.758 | 3 | 0 | 0 | 642.4 | 439.5 | 4143 |
| tether-yard / 104222_382_054b8df8 | loadout | 0.000 / 6.938 | 0 | 0 | 0 | 0.0 | — | 0 |
| tether-yard / 104245_682_66a80f5c | restart | 9.180 / 9.953 | 2 | 0 | 0 | 710.2 | 679.4 | 4453 |
| tether-yard / 104256_320_0654b2ba | restart | 2.586 / 3.641 | 0 | 0 | 1 | 558.6 | 362.2 | 0 |
| tether-yard / 104300_288_12cd73c3 | loadout | 3.312 / 3.859 | 0 | 0 | 0 | 741.9 | 739.5 | 0 |
| tether-yard / 104310_596_57e9484d | restart | 2.984 / 3.609 | 0 | 0 | 0 | 668.7 | 470.9 | 0 |
| tether-yard / 104314_856_85078b28 | map | 7.109 / 7.773 | 1 | 0 | 0 | 747.0 | 285.7 | 1675 |
| tether-yard / 104603_434_74e09f34 | loadout | 0.297 / 1.305 | 0 | 0 | 0 | 176.1 | 151.3 | 0 |
| tether-yard / 104606_420_94becc39 | restart | 7.195 / 7.930 | 1 | 0 | 0 | 665.7 | 345.2 | 1575 |
| tether-yard / 104615_020_a537122b | restart | 15.727 / 16.352 | 3 | 0 | 0 | 708.6 | 708.6 | 3456 |
| tether-yard / 104631_375_11e341ee | restart | 4.984 / 5.172 | 1 | 0 | 0 | 646.3 | 257.7 | 939 |
| tether-yard / 104636_542_9ccdcb3b | finish | 16.609 / 17.234 | 3 | 0 | 0 | 678.1 | 403.9 | 6454 |
| tether-yard / 104706_203_0b44f56e | loadout | 0.000 / 0.391 | 0 | 0 | 0 | 0.0 | — | 0 |
| tether-yard / 104708_972_1da09175 | restart | 2.430 / 2.852 | 0 | 0 | 0 | 644.8 | 387.2 | 0 |
| tether-yard / 104715_204_33ac95ce | finish | 15.352 / 15.930 | 3 | 0 | 0 | 729.5 | 720.6 | 3394 |
| through-line / 104809_739_128c8541 | quit | 11.047 / 11.836 | 0 | 0 | 1 | 326.0 | 276.9 | 219 |

Breakwater's three finishes traverse the container rows, crane quay and runway; the fastest recorded course time is 21.9765625 s in `104452_450_01990cad`. Saltglass's completed run reaches west landing at tick 1428 / 10.515625 s, east headrace at 2231 / 16.7890625 s, east landing at 3281 / 24.9921875 s and finish at 4474 / 34.3125 s, with zero respawns. The other Saltglass attempt restarts at the entrance before either fin exit. Tether's three finishes use Classic manual, Elastic manual and Elastic automatic respectively; these are entire attempts, not equally controlled trials. Through Line remains on its initial segment.

## Saltglass: two actual fin exits, both in the completed attempt

The two Saltglass files do **not** contain one fin exit each. `104051_036_14c2d18d` stops after 3.328125 course seconds: at ticks 679→680 / 2.5234375→2.53125 s, feet move `(11.098,15.501,0.429)`→`(11.090,15.560,0.406)`, actual horizontal speed falls 374.7→127.0 u/s and stored forward Z velocity becomes zero. This is a front-entry collision candidate from position/velocity near the fin entrance, not a logged contact. It cannot be used as an exit-speed measurement.

Both exits below are from `saltglass_server128_20261111-104057_050_d1951cf9.r16run`. Positions and stored velocities are metres and m/s; horizontal u/s comes from actual travel. The pinned R20 source makes each fin 168 m long with an 18 m crest, landing decks at y=14 m, and crescent rises 14.5, 15, 15.5 m. West's low trough is near y=2.2 m, making the eventual landing roughly 12 m higher.

| Fin / observation | Tick | Course s | Feet (x,y,z) m | Stored v (x,y,z) m/s | Horizontal u/s | Total stored u/s |
|---|---:|---:|---|---|---:|---:|
| west | 1272 | 9.296875 | 1.146, 2.192, -147.861 | 1.559, 0.928, -28.207 | 1112.21 | 1112.80 |
| west | 1344 | 9.859375 | 5.338, 8.477, -159.980 | 10.028, 14.964, -14.867 | 706.04 | 919.53 |
| west | 1415 | 10.414062 | 10.060, 15.563, -166.961 | 6.812, 10.139, -10.840 | 502.61 | 642.95 |
| west | 1427 | 10.507812 | 10.487, 16.424, -168.084 | 3.190, 8.234, -12.519 | 508.65 | 603.14 |
| west | 1479 | 10.914062 | 10.398, 18.092, -173.371 | 0.651, -0.021, -13.124 | 517.37 | 517.34 |
| west | 1550 | 11.468750 | 14.700, 14.955, -178.960 | 11.147, -11.292, -8.094 | 542.35 | 701.28 |
| east | 3101 | 23.585938 | 82.827, 2.247, -31.118 | -1.055, 1.503, 30.285 | 1193.36 | 1194.52 |
| east | 3200 | 24.359375 | 78.521, 8.689, -10.608 | -9.811, 14.638, 19.310 | 852.75 | 1029.22 |
| east | 3266 | 24.875000 | 74.007, 15.462, -1.764 | -7.526, 11.210, 15.380 | 669.88 | 805.73 |
| east | 3280 | 24.984375 | 73.408, 16.576, 0.001 | -3.729, 9.086, 16.726 | 674.68 | 763.64 |
| east | 3337 | 25.429688 | 74.238, 18.607, 7.505 | 9.132, 0.037, 15.058 | 693.34 | 693.33 |
| east | 3410 | 26.000000 | 83.188, 15.324, 11.697 | 17.042, -11.552, 6.164 | 713.49 | 846.10 |

West's drop spans ticks 1272–1415 (9.296875–10.4140625 s): approximately 1112→503 u/s while rising 13.371 m, with upward velocity reaching 14.964 m/s at tick 1344. Its exact fin-end plane crossing is ticks 1426→1427 (10.500000→10.5078125 s), y=16.359→16.424 m, horizontal 508.22→508.65 u/s and stored vertical +8.393→+8.234 m/s. Its later apex reaches y=18.092 m at tick 1479. This supports the reported “about 1000 then about 500” for west.

East's analogous rise is ticks 3101–3266 (23.5859375–24.875 s): 1193→670 u/s while rising 13.215 m. Fin-end crossing is ticks 3279→3280 (24.9765625→24.984375 s), y=16.505→16.576 m, horizontal 674.29→674.68 u/s, stored vertical +9.244→+9.086 m/s. Its apex is y=18.607 m at tick 3337. “About 500” does not describe this exit: it is nearer 675. The completed attempt has **no single-tick horizontal loss >=100 u/s**, zero grounded samples in the two rising drawdown sections, and no land/step motion event in either. It rises on the surf face and then flies upward beyond the fin. Lack of grounded flags does not mean no surf contact, because steep non-walkable faces are not ground.

Interpretation: converting forward motion into height, gravity and the surf constraint are consistent with the trace. It is not a lossless energy conversion: total stored speed also drops (1113→643 west, 1195→806 east at the table's low/high endpoints). Recordings omit normals, impulses and per-step surf contacts, so they do not isolate dissipation among the collision solver, surf law and steering. They do not prove a discrete exit-platform impact. Lower, more separated landing geometry is supported by the observed rise burden; exact new heights and distances require parent tests. The 34.3125 s clean R20 finish is below the R21 target of 40–70 s, so added route features must be checked against duration, rather than assuming the existing map meets it.

## Breakwater: the right-side outside line is real and already earns points

The strongest clear example is `breakwater_server128_20261111-103932_453_d8f49e3b.r16run`, ticks 1526–1721 (10.828125–12.3515625 course seconds). Another successful example occurs in `104452_450_01990cad`, ticks 1648–1748. They are at the **second crane-line chicane**, after the container-roof hops and first bend, not outside the early roof-row containers. This matches a right-side bypass while travelling west (-X): right is south (-Z), over open harbour.

The exact baseline source `r15_breakwater_level.gd` builds real convex solids and appends them to `manifest` in `_solid`; these are not decorative container meshes. `_crane_line` / `_container` builds the second two-tier stack from four prisms, y=0..5.182 m, union x=-50.876..-46 and z=-97.432..-88.383. Its harbour-side 10-foot prisms are `s2_chicane_2_2_1` (x=-48.438..-46) and `s2_chicane_2_2_2` (x=-50.876..-48.438), both z=-97.432..-94.441. `s2_quay_b` ends at z=-97.432, top y=0 and base -8. Recorded base geometry identity is `bc7d35582a7f18228692a625441a4d630f515f7b45dae366cf91f00b2b7b6162`; optional overlay identifies `r19-breakwater-flow-1`. That overlay modifies the much later runway thread, not this stack. The JSON contains a source-derived **partial** manifest for these solids, not a claim that Python recomputed the entire Godot geometry hash.

In `103932`, the preceding jump leaves at tick 1527 after ground at 1526, feet `(-30.752,0.017,-93.927)`, 688.6 u/s. It lands at tick 1622 / 11.578125 s at `(-42.289,0.001,-95.305)`, 718.2 u/s, then jumps on the very next tick. That precise ground point gives room to turn south before reaching the stack's east face. At tick 1670 / 11.953125 s the physical feet are `(-47.279,1.648,-99.175)` (reference y=1.419 due to crouch), 726.6 u/s. It returns west of the stack to `(-54.447,0.023,-97.365)` at tick 1721 / 12.3515625 s, 732.8 u/s, and immediately hops on tick 1722. Air time is 0.765625 s, takeoff yaw 0.512→landing yaw 1.716 rad, pitch -0.310→-0.179. The source uses world yaw, not a scripted track. It is a curved, input-steered airborne excursion, not a hidden route trigger.

With the recorded 32-u box hull (half-width 0.4064 m), the hull spans the stack's X interval on ticks 1659–1698. Minimum separation from its south face while spanning it is 0.4425 m; closest horizontal box-to-box separation over the flight is 0.4121 m at tick 1699. The player clears the stack horizontally, not over its 5.182 m roof. These are sampled nominal AABB clearances, not engine sweep/contact results. The second example reaches z=-100.1035 and has 1.5698 m minimum sampled horizontal clearance.

**Actual rewards:** the first example gets `speed` +181 at tick 1676 and `gap` +2328 at landing tick 1721 (`s2_quay_b`→`s2_quay_b`). The takeoff-ground tick 1622 also records `sync` +178 from the preceding flight. The second example gets `gap` +2695 at tick 1748. Neither outside flight records `near_miss`, `edge`, `crouch_save` or a directional bank. Tick 1753 of the second example, after its next takeoff, does record `crouch_save` +4500 against the quay's side; that is a separate event, not a bonus for this container.

The source's existing near-miss detector needs >=380 u/s, clearance <=8 u (0.2032 m), no scrape, passage <=6 m, open entry/exit and novelty by geometry. This first line stays more than twice the clearance threshold from the stack; the second is wider still. The recorded gap award already recognizes the airborne loss of support even with the same takeoff/landing deck. It is false to say the outside line received nothing, and no new hand-placed award is justified. Recommendation: reproduce the geometry pattern in Saltglass and retain generic gap scoring; a wider close-pass detector remains optional research, with anti-repeat and scrape tests required before implementation. These recordings alone do not prove a new bonus cannot be farmed.

## Grapple: compare actual attempts and preserve the limits

Each model comes from the recorded mechanics identity, not current settings or inference from its motion. All ten manual/automatic Elastic attempts are counted; menu-only attempts stay in the denominator. `Started` means the course timer started, not necessarily that a full transfer was attempted. Episode metrics include all attach/release pairs, including reset endings, and are not controlled model A/B trials.

| Model / reel | Attempts (started / with attach) | Finishes | Attachments | Miss events | Recorded LMB presses | Peak u/s | Median episode peak u/s | Median release u/s | Median attach seconds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| classic/manual | 3 (2 / 2) | 1 | 4 | 0 | 4 | 642.4 | 585.9 | 300.2 | 1.2266 |
| pendulum/manual | 3 (3 / 2) | 0 | 2 | 1 | 3 | 747.0 | 707.8 | 346.6 | 1.6992 |
| elastic/manual | 8 (7 / 7) | 1 | 16 | 9 | 21 | 741.9 | 656.5 | 321.6 | 1.3945 |
| elastic/auto | 2 (2 / 2) | 1 | 4 | 2 | 4 | 729.5 | 666.7 | 400.6 | 1.5117 |

Recorded LMB presses are an input count, **not** a target-acquisition success denominator: some misses precede a later attach while the button remains held, one attach and miss even share an outer tick, and pre/post-step event placement differs. No false success percentage is manufactured. Classic is 2 attaches-bearing attempts of 3; Pendulum 2/3; Elastic manual 7/8; Elastic auto 2/2. No diagnostic release reports `range`, `time` or `obstructed`: Classic has 3 `released` +1 `restart`; Pendulum 2 `released`; manual Elastic 15 `released` +1 `restart`; auto Elastic 4 `released`. A cue being marked active in a diagnostic does not prove Mike heard it.

| Model / reel | Total endpoint shortening u | Observed reeling input seconds (inclusive) | Median prior-centre distance minus release rope u |
|---|---:|---:|---:|
| classic/manual | 895.8 | 3.4766 | 221.43 |
| pendulum/manual | 873.7 | 3.3281 | 1.15 |
| elastic/manual | 6608.7 | 22.6875 | 199.88 |
| elastic/auto | 1731.9 | 6.4219 | 214.38 |

Endpoint rope lengths and `attached_ticks` come directly from tether diagnostics. Reeling duration comes from RMB input edges or recorded automatic mode, includes endpoints, and can differ by one tick from the physics update. Automatic mode starts with no invented RMB input. Distance-minus-rope is an **estimate** from the previous recorded physical feet, nominal standing/duck centre and the anchor name provided at release. It is not serialized rope tension or solver error. Medians are Classic ~221 u, Pendulum ~1.15 u, Elastic manual ~200 u, auto ~214 u. R20's `stretch_u=80` is extra **anchor-range allowance**, not an 80-u maximum rope extension: break checks `range_u+stretch_u`, not `rope_length+stretch_u`.

Pinned source distinguishes the models concretely. Classic removes outward radial velocity before its bounded stiffness-30 / 1300 u/s² pull and allows 3 s attachment. Pendulum uses a hard radial/excess-per-dt correction, no spring and 5 s attachment; it has no added speed cap. Elastic uses stiffness 90, outward damping 10, bounded 1800 u/s² pull, no Classic hard radial catch, and 5 s attachment. Classic/Elastic pull caps at max(incoming total speed,650 u/s), which preserves higher incoming speed; 650 is not a global measured horizontal-speed ceiling. All reel at 260 u/s to a 96-u minimum, share a 9° acquisition cone and ~30 m target range, and release when LMB is released. Elastic's measured extension and stronger episode peaks are consistent with a softer catch and spring-driven sweep; recorded differences alone cannot tell whether reel, compliance, aiming or order/practice caused his preference.

### Acquisition and platform reproduction windows

The exact map source `r19_tether_level.gd` has anchors `(0,12,-8)`, `(10,12,-38)`, `(-2,12,-68)`; deck tops are y=4 with solid thickness 0.8 m (`r19_course_geometry.gd::deck`). Transfer deck 1 is x=-8..12,z=-30..-16; deck 2 x=4..22,z=-60..-46; dispatch x=-14..8,z=-92..-76. These are source facts, not recorded contacts.

In manual Elastic `104245_682_66a80f5c`, miss tick 698 / 4.6875 s is at `(7.034,5.172,-31.213)`, 537.0 u/s; attach follows tick 705. More directly after the second transfer platform, miss tick 991 / 6.9765625 s is at `(6.506,5.124,-59.011)`, 583.0 u/s; it acquires Transfer 3 at 994 (three ticks, 0.0234375 s later). In automatic Elastic `104715_204_33ac95ce`, miss tick 1373 / 10.15625 s is at `(4.171,5.191,-59.182)`, 500.0 u/s, then Transfer 3 attaches at 1393 (20 ticks, 0.15625 s later). These are direct missed-acquisition events at speed; target state, eye interpolation and line-of-sight result are not logged, so they do not prove cone failure versus range or occlusion. Parent should reproduce these view/position windows when widening acquisition; not infer the best angle from a single miss.

Platform clip candidates with stronger spatial evidence:

- **Dispatch front, manual Elastic `104245`**, ticks 1146→1147 / 8.1875→8.1953125 s. Feet `(-2.220,3.903,-75.592)`→`(-2.214,3.945,-75.592)`, actual horizontal 283.1→30.8 u/s; Z has already been zeroed in stored velocity. The hull's front edge is at approximately z=-75.998, matching the dispatch front z=-76, and feet y overlaps the solid's 3.2..4 band. It remains airborne. Wider drawdown ticks 1091–1147 loses ~679 u/s. Transfer 3 stays attached until 1152. This is a strong front-face collision inference; collider and normal are **not recorded**.
- **Dispatch front, automatic Elastic `104715`**, ticks 1527→1528 / 11.359375→11.3671875 s. Feet `(-4.006,2.497,-75.583)`→`(-4.062,2.560,-75.592)`, actual horizontal 419.2→283.6 u/s; stored Z -7.879→0 m/s. Standing hull top overlaps the 3.2..4 m solid band. Wider drawdown 1468–1536 / 10.898–11.430 s is ~721 u/s. Transfer 3 remains attached until 1580. It subsequently recovers and finishes, so a finish does not exclude a clip.
- **First transfer front, manual Elastic `104300`**, ticks 370–372 / 2.3515625–2.3671875 s. Feet `(0,3.139,-15.559)`→`(0,3.230,-15.593)`, actual horizontal 392.1→169.7→2.4 u/s; stored Z -9.959→0 m/s. Hull leading edge lies at the z=-16 front. It stays attached until tick 425. Again a front-face inference, not a logged normal.

Not every speed loss is a platform hit. Manual Elastic `104615`, ticks 863–948 / 6.125–6.789 s, loses ~624 u/s after Transfer 2: the sampled path climbs from y=2.56 near z=-38.44 to y=6.36 near z=-45.70. At tick 934 feet are y=5.335, above the y=4 deck top, while stored Z has gradually fallen to -4.996 m/s and vertical velocity is +8.931 m/s. This is consistent with continued reel/pull and upward conversion, not proven platform contact. Its trace and release at 948 should test over-reeling separately from the front-face fixtures. The abrupt loss at `104300` ticks 433–435 occurs at y=7.2 above the deck, after release, and cannot be called a deck-front clip. Pendulum `104314` tick 969 has x=21.592 near a return-ramp side below the main platform; it is another geometric-contact candidate, not evidence against Elastic.

Parent reproduction targets: use `runs[].clip_windows`, `runs[].miss_windows`, `runs[].tether.episodes[].trace` and the source snapshots. Recreate labelled initial poses/views and actual input routes in the parent's permitted runtime harness, then inspect true contacts and rope forces. The current recordings cannot establish whether geometry clearance or rope tuning alone fixes the observed problem. They justify testing more vertical clearance at the dispatch approach as well as earlier/friendlier Transfer 3 acquisition. No changes to Classic, Pendulum, mouse controls or the original maps were made here.

## Backwards stacks and Through Line: preserve them

All 33 runs reconcile recorded style score to the sealed score and validate every triangular pending/banked formula and nonzero bank-to-diagnostic pair. Breakwater has four backwards banks totaling 6720 points: `103825` ticks 1204 (+160, heading) and 1587 (+480, efficiency), `103900` tick 1741 (+1600, efficiency), `104013` tick 1436 (+4480, facing). `104030` reaches six hops / 2400 pending then loses it at tick 1308 for `stall`; it does not appear in scored style. No sideways bank is recorded. This is observed accounting, not complete eligibility reconstruction or engine replay; no proven stack bug warrants retuning.

The only Through Line attempt `104809_739_128c8541` quits at course 11.046875 s, recorded 11.8359375 s, checkpoint 0, feet `(4.365,4.001,-28.696)`. It never logs a `through` launch/transition event; its reference line never passes z=-28.70. Its final 4.3281 s stall has no movement held. This provides no launch-continuity verdict and no demonstrated launch bug. Leave Through Line unchanged as specified.

## Actual style kinds and points, including unfinished attempts

| Map | Kind: count / points |
|---|---|
| breakwater | sync: 97 / 13383; gap: 41 / 24476; speed: 44 / 6929; backward_bhop_bank: 4 / 6720; near_miss: 1 / 283; crouch_save: 3 / 13500; edge: 1 / 400 |
| saltglass | sync: 25 / 3208; speed: 20 / 2447; gap: 5 / 807 |
| tether-yard | sync: 36 / 4080; gap: 17 / 20034; speed: 13 / 776; edge: 2 / 1265 |
| through-line | sync: 4 / 219 |

## Reproduce and verify

From `/home/thatmike1/foldrunner-build-2026-11-05/look/wt/projects/foldrunner`:

```bash
python3 -I tools/analyze-r21-playtest.py /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/userdata-spillway/r16_runs --exclude /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/userdata-spillway/r16_runs --baseline e6baa995da84d380abc8b8d6a3769b33e771945e --output /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/r21-analysis.json --manifest /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/r21-input-integrity.json
```

The tool hashes inputs in 64 KiB blocks, loads only one recording at a time through the unchanged strict reader (that reader internally reads a complete file), checks reader bytes against the pinned baseline, and takes interpretation sources from `git show` at that baseline so concurrent runtime edits cannot change the evidence. It isolates strict failures in `strict_failures`, continues valid neighbors, writes a diagnostic report and returns nonzero rather than silently dropping bad files. Unexpected cohorts/identity, changed input bytes or failed direction accounting also return nonzero. Output paths inside either input tree or sharing one filename are refused. It checks HOME >=15,000,000,000 bytes before and after inventory, between runs and after writes; derived output is bounded and Python VmHWM must remain <=100 MiB. Linux `/proc/self/status` measures this process's own high water, since `getrusage` can retain the launcher's pre-exec high water.

Machine evidence is `r21-analysis.json` and `r21-input-integrity.json` beside outer ANALYSIS.md. The report embeds pinned source snapshots/hashes, reader/helper hashes, all 33 run hashes, run-level metadata and named evidence windows. The integrity file retains before/after hashes of all five settings and all recordings, all 90 exclusion recordings, exact hash matches (none), free space and memory reading. Settings are not used to override each recording's identity. Raw recordings/settings remain private and read-only and are not committed. The committed `docs/r21/PLAYTEST.md` and outer `playtest-r20/ANALYSIS.md` carry identical prose.

The successful evidence run used 38,928,384 bytes Python peak RSS and left 15,323,598,848 HOME bytes. JSON size is 5,626,061 bytes and integrity size 48,566 bytes, comfortably below 20 MiB together. No deliveries, cache or raw files were altered.

The canonical sorted input inventory SHA256 (`sha256(json.dumps(before,sort_keys=True,separators=(',',':')).encode())`) is `4c9f91c85cd08d3ec82ec0c59c4366d22799c6c5aead90736e1ade368537dde7`. Each constituent hash is in the manifest.

| Artifact / source | SHA256 |
|---|---|
| analyze-r21-playtest.py | `07ad88de2755496b9daf7b40083f912dfc0e929beebc34f269a838f33bc5a816` |
| analyze-r16-runs.py | `d4dac3dd0e1c55f50317041f4c63ed399f7188d9c4b23fd4f4487e7bf751a261` |
| analyze-r19-playtest.py | `d337b198aa058860f1380eb8c36f4916481200896c2f34b225a6ded6386a5030` |
| r21-analysis.json | `b4f7f271c18544ca24a18cf8bc96492d30584671f5708fd7b7c337ab8ee73844` |
| r21-input-integrity.json | `6c3eecb015bb81b6dd867fa4df73a68571d9ec20119614d6c1975b67917137f5` |

Additional executed checks: truncated header rejection; last-byte corruption rejected by the strict hash chain; a synthetic corrupt neighbor isolated while the real valid neighbor remained in the diagnostic report and the command returned nonzero; output under the input tree refused before writing; identical hashes under different filenames confirmed; final live inventories equal both captured inventories; Python AST parses; all helper hashes match; both prose files are byte-identical. Existing engine-dependent suites were not run because this assignment forbids Godot. No runtime files changed in this commit.

Done-condition check for this analysis assignment: 33/33 strict reads, correct per-map cohort, complete input/settings hash equality, both actual fin exits, actual outside-line geometry/rewards, recorded model comparison with denominators and unknowns, concrete miss/clip windows, unchanged directions/Through Line and reproducible JSON are complete. The overall R21 spec is not complete here: runtime improvements, GRAPPLE-RESEARCH.md, verified Linux/Windows ZIPs, final RESULTS-R21.md and gameplay-branch fast-forward remain parent-owned. No analysis result substitutes for those checks.
