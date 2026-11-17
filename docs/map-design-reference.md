# Measured bhop-map reference

17 November 2026. **BSPs are readable without Java; recorded contacts are needed to identify played jumps.** Eight core CS:S maps were measured from compiled brush geometry and public SourceJump replays. Two, Epiphany and Fury 2, have player comments praising their appearance. This is a measured reference, not approval of Spillway's maps or a claim that server difficulty transfers to F2.

**Correction to the early sheet:** Eazy's 0.813 m median was adjacent-pad spacing in an inferred tour, not a jump requirement. That recommendation and the bonus tour gap statistics are withdrawn. The bonus tour crossed omitted sloping supports. The final comparison below uses supports actually contacted in recorded runs.

## What was measured

A run's ground-flag transitions select landing events. Their 32×32 u hull footprints are matched to horizontal collision-brush tops at the recorded height, allowing −0.2 to +4 u for sampled contact timing. Coplanar connected tops are united before measurement. This includes invisible collision surfaces. A support's size is its minimum rotated bounding rectangle, which can overstate local landing room on a concave island.

A jump pair requires two consecutive matched landings on distinct supports, airborne ticks between them, and no detected position step over 128 u in one tick. The gap is **minimum horizontal polygon separation between those supports**, not flight distance, clearance along the actual curved path, or mandatory jump demand. A projected gap can be zero across overlapping supports at different heights. Missing contacts and slopes are not silently bridged. Short teleports below the step threshold, moving geometry and unmodeled props remain possible sources of error.

“Flat” below means support-height difference ≤4 u and contact interval 0.68–0.82 s. This selects comparable ordinary hops, not boosts or long drops. Percentiles count performed contacts, so repeated landings count again. **1 Source u = 0.0254 Spillway m**, the convention in [movement-reference.md](movement-reference.md).

## Eight played maps across tiers and styles

All runs are SourceJump normal style at 100 Hz, ruleset 5: AA1000, autobhop, run speed 260 u/s. F2 is AA100 at 128 Hz. Tiers below are SourceJump's current ten-tier scheme, not bunnyhop.lol's scheme or a F2 rating. The four short T1 maps cover fast strafe/linear routes; 98sync adds a longer strafe line; Epiphany, Fury 2 and Badges cover long staged courses. Each sample is rank one on SourceJump beta's ruleset-5 board at retrieval (the API's world-record time), not a typical player traversal; slower players may land on more, closer supports. Public metadata and raw replay URLs identify each sample.

| map / run / tier | matched landings | flat pairs | gap u p10 / median / p90 | median gap m | flat-pair landing short side median u / m | flat-pair horizontal travel speed median u/s |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| bhop_flartstrafe_cyber / [3793](https://beta.sourcejump.net/v1/runs/3793) / T1 | 39/39 | 24 | 128.0 / 256.0 / 775.4 | 6.502 | 256.0 / 6.503 | 1056 |
| bhop_duster / [3790](https://beta.sourcejump.net/v1/runs/3790) / T1 | 29/29 | 28 | 138.8 / 288.0 / 675.2 | 7.315 | 256.0 / 6.502 | 1027 |
| bhop_edibles_v1 / [3075](https://beta.sourcejump.net/v1/runs/3075) / T1 | 19/19 | 17 | 128.0 / 192.0 / 576.0 | 4.877 | 256.0 / 6.502 | 875 |
| bhop_surge / [3256](https://beta.sourcejump.net/v1/runs/3256) / T1 | 17/17 | 16 | 100.0 / 192.0 / 528.0 | 4.877 | 192.0 / 4.877 | 811 |
| bhop_98sync / [3499](https://beta.sourcejump.net/v1/runs/3499) / T2 | 39/39 | 34 | 195.1 / 608.0 / 832.0 | 15.443 | 160.0 / 4.064 | 1159 |
| bhop_epiphany / [4018](https://beta.sourcejump.net/v1/runs/4018) / T3 | 605/616 | 149 | 90.5 / 272.5 / 559.4 | 6.921 | 192.0 / 4.877 | 887 |
| bhop_fury_2 / [3737](https://beta.sourcejump.net/v1/runs/3737) / T4 | 441/481 | 117 | 144.0 / 256.0 / 406.1 | 6.502 | 64.0 / 1.626 | 597 |
| bhop_badges / [456](https://beta.sourcejump.net/v1/runs/456) / T5 | 438/471 | 101 | 128.0 / 306.3 / 624.0 | 7.780 | 64.0 / 1.626 | 736 |

This is a small, conditional sample. Core coverage is 91.7–100%; unmatched landings are excluded from gap statistics, not filled in. Low-coverage Together and Blue Aux were retained as diagnostics, not used to complete the eight-map comparison. No replay header contains a BSP checksum: high contact agreement supports alignment but does not prove the server used byte-identical BSPs.

The numerical difference between these easier and harder map samples is not “hard means longer gaps.” Duster's flat median is 288 u (7.315 m), onto supports with a 256 u (6.502 m) median short side, at about 1027 u/s. Fury 2's flat median is 256 u (6.502 m), with a 64 u (1.626 m) landing short side, at about 597 u/s. The harder sample offers less landing room and lower mean horizontal speed during the hop despite its smaller median gap. These are observations from these runs, not causal difficulty estimates. Use the local F2 takeoff speed and a driven tape before sizing a new gap.

## Length and grouping

The length below sums every recorded 3D displacement from start-zone exit to finish, excluding steps over 128 u in one tick as discontinuities. It is **one run's travelled path**, including retries, loops and detours, not the shortest route or nominal map length. The discontinuity count includes teleports/resets and is not a count of failures.

| map | run time s | path length u / m | discontinuities | absolute height change p90 u / m | map-wide teleport destinations | performed pattern changes/min |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| bhop_flartstrafe_cyber | 29.697 | 33619.2 / 853.9 | 0 | 17.6 / 0.447 | 1 | 36.4 |
| bhop_duster | 21.937 | 21647.8 / 549.9 | 0 | 0.0 / 0.000 | 1 | 57.4 |
| bhop_edibles_v1 | 14.405 | 11879.7 / 301.7 | 0 | 0.0 / 0.000 | 1 | 54.1 |
| bhop_surge | 13.109 | 10359.8 / 263.1 | 0 | 0.0 / 0.000 | 0 | 54.9 |
| bhop_98sync | 33.130 | 37467.1 / 951.7 | 0 | 0.0 / 0.000 | 5 | 34.4 |
| bhop_epiphany | 496.625 | 442827.3 / 11247.8 | 21 | 64.0 / 1.626 | 77 | 52.8 |
| bhop_fury_2 | 359.527 | 206099.8 / 5234.9 | 11 | 48.0 / 1.219 | 51 | 34.0 |
| bhop_badges | 424.615 | 378285.1 / 9608.4 | 32 | 185.6 / 4.714 | 55 | 33.1 |

Height-change percentiles use all measured distinct-support flight pairs, not just the flat subset. Reset destinations supply an authored form of grouping, but the map-wide counts include bonus/helper areas. Short strafe maps commonly have one reset destination; the long maps have many. For Eazy specifically, reset volumes identify 25 groups containing main-course movers, with 2/5/9.6 pads per group at p10/median/p90. One further main destination has no mover assigned. This is measured recovery grouping; the old script's four rows per room were analyst-selected and are not independent evidence of cadence.

“Pattern change” is an explicit operational proxy for performed rhythm: a different gap bin (128/256/512 u), landing-short-side bin (64/128/256/512 u), rise/drop class (±16 u), or turn ≥60°. Only directly consecutive matched flights count. The rate divides detected changes by the full run duration, including unmatched and teleport stretches. It is sensitive to these bins, player routing and speed, and does not measure perceived rhythm or when the art changes. The raw per-flight records retain the values so another classification can be used. Do not turn these rates into a timer for changing scenery.

## Appearance: useful structure and useful criticism

- **Epiphany:** a player praises its scale and another praises how it looks ([page](https://gamebanana.com/mods/124957), posts 7900257 and 7892119). The public first screenshot shows a coherent concrete interior with a large bright opening, smaller lit recesses and overlapping levels. The big opening organizes the view; the architecture carries the route. Players also criticize velocity-stopping teleports. This supports separating visual scale from continuity of motion.
- **Fury 2:** players praise its lighting and appearance, while another explicitly calls its levels beautiful but criticizes gameplay ([page](https://gamebanana.com/mods/125106), posts 6851374, 6852452 and 6853911). Public screenshots show large portal frames, numbered spaces and repeated rings that organize depth. Other comments criticize thin or unsupported-looking blocks, empty rooms and repetition. Borrow a clear structural rhythm and lighting hierarchy, not its neon palette, which Mike rejected.
- **Interloper:** [player comments](https://gamebanana.com/mods/125285) praise its atmosphere and detail but criticize route blocks blending into scenery and long resets. Its stone masses, water and repeated globe lights form a coherent cavern. Visual acclaim does not establish readable routing.
- **Tranquility:** the [author page](https://gamebanana.com/mods/126240) describes repeated player testing. Its courtyard screenshot has one organizing round pavilion and surrounding facades rather than unrelated small shapes.

These are sourced observations from public screenshots and comments, not first-person playtests or Mike's taste verdict. Screenshots and map content stay outside Git. For blend C, translate the principles into supported structures, pale landable tops, darker sides and restrained orange edges, rather than copying a layout or importing assets.

## Written rules worth carrying over

[Momentum's review checklist](https://docs.momentum-mod.org/guide/map_submission/review_checklist/) asks for room to prestrafe, precise zones and checkpoints at meaningful progress/failure boundaries. Its rough ten-second checkpoint spacing concerns optimized runs, not visual beat frequency. [CS2KZ's mapper guide](https://docs.cs2kz.org/mapping/guide) favors using room volume, integrating supports into the setting and lighting for readability. Its KZ longjump distances describe a different ruleset and are not bhop gap targets. [Momentum's surf guide](https://docs.momentum-mod.org/guide/mapping/create_surf_ramps/) treats ramp scale/steepness as choices to test and explains the separation of visible segmentation from smooth collision. None supplies a universal recipe for an enjoyable course.

## Spillway on the same geometric definitions

Five original r15 courses and Saltglass were built headlessly from source `231b6d28d7e16305b8293457a129ac96714b16b7` using the pinned Godot helper and engine lock. All 64 authored endpoint pairs matched horizontal route-role support geometry. Connected coplanar tops were united and measured with the same polygon-distance and rotated-rectangle definitions. These are **authored support pairs**, not a new recorded F2 traversal; they include height changes and optional lines. One Nightshift pair starts and ends on the same island and is excluded from the comparison, leaving 63 distinct-support pairs out of 64 declarations. Large concave islands can have large bounding sides and short minimum separations far from the intended flight.

| course | pairs used / declared | gap m p10 / median / p90 | median landed support short bounding side m | basic waypoint polyline m |
| --- | ---: | --- | ---: | ---: |
| saltglass | 19/19 | 0.000 / 1.500 / 1.800 | 19.000 | 788.053 |
| breakwater | 6/6 | 2.250 / 3.000 / 6.000 | 9.125 | 340.595 |
| nightshift | 7/8 | 2.000 / 2.500 / 3.000 | 6.000 | 402.388 |
| rainline | 3/3 | 1.720 / 2.200 / 7.240 | 17.700 | 307.963 |
| sunken | 19/19 | 2.000 / 2.491 / 3.915 | 5.022 | 336.059 |
| whiteout | 9/9 | 2.000 / 3.000 / 3.700 | 10.000 | 365.879 |

Spillway's authored pairs generally have smaller minimum separations and broader connected landing islands than these fast CS:S traversals. That is a geometry comparison, not a difficulty ranking. Sunken Court's old per-prism 1.612 m median was dominated by subdivisions; it must not be compared with complete bhop pads. Saltglass's `salt_house` points are 14 m apart, but its unioned support projections touch (0.0 m separation at a 0.1 m step). Nine of 19 Saltglass pairs have zero projected separation across 0.1–0.3 m height steps; these are stepped terraces, not open horizontal gaps. The old 4 m per-piece value is superseded by this consistent union method. The data preserves declarations separately from footprint separation; no geometry was changed to make them agree.

## Surf and rope limits

`surf_kitsune` was read successfully. A sample of 752 visible steep world faces (area ≥4096 u², normal z 0.1–0.7072) has median long horizontal span 508.992 u (12.928 m) and height span 416 u (10.566 m). These are subdivided faces including scenery, not complete ramps or a played surf route; they are not a recommended angle or rope-slot size.

A historical [CS:S Ninja Rope plugin](https://forums.alliedmods.net/showthread.php?t=64149) provides indexed evidence of swinging. No maintained dedicated rope-course pool with a specified comparable force law and readable anchor metadata was established in this bounded search. That does not prove none exists. There is no evidence-based rope length or anchor-spacing prescription here; surf and ordinary bhop dimensions cannot substitute for it.

## Reproduction and confidence

The complete sheet, scripts, raw data and plots are retained at `/home/thatmike1/spillway-r22-run/reference/`. `downloads.json` records URL/size/SHA256 for 23 BSPs; all match the size/SHA1 separately published by the same distributor in [fastdl's index](https://main.fastdl.me/maps_index.html.csv). A bounded Eazy redownload matched the fixed snapshot. These establish reproducibility, not redistribution rights or author authenticity.

[SourceJump's format-12 reader](https://github.com/sourcejump/sourcejump/blob/0333392f70799bae27067d530e4af9b7a5d32efa/api/crates/api/src/replays/header.rs) documents 40 bytes per frame. Every one of 13 downloaded replays passes header/map/frame-count/time checks and reproduces all of its API's 200 sampled route positions. A separate read of render-face edges/planes finds some horizontal visible surface at the recorded height for 1617 of the core sample's 1627 brush-matched contacts. This checks surface existence, not the same support identity or size. The ten remaining contacts have no matching render face and may use invisible collision. Eazy's 188 mover tops additionally match face vertices in both directions within 0.000054 u. These checks cover the stated populations, not every brush or every possible route.

Only this original summary enters the repository. No third-party map, screenshot, layout reconstruction, replay or texture is redistributed. No F2 physics, level, recording identity, comparator or golden data changed.

## Visual reference, wave 2

The private `reference/LOOK-REFERENCE.md` adds 64 primary first-person route views across Epiphany, Fury 2, Tranquility and Interloper, plus eight alternate-height checks. Epiphany and Fury 2 use native full-tick [SourceJump recordings](https://beta.sourcejump.net/runs/4018). Tranquility and Interloper use recorded Bunnyhop.lol position checkpoints and last processed look commands; both recordings' map hashes match our BSPs. All source positions and angles are checked, but those two cameras' stance is inferred from input rather than recorded duck flags. Their four paired eye-height checks per map span 17 u (0.432 m). The pose transport is explicitly derived data, not a reconstructed playable run or new movement evidence.

These are SourceJump's noclip-derived renders, with bloom/fog disabled and device-dependent exposure, rather than native CS:S screenshots. Interloper needs one labelled viewer-only MonitorScreen-to-UnlitGeneric material alias to render its original globe texture brightly instead of black. Its BSP bytes, geometry, lighting and texture remain unchanged; exact native shader equivalence is not claimed. All imagery, recordings, shaders and imported geometry remain private and outside Git.

| Map | Central ray depth p10 / median / p90 (m) | Median saturation | Views with a local focal feature |
| --- | --- | --- | --- |
| Epiphany | 5.1 / 12.7 / 48.1 | 0.286 | 11/16 |
| Fury 2 | 1.9 / 6.3 / 13.9 | 0.410 | 7/16 |
| Tranquility | 3.4 / 7.6 / 19.3 | 0.338 | 9/16 |
| Interloper | 3.3 / 8.1 / 28.7 | 0.273 | 9/16 |

Rays include world displacement terrain, with nine central rays at each sampled camera, capped at 200 m. They omit static model props, moving state, sky and some transparent surfaces, so they remain a sightline proxy. The initial brush-only Epiphany median of 12.8 m refines to 12.7 m with terrain. The focal count is a manual local-cue tally, not a count of unique landmarks or proof of uninterrupted guidance. The samples are rank-one recordings from their respective boards, with fast-runner gaze and different physics implementations.

Epiphany contributes connected concrete masses, overlapping routes, framed thresholds, wall details and broad sky reveals. Water and ship masts are not established by its frames. Fury 2 contributes large repeated frames, fins and a ring tunnel, while its neon palette conflicts with Mike's choice. Tranquility puts a fountain courtyard, facades, an arched entrance and timber bracing around its landings. Interloper uses local globe chains and luminous patches against large stone masses; attractive lighting alone does not prove good guidance. Keep Spillway's pale landing tops, dark weathered sides, restrained orange lips and ink treatment. Directional light does not always make tops brighter than sides.

Individual appearance praise is retained from public pages for [Epiphany](https://gamebanana.com/mods/124957), [Fury 2](https://gamebanana.com/mods/125106), [Tranquility](https://gamebanana.com/mods/126240) and [Interloper](https://gamebanana.com/mods/125285), with post IDs in the private sheet. This is evidence of player reactions, not beauty consensus. Image luminance, saturation, frame-relative edge grids, authored light RGB/direction fields and all sample-level values are retained privately with the frame manifests. Rendering settings, exposure settling after two draws and black regions limit brightness comparisons; no statistic here measures beauty or enjoyment.
