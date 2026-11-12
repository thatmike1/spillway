# Spillway R21: Mike's R20 playtest

Mike played R20 this morning. Saltglass is fun but feels empty. Breakwater has a moment he loves. Elastic is the grapple model he likes best. He hasn't really tried Through Line yet. His 33 recordings from this session are in /home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/userdata-spillway/r16_runs/: 14 breakwater, 2 saltglass, 16 tether-yard and 1 through-line. Read them with the project's strict reader, and write playtest-r20/ANALYSIS.md first, in the same form as playtest-r19/ANALYSIS.md.

Where: repo ccChat-general, projects/foldrunner, in /home/thatmike1/foldrunner-build-2026-11-05/look/wt. Make a new branch feat/spillway-r21 from origin/feat/foldrunner-me-build (e6baa995d). Never touch main. Keep at least 15 GB free on laptop /home (about 15 GB now), and prune your own intermediate evidence first. Do not copy anything to the desktop; the parent session does that.

Work in this order. One commit per item.

1. **Saltglass: keep the speed, then fill the map.**
   a. Lower the exit platforms after the surf ramp. Mike builds about 1000 u/s on the ramp, and he has to swing up to the platforms, which leaves him at about 500. Losing that much speed is no disaster, but it slows the run down. Lower the platforms and move them further apart, so the speed he built carries into distance between them instead of being spent on climbing. Check his two saltglass runs for the exit speeds and heights.
   b. Spice up the map. It "feels a bit empty". Add features that ask for skill and reward a good line, in the spirit of item 2 below: obstacles that invite a hard outside line, a choice between a safe line and a fast one, and enough set dressing that the space reads as a place. Keep R20's rules: no free skip, high fin entries, flat landings, no safety net. Keep the run at 40 to 70 s at F2.

2. **The Breakwater outside line, as a pattern.** Right after the first few hops on Breakwater there are containers on the left and on the right. Mike loves bhopping around a container on its outside, on the right side. It is hard to land in the right spot to take off from a position where you can strafe around it, and that difficulty is what makes it exciting. At least one of his 14 breakwater runs should show it. Find that run and describe the line.
   - Breakwater itself stays unchanged.
   - Use this pattern deliberately in Saltglass (item 1b) and anywhere else it fits.
   - He asked whether it gives style points. Check, and tell him. If a generic, location-free reward fits the existing style rules (for example, a close airborne pass around solid geometry at speed), propose it with numbers from his runs, and implement it only if it can't be farmed. No hand-placed bonuses at specific spots: Mike likes emergent lines and dislikes coded hidden paths.

3. **Grapple: research first, then build on Elastic.** Elastic feels closest to what Mike imagines a good grapple feels like, but it still needs tuning, and he can't say why it feels better: the reel, the ratio, something else. Two problems:
   - At speed, after the second platform, the anchor is hard to catch. He has to keep the tether point in view and aim at it while coming in fast.
   - He sometimes clips a platform, possibly because something is too close.

   Steps:
   a. Research how grapples work in games: the physics model (rope constraint, spring, pull-to-point, hybrids), how they handle reel, release and momentum, and how they help with aiming and target acquisition. Use public sources (developer talks and posts, wikis, open-source mods and engines) and cite each one. Write look/GRAPPLE-RESEARCH.md with a short comparison and what it implies for Spillway. Study mechanics only; do not recreate any specific game.
   b. From his tether-yard runs, measure what Elastic does differently from Classic and Pendulum, so that what feels better is described in numbers.
   c. Make attaching at speed forgiving: a generous acquisition cone or magnetism toward anchors in view, and a clear readout of which anchor will be grabbed before he presses. Find the platform clips in his runs and fix their cause (geometry clearance or rope behaviour).
   d. Build two or three tuned Elastic variants beside the R20 Elastic, selectable in the pause sheet like today, each with a one-line note on what it changes. Keep Classic, Pendulum and the mouse controls as they are.

4. **Leave the rest alone.** Through Line stays exactly as it is; Mike will test it later. The backwards stack "seems about right", so keep its rules and only fix real bugs his runs show.

Constraints:
- F2 physics and the original eight maps stay exactly as they are; parity holds.
- The R18 UI language stays.
- GPT only: you may start gpt-6.1-sol or gpt-6.1-terra children, no Claude agents.
- Run the project's suites and fix what fails.

Done when:
- verified Linux and Windows ZIPs with SHA256SUMS are in /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r21/;
- look/RESULTS-R21.md exists, with what to try first, a per-item change list, items not reached, and three to five taste calls;
- look/GRAPPLE-RESEARCH.md exists;
- feat/spillway-r21 is pushed, and feat/foldrunner-me-build is fast-forwarded to it.

Commit subjects end with (ccChat-general-epsz). Ground every claim in a file you read or a command you ran, and label guesses as guesses. Check the result against the done condition and fix what fails before you report. Final report in four parts: what changed, does it work, what Mike decides, where.
