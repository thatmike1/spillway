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

| plan / keys | clean | releases +120 ms | upward look limited to 30° | risk |
| --- | ---: | ---: | ---: | --- |
| West / A1 A4 A7 | 6.898 s | fails at 14.750 s | 6.898 s | Low swings need timely lift over water. |
| Diagonal / A2 A5 A9 | 6.609 s | 11.719 s | fails at 3.156 s | Crosses the caisson and exits sideways toward the east quay. |
| Centre / A2 A5 A8 | 6.797 s | 8.805 s | fails at 3.156 s | Needs height over the inspection channel and rear crown. |

All three finish clean from normal spawn. Each tape opens Tab, removes the default sockets, places its own plan with number keys and commits Enter before moving. Replaying each tape in a fresh production host matches its finish tick, time, position, identity and attached-tick count exactly. The clean spread is 0.2890625 s (about 4.4% of the fastest tape). The diagonal is faster than the visually shorter central line in these executions. These are three input tapes, not a search for globally optimal placements. With a 120 ms delay at each rope release, Centre takes 8.8046875 s, Diagonal 11.71875 s and West fails after 14.75 s. The winner changes from Diagonal to Centre. A separate 30° upward-look limit leaves West unchanged while both high-start plans fail. Each plan therefore leads one of these three tested input conditions. A stricter 26° limit made every plan fail; a 35° limit changed none of them. This controlled input perturbation is evidence of an execution tradeoff, not a claim about every player or every possible plan.

Reproduce with `python3 tests/plan_check.py --out /tmp/r22-14-anchor-plan/NEW-NAME`; `--safe` checks the original safe-quay baseline, `--trial 0|1|2` selects one plan, and `--delay 0.12` adds a delay to rope releases. Outputs must be new directories outside Git. The wrapper uses the pinned engine and shared lock and removes its imported source/profile after reading the result. Runtime fast checks remain `python3 tools/test.py --out /tmp/r22-14-anchor-plan/NEW-FAST-NAME`.

The delayed-release probe returns nonzero when a plan fails; its JSON and tapes are retained so the failure stays visible. The clean default check must pass every plan and exact replay comparison.

## Optional pieces

A selects anchors. B enables and selects the rising block; P enables and selects the launch pad. Shift+B and Shift+P disable those options and remove their piece. They are off by default. F8 switches between one and three pieces; Delete clears the plan. Every piece costs one, with one block and one pad maximum. Brushing a zone again removes that piece. Unsupported zones and full budgets explain the recovery without changing the plan.

The centre block is a supported +8 m lift before the inspection channel. The side lifts are +3 m landing platforms. Pads snap to real quays/crowns and fire only when the actual grounded hull has walkable pad contact, carrying at least 300 u/s toward the far quay. They reuse the unchanged Line Drive response and fire once per attempt. Merely crossing their drawn bounds does not launch.

| loadout | keys | time | observed use |
| --- | --- | ---: | --- |
| One anchor | A4, budget 1 | 7.9609375 s | 292 attached ticks; quay line. |
| Three anchors | A1 A4 A7 | 6.8984375 s | 467 attached ticks; water line. |
| Two anchors + block | A2 A5 B5 | 8.796875 s | 88 supported physics ticks on the lift, followed by the higher-crown jump. |
| Two anchors + pad | A2 A5 P8 | 6.3359375 s | One real pad launch at tick 702, 510.1013 to 670.1013 u/s along the quay and 480 u/s upward before the inherited gravity step. |

Each retained tape finishes clean and replays exactly. The one/three comparison includes a different line and technique, not a causal speed multiplier per anchor. The block is the weakest option in these examples: it is slower, needs another deliberate landing/jump, and an earlier test finished without touching it. That earlier tape was rejected as proof of block use. The retained block tape proves operation, not necessity or enjoyment. Inventory limits and enabled-but-unused options do not split the identity of an otherwise identical physical plan.

Run `python3 tests/plan_check.py --out /tmp/r22-14-anchor-plan/NEW-PIECES-NAME --loadout pieces` to check all three optional loadouts through one imported snapshot. The suite fails if the block is never stood on, the pad never fires, a run fails or replay differs. Geometry, height, invalid equipment/budget, planner timing and recording-boundary checks precede the tapes.

## Saved plans and ghost plans

The survey has three local slots. Brackets select a slot, F6 saves the current pieces and settings, and F7 loads it without starting the clock. Mouse targets perform the same actions. A loaded plan still needs Enter to run. Empty, oversized or invalid saves leave the current plan alone; checked atomic writes reuse the project's profile backend and keep a previous good backup. The save is `user://plan-yard-plans.cfg`, independent of run recordings.

A matching best ghost supplies its physical plan from the recording's `header.metadata.physics.mechanics` entry `plan-yard-design`. The survey outlines those pieces in blue and says whether the pending plan matches. After Enter commits a changed physical plan, the existing course/geometry identity selects that plan's own best; it never compares different plans as one course. Inspecting the ghost plan only reads the recording. Budget and unused settings remain editable without creating different identities for identical placed equipment.

`python3 tests/plan_check.py --out /tmp/r22-14-anchor-plan/NEW-SAVE-NAME --persistence` additionally drives save/load keys, records a complete clean production run, checks recipe display and different-plan rejection, verifies the recording SHA remains unchanged, then reads the saved plans and matching ghost in a fresh process.

## Native look passes

The yard reuses the original project's licensed painted sky, deterministic wear texture, surface/water shaders and structural contour generator (`assets/look/PROVENANCE.md`). These are presentation only; the physical plan hash and colliders stay unchanged. Pass 1 adds the gantry's far-quay sign and verifies the normal centre tape natively at 6.80 s with no respawns. Its fresh image review found weak landing-edge/finish-threshold cues, an unsupported-looking sign and flat-looking materials; these remain work for the next pass. Native capture exit reports ObjectDB leaks (10 instances in this pass); no script error or explanation of that warning is claimed.

Pass 2 adds exposed-water rims, a wider finish stripe and floor word, sign hangers and rail connections. The native West tape finishes 6.90 s without respawns; the fast gate passes. A second fresh reviewer still finds weak high-landing reads, flat concrete, repeating water and bulky/protruding gantry connections. Pass 3 targets those existing surfaces and fixtures. Exit warnings are now 12 ObjectDB instances; the count tracks added world labels, but that is a correlation, not a diagnosis.
