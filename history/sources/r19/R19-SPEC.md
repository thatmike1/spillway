# Spillway R19, an overnight round: Mike's asks first, then playtest-driven tuning, ghost sharing and a surf map.

Context: R18 (a new UI from a Claude design agent: cream-and-ink sheets, a title card, telemetry behind F9) is delivered and pushed. feat/foldrunner-me-build and feat/spillway-ui are both at 640d06e65. Mike played R18 tonight, had fun, and is asleep. Nobody is around until morning, so make every call yourself, log it in look/decisions.tsv, and keep going.

Where:
- Repo ccChat-general, project projects/foldrunner. Work in your worktree /home/thatmike1/foldrunner-build-2026-11-05/look/wt. First fast-forward it to origin/feat/foldrunner-me-build on a new branch feat/spillway-r19.
- Read the R18 delivery first: /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r18/ and projects/foldrunner/look/ui-r18/index.html.
- Never push or merge main.
- Disk: /home is at about 13 GB free. Get it back above 15 GB before building, and keep it there. You may remove the finished R18 packaging worktree ~/foldrunner-r18-wt with `git worktree remove`, since it is pushed at 640d06e65. You may also prune your own intermediate evidence that RESULTS files don't reference. Do not delete other rounds' deliveries.

Work in this order and ship whatever is done. Each item is its own commit.

1. Mike's four planned asks.
   a. A big style bonus for bhopping backwards. While sustained bhops carry real speed and the horizontal velocity points against the view direction, award a growing multiplier with a clear callout in the R18 HUD style. Give sideways (half-sideways) a smaller version. It must be hard to farm by standing still or by tiny speed.
   b. Rename the stale map subtitles that still say "R14 map" or "R13/R14 dam course" to player-facing descriptions.
   c. Move the R13 mouse sliders into an Advanced section of the pause menu.
   d. Put the "Look C · L" label behind F9. L still works.

2. Playtest-driven map tuning from Mike's real runs.
   - Tonight's recordings are in /home/thatmike1/foldrunner-build-2026-11-05/playtest-r18/userdata-spillway/r16_runs/: 32 runs across breakwater, rainline, whiteout-relay, sunken-court, night-shift and experiment, all on F2 (server128). His settings and other user data are beside them. Read them with the project's run reader.
   - Write playtest-r18/ANALYSIS.md covering, per map: where he loses speed, stalls, respawns or quits; which style events fire; which lines he took; and what he played most and restarted most.
   - Then make small, listed fixes where the data shows the map fighting the movement: snags, awkward heights, gaps that kill flow, unreadable edges. Mike likes emergent skips and dislikes coded hidden paths, so never remove a skip he found and never add a secret route.
   - Ghosts recorded on geometry you change must be labelled as from an older map version, never silently replayed into a wall.

3. Ghost sharing, so Mike can race a friend (Jindra, on Windows).
   - Export a best run as one file.
   - Import by dropping files into a visible ghosts folder; add a pause-menu button that opens that folder.
   - The ghost menu lists imported runs with the player name and time.
   - Choose one ghost to race. It must work across Windows and Linux builds of the same version, and a ghost file from another version or map revision must show a clear note instead of breaking.

4. One new map built around bhop plus surf (Mike loves CS surf).
   - Source-style surf ramps steeper than walkable, sitting in the existing Source movement code without changing F2 physics. Check that surf actually works under the current movement code before building the whole map.
   - Look C, a 40 to 70 s route at F2, with an emergent-skip-friendly layout and style events that fit it.
   - If surf does not work on the faithful movement, ship a bhop-only map and write down why.

5. Experiments wing (Mike asked for this after the goal started: "a bunch of experiments, more ambitious, outside Movement Lab, maybe their own map"). After items 1 to 4, spend the rest of the night on ambitious experiments. Each one gets its own small map, listed in the Esc menu under an Experiments section and clearly tagged experimental. Pick 3 to 5 that could make Spillway more fun, and push each far enough to be playable and judged, not a stub. Candidate directions, your pick:
   - a grapple course;
   - a skatepark-like style arena built for chaining tricks;
   - launch pads or boosters that reward a good line;
   - wallrun surfaces;
   - a time-attack with moving or collapsing platforms;
   - a race against a bot ghost;
   - anything better you think of.
   Mechanics stay inside their experiment map and never change F2 on the main maps. No anime or story layer, no neon, no chevrons. List each one in RESULTS-R19.md with a one-line pitch, how to reach it, and your honest read of whether it is fun.

Constraints:
- F2 (Bhop server, AA 100, 128 Hz) movement physics stay exactly as they are. Parity on existing maps holds except where item 2 deliberately changed geometry, and those changes are listed.
- The R18 UI language stays. New UI follows it.
- GPT only tonight: you may start gpt-6.1-sol or gpt-6.1-terra children; start no Claude agents.
- Run the project's suites (parity, visual invariants, release probe) and fix what fails.

Done when the finished items pass their checks and the following exist:
- verified Linux and Windows ZIPs with SHA256SUMS in /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r19/;
- look/RESULTS-R19.md: what Mike should try first, what changed per item, which items were not reached, and the 3 to 5 taste calls he should make;
- feat/spillway-r19 pushed, and feat/foldrunner-me-build fast-forwarded to it.

Commit subjects end with (ccChat-general-nrbo). Ground every claim in a file read or a command run, and label guesses as guesses. Final report in four parts: what changed, does it work, what Mike decides, where.
