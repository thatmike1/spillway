# Spillway R20: Mike's R19 playtest

Mike played R19 this morning. Saltglass is fun and Tether Yard is "actually quite fun". Line Drive and Fall Line didn't land. His 58 recordings from this session are in /home/thatmike1/foldrunner-build-2026-11-05/playtest-r19/userdata-spillway/r16_runs/ (34 saltglass, 12 tether-yard, 8 line-drive, 3 fall-line, 1 breakwater). Read them with the project's strict reader and use them as evidence for every item below. Write playtest-r19/ANALYSIS.md first, in the same form as playtest-r18/ANALYSIS.md.

Where: repo ccChat-general, projects/foldrunner, in /home/thatmike1/foldrunner-build-2026-11-05/look/wt. Make a new branch feat/spillway-r20 from origin/feat/foldrunner-me-build (065f7b279). Never touch main. Keep at least 15 GB free on /home (about 15 GB now). Prune your own intermediate evidence first.

Work in this order. One commit per item.

1. **Saltglass rework.**
   a. The skip is too obvious. Turning around at the start finishes the course; the game flags the skipped checkpoint, but it is still the obvious shortcut. Mike likes emergent skips, earned by skill, and dislikes freebies. Make that skip demanding (a real speed or line requirement), or remove it if it can't be made earned. Use his recordings to see exactly how he did it.
   b. Surf entries are too low. He drops in at about half the ramp's height, so he can't carry enough speed to fling off a fin. Leaving a fin early and bhopping up the recovery is faster than surfing it, which is backwards. Rebuild so each fin is entered from near its top: the connector between fins (the "crescent" of platforms) climbs instead of descending, so the second fin also starts high. Surfing a fin well must clearly beat bailing out.
   c. Landings after a fin are flat decks, not another inclined surface.
   d. Remove the safety platforms under the surf ramps. Failing a surf means you fall and respawn at the last checkpoint.
   e. Keep 40 to 70 s at F2. F2 physics unchanged.

2. **Backwards bonus stacks with chain length.** Mike earns it once, then not again (check his recordings: is that a bug, or a re-arm rule too strict?). He wants a reward that keeps growing the longer an unbroken backwards bhop chain lasts. A few backwards hops on a straight are easy, but long blind backwards chains are hard and should pay a lot. Make it a running stack shown live in the HUD that banks when the chain ends and is lost on a stall. Not a flat multiplier. Same anti-farm rules as R19. Re-tune sideways the same way, smaller.

3. **Tether Yard: grapple on the mouse.** E takes his fingers off A and D.
   - Hold left mouse to stay attached (swing). Hold right mouse to reel in while attached.
   - Holding both reproduces today's E behaviour exactly.
   - Add a setting in the pause menu: "reel on right mouse" versus "reel automatically while attached".
   - Detach must be predictable: release the button and you let go. Any automatic detach (minimum distance, line of sight) gets a visible and audible cue and a documented rule. Today it seems random to him.
   - Reel from the ground pulls him under the anchor but doesn't lift him until he jumps. Keep that, but document it.
   - Then add 2 or 3 alternative grapple models on a key or menu toggle inside Tether Yard, without breaking the current one: for example a fixed-length pendulum rope, an elastic rope, and a pull-to-point zip, each with a one-line note. Tether Yard stays in Experiments.

4. **Shelve Line Drive and Fall Line.** Remove both from the Experiments menu and keep their code. Write SHELVED.md with Mike's reasons:
   - Line Drive's pads are flat lines with no feedback, the landing spot is unclear, and his own built speed beat them.
   - Fall Line has no sound or visual on contact or on the drop. Its 2 s timer is far too long at bhop speed: he hopped two or three times on a block and it never fell under him. If revived, it needs a theme that explains the collapse (lily pads on water, scaffolding).

5. **Momentum launch into the next level** (Mike: "a super cool idea"). Build a launch pad or gate that throws you high upward while keeping your horizontal speed: speed you built becomes height and distance.
   - It needs strong feedback: a readable shape, not a flat line, plus a sound, a screen cue and a visible trajectory hint.
   - Use it for a seamless level transition: at the end of a map you hit the launcher, fly, and land in the next map's start without a loading screen or menu, carrying your speed.
   - Prototype it as a chain of two existing maps or two small new segments in an Experiments entry called "Through Line". Keep it inside Experiments, and leave the main maps' finishes alone.
   - Report honestly whether the transition feels seamless.

6. **Collecting runs from friends.** Every attempt is already recorded, including restarts and quits. Friends' runs stay on their own machines.
   - Add a pause-menu button "Export my runs" that packs every local recording plus settings into one zip with a clear name, and opens its folder so a friend can send it to Mike.
   - Add a tools/ script that ingests such zips into a per-player folder and runs the analysis on them.
   - Nothing uploads automatically.
   - Name the Windows path of the recordings folder in the player README.

Constraints:
- F2 physics and the original eight maps stay exactly as they are; parity holds.
- The R18 UI language stays.
- GPT only: you may start gpt-6.1-sol or gpt-6.1-terra children, no Claude agents.
- Run the project's suites and fix what fails.

Done when the reached items pass their checks and the following exist:
- verified Linux and Windows ZIPs with SHA256SUMS in /home/thatmike1/foldrunner-build-2026-11-05/delivery/spillway-r20/;
- look/RESULTS-R20.md: try-first, a per-item change list, items not reached, and 3 to 5 taste calls;
- feat/spillway-r20 pushed, and feat/foldrunner-me-build fast-forwarded to it.

Commit subjects end with (ccChat-general-epsz). Ground every claim in a file read or a command run, and label guesses as guesses. Final report in four parts: what changed, does it work, what Mike decides, where.
