# Outer Reach

Outer Reach is the outer pump channel beside Sluice Six's estuary works. A transverse tidal-pump portal is its landmark. From the acceleration quay the player sees broad receivers separated by long water gaps, with open sea to the left and the modeled shore to the right. Real cap beams and piles support every receiver. Warm side light, cool water, pale tops and restrained orange lips share the established material language.

## Original F2 route

The 65 m quay gives room to earn speed from rest. Seven 12×4 m receiver decks lead to the pump court. Eight authored gaps measure 9.5, 11.1, 12.1, 12.7, 13.9, 14.7, 15.3 and 16 m. Compared with Sluice Six's fifteen shorter gaps, this is a continuous long-strafe reach with fewer receivers and greater required speed. F2 movement is unchanged.

Lane 12's 98sync sample informed the pattern: its recorded high-speed run had a 15.443 m median flat gap, 4.064 m median landing short side and about 1159 u/s mean horizontal flight speed. That run uses different server settings and is not an F2 distance prescription. Our positions come from separately labelled legal-F2 air-arc measurements and are original, not copied from a map. Two early script trials failed: one hopped before earning running speed; another spent too long grounded before the first gap. Seven receiver windows were then measured around sustained legal F2 air arcs. Those failures diagnose the trial helpers, not universal reachability limits. No velocity is granted and gravity is unchanged.

There is one continuous lap. Water retries return to the acceleration quay; no cold mid-course checkpoint pretends to supply the speed needed for the next long gap. The pump court is the terminal checkpoint. Route hints use physical progress along the channel.

## Proof boundary

`tests/outer_reach_tape.gd` earns speed using forward inputs on the initial run-up, then releases W airborne and uses paired air arcs. Above 12 m/s each steering side lasts 16 ticks rather than alternating every tick. It exports raw action/mouse events at sensitivity 2.5/FOV 90, the map/geometry identity, landing positions, peak speed and normal-spawn result. It never seeds velocity or resets during a lap.

Its `--calibrate` mode is explicitly labelled and uses a separate floor/geometry identity. It is not accepted as a course finish. `tests/outer_reach_replay.gd` rejects calibration data and replays only retained real-course events, without choosing takeoffs or correcting yaw. Native host capture and the full visual bar remain required before delivery; their actual results belong in the external lane report.

All new geometry/material code is original. The sky/font reuse the existing manifests. Private concepts and community maps remain outside the repository.

The supported shore control house, causeway, terminal service gate and gallery sit outside the receiver corridor. Their solid parts and the pump portal’s piers and crossmembers use real non-progress collision. Low quay curbs frame the acceleration deck while leaving the centre open. The normal input line and all receiver footprints are unchanged.

`tests/outer_reach_host.gd` replays the retained input program in the real host. Its separate fault probe drops the runner below water after an early receiver landing, verifies a quay retry and quay practice, then restarts from spawn for an unmodified clean replay. Support progress metadata uses checkpoint indices, independently of the route’s physical section labels. Calibration output uses `calibration_complete`, with `finished=false`, and cannot count as a course finish.
