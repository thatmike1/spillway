# Foldrunner: Spillway

**Build one finished, satisfying parkour level: carry downhill speed through a sunlit dam complex.** Run, jump, slide, recover a near miss, choose a better line and go again. The level is a place with a purpose, not a row of movement demonstrations.

This is the current design contract. Mike played the Linux build and rejected its feel. It supersedes the Mirror's Edge reconstruction targets in BRIEF, FEEL-BRIEF, FEEL-CONTRACT, FEEL-CHECKLIST and the old runtime contract. Recovered numbers, all-moves coverage, source camera tracks, folding buildings, gravity turns, runner vision and the city are no longer requirements. Existing results remain historical evidence. Keep original/private game material out of Git, retain useful infrastructure and preserve honest collision.

The clean, pushed runtime baseline is `86bb26c754424f9cb0c36b5c5fff5f6a8fc94874`, branch `feat/foldrunner-me-build`. The source is in `projects/foldrunner`; the working checkout for this run is `/home/thatmike1/foldrunner-build-2026-11-05/wt`. [COUNCIL.md](COUNCIL.md) records Sol's proposal, Opus's challenge and the lead's decisions. The council inspected code and existing frames; nobody claims to have played a new build yet.

## The game

Keep Godot 4.7.2. Replace the controller's control policy rather than retuning fourteen inherited states. Build **Spillway**, a 1950s dam and sluice complex on a hillside, in clear late-morning light. The player starts at the crest and descends to a pump tower, carrying speed from dry chutes into jumps and shortcuts. Safe paths and shallow channels keep a mistake in play. Replays improve a chosen line and three personal-best splits.

One finished level is the scope for this evening. No second level, ghost, combat, collection system, folding spectacle or engine migration. A serious reproducible engine limitation can reopen the engine choice; preference alone cannot justify losing the working native pipeline. Enjoy the experiment and make strong creative choices inside this direction.

## Movement that belongs to the player

One velocity-based motor owns collision. Keep input, collision, presentation and run state distinct. Reuse proven helpers selectively; do not retain hidden legacy behavior just to satisfy old tests.

- **WASD runs immediately.** Useful speed arrives promptly. Releasing or reversing brakes predictably. There is no multi-second sprint unlock. Initial game choices: about 8.5 m/s and 0.35 s to running speed.
- **Space jumps reliably.** Coyote time around 100 ms and buffering around 120 ms are always on. An ordinary landing preserves horizontal speed. Start around 1.3 m jump height with a brisk fall. No normal landing, roll or hard-landing clip may freeze controls.
- **Air input corrects a landing.** Keep directional inertia, but make correction visible. Looking alone never changes airborne velocity. A standing jump must still permit correction: its air-speed budget cannot be capped at zero. Preserve excess launch speed without unlimited air pumping.
- **Crouch lowers; crouch at speed slides.** Sliding has clearance, steering and friction consequences. Downhill gravity supplies extra speed; jumping and releasing slide preserve it. Repeated crouch presses on flat ground must not manufacture speed. Start with low flat friction, steering near 90°/s and a generous speed cap around 16 m/s. Extra speed decays smoothly on ordinary ground rather than snapping to run speed. Jump interrupts a slide. Stand only when there is clearance.
- **An airborne mantle forgives a near miss.** It requires forward and held jump intent, a reachable lip and clear landing volume. It never starts from grounded forward movement alone. Keep it brief, swept and cancellable; retain free look and useful outgoing motion. The safe route never requires it. If it still steals control, simplify or cut it before expanding the course.

Releasing jump or pressing backward cancels a mantle promptly into collision-resolved airborne motion with applicable momentum and free look. The same held input cannot immediately retrigger a catch. Test a catch, cancellation and a nearby jump that intentionally avoids catching.
- **Mouse look is always live.** No state throws away yaw or pitch. Keep the horizon stable, landing compression small and straight down, with no forced pitch. Start near 90° horizontal FOV, with a restrained speed expansion. Comfort settings remain useful; jump forgiveness is fundamental behavior.

Delete automatic vaults, wall runs, wall climbs, hang/pull-up chains, rolls, springboards, scripted Q turns and step-up clips from the active game. Ordinary curbs are collision accommodation. Keep the old city and yard available only as developer fixtures if useful, outside the normal game flow.

All new values are **P / game choices** and tuning hypotheses. Change them when evidence warrants it and record why. They are not a second immutable reconstruction spec.

## Stairs and recovery

Stair meshes have **no player collision**. One continuous ramp carries the body, joined cleanly to its landings. A ramp beneath active step colliders does not solve the problem. Test ascent, descent, slow movement and diagonal crossings. Measure camera jitter relative to the expected slope, not absolute vertical movement, which naturally rises during ascent.

Shallow channels have a real floor, slow the player and lead to obvious exit ramps. They are recovery routes, not reset triggers. Deep water and genuine out-of-bounds falls return to the current segment quickly. A missed shortcut usually costs distance instead of a whole run. Respawns, practice restarts and full attempts must be distinguishable in traces and results.

## The authored route

The whole place descends toward a recognizable pump tower and its large wheel. Show the destination and landing surface before commitment. Obstacles are working parts of the dam: channels, gates, pipe supports, housings and maintenance access. No floating boxes, metre grids, station labels, chevron trails or constant floor stripes.

1. **Crest.** The first view shows the tower and the route below. A broad switchback stair/ramp is safe. A dry sloping chute is fast: slide down it, jump a channel, reach the first terrace carrying extra speed. A miss lands in shallow water with a ramp back to that terrace.
2. **Sluice yard and filter house.** A wide path winds between valve housings. A faster line slides beneath a half-open gate and changes the approach to the next jump. Optional pipe-supported maintenance platforms offer a narrower line if the main routes are already finished. Low housings provide optional mantle access to the filter-house roof; a ramp always reaches it too. The roof supplies height for the finale.
3. **Outflow.** A railed gantry is safe. Diagonal jumps across sluice supports form the fast line, using a downhill run-up to reach the tower's open loading platform. A basin-edge walkway catches misses and rejoins. The wheel starts at the finish and three splits show where time was gained or lost. Flooding the chutes at the finish is optional polish.

Aim for a compact first clear near a minute and a substantially faster skilled route, not a mandatory completion-time target. Geometry, spacing and clearances are authored against the actual new motor, not copied coordinates. Each segment must offer a consequential choice in speed, approach or risk. Avoid three visually dressed versions of the same jump lane.

R restarts the run immediately. F restarts the current segment for practice; a practice-assisted finish never overwrites a clean full-run best. The timer stays quiet during the first attempt. Finish and replay are immediate, understandable and non-modal.

Segment restarts and checkpoint respawns invalidate clean full-run eligibility until R starts a fresh attempt. Clean records require ordered segment passage within that attempt. Practice splits, if stored, are separate and labelled; they cannot replace clean records. Shallow-water recovery without a reset remains a legitimate slower line.

## A visual identity the game can deliver

Use pale board-formed concrete, blue-green water, terracotta valve housings, ochre safety paint and dark steel. Concrete has restrained seams, stains and a moss/wet band at the waterline. Gate supports, grates, pipes and railings give foreground parallax and a human scale. Warm sun models forms; cool sky light keeps traversal surfaces readable in shade. Use depth layers and the tower silhouette, not darkness, to make the view dramatic.

Create a compact coherent material set: world-projected concrete, moving water/foam, and distinct metal/paint. Procedural geometry is sufficient if its supports, silhouettes, corners and surface scale are authored. No external mesh kit is required. If sound or texture assets are adopted, use legitimate sources and retain their licences and provenance. No downloaded assets have been selected by the council.

Do not spend the first pass repairing the old procedural hands. Hide distracting running arms. Mantle contact hands, if shown, stay peripheral and match geometry. Bodies never cover the landing view. Sound provides surface-specific footfalls, slide scrape, impact weight, speed wind and a spatial water roar. These should communicate motion instead of adding constant noise.

Keep Compatibility until a bounded comparison in the new slice demonstrates that Forward+ improves native frames without breaking launch, capture or measured frame pacing. Renderer exploration cannot block the controller or become a migration project. Record which renderer/hardware produced performance claims; software rendering on the agent host is not Mike's desktop benchmark.

## Build the risky slice first

The first playable is **Crest**, with representative final materials and lighting: spawn view, chute, jump, switchback stairs, shallow-water recovery and a terrace finish. Include a small mantle fixture here so its control/collision policy can be challenged before it appears later in the route. Do not expand into segment two on the strength of isolated unit tests.

The terrace must offer a consequential exit choice before the slice finish: a forgiving turning path and a tighter line approached differently with carried speed. Show the player steering, braking or abandoning that line. A chute followed by one jump and an immediate finish does not test the premise.

Capture uninterrupted player-view runs at normal playback speed along safe, fast and missed-jump recovery lines. Use actual input events. Route proof never writes player position or velocity except documented spawn/reset. A precise waypoint bot establishes one executable line, not discoverability or enjoyment.

Challenge the slice with early/late jump presses, off-centre and oblique approaches, crouch release under a ceiling, repeated crouch input on flat ground, standing-jump correction, mantle cancellation and looking away during movement. Check stair motion at the real ramp seams. Repeat with controlled timing/aim perturbations and record seeds, failure locations and denominator. Do not tune a bot alone until it hides fragile geometry.

Initial diagnostic hypotheses: chute speed clearly above run speed (around 40%), a meaningfully faster shortcut (around 25%), reliable safe-route completion under small timing/aim variation, and visible landing surfaces in ordinary forward-looking jump frames. These help find failures; none is proof of fun. After two unproductive passes, change the geometry or control policy instead of multiplying tuning variants. If mantle keeps interrupting, remove it and revise the housings.

If checks pass but playback is still empty or confusing, fix composition and activity before adding props. Review the weakest approach, airborne and recovery frames: route contrast, landmark placement, foreground parallax and visible next decisions. A bright corridor with no route choices still fails the design.

## Finish and prove the game

After the slice is coherent, finish Sluice yard and Outflow. Complete recovery, segment practice, finish, clean-run personal bests, audio, performance and native packaging. Cut finish flooding, the optional pipe line, elaborate hands and extra sound variants before cutting collision, responsive input, readable lighting or recovery.

Retire tests whose acceptance is obsolete source fidelity or every-move coverage. Preserve and adapt useful collision, input, persistence and restart checks. Add only tests that catch meaningful new failures. Record the distinction in the same implementation change; do not quietly weaken the old test wrapper to print success.

Done requires:

- the default native launch enters finished Spillway with the new controller, not the metric yard;
- safe and faster routes through all three segments, useful recovery, finish and replay, with representative uninterrupted rendered evidence;
- smooth stair collision, reliable jump grace, free look, continuous ordinary landings/slide release, and no flat-ground slide pumping;
- deliberate material, lighting, sound and composition passes across the whole route, not only the spawn screenshot;
- checks and clean launch using the delivered files, Linux play instructions, Windows delivery/instructions, a build identity that avoids stale-launch confusion, and explicit limits if native Windows execution is unavailable;
- coherent step commits pushed to `feat/foldrunner-me-build`, plus REPORT.md and a concise reboot checkpoint linking evidence, failures fixed and remaining uncertainty.

No automated count, council score or bot finish may be reported as proof that Mike will enjoy it. Do not stop at passing numbers: use normal-speed playback and fresh critiques to find what still looks awkward. Do not request a human review during the run. Human enjoyment and comfort remain unverified until he plays.

## The unattended run

Mike authorizes autonomous decisions and a sustained build run until at least **20:00 Europe/Prague, 2026-11-05**. Do not end early just because the first checks pass. Use remaining effort to improve the actual playable result; do not fill time with paperwork. Near the evening target protect a coherent playable delivery, then complete required fixes and report honestly. Never mark an unfinished goal complete.

Use GPT execution freely and at most one Opus 5.5 consultation per hour on the most consequential current code or rendered artifact. This planning consultation began around 16:42 CET; the next must start no earlier than **17:45 CET**. Later slots should inspect the first slice, the complete route and final weak spots as artifacts become available. They are opportunities for real code/design help, not a score ritual. If a provider fails, disclose it and continue independent authorized work without claiming its review.

Keep a concise decision/evidence trail and a durable next-action checkpoint for capacity errors or context loss. Make all choices yourself. This council-plan handoff is authorized, but it does not itself satisfy the runtime build goal.
