# Foldrunner: choose the game

The synthesis at the end records the final decision and corrections to member claims. The posts preserve the debate; they are not independent proof of play quality.

Opened 2026-11-05. Baseline: `wt` branch `feat/foldrunner-me-build`, clean and pushed at `86bb26c754424f9cb0c36b5c5fff5f6a8fc94874`.

## The decision

What should we build so that moving through a finished parkour level is satisfying, readable and worth replaying? Choose a concrete direction and the smallest playable experiment that could disprove it. This is a game design decision, not an exercise in satisfying the old test suite.

## What Mike has decided

- He played the Linux build and is still disappointed. His experience outweighs the previous numerical checks and positive agent reports.
- The Mirror's Edge reconstruction target is dropped. The folding world, bending buildings and gravity spectacle can be dropped too. They were background noise.
- Movement feel, fun gameplay and appealing visuals are the priorities. One or two finished levels, with meaningful parkour, are the intended result.
- Stairs must have smooth ramp collision beneath their visible steps.
- Changes to the controller, world, language and engine are authorized. Make the decisions without questions or live review from Mike.
- A cross-family consultation is authorized now: Sol, Opus 5.5, and optionally Gemini. At most one Opus consultation per hour. GPT work may continue freely.
- An evening build run should work toward 20:00 Europe/Prague, not stop at a paperwork milestone. A council plan and a paste-ready autonomous goal are an explicitly permitted handoff first.
- Mike explicitly wants the agents to enjoy the experiment and use their creative judgment. Opus consultations during the build may help with code, visuals or design, not just this council. The hourly allowance should be used on the most consequential current artifact, without a request for Mike to review it.

## Facts to investigate

The existing game is native Godot 4.7.2, using Compatibility rendering and a 120 Hz controller. It already exports on Linux and Windows. Code is under `wt/projects/foldrunner`. The metric yard is the default playable scene. The older city route is also available. Source assets are original procedural geometry; private reference assets stay outside Git.

Lead's initial code observations, to challenge rather than inherit as conclusions:

- Jump buffering and coyote time exist but default off, leaving an approximately one-tick jump request.
- Ground acceleration follows recovered source values, taking seconds to reach full speed. Air acceleration is weak.
- Context detection precedes jump handling; several path-driven moves seize input and zero velocity.
- Slide exit halves speed. Step-up clips end at zero speed. Landing/roll states can lock look or movement.
- The yard has individual stair colliders and no continuous ramp under those steps.
- The yard is a metric test facility, not a finished game level. The city prioritizes scripted spectacle.

Read live code and frames before treating these as the causes of Mike's dissatisfaction.

## Open forks, not requirements

- Keep Godot and replace the controller, simplify the current controller, or change engine?
- What is the central repeatable pleasure: flowing traversal, expressive routes, precision challenges, speed mastery, or another defensible choice?
- What world and art direction can carry an authored level with the available production pipeline?
- Which verbs earn their complexity? Wall runs, grabs, vaults and slides are candidates, not obligations.
- Is a timer helpful? Is a second level useful? First-person, rooftops and dusk are assumptions, not user requirements.

Avoid turning every old move into a checklist obstacle. Avoid replacing numeric fidelity with another self-scored checklist that claims to prove fun.

## Evidence

- Local baseline contact sheets remain under `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/frames/`, outside Git as the project's current capture policy requires. No private reference images are included here.
- User-facing report: `REPORT.md`.
- Historical contracts, now superseded on design targets: `FEEL-BRIEF.md`, `BRIEF.md`; game-local `AGENTS.md` and `docs/CONTRACT.md` contain technical guardrails worth preserving.
- Controller: `wt/projects/foldrunner/scripts/player.gd`; movement owners under `scripts/moves/`; tuning in `wt/projects/foldrunner/data/movement.gd`.
- Existing rendered contact sheets: `checkpoints/frames/feel-yard2.jpg`, `feel-yard1-vault.jpg`, `feel-yard1-roll.jpg`, `feel-city2-a.jpg`, `feel-city2-b.jpg`, `feel-city2-sprint.png`; yard views under `checkpoints/frames/feel-2/`.

## Council method

Sol and Gemini first make independent proposals and identify assumptions that this brief accidentally forces. Opus then reads both, challenges them and recommends a direction. The lead settles disagreements and writes a build contract. This adapts the council skill's shared-board debate to the one-Opus-per-hour limit; it is not represented as two full rounds from every member. No further question to Mike is needed.

## Independent posts

### Sol: movement and gameplay

The brief establishes Mike’s disappointment, freedom to replace the design, and ramp collision for stairs. First-person, rooftops, dusk, a timer, and momentum as the main pleasure remain choices. The missing question is whether reliable movement alone would make this enjoyable, or whether the activity itself needs replacing. The first experiment must distinguish those.

**My recommendation: keep Godot, rewrite the movement controller around run, jump and slide, and build one compact daylight waterworks course whose routes reward choosing and executing a clean line.** Cut automatic parkour sequences from this build.

This is an independent source-and-frame review. I did not play the executable or read another council member’s conclusions.

**Verified code facts explain why passing tests is insufficient.**

- Jump grace defaults off in [player.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/scripts/player.gd:16). The request lasts approximately one physics tick, although it can be consumed anywhere within that interval. There is no default forgiveness for pressing just before landing or just after leaving an edge.
- Context selection precedes ordinary jump handling in [player.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/scripts/player.gd:386). Forward input and nearby geometry can initiate a step, vault, grab or wall move. Thus Space’s result depends on hidden context, and some traversal requires no fresh action.
- The grounded acceleration table falls from 10 to 2 and then below 0.6 m/s² as speed rises in [movement.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/data/movement.gd:5). Air acceleration is 1.536 m/s². This establishes slow late acceleration and limited correction, not inherently bad feel.
- Control changes owners across fourteen movement states. Vault follows an authored trajectory; grab clears momentum; special step-up begins and ends with zero velocity. Every slide exit multiplies velocity by 0.5, including departure from the floor: [slide.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/scripts/moves/slide.gd:14).
- Roll substitutes a fixed forward displacement, while hard landing stops movement. Look is rejected during roll, hard landing and early pull-up: [player.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/scripts/player.gd:192). These are authored restrictions, not engine limitations.
- Yard stairs are ten individual solid boxes with no continuous ramp: [yard.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/scripts/yard.gd:50). Adding a ramp beneath active step colliders would leave the riser contacts intact. Visible steps should have no player collision; one continuous ramp should carry the player.

The tests verify different promises. [test_feel.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/tests/test_feel.gd:94) explicitly rewards automatic vault selection and preserved forward displacement. That can pass while lateral intent is ignored. Its roll fixture directly prepares eligibility state. The integration bot uses authored takeoff points and state-aware crouch timing. [test_traversal.gd](/home/thatmike1/foldrunner-build-2026-11-05/wt/projects/foldrunner/tests/test_traversal.gd:62) demands completion, every move and a duration range. None establishes discoverability, agency or replay value.

**Visual observations support a separate diagnosis.**

I inspected these existing captures:

- [yard traversal sheet](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/frames/feel-yard2.jpg)
- [vault sheet](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/frames/feel-yard1-vault.jpg)
- [roll sheet](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/frames/feel-yard1-roll.jpg)
- [city sheet](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/frames/feel-city2-a.jpg)
- [yard overview](/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/frames/feel-2/yard-overview.png)

The yard is visibly a measurement facility: repeated lanes, isolated blocks, metre grids and instruction labels. The city has stronger atmosphere, but several pictured traversal surfaces merge into dark foregrounds. Vault and roll sequences repeatedly devote the central view to floor tiles or body parts.

My hypothesis is that the player loses both control and useful sight of the next decision during actions intended to express mastery. Static frames cannot establish nausea, perceived latency or how long those interruptions feel.

**Keep the engine; replace the control policy.**

There is no inspected evidence that an engine defect causes the disappointment. Export and capture infrastructure already exist. Godot documents configurable character movement, slope speed and floor snapping in its [CharacterBody3D reference](https://docs.godotengine.org/en/latest/classes/class_characterbody3d.html). An engine migration would preserve the unresolved design questions while adding integration work before 20:00.

Rewrite the small movement core rather than preserving fourteen states and changing their constants. Keep collision helpers, input bindings, restart infrastructure and useful presentation assets selectively. Preserve tests for collision integrity; retire superseded fidelity expectations.

The player contract should be explicit:

1. **WASD runs.** Reach useful speed promptly, with no separate sprint threshold. Start around 8 m/s and roughly 0.3 seconds to running speed, as tuning hypotheses. Releasing or reversing input brakes predictably.
2. **Space jumps.** Enable approximately 100 ms coyote time and 120 ms buffering. Preserve horizontal momentum on ordinary landings. Air steering allows visible landing corrections without instantly reversing travel. Looking around alone never redirects airborne momentum.
3. **Crouch lowers; crouch while running slides.** Sliding has controllable steering, friction and clearance consequences. Release stands when clear. Jump can interrupt it. No compulsory half-speed exit.
4. **Mouse look always belongs to the player.** Remove forced pitch and look locks. Begin with a stable horizon, restrained impact compression and peripheral limbs. Camera animation must preserve the landing view.

No vaults, wall runs, grabs, springboards, rolls or scripted turns in the first course. Small curb handling remains collision accommodation.

**Build “Spillway”: one finished route with consequential choices.**

Use terraced waterworks around a recognizable pump tower. Pale concrete, muted blue water, terracotta machinery and bright overcast light give original procedural geometry a coherent appearance and readable silhouettes. Reuse geometry helpers; replace the inherited lighting. Put nearby rails, seams and machinery where movement provides visible parallax.

Author a roughly 45–60-second route through three connected spaces:

- An opening channel offers a broad ramp around it or a direct running jump.
- The middle courtyard offers a wide turning route or a shorter slide beneath pipework. The slide’s exit position changes the approach to the next jump.
- The final terrace offers a safe switchback or a diagonal sequence across raised maintenance islands. A missed shortcut lands on a lower recovery path that rejoins the course.

Show destinations and landing surfaces before commitment. Recovery costs distance rather than restarting the whole run. An unmistakable finish completes the first attempt; subsequent attempts offer a personal-best ghost and elapsed time. Replay comes from improving a chosen line, not collecting every movement state.

Prioritized cuts: folding and gravity spectacle, legacy move coverage, second level, elaborate body animation, then decorative density. Protect movement, route readability, recovery and restart.

**The falsifiable first playable is a 20–25-second section of Spillway.**

Include one turn, a jumpable channel with ramp bypass, a slide shortcut, a recovery path and a finish. Give it representative lighting and materials immediately. A grey metric corridor would leave the visual hypothesis untested.

Agents can verify input timing around edges and landings, jump cancellation rules, collision clearance, ramp continuity, speed continuity, route completion with varied approaches, restart behavior and frame pacing. They can inspect whether landing destinations remain visible throughout movement.

Human uncertainty remains decisive. The prediction is that Mike can understand the route, correct small errors and choose a different or cleaner line on replay. If controls still feel delayed or commandeered, revise the controller/camera before expanding. If control feels reliable but he still has no interest in another run, revise the route activity and replay premise before building level two.

Only reproducible collision or performance failures in this reduced slice would reopen the engine decision. A successful bot run would not establish that the game is fun.

### Gemini: unavailable

The optional Gemini Argon high task failed before opening its provider session: process exited with SIGKILL. No Gemini advice was obtained and no position is attributed to it.

## Opus challenge

# Opus challenge: Spillway, rebuilt around carried speed

**Decision.** Keep Godot and replace the controller with four verbs: **run, jump, slide, and a mantle that only works in the air**. Build one finished level, **Spillway**. The player descends a daylight dam and sluice complex from the crest down to a pump tower. Slopes and chutes turn height into speed, and the shallow water below catches missed jumps without a restart. The pleasure to sell is carrying speed through a working place, not performing a list of moves. Build one level to finished quality and no second level tonight.

I did not run the executable. Everything below comes from code and still frames.

## What I checked

**Verified in code:**
- **Jump input is fragile.** A jump press lasts one physics tick unless the assists toggle is on, and that toggle defaults to off (`scripts/player.gd:189,272`, `scripts/main.gd:37`).
- **Every jump costs speed.** Ordinary landings cap speed at the pre-jump speed minus 0.65 m/s (`scripts/moves/landing.gd:33`). Above 5.76 m/s the acceleration table drops to 0.52 m/s² and then to 0 (`data/movement.gd:5`), so getting that 0.65 m/s back takes seconds. The move meant to show mastery is punished.
- **Big drops freeze the player.** A fall of 5.3 m or more zeroes velocity for **2.0 s** (`hard_height` and `hard_duration` in `data/movement.gd`). During roll and hard landing, mouse look is thrown away, not delayed (`scripts/player.gd:193`).
- **Slide fights the player.** It clamps turning to ±55° from where the slide started, locks for 0.5 s and halves speed on exit (`scripts/player.gd:195`, `scripts/moves/slide.gd`).
- **Step-ups stop the player.** The step-up clip sets velocity to zero at both start and end (`scripts/moves/step.gd`).
- **The darkness comes from the lighting setup.** The city uses a flat colour ambient at energy 0.23 with filmic exposure 0.9 (`scripts/level.gd:310-315`). The yard only raises ambient to 0.48.
- **The renderer reason is gone.** The Compatibility renderer was chosen to keep a browser export possible (`docs/BRIEF.md:28`), and that goal no longer exists.
- **All sound is synthesized** from noise and sine waves (`scripts/audio.gd:2`).

**Visual observations from the frames I opened:**
- `checkpoints/frames/feel-yard2.jpg`: rows 4–5, which are the wall run, are mostly flat navy wall filling the view.
- `checkpoints/frames/feel-yard1-roll.jpg`: 5 of 11 frames are nearly uniform dark navy.
- `checkpoints/frames/feel-yard1-vault.jpg`: frames 4–6 show the player's own legs and floor tiles. The next target is out of view.
- `checkpoints/frames/feel-city2-a.jpg` and `7-route-2.jpg` have the best atmosphere in the set: warm windows and haze. But about a quarter of the route frames are near-black, and the surfaces the player runs on are the darkest values on screen.
- `checkpoints/frames/feel-2/yard-start.png` looks like a lab: text labels, a metre grid, and dark boxes on a pale floor.

**Hypothesis:** Mike's dissatisfaction may have three causes stacking up:
1. Input is dropped or taken away (the one-tick jump, look locks, the 2 s freezes).
2. The verbs that should express speed cost speed instead.
3. In many frames the route itself can't be seen.

None of these needs a different engine.

## Where I differ from Sol

I agree with Sol on keeping Godot, rewriting the controller rather than retuning it, and cutting the automatic context moves. I also agree on visible steps with no collision sitting on one ramp, the Spillway palette, one level, and recovery that costs distance rather than a restart.

What I change:

1. **Add a mantle.** Run, jump and slide alone make a first-person platforming lab with that genre's classic failure: you can't see your feet, so missing a ledge by 10 cm feels like the game's fault. An airborne-only mantle is the forgiveness move that makes this feel like parkour. It never fires on the ground, so it can't take over input the way vault and step-up did.
2. **The pleasure needs a source of speed beyond running.** On flat ground, Sol's "clean line" only means a shorter line. Instead:
   - sliding speeds up on a downhill;
   - jumping out of a slide keeps all its speed;
   - friction on flat ground returns you to run speed over about 1.5 s.

   Route choice becomes "which line keeps me on the downhill", and replays are about carrying speed further. That is why the course descends.
3. **Use sun, not overcast.** Overcast light with a flat ambient in this renderer is what we already have: shapes with no form. Use a hard warm sun, a strong cool sky ambient and lifted shadows. First try Forward+ for 20 minutes, since it adds screen-space ambient occlusion (soft contact shadows) and glow. Revert if `tools/play.sh` or frame capture breaks.
4. **Water is the recovery layer.** Shallow channels are walkable floor at 55% speed with splashes, and ramps lead back up. Only the deep centre of the basin respawns you, at the start of that segment, in under 1 s.
5. **Splits before a ghost.** Three segment times compared with your best, shown at the finish, give most of the replay value for a fraction of the cost.
6. **No text labels in the level.** Affordances are painted on: ochre safety paint on lips you can land on, terracotta on housings you can mantle.

## Movement contract (starting values, not targets)

- **Run:** 8.5 m/s, reached in about 0.35 s, with no separate sprint threshold. Going faster than that only comes from slopes and slides. Extra speed fades on flat ground over about 1.5 s. Cap 16 m/s.
- **Jump:** about 1.3 m high, snappy (gravity about 20 m/s² rising, 26 m/s² falling).
  - Coyote time 0.10 s and jump buffer 0.12 s, always on; delete the toggle.
  - Landings from under 6 m keep all horizontal speed.
  - Bigger drops get a 0.15 s, 25% slowdown and a small camera dip, with no lock.
  - Delete roll, hard landing and fall death.
- **Air control:** steering turns you toward your input at about 12 m/s² but never raises speed above takeoff speed.
- **Slide:** crouch while moving faster than 5 m/s.
  - Entry boost of 1.5 m/s, with a 0.8 s cooldown.
  - Low friction on flat ground; gravity pulls you along slopes.
  - Steering up to 90°/s, and look is never clamped.
  - Jumping out keeps full speed, and there is no exit penalty.
  - Under low clearance the slide continues until there is room to stand.
- **Mantle:** airborne, forward held, ledge top between hip height and 0.5 m above the eye. It takes 0.3 s and leaves you at 70% of your horizontal speed. The hands appear only here.
- **Deleted:** vault, wall run, wall climb, hang and pull-up, roll, springboard, the Q turn, step-up clips, red runner vision.
- **Kept:** the camera rig and its interpolation, `sweep_motion` and `detect_edge` (the mantle reuses them), the input map, restart, the bot and frame capture.

## Camera, body and audio

- Mouse look is never discarded or clamped, in any state.
- Horizontal field of view 90°, widening by 6° above 10 m/s. Camera roll only during a slide, at most 3°. Landing dip at most 6 cm, straight down, with no pitch change.
- Arms are hidden while running. Any frame with the body covering the centre 20% of the screen is a bug.
- Sound:
  - footsteps that change by surface (concrete, steel grate, water splash);
  - a slide scrape whose pitch follows speed;
  - wind that grows with speed;
  - a landing thump scaled by impact;
  - a background roar of water whose position tells you where the chutes are.

  Keep the synthesized sounds unless the run finds a CC0 sound pack and records its licence in the decision log. Don't promise a pack.

## Spillway

**Identity.** A 1950s concrete dam and sluice complex on a hillside, late morning:
- pale concrete with formwork board seams, a dark wet band near the water fading to bleached above it, and a moss tint at the waterline;
- steel grate walkways, terracotta valve housings and pipes, ochre paint on lips;
- blue-green water with foam scrolling down the chutes.

The landmark is a pump tower with a large wheel, visible from every segment. Everything you can traverse has a plausible job; nothing is a floating box.

**How it gets made.** Procedural geometry in GDScript as now, plus three materials:
- one concrete shader that projects onto any surface, with noise, board seams and the height-based stain;
- one water shader;
- flat-coloured metal, with paint applied as vertex colour.

No external mesh kit tonight. None has been checked, and matching one to the rest of the level would cost more than it adds.

**Route** (about 60 s on a first clear, about 35 s skilled):

1. **Crest (beginning).** You spawn on top of the dam and can see the whole course and the tower.
   - *Safe:* switchback stairs down. You see steps, but you walk on one ramp collider.
   - *Fast:* slide down the dry 25° chute and jump the 6 m channel from its lip onto the first terrace.
   - *Miss:* you land in the shallow channel and wade to a ramp, about 5 s lost.
2. **Sluice yard (middle).** Three ways across:
   - *Safe:* arcades that wind between valve housings.
   - *Fast but narrow:* a raised pipe walkway with two short jumps between pipe supports.
   - *Shortcut:* slide under a half-open sluice gate with 0.9 m clearance. It only pays off if you arrived carrying chute speed.

   Then the filter house: mantle up two 1.6 m terracotta housings to its roof, or take the ramp around, about 4 s slower. The roof gives you the height for the finale.
3. **Outflow (end).**
   - *Safe:* a railed gantry with two turns to the tower.
   - *Fast:* diagonal jumps across sluice pillars. The last one is a downhill run-up that launches you through the tower's open loading door.
   - *Miss:* you land on the basin-edge walkway, about 6 s lost. Only the deep centre respawns you.

   At the finish, the wheel spins up, the chutes behind you flood, and your splits appear.

**Replay.** Three splits against your personal best. R restarts instantly; F restarts at the current segment.

## First experiment and kill criteria

Build only the **Crest**, with the new controller and final materials and lighting: spawn, chute and gap, switchback ramps, channel recovery, and a finish trigger on the first terrace.

Checks a bot can run without a human:
- **Input:** a jump pressed up to 120 ms before landing, or up to 100 ms after leaving a lip, always jumps.
- **No seized control:** across whole runs, no state zeroes horizontal velocity except running head-on into a wall or respawning, and mouse look is applied every frame.
- **Stairs:** speed stays within ±3% going up and down the ramps, and eye height moves less than 2 cm per frame.
- **Mantle** never fires while grounded.
- **Speed premise:** at the chute lip, speed is at least 40% above run speed.
- **Route choice:** the fast line is at least 25% quicker than the safe line. A "jitter bot" whose timing is off by up to ±60 ms and aim by up to ±5° clears the safe line in 20 of 20 runs and the fast line in at least 12 of 20.
- **Frames**, captured at 4 per second along both lines:
  - fewer than 5% are near-black (mean brightness under 0.12);
  - the body never covers the centre 20% of the screen;
  - in at least 90% of airborne frames, the next landing surface is in view.

Kill criteria:
- If the jitter bot can't reach those rates after two tuning passes, the geometry or the jump is wrong. Fix that before building segment 2.
- If chute speed doesn't beat run speed by 40%, the core idea is missing. Fix that before anything else.
- If the Forward+ trial fails, stay on Compatibility and switch to sky-based ambient light at much higher energy.

**If the checks pass but the frames still look boring,** don't add props. Do a composition pass on the contact sheet. Each frame should have:
- the tower as a landmark;
- three depth layers: a near rail or pipe, the route in the middle, the hillside far away;
- a lit route against darker surroundings;
- moving water.

Use the hourly Opus slot as a blind critic of that sheet alone. Fix the three weakest frames by changing the light direction, where the landmark sits and the foreground parallax. At most two visual passes per hour.

## Build order to 20:00

1. Forward+ trial (20 min).
2. New controller and new tests. Retire the old fidelity tests (`tests/test_feel.gd` and the `tests/test_spec_*.gd` files) in the same commit, with a note saying why.
3. Crest slice with materials and lighting, the checks above, then commit.
4. About 17:45, the Opus slot: blind critique of the Crest contact sheet. Mike asked for hourly Opus help with visuals and code, not only for the council.
5. Sluice yard and filter house.
6. Outflow, finish, splits and segment restart.
7. Surface audio pass and the finish flood.
8. Linux and Windows exports, a clean check, and a report that says human enjoyment is unverified.

**Cuts if time runs short, first to last:** finish flood, the pipe walkway option, surface audio variants, Forward+. The ghost stays unplanned.

**Never cut:** the controller contract, ramp collision under stairs, recovery paths, readable lighting.

The yard becomes a developer-only tuning scene, and the city comes out of the menu.

## Honest limits

- I didn't play the build. Stills can't show latency, nausea or timing feel.
- Every number above is a tuning hypothesis.
- Bot and frame checks can show the game is controllable and readable, not that it's fun. Fun stays unverified until Mike plays it.

## Trail review

1. **The council is less cross-family than it looks.** The lead runs gpt-6.1-sol (`inheritedModel` in the 15:27 capabilities output), and Sol is also gpt-6.1-sol. Sol's brief included the lead's own code observations, and Sol mostly confirmed them. With Gemini down, this post is the only view from another model family. Treat lead-plus-Sol agreement as one voice.
2. **The lead leaned in before Sol answered.** At 15:39:57 the lead told Mike "I'm favoring a much smaller game… one compact level", before Sol's result arrived at 15:41:03. The outcome is harmless, but `reboot-decisions.tsv` presents that direction as Sol's alone.
3. **Two things Mike asked for are missing from `COUNCIL-REBOOT.md`.** In his 15:23:31 message he wanted the hourly Opus delegate to help with code and visual direction during the run, not only to advise the council. He also said his main goal is for his agents to have fun. The goal handoff should schedule the hourly Opus slot.
4. **Research with no logged outcome.** The 15:40 Kenney asset search and the Godot docs lookup have no row in the decision log, and no asset licence was checked. Any kit adopted later needs a row with its licence URL.
5. **Causes the brief and Sol missed.** Neither named the 2 s hard-landing freeze, the 0.65 m/s cost of every jump, the ±55° slide turn clamp, or the 0.23 ambient energy behind the dark frames. All four are now verified, with paths above.
6. **The log's claims check out.** Row 1 of the TSV cites "latest user messages". I checked it against Mike's 15:23:31 and 15:26:16 messages: the folding drop and the stairs-as-ramp request are both there, and he requests sustained work until at least 20:00 local time. I found no unsupported claims in `.orchestra/ledger.md`.

## Synthesis

### Lead's decision

Adopt Spillway: keep Godot, rewrite the small movement core, and build one finished descent through a sunlit dam and sluice complex. The central pleasure is carrying speed from a chute through jumps and route decisions. Safe routes, shallow-water recovery and faster lines coexist. The pump tower is the destination. Three segment splits supply replay feedback; no ghost or second level tonight.

Adopt Opus's airborne mantle as a forgiving catch, subject to explicit held jump/forward intent, clear swept geometry, free look and a way to cancel. Grounded forward movement never starts a canned climb. It remains optional to completing the safe route. A failed mantle implementation must not delay the run/jump/slide slice.

### Lead amendments to the Opus proposal

- Remove the repeatable +1.5 m/s slide-entry boost. Slopes supply extra speed. Repeated crouch presses on flat ground must not pump velocity toward the cap. This protects the route premise.
- Air correction must work from a standing jump. Use an air-speed budget at least as high as normal run speed; a strict zero takeoff-speed cap would forbid correction. Preserve excess speed without unlimited air acceleration.
- Test smooth stair motion relative to the ramp's expected height profile. A 2 cm limit on absolute eye movement per frame would fail during legitimate fast descent. Test run-speed continuity separately from intentional downhill slide acceleration.
- Treat sample speeds, clearances, durations, percentages and jitter-bot rates as tuning hypotheses and diagnostics. They do not become a new reconstruction spec or establish fun. A coherent playable slice and frame review are required before expansion.
- Retain the existing renderer unless a bounded Forward+ comparison demonstrates a visual gain with reliable native launch, capture and acceptable measured frame pacing. Renderer work must not precede or block the movement/route slice.
- Ordinary landings do have a speed cap, but Opus overstated its duration: the existing one-frame continuation adds 0.512 m/s at 120 Hz. Do not claim the full 0.65 m/s loss persists for seconds. The multiple input owners, look locks, hard landing stop and slide penalty remain verified.
- The lead and Sol share a model family and initial code observations. This was two participating families, not three independent confirmations. Gemini produced no advice.

### Next check

Sol read Opus's challenge and the build contract. Its reply follows. No human acceptance has occurred, and the runtime remains unchanged during this planning handoff.

### Sol reply after the Opus challenge

**Changed position**

Opus makes the downhill premise stronger: height becomes something the player spends and preserves, so a better line can mean more than a shorter path. I support the descent, shallow-water recovery, sunlight and splits before a ghost.

I also soften Sol’s blanket rejection of contextual moves. An intentional airborne catch could forgive a near miss without recreating automatic vaulting. But airborne eligibility alone does not protect agency. The synthesis’s held intent, cancellation and free look are essential.

I retain the lead’s rejection of repeatable slide boosts, the strict takeoff-speed air cap and renderer migration as prerequisite work. Opus’s landing-recovery claim was overstated; the documented one-frame continuation restores 0.512 m/s at 120 Hz. That correction does not erase the other control restrictions.

This is reconsideration within the lead’s model family, not another independent-family vote. I have not played the build.

**Remaining disagreements**

Run, jump and slide do not inherently produce a platforming lab; adding mantle does not inherently produce parkour. The distinction comes from reading a place and choosing movements whose consequences carry into the next decision.

Mantle should therefore remain expendable. Holding jump from takeoff can reasonably authorize a catch, but it must not authorize repeated catches or an unavoidable ride onto the roof. Cancellation must matter while the catch is happening.

Downhill speed is promising only if the player can shape it. If the fastest route becomes “hold forward, crouch, jump at the marker,” while overspeed makes braking and correction ineffective, the new controller would reproduce lost agency through momentum instead of animation.

**Blocking contract corrections**

There is no blocking contradiction in the overall direction. Two implementation-facing safeguards need explicit wording:

- **Mantle cancellation has no defined input or aftermath.** Smallest addition: “Releasing jump or pressing backward cancels the mantle promptly into collision-resolved airborne motion, retaining applicable momentum and free look. Cancellation cannot immediately retrigger a catch from the same held input.” A failed mantle can still be cut without blocking the slice.
- **Practice exclusion does not explicitly cover checkpoint respawns or split provenance.** The brief prohibits practice-assisted finishes from overwriting a clean best, but merely distinguishes respawns in traces. Add: “Segment restarts and checkpoint respawns invalidate clean full-run eligibility until R starts a fresh attempt. Clean records require ordered segment passage within that attempt. Practice splits may be stored separately and labelled; they cannot replace clean records.”

The scope is otherwise defensible, with the optional pipe line, flooding and elaborate hands already expendable. The remaining design risk is expanding after a chute jump works, before demonstrating that carried speed creates a consequential next choice.

The contract correctly supersedes fidelity acceptance, forbids self-scored proof of fun and permits unattended progress without a human gate. Preserve those distinctions in the actual test entry point and final report.

**The first experiment’s decisive evidence**

Crest should show one continuous sequence: choose the chute, gain speed, steer or brake into a landing, then make a useful next decision. Compare that with the safe route and a missed-jump recovery using normal-speed, uninterrupted input-driven playback.

The decisive observation is whether earlier choices change the next approach while the player can still correct or abandon the fast line. Include one mantle catch followed by cancellation and one nearby jump where no catch occurs.

If the evidence shows only a faster straight corridor, a concealed landing or a catch that overrides an attempted escape, revise the slice before expansion. Successful playback can support control and route claims. Enjoyment remains unverified until Mike plays.

### Final resolution

Adopt Sol's two safeguards: releasing jump/backward cancels a mantle without immediate recapture, and practice/respawn invalidates a clean full-run record. Add a consequential exit choice to the Crest terrace so the first experiment demonstrates speed influencing the next decision. The mantle is still expendable. No design decision is left for Mike; the next action is the new motor and Crest slice, followed by the complete level. The build contract and goal are in BRIEF.md and GOAL.txt beside this board.

### Review scope

Opus reviewed the source, frames and initial council trail. Sol then read and challenged the synthesized contract. A narrow Gemini retry for the final trail again failed at provider startup with SIGKILL; no Gemini review exists. The final wording changes and documentation links were checked by the lead. No runtime, human-play or independent final-build verification is claimed by this planning checkpoint.
