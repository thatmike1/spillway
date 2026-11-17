# Plan Yard

A tidal maintenance basin has two service quays and a central caisson split by an inspection channel.
A travelling steel gantry spans the basin and is the single landmark.
From spawn the player sees the caisson ahead, its higher rear crown beyond the channel, and water corridors on either side.
Before moving, Tab opens a surveyed overhead drawing; three pieces snap to sockets with printed heights, avoiding ambiguous depth picking.
The player chooses a line, closes the drawing and runs it with inherited F2 and fixed Arc, then can restart into the same plan or change it at spawn.

Prototype controls: Tab restarts into planning; click sockets or press 1–9 to toggle anchors; Enter commits the plan and starts at normal spawn. Placement is outside timing. The plan's canonical sorted socket list contributes to geometry identity. No original runner is modified.

The existing launch impulse is in `scripts/r19_line_drive_player.gd` (shelved Line Drive), not in the Movement Lab. It requires real grounded support, 300 u/s aligned entry, adds 160 u/s horizontally and at least 480 u/s vertically, once per pad per attempt. Any plan-pad comparison must be isolated to Plan Yard.

Validation uses the production game host, normal spawn, F2, actual InputEventAction and mouse events. A controller first records a tape; a second run replays it without feedback. These scripted finishes establish reachability only. They cannot establish enjoyment or the absence of a dominant plan.

## Three executed plans

Geometry revision 6 starts at the western service entrance. The caisson has a +7 m front crown, an open 3 m inspection channel and a +9 m rear crown. Anchor elevations are fixed at +11/+14 m; the overhead survey shows that datum. There are no serpentine corner cuts.

| plan | sockets (keys) | clean time | observed line and risk |
| --- | --- | ---: | --- |
| West | 1, 4, 7 | 6.8984375 s | Low swings through the water corridor; a late lift can leave no quay beneath the runner. |
| Diagonal | 2, 5, 9 | 6.609375 s | Clears the caisson and exits toward the east quay; the final lateral swing needs a clean release. |
| Centre | 2, 5, 8 | 6.796875 s | Lands on the +9 m crown; insufficient lift drops into the inspection channel. |

All three finish clean from normal spawn. Each tape opens Tab, removes the default sockets, places its own plan with number keys and commits Enter before moving. Replaying each tape in a fresh production host matches its finish tick, time, position, identity and attached-tick count exactly. The clean spread is 0.2890625 s (about 4.4% of the fastest tape). The diagonal is faster than the visually shorter central line in these executions. These are three input tapes, not a search for globally optimal placements. With a 120 ms delay at each rope release, Centre takes 8.8046875 s, Diagonal 11.71875 s and West fails after 14.75 s. The winner changes from Diagonal to Centre. This controlled input perturbation is evidence of an execution tradeoff, not a claim about every player or every possible plan.

Reproduce with `python3 tests/plan_check.py --out /tmp/r22-14-anchor-plan/NEW-NAME`; `--safe` checks the original safe-quay baseline, `--trial 0|1|2` selects one plan, and `--delay 0.12` adds a delay to rope releases. Outputs must be new directories outside Git. The wrapper uses the pinned engine and shared lock and removes its imported source/profile after reading the result. Runtime fast checks remain `python3 tools/test.py --out /tmp/r22-14-anchor-plan/NEW-FAST-NAME`.

The delayed-release probe returns nonzero when a plan fails; its JSON and tapes are retained so the failure stays visible. The clean default check must pass every plan and exact replay comparison.
