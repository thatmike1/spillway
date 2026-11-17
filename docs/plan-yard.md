# Plan Yard

A tidal maintenance basin has two service quays and a solid central caisson.
A travelling steel gantry spans the basin and is the single landmark.
From spawn the player sees the pale finish pier beyond the caisson, with water corridors on either side.
Before moving, Tab opens a surveyed overhead drawing; three pieces snap to sockets with printed heights, avoiding ambiguous depth picking.
The player chooses a line, closes the drawing and runs it with inherited F2 and fixed Arc, then can restart into the same plan or change it at spawn.

Prototype controls: Tab restarts into planning; click sockets to toggle anchors; Enter commits the plan and starts at normal spawn. Placement is outside timing. The plan's canonical sorted socket list contributes to geometry identity. No original runner is modified.

The existing launch impulse is in `scripts/r19_line_drive_player.gd` (shelved Line Drive), not in the Movement Lab. It requires real grounded support, 300 u/s aligned entry, adds 160 u/s horizontally and at least 480 u/s vertically, once per pad per attempt. Any plan-pad comparison must be isolated to Plan Yard.

Validation uses the production game host, normal spawn, F2, actual InputEventAction and mouse events. A controller first records a tape; a second run replays it without feedback. These scripted finishes establish reachability only. They cannot establish enjoyment or the absence of a dominant plan.
