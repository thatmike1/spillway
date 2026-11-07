# Movement, engine and agent testing council

## Decision

Which causes of R12's rejected handling can playable comparisons distinguish, and what can that evidence justify about the final product's movement and engine? Separate the platform used for an experiment from the final engine decision. Recommend a direction and the experiments that could overturn it; an unmeasured cause stays open.

Candidate final-product forks, none selected. Order does not rank them:

- Keep Godot and replace control/collision policy where needed, retaining or changing the current scene.
- Build the representative slice in Unity with an appropriate custom or available kinematic controller.
- Build it in Unreal with a suitable movement implementation.
- Use a smaller native or web engine/custom controller, or another justified candidate.

Testing may combine state-aware fixtures/replay, imperfect open-loop input tapes, screenshot/video-only navigation, semantic inspection, learned/real-time agents and adversarial exploration. Explain what each can establish and what it cannot. A successful exact-state bot is not proof of satisfying handling or human enjoyment. Mike is the eventual human judge; optional asynchronous A/B builds may help him react, but his availability is not a gate on continued work.

## Settled by Mike

On 7 November he said he remains unsatisfied with movement and momentum and asks for broad research and continued work. He enjoyed VHOLUME as a reference resembling CS bhop. He permits our own implementation, dropping surf (which he disliked here), external assets/textures and anything useful to advance the game. Delegate budget is unlimited today. He asks to reconsider Godot for the final product and put a council to work. Earlier autonomy remains: make decisions without stopping to ask for a live review.

These are his decisions. No exact movement constants, engine, required surf mechanic, visual reference reconstruction or hard new completion-time target is settled.

## What Mike's feedback does and does not tell us

- His current rejection names movement and momentum, without a more specific symptom or input recording. Do not turn that into a proven air-control diagnosis.
- He liked VHOLUME and perceived a resemblance to CS bhop. That does not establish which component he liked or VHOLUME's physics constants.
- He disliked surf in our version and permits dropping it. That is sufficient to remove mandatory surf, not evidence that every steep-surface mechanic is bad.
- Earlier he called stair walking poor and asked for continuous collision ramps. R12 subsequently used ramp collision beneath noncolliding treads. That historical fix does not prove all step, edge or slope contacts now feel good.
- He also wants a visually appealing finished game and authorizes assets, original code and even an engine change. A higher speed number alone does not meet that request.

## Facts and existing evidence

R12 is a working portable Godot 4.7.2/GDScript/Compatibility implementation, with 120 Hz physics and an original procedural dam. Its archived Linux/Windows packages and source remain available. Tests and native scripted runs passed specified R12 gates; Mike still rejected its feel. Existing evidence therefore establishes execution and regressions, not satisfaction. Root's captures used Linux llvmpipe, not desktop GPU measurements. Native Windows play remains unverified.

The classic-model research derives a narrow forward-key air-steering response. The separate Godot FLOW lab now measures one W-plus-mouse 60-degree airborne turn as 0 degrees of flight turn in R12 and 60 degrees in FLOW, with the same camera and fixture. This verifies those gestures' behavior, not the cause of Mike's dislike. FLOW also changes ground steering, slope energy, drag and ramp launches, so its whole-policy comparisons do not isolate those causes. Its ground-turn/brake episodes enter at different speeds. Root reran its 38 checks; they validate its own targets, not enjoyment. No final motor is selected.

The current agent helper advances paused native screenshot decisions, up to three seconds of key holds. A request's total mouse displacement is already distributed evenly over its rendered frames, producing a constant-rate turn at 30 samples per simulation second. It does not currently accept a time-varying key/mouse tape within one uninterrupted decision. The exact-state route drivers know authored geometry. These are capabilities/limitations to inspect, not constraints to preserve. Root corrected the earlier misleading single-displacement description after reading tools/visual-play.gd on 7 November.

A working export pipeline and existing geometry are facts about the baseline, not vetoes on migration. Conversely, a fashionable engine or impressive framework does not establish better control. Missing measurements must be labelled and tested rather than silently resolved by preference.

## Competing explanations, none established as Mike's cause

Input mapping/latency, acceleration and braking policy, earned-speed retention, jump timing, collision/steps/slopes, camera/FOV, scale and speed feedback, route affordance and readability could each contribute. A satisfying basic line and a meaningful mastery line might need different tradeoffs. Forward steering is one candidate, not a required answer. The existing dam, FLOW lab, 120 Hz setting and Compatibility renderer may all be replaced if evidence supports it.

## Decision criteria and moderator's process choices

These are the moderator's autonomous framing choices, not additional facts or Mike's approval. Challenge them where they distort the decision.

- Compare controllers on shared geometry/camera first; compare presentation and course separately. A bundled improvement can be shipped later, after attribution is clear enough to make a coherent choice.
- Assess start/stop, deliberate reversal, imperfect hops, high-speed turns, slopes, contacts and recovery, plus what mastery rewards. Record actual displacement, not just claimed speed. Faster and more forgiving are not automatically better.
- Assess native Windows/Linux delivery, licence/distribution, external-asset pipeline, collision control, actual input/render cadence, visual quality/performance and agent iteration/test access for each serious engine candidate. Unsupported dimensions remain unknown. Do not infer desktop GPU behavior from llvmpipe captures.
- Use symmetric falsification. Keeping Godot needs credible evidence that it can deliver the chosen behavior and presentation; migration needs credible evidence that the candidate solves a material problem or enables a valuable result. Identify what evidence would disqualify either recommendation. Porting controller math alone does not show an engine improvement.
- Prefer a bounded representative slice to an open-ended rewrite. Name a stopping result for each experiment and choose the next playable direction after the comparison, while preserving unresolved risks explicitly. A harness or research catalogue is supporting work, not the delivered game.
- Do not claim a match to VHOLUME or human satisfaction. We can assess observable response, robustness, legibility and choice; Mike's later play remains the subjective check.

## Materials

- docs/momentum/BRIEF.md, research/classic-movement.md and research/vholume-and-peers.md
- research/controller-lab.md and research/input-camera-audit.md; the FLOW scripts/probe are optional experiment evidence, not prescribed architecture
- research/ai-game-testing.md compares available frameworks with an original timed-input executor; it is a research recommendation, not an adopted dependency or harness
- scripts/spillway_player.gd, spillway_main.gd, spillway_course.gd
- tools/visual-play.py, visual-play.gd, visual-play.sh, capture-route.gd
- docs/surf/RESULTS.md and the preserved R12 report/evidence under the outer build directory
- Official reference page: https://store.steampowered.com/app/4131730/VHOLUME/

Use current primary engine/framework sources for external technical claims. Distinguish a paper's research result, a downloadable usable tool, a commercial product claim, a local experiment and an inference. Do not invent reference-game constants or report a local baseline measurement as human feel.

## Process and members

Use Opus 5.5 and GPT-6.1 Sol at high effort, the two-family combination Mike previously requested. Moderator is the current Codex lead. The brief first receives separate Opus/Sol pre-mortems: likely forced answer, fact/decision/assumption classification, omissions and sharper question. Root revises the board under Mike's explicit autonomy instead of requesting another approval round.

Round 1 proposals are independent and withheld from the other member until both are back. Round 2 members see the full board and challenge one another. Each round is a fresh watchable T3 task. The synthesis records the choice, continuing disagreements and falsifiable experiments. It must lead to a playable comparison, not end at a score or engine shopping list.

## Pre-mortem

The two independent written critiques are premortem-opus.md and premortem-sol.md. Both found a Godot/incumbent bias and premature emphasis on forward air steering. Opus also caught the auto-loaded AGENTS.md presenting Godot as a requirement. Root changed that to a baseline fact, split the experiment platform from the final-product choice, added competing causes and symmetric falsification, and made the eventual human judgment explicit. No new approval was requested because Mike already delegated decisions autonomously. The live mouse-helper correction above supersedes both critiques' inherited single-flick premise.

Both round-one posts returned independently and are included below. Neither member read the other proposal before returning. No final motor or engine is selected.

## Moderator updates before round two

Both proposals recommend a hop-focused descent with a complete basic line, optional strafe mastery, no mandatory surf, a timed relative-input executor and provisional Godot. Their main policy disagreement is narrow Source-like versus broad projection gain, plus ground friction/grip. Those are choices to compare, not a recovered VHOLUME contract.

The independent FLOW challenge is now committed in research/controller-review-sol.md. Root reproduced it, fixed event-cadence reward and multi-contact landing restoration, and retired the automatic continuous-crest rule after repairing its history exposed stair pops. See research/controller-fixes.md and commit 27dc83bc. The original 38 checks still pass; root's post-physics checker passes 67 characterization episodes, including six additional mouse-sampling phases. This remains headless injected-input evidence and does not select FLOW. Its intentional A/D semantics remain a comparison risk.

Questions for the challenge:

- Similarity to a Source family is useful context, not evidence that preserving its exact cap is what Mike wants. Also, 30 inches is 0.762 m, not exactly 0.75 m. Keep conversion conventions and reference-game claims explicit.
- Resolve narrow versus broad air gain and ground policy into a bounded implementation comparison. Explain where speed should be earned and spent, and how the ordinary line and mastery differ. Avoid a large matrix of unbuilt feature combinations.
- Opus reports an unset backend resolving to Godot Physics through a local ray probe. Root verified the setting is absent, but has not independently run that backend probe. Retain a runnable artifact if this claim matters. Compare backend and controller ownership separately; changing both cannot establish which solved a contact fault.
- Lower landing spread or a perfect bot's completion is not automatically a better game. A route authored around one candidate is an explicit bias. Choose criteria that preserve meaningful movement decisions without turning human enjoyment into a test score.
- State what can be built now and what remains contingent on real GPU/display or Windows access. Do not silently operate Mike's desktop to fill those gaps.
- Both members favor a finite tape executor. Root will build this bounded supporting experiment while the policy question is challenged. It must remain usable if the eventual controller or engine changes.

## Round 1: Opus 5.5

Source post: round1-opus.md

### Round 1: Opus 5.5

Independent proposal, written 7 November 2026 against board `a0e2b62e`. I did not read Sol's round-one post or the running Sol controller challenge. All constants are **P** (game choices to test), not reference-game values. Claims are tagged **[src]** (primary source read today), **[local]** (probe or code read in this checkout today), **[board]** (from the council materials, not rechecked) or **[inf]** (my inference).

#### 1. Recommendation in one paragraph

Build one motor, **CARRY**, and test it against R12 and FLOW on shared fixtures and then on one authored slice. CARRY keeps R12's Source-style air law **unchanged for side-only input**, so the bhop skill Mike's reference implies stays exactly as it is. It adds three things around that law: a bounded forward-key bend that costs a little speed and fades out for large view offsets; Source-style ground friction with a short landing grace in place of R12's target chasing and overspeed tax; and physical slope energy (downslope landings and hops keep plane-projected velocity). It also moves contacts onto an owned sweep over Jolt. Keep Godot as both the experiment platform and the provisional final engine, with four named disqualifiers and a port proof that runs only if one of them fires.

#### 2. A fact the board under-uses

R12's air rule is close to the Vanilla CS family, not a departure from it. Its air cap (0.75 m/s) equals Source SDK 2013's default 30-unit cap if one unit is taken as one inch (a conversion convention, not a source fact), and its air coefficient 12 matches GOKZ's Vanilla mode **[board: classic-movement.md]**. At 120 Hz the per-tick budget already saturates the cap, so raising air acceleration to bhop-server values changes almost nothing for perpendicular input **[board]**. R12 also already has held autohop.

So "Mike liked a CS-bhop-like game but rejected R12" does not point mainly at the air law. **[inf]** The likelier differences are everything around it: ground policy, slope energy, contacts and edges, the surf course, camera and scale, and VHOLUME's more permissive basic line. Forward air steering may still matter for a player who does not strafe. CARRY is built so the experiments can separate these: its strafing is bit-identical to R12's, so any difference in how strafing feels must come from somewhere else.

A second local fact: `project.godot` never sets `physics/3d/physics_engine`. A ray-hit probe on the installed 4.7.2 binary shows the unset value resolves to **Godot Physics, not Jolt**: `face_index` came back 0 when unset or set to GodotPhysics3D, and -1 with "Jolt Physics", which is the Jolt signature the docs describe **[local]**. Godot's docs say Jolt is built in since 4.4 and is the default only for *new* projects **[src: docs.godotengine.org, Using Jolt Physics]**. R12's contacts and FLOW's inherited contacts therefore run on an engine nobody chose. This is a variable, not a diagnosis.

#### 3. The movement policy (CARRY)

Each channel has one job, and the motor reports every per-tick speed change in a **ledger** by cause: run acceleration, strafe gain, bend cost, friction, brake, slope clip, contact loss, soft drag, and a residual that must be zero.

| Channel | Rule (P) | Job |
|---|---|---|
| **Strafe (mastery)** | R12's projection exactly: C = 0.75, a = 12, W = 8.5, full wish vector. | The only way to gain speed on flat ground. Synchronised A/D plus mouse, as in CS. |
| **Bend (basic line)** | With forward input f = max(0, wish·view) > 0, rotate horizontal velocity toward view yaw at up to f·A_bend/speed rad/s, A_bend = 14 m/s². That is 94°/s at 8.5 m/s, 62°/s at 13 m/s and 40°/s at 20 m/s. Authority is full when view and travel differ by up to 45°, falls linearly to zero at 90°, and costs 4% of speed per radian turned. | Gentle placement while holding W. It never gains speed, so it cannot beat strafing. Big turns at speed belong to strafing. No keys, or side keys alone, never bend. |
| **Ground** | Speed-scaled friction 4/s with a 3 m/s stop floor, then projection acceleration toward 8.5 m/s at a = 10/s. Jump is processed before friction. Friction ramps from 0 to full over the first 80 ms grounded. S, or a wish more than 120° from travel, adds a 24 m/s² brake. | The ground is slow and the air is fast, as in bhop. A slightly late tap costs a little; standing around costs a lot. Release and coast are distinct from a deliberate brake. |
| **Hop** | Held space rehops (autohop on). 120 ms press buffer and 100 ms coyote time, as in R12. | Timing is forgiven; aim and line are not. A tap-only variant is a later accessibility ablation. |
| **Slope** | Walkable up to 45°. A landing keeps the velocity clipped onto the plane, so a downslope turns the fall into speed and an upslope costs it. A hop adds jump speed to the surface's climb rate. Running on a slope adds no tangent gravity in the base version. | Height pays through landings and lines, not through a hidden running bonus. This is a Source-native mechanic (bhop slope boosts), with no surf. |
| **Contact** | Owned collide-and-slide over `PhysicsServer3D.body_test_motion` on Jolt with enhanced internal edge detection. Planes clip velocity with overbounce 1.0, so a glance keeps its tangential speed and a head-on hit loses its normal component. A lip rule steps the body up when a blocking edge is within 0.35 m of the feet while moving level or upward above 2 m/s. | Predictable losses, and no snag on a landing slab's front edge. Both R12 and FLOW catch on that edge in the e4 fixture **[board]**. |
| **Limits** | No hard 30 m/s clamp. Air drag of 0.5/s above 26 m/s, logged. | An earned gain is never silently erased. |

Surf, mantle, crouch-slide and walls stay off for the first comparison. A crouch-slide (friction ×0.15 plus tangent gravity, entered on landing above run speed) is the natural second mastery layer, close to VHOLUME's slide-hop. It comes in only after the first comparison, as a single rule with its own ledger channel.

**Why this rather than the alternatives.** I compared four policies that differ in kind, not just in air acceleration:

- **R12 or Q3 projection only.** Steering comes only from strafing. That is honest for experts, but a W-holding player gets no help: the 60° W-plus-mouse turn moves the flight 0° in R12 **[board]**.
- **FLOW.** Travel follows the view with any key held. It is coherent and answers W-plus-mouse, but it replaces the CS skill (see section 5).
- **Downhill momentum** (classic-movement option C). It gives up flat strafe gain and with it most of the bhop fantasy.
- **Wall relay or tether.** These are new verbs that need their own geometry. They are a later layer, not the base motor.

CARRY is the only one of the four that leaves the reference's skill intact and also gives the basic player a line.

#### 4. One playable slice: "Overflow"

The slice is about a minute long, built in the existing dam's concrete and steel and graybox-first.

1. **Crest walk.** About 40 m of 6 m wide walkway with a 3° fall. Railing posts every 2 m and expansion joints every 5 m serve as motion references. You learn run, hop and held hop here.
2. **Apron.** An 18° concrete face about 30 m long. Hopping down it, each landing on the downslope adds speed. A cleaner rhythm, with landings placed on the slope rather than at its foot, arrives faster.
3. **Pier bend (first decision).** A 90° bend around a pier.
   - **Safe line:** a walkway on a 12 m radius. At 11 m/s it needs about 10 m/s² of lateral acceleration, well inside the bend channel's 14.
   - **Cut line:** a gap across the stilling-basin corner to the pier top. Size it after the first experiment, so that a held-W descent arrives below the required speed and a clean descent with one strafe correction arrives above it. For a gap d with drop h, the required speed is d·g / (v_j + √(v_j² + 2gh)), with v_j = 7.2 and g = 20.
   - **Miss:** knee-deep basin water slows you, and a ramp leads back to the walkway for about 3 s of lost time. No restart.
4. **Baffle blocks.** Six energy-dissipator blocks with irregular headings, gaps of 3–6 m, and two blocks with sloped tops. Side strafing through them earns flat speed, and the bend places you. A lower service ledge runs alongside, so a missed block costs time, not the run.
5. **Tailrace and finish.** An uphill ramp to the valve-house roof. Climbing spends speed, so earned speed shows up as a shorter climb and an earlier final jump.

**Replay reasons:**
- Splits at the pier and at the blocks.
- A ghost of your own best run.
- The visible cut line.
- Bronze, silver and gold times, with bronze set from a basic-line run without strafing, following VHOLUME's principle that bronze ghosts avoid advanced tech **[board]**.

#### 5. FLOW: what it gets right and the risks it carries

**Strengths [board, local code read]:**
- It is the only implemented candidate that answers W plus mouse (a 60° flight turn).
- Heading and speed are cleanly separated.
- Slopes pay and the brake is explicit.
- It is deterministic and inherits R12's contacts, so its differences come from policy.
- Its lab identity and records isolation are done properly.

**Risks to test, not verdicts:**

1. **View-led steering with any key** (`_flow_air`: heading follows view yaw at up to 3.2 rad/s). A glance toward a landing while holding A or W bends the line, so free look is coupled to travel. CARRY has the same coupling for W only, reduced by the 45–90° fade. The glance tape in E1 measures both.
2. **The carve gains speed by rotation, not synchronisation.** It adds 1 m/s per radian the view turns with a strafe key on the inside, up to 17 m/s. That gain has no optimal angle, so steady turning earns speed whatever the velocity–wish relationship. It replaces the CS skill rather than refining it. The off-beat A/D tape reached 15.9 m/s **[board]**, a strong sign of how forgiving it is.
3. **The crest launch is a hidden trigger**: speed at least 11 m/s plus thresholds on climb rate. This is the same class of thing VHOLUME players complained about (unpredictable boosts) **[board]**.
4. **It is a whole-policy bundle**: ground, slope and air all changed at once.
5. **The 38 checks test its own targets**, and it inherits Godot Physics contacts with the edge catch.

FLOW stays in the comparison as the strongest "forgiving" pole. If it wins the basic-line tapes and the blind A/B, CARRY's case is refuted.

#### 6. What each experiment tests about the rejection

| Suspected cause of the rejected handling | Tested by |
|---|---|
| No forward-key air steering | CARRY against CARRY without bend (which is R12's air), on W tapes |
| Ground tax and chord turns | CARRY's ground against R12's ground, at matched entry speeds |
| Slopes carry no energy | CARRY against CARRY without the slope clip, on apron tapes |
| Edge catches and contacts | CARRY on Godot Physics against Jolt, with and without the lip rule, plus adversarial search |
| Silent caps and implicit brakes | The ledger shows every cap and brake; brake, release and reverse tapes |

**Left unresolved:** camera, FOV and roll; sense of speed from scale; audio; latency and frame pacing on a real GPU (E4 measures them but cannot judge feel); tap versus autohop; slide, wall and mantle; and above all whether Mike wants CS-style strafing at all. Only his play answers that last one.

#### 7. Evidence loop: the smallest version that is useful

This extends the tape contract in `ai-game-testing.md`, implemented in Godot first and engine-neutral at its interface. Its outputs are five separate fields, never merged into one score.

1. **Exact-state fixtures.** Labelled setup places the body at matched entry speeds (8.5, 13 and 20 m/s). Per-tick invariants:
   - the ledger residual is zero;
   - CARRY's side-only air equals R12's per tick within 1e-4 m/s;
   - with no keys held, looking changes the velocity by exactly zero;
   - the bend never increases speed.
2. **Open-loop tapes.** Relative mouse deltas and key edges at 120 Hz, injected before the motor with both `relative` and `screen_relative` set. The gesture set:
   - start from rest on W;
   - a bell-curve 60°/s W turn with a 10% overshoot and correction;
   - synchronised side strafing;
   - strafing 120 ms out of sync;
   - a jump 100 ms late;
   - S, release and reverse;
   - a 40° glance for 0.3 s while holding W;
   - a 15° glance off a wall and a head-on hit;
   - an approach to a lip 0.2–0.4 m below the landing edge.

   Seeded perturbations: ±20% yaw rate and ±80 ms key edges. The same tapes run against every motor without modification. Output per tape: actual displacement, heading, landing point and ledger.
3. **Pixel-only discovery.** A fresh model sees frames only, in paused-planning mode, on a held-out variant of Overflow (moved pads, changed cue), with a fixed plan budget. This measures whether landings are visible and runs are recoverable for that model. It is never used for tuning.
4. **Adversarial search.** Seeded mutation of the tapes over the slice, with these oracles:
   - penetration;
   - stuck (movement input with near-zero displacement over 0.5 s);
   - a non-zero ledger residual;
   - speed above 26 m/s with no cause;
   - an edge catch, meaning a near-horizontal contact that removes more than half the horizontal speed while the feet are within 0.4 m of the surface top.

   Failures are minimised and saved with their tape and clip.
5. **Human judgment.** Blind asynchronous builds for Mike. Satisfaction stays unverified until he plays, and no work waits on him.

Presentation cues read the same ledger the tests read, so a cue cannot claim a gain that did not happen.

#### 8. Experiments and stopping points

- **E1, matched fixtures.** Motors: R12, FLOW, CARRY, and CARRY without bend, without slope clip, and with R12's ground. Run the fixture invariants and the full tape set.
  - *Stop* when every tape has run on every motor.
  - *Refutes CARRY* if any of these happens:
    - side-only identity fails;
    - the no-key free-look check fails;
    - the perturbed bell-curve W tapes leave CARRY's landing-point spread wider than FLOW's on the pier-bend fixture.

    In that last case, FLOW-style view steering wins the basic line, and I would graft CS strafing onto FLOW instead.
- **E2, contacts.** CARRY on Godot Physics against Jolt, with and without the lip rule, on seam, edge and lip fixtures and under adversarial mutation.
  - *Stop* after two consecutive mutation passes over every tape with no new minimised failure signature, or after one wall-hour.
  - *Outcome*: an adopted contact configuration, or a named unfixed snag. An unfixed snag feeds disqualifier D2.
- **E3, Overflow slice.** Build P0 (fixed presentation), size the cut gap from E1 speeds, and run the perturbed basic-line tapes.
  - *Requirement*: every seed finishes the safe line without a restart, for CARRY. If one does not, change the geometry or the bend, and say which.
  - *Output*: blind builds X, Y and Z (R12, FLOW and CARRY on Overflow, with identical presentation and shuffled labels), plus R12 unchanged as the archived control. Overflow is authored around CARRY, and the hand-off note says so, as a known bias.
- **E4, the Godot disqualifier run** on this machine's real GPU and display, during a window when the desktop is free. Matrix: Compatibility against Forward+, and X11 against Wayland. The project leaves the display driver at "default", and I have not verified which server it resolves to under Hyprland.
  - *Measure*: frame-time p99, and how uniform the camera step is per presented frame during a constant-speed straight run (120 Hz physics against the display's refresh rate).
  - *Stop* after one recorded run per cell.
  - If the running Sol cadence challenge already covers the measurement method, E4 only confirms it on a real display.
- **E5, pixel-only discovery** on the Overflow hold-out, after E3.
  - *Stop* when the budget is spent.
  - *Outcome*: findings on visibility and recovery that feed changes to the presentation, not to the motor.

**Choice:** pick the motor after E1 to E3, using elimination, the ledger's legibility and Mike's A/B if he plays it. Pick the engine as described in section 9.

#### 9. Engine: experiment platform and final product kept separate

**Experiment platform: Godot 4.7.2.** It has the shared geometry, the tape helper, the FLOW lab and the export path. Using it for the motor comparison says nothing about the final engine, because CARRY's math is written as a pure function over (state, input, sweep results) behind a small sweep interface, and would port to any engine.

**Final product: keep Godot provisionally**, because no measured blocker exists today. The comparison below names evidence for and against each engine.

| | Godot 4.7.2 | Unity 6 | Unreal 5 | Bevy or custom |
|---|---|---|---|---|
| Control and collision | Owned sweep over `body_test_motion`; Jolt built in **[src]**; currently unused **[local]** | Custom kinematic controller over PhysX queries; mature ecosystem | The mature controller is CMC; Mover is labelled Experimental, with APIs subject to change **[src: Epic docs]** | Full ownership; physics comes from third-party crates (not verified today) |
| Input and render cadence | Manual camera interpolation plus unsmoothed mouse look **[board]**; real-display pacing unmeasured | Unmeasured | Unmeasured | Unmeasured |
| Visuals and assets | Compatibility renderer today; Forward+ is untried; CC0 materials import directly | Strong store; HDRP and URP | Strongest high-end pipeline (inf from reputation, not measured here) | Weakest; no editor |
| Agent iteration and testing | Text scenes, headless runs, scripted stepping, harness exists **[board]** | ML-Agents, Apache-2.0 **[board]**; heavier editor loop | Automation Driver and Learning Agents (Experimental) **[board]**; C++ compile cycles | Code-only suits agents; everything else must be built |
| Linux and Windows delivery | Linux works; Windows export exists, but native Windows play is unverified **[board]** | Linux editor officially supports Ubuntu 22.04 and 24.04 only **[src: Unity 6000.3 requirements]**; this machine runs Arch-based Omarchy | Linux development targets Ubuntu 22.04 and Rocky 8, with 32 GB RAM listed **[src: Epic Linux requirements]** | Cross-compilation is our own work |
| Licence and setup | MIT, portable binary already installed | Personal plan limited to $200k revenue and funding **[src: unity.com]**; activation through an account (not confirmed from a primary page today) | 5% royalty above $1M lifetime gross **[src: unrealengine.com/license]**; Epic account and a large install | MIT or Apache; Rust toolchain; latest release v0.19.1 **[src: GitHub releases]** |

**Godot disqualifiers.** Any one of these triggers a scoped port spike. None of them is a vote for migration in itself.

- **D1 (pacing).** On the real display, frame-time p99 stays above 1.5× the refresh interval, or the camera step shows periodic unevenness at constant speed. To count, it must survive tick-rate matching, engine physics interpolation and the faster renderer, and the cause must be traced to the engine rather than to our code.
- **D2 (contacts).** E2 leaves a reproducible snag that occurs on Jolt with edge detection on, and that the owned sweep cannot work around with shape queries.
- **D3 (visuals).** Overflow with the adopted CC0 set (concrete, wet surfaces, water reflection, long sun shadows) cannot reach refresh rate in Forward+ on this GPU at its native resolution.
- **D4 (delivery).** The Windows export fails on real Windows hardware. This is untestable today, because no Windows machine is known; Wine is not proof.

**Port proof, if triggered.** Rebuild Overflow's graybox plus the same asset set in the candidate engine, implement the same tape interface, and run E1's tapes, E2's oracles and E4's measurements. The port is refuted if it does not remove the specific disqualifier that fired. The candidate is chosen by the disqualifier: Unreal for D3, a custom stack for D2, any engine for D1. Unity and Unreal both need an account and a large install that are not approved today, so this proof is conditional and outside this proposal.

#### 10. Presentation that helps reading motion without blurring attribution

- **Freeze presentation during E1–E3.** Horizontal FOV fixed at 90° as in R12, no speed FOV, no bob, no roll, and the same audio. The build label shows the motor ID and the presentation ID separately.
- **Presentation variants after the motor choice, on the chosen motor only:**
  - **P1, scale.** CC0 concrete with formwork panels at true size and tie holes, joints every 5 m, railing posts every 2 m. Source: ambientCG and Poly Haven, both CC0 **[src: their licence pages]**. Each asset's URL, licence, hash and modifications are recorded in the manifest.
  - **P2, motion cues:**
    - speed FOV of at most +6°, driven by measured displacement;
    - wind volume driven by actual displacement;
    - landing sound scaled by the vertical speed removed;
    - a quiet strafe-gain tick read from the ledger, in the spirit of VHOLUME's crosshair flash and speedometer **[board]**.
- **Show presentation and motor changes to Mike separately**, not combined, until attribution is clear.

#### What I would still change in the revised brief

State that R12's air law is substantially Vanilla Source's, so the rejection points at least as much to ground, contact, slope, course and presentation as to air steering, and record that R12's physics engine is unset and resolves to Godot Physics rather than Jolt.

## Round 1: GPT-6.1 Sol

Source post: round1-sol.md

### Round one: assisted bhop through a recoverable dam

Independent Sol proposal, 7 November 2026, against board `a0e2b62e`. I read the local instructions, revised board, brief and listed research, inspected the player/input/course/capture paths, and checked the primary sources linked below. I read no other round-one output. This is a recommendation, with no new gameplay execution or measurements.

#### The game I recommend

Make Spillway a **run-and-hop descent with assisted steering and optional strafe mastery**. Ordinary running, forgiving jumps and broad corrections should make a complete, active basic line. Better approaches and strafe hops earn speed that opens longer transfers and shorter routes. Remove mandatory surf, automatic mantle and crouch-slide from the first slice. They can return only with a specific job that ordinary running and jumping cannot do.

Recommend Godot for the experiment and, conditionally, the product. These are separate decisions. The experiment needs a trustworthy way to compare policies; the product needs convincing movement, presentation and native delivery. A successful experiment in Godot does not settle the second question.

Mike's enjoyment of VHOLUME and bhop authorizes this direction, but supplies no coefficients or diagnosis. VHOLUME's [official description](https://store.steampowered.com/app/4131730/VHOLUME/) emphasizes free traversal, momentum shortcuts and ghosts. Its [developer discussion](https://steamcommunity.com/app/4131730/discussions/0/563659628006802205/) says progression does not require proper bunnyhopping. That optional mastery is the useful design precedent. I have not played or reverse-engineered its motor.

##### One movement contract

All proposed rules and values below are **P / game choices**.

- Ground input accelerates to a competent run. Lateral grip bends travel without the target-vector chord loss in R12. Earned overspeed decays gradually while grounded; releasing input slows down, and sustained opposing input brakes before reversing. No instant pivot.
- Jump buffering, edge grace and optional held rehop forgive timing. A missed rehop remains a usable landing and subsequent jump. Landing friction has no discontinuity that makes a tiny timing error erase the entire chain.
- Air movement combines a broad projection accelerator with a separate, speed-neutral forward steering assist. Start the projection allowance at ordinary run speed, rather than R12's 0.75 m/s. Forward input bends horizontal travel toward its wish heading in the forward hemisphere, with angular rate bounded by lateral acceleration divided by speed. No keys means ballistic horizontal travel; looking alone never turns it.
- Side-only input retains projection-based strafe acceleration. Blend forward assistance by the forward contribution of W+A/D so overlaps do not switch control abruptly. Opposing S brakes; it cannot turn the velocity through 180 degrees at unchanged speed. There is no extra reward per radian of mouse movement or per landing.
- Descent may add tangent gravity while supported. Uphill motion pays for height. A lip carries the actual supported trajectory, rather than a launch bonus triggered by a speed threshold. A collision removes blocked velocity; a square wall hit must cost more than a graze. Steep faces are walls in this slice.

For the first isolated comparison, retain R12's run speed, jump impulse, gravity, body and camera. This controls nuisance variables; it is not a commitment to those values. Start assistance with a declared lateral-acceleration limit, then derive whether its turn radius fits the slice. Log each speed contribution separately: thrust, strafe acceleration, slope gravity, friction, braking, contact and emergency limiting. Avoid making descent, air strafing and contact bonuses all unexplained sources of energy.

The distinction from FLOW is material. A/D retains directional meaning and a strafe technique; every movement key does not simply enable following the view. The distinction from strict Source-like movement is also material: forward input can correct a jump without first learning to release W. These are original policy choices informed by the families described in [classic movement research](research/classic-movement.md), not a claim of CS, CPMA or VHOLUME fidelity.

##### The representative playable slice

Build one descending service loop from a crest gate to a safe pump apron. Start facing a visible lower landing and the turning wheel beyond it. A short broad approach lets the runner learn acceleration before the first physical decision.

The service walk descends into a broad bend. The basic line follows its outside, then crosses staggered slabs with gaps comfortably inside an ordinary jump's measured reach. The player chooses when to turn and whether to coast or brake before the second landing. A longer diagonal cuts across the bend: reaching it requires carried speed and a good takeoff, while landing leaves a meaningful correction before the next jump. Its destination is visible from the approach.

Below the diagonal sits a catch walk, not a reset volume. A late turn or short jump lands there, loses height and time, and gives a continuous ramp back into the next approach. Recovery must contain a decision and useful movement, rather than an empty corridor. A broad final landing leads to the apron; arrival visibly starts the wheel without requiring a collision with machinery.

Author the basic gaps from measured jump envelopes, leaving clearance for imperfect approaches. Author the shortcut beyond the basic envelope but inside an earned-speed envelope. No exact gap dimensions are inherited from the reference game. Replay comes from carrying speed through the bend, choosing the diagonal, and improving a previous line. A visible personal ghost can later demonstrate an achievable alternative. Completion never demands a medal time or the shortcut. Enjoyment remains a hypothesis until Mike plays.

#### What the comparison must distinguish

The board's measured W-turn contrast is real evidence about that gesture. It does not establish why Mike rejected R12. The local player also combines ground-vector chasing, overspeed decay, snap/contact classification and presentation. Changing all of them and calling the result an air-control fix would lose the useful evidence.

Use one calibrated block with matched starting pose, speed, support state and camera. Compare three policies, with the assisted bhop policy above as the proposed product direction:

| Policy | Where control and speed come from | What a different result would tell us |
| --- | --- | --- |
| Retained R12 | Small-cap projection acceleration; current ground/contact behavior | Reference behavior and reproducible failure, with no implication that its targets remain acceptance criteria. |
| Assisted bhop | Speed-neutral forward steering plus broad projection gain; deliberate braking and modest grounded losses | Tests whether ordinary correction and earned strafe speed can coexist without camera-led gain. |
| Terrain carry contrast | Bounded vector acceleration toward intent, turning that spends speed, no flat strafe gain; descent supplies overspeed | Tests whether line choice and recoverable momentum work better without a flat-ground bhop acceleration economy. This changes the game rule, not just air acceleration. |

Within the proposed policy, disable steering assistance and projection gain separately for diagnosis. Match ground loss before comparing airborne behavior. Match entry speed before comparing braking or turning. Then test complete policies on the slice, where their different costs are intentional. These switches are experiments, not a product menu of motors.

FLOW is useful existing experimental evidence. Separating speed and heading, retaining overspeed and letting the terrain matter are strengths. Its W-turn result demonstrates substantial steering authority. Its 38 passing checks establish its specified targets, not a preference vote. Whole-policy ground comparisons have unequal entry speeds; they cannot isolate braking quality. View-following with A/D may erase intended lateral movement, mouse-angle carve may reward wiggles, and generous steering may make route choice inconsequential. Its slope approximation and crest launch need energy/contact scrutiny. It inherits much of the collision and camera path, so it cannot independently clear either. Do not adopt FLOW wholesale or treat the separate cadence/contact challenge as a council candidate.

##### Experiments with decisions and stopping results

1. **Input and replay validity.** Prove the executor applies relative mouse deltas and key edges at its declared boundary. First reproduce the old helper's actual 30-render-sample constant turn, then label a higher-resolution tape separately. A dropped release and a mouse event missing `screen_relative` must produce detectable discrepancies. Stop calibration when applied-event ordering and repeated trajectories are explained within a tolerance smaller than the relevant landing clearance. If they are not, controller comparisons remain invalid; do not tune the motor around the runner.
2. **Steering versus speed.** From matched ordinary and overspeed starts, execute forward, diagonal, side, released and opposing input with the same smooth turn, overshoot and correction. Include mirrored turns. Measure travel heading, displacement and stopping distance, not just velocity magnitude. With gain disabled, steering must not mint speed. With assistance disabled, establish what the projection policy alone does. Reject the proposed combination if useful forward correction requires such strong assistance that the shortcut and basic line become equivalent, or key overlap causes an abrupt turn/brake transition. The stopping artifact is the paired response trace and a playable selection, not a winning speed number.
3. **Hop and energy policy.** Compare early buffered, held, late and missed hops at equal entry speed; compare slope/flat/uphill transitions independently of steering. A frictionless diagnostic descent must account for height and kinetic energy; intentional game losses are then labelled. Repeated flat crouch/jump/look cycles may gain only through the declared strafe rule. Stop when each observed gain/loss has an attributable cause and imperfect hopping still has a physical onward route. If slope handling remains unstable, remove slope energy for this slice rather than hide it with a boost.
4. **Contacts and recovery.** Approach the same slab edge, shallow seam, wall graze, square wall and ramp crest over the slice's actual speed range. Sweep approach position and input phase across the boundary that changes the outcome. Retain failures and minimize each tape. A supported line must not catch an invisible join, an apparent landing must correspond to collision, and a wall cannot report progress through velocity alone. If the failure survives a minimal lower-level sweep comparison, it becomes engine evidence. Stop at explained outcomes for these named contact families; this does not claim exhaustive collision coverage.
5. **The game loop.** Run the basic line without advanced strafe technique, the earned shortcut, and a missed-transfer recovery from normal spawn using imperfect tapes. Keep a separate held-out approach with altered landing position/readability. The shortcut must offer a measured route advantage, recovery must physically reconnect, and the ordinary line must contain meaningful contacts and choices. If the controller passes the block but the slice fails, change route affordance or presentation as its own experiment. Finish with one coherent build and unsuccessful evidence retained. Mike's optional asynchronous comparison can overturn the choice later; work does not wait for it.

These address acceleration/braking, earned-speed loss, ordinary control, hop timing, contacts and route readability. They leave Mike's causal preference unresolved. They also leave physical mouse latency, actual GPU display behavior and Windows execution unresolved unless measured on those paths. No replay recovers commercial-game constants.

#### Experiment platform and final engine

Use the installed Godot 4.7.2 for the controlled block and tape executor. Its [release archive](https://godotengine.org/download/archive/4.7.2-stable/) provides Linux/Windows binaries and export templates. Its [input API](https://docs.godotengine.org/en/4.7/classes/class_input.html) exposes event injection and input accumulation. That is a concrete experimental capability, not an endorsement of the inherited controller.

For the product, I recommend retaining Godot with an original motor and explicit collision policy, provided the slice survives the gates below. I would make the same recommendation for a fresh project with this scope: a single-player static-geometry traversal game needs direct kinematic control, inspectable input, asset import and native exports. All candidates can plausibly provide those. Existing exports reduce experiment cost, but do not excuse failed behavior or presentation.

The following compares specific documented surfaces, not reputations. Releases/docs were checked on 7 November; alternative editors were not installed or benchmarked.

| Candidate | Control and collision | Actual input/render cadence | Visual assets and agent iteration | Native delivery, licence and setup |
| --- | --- | --- | --- | --- |
| **Godot 4.7.2** | Scripted `CharacterBody3D` supports high-level sliding; lower-level `move_and_collide`/motion tests allow our own sweep/clip policy. Replacing `move_and_slide` can remove its grounding policy, but does not replace the physics backend. | Accumulation defaults on and merges OS events per rendered frame. Disabling it may improve responsiveness at CPU cost; 120 Hz physics alone proves neither input nor display cadence. Keep direct mouse rotation separate from interpolated body position. | glTF/GLB and FBX import; Compatibility and Forward+ are different rendering options. Plain scripts and headless fixtures support local iteration. Native rendering is still necessary. | MIT with notices/third-party obligations; native Linux/Windows supplied. Available locally without a new account. Current Windows packages are not proof of native Windows play. |
| **Unity 6.6, 6000.6.8f1** | Built-in `CharacterController.Move` constrains supplied displacement and does not supply gravity. A custom C# motor is possible. The separate Character Controller 1.4.5 package is ECS-based, not a drop-in replacement for that API. Either requires its own grounding/contact proof. | Input System 1.17.0 documents timestamped event injection/traces and dynamic/fixed processing. Fixed processing uses best-effort timestamp slicing. Neither `FixedUpdate` nor trace replay proves low latency. | Documented model import and URP offer a serious asset/render pipeline. C# fixtures and first-party ML-Agents offer useful test integration; project import, package alignment and edit/build iteration must be measured. | Linux editor/player and Windows player supported; the documented Linux distro list does not certify every host. Proprietary terms; Personal eligibility is conditional, and the Runtime Fee is cancelled. Hub licence activation needs sign-in. Windows Mono versus IL2CPP has different build prerequisites. |
| **Unreal Engine 5.8** | Character Movement exposes walking/falling/custom modes, braking and air control. A custom implementation can replace defaults. Its built-in policies are not automatically bhop policies. | Character movement accumulates input each frame. Physics substepping subdivides simulation and delays collision callbacks; it does not establish raw-input cadence or make the entire character/input/render loop fixed-step. | FBX mesh/material/animation import, Lumen and other renderer tools are real production capabilities. Automation Driver injects desktop input; raw captured-camera behavior and iteration cost remain to prove. C++ build/cook complexity is an experiment cost, not a handling defect. | Native Linux development and Windows delivery are supported workflows, but this Linux checkout has no demonstrated Windows packaging path for Unreal. Epic's documented Linux cross-compilation path is Windows-to-Linux. EULA/royalty terms, Epic sign-in and a substantial editor/toolchain setup differ from MIT. |
| **raylib 6.2 + Jolt Physics 5.6.0, C++** | Jolt `CharacterVirtual` gives collision-driven character motion with explicit update timing, gravity ownership, contact settings and optional stair/stick-to-floor operations. It is a credible different collision stack; integration may still reproduce our policy errors. | raylib exposes mouse delta and explicit input polling; default `EndDrawing` polls input. We must implement and measure the fixed-step accumulator, event timing and interpolation. Smaller does not mean lower latency. | raylib loads models, including glTF in the checked source, and supplies shaders/audio. We would own lighting/material conventions, scene tools, capture and lifecycle. Pure motor tests are straightforward; a finished asset pipeline is additional work. | Both libraries document Linux/Windows support. raylib's zlib-style licence and Jolt's MIT permit redistribution subject to their notices. No engine account needed; native compilers/build integration are still required. No combined Spillway executable or Windows build has been demonstrated. |

Primary contracts: [Godot body](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html), [lower-level source](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/3d/physics/physics_body_3d.h), [renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [formats](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [licence](https://godotengine.org/license/); [Unity release](https://unity.com/releases/editor/whats-new/6000.6.8f1), [Move](https://docs.unity3d.com/6000.6/Documentation/ScriptReference/CharacterController.Move.html), [ECS controller](https://docs.unity3d.com/Packages/com.unity.charactercontroller@1.4/manual/index.html), [input events](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.17/manual/Events.html), [requirements](https://docs.unity.com/en-us/engine/6000.6/manual/get-started/install-and-upgrade/getting-started-installing-unity/system-requirements), [model import](https://docs.unity.com/en-us/engine/6000.6/manual/assets-and-media/asset-types/models/importing), [pricing/eligibility](https://unity.com/products), [fee cancellation](https://unity.com/products/pricing-updates), [activation](https://docs.unity.com/hub/manage-license); [Unreal release](https://www.unrealengine.com/news/unreal-engine-5-8-is-now-available), [movement](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UCharacterMovementComponent), [substepping](https://dev.epicgames.com/documentation/en-us/unreal-engine/physics-sub-stepping-in-unreal-engine), [FBX](https://dev.epicgames.com/documentation/unreal-engine/fbx-content-pipeline), [Linux requirements](https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine), [Linux setup](https://dev.epicgames.com/documentation/unreal-engine/linux-development-quickstart-for-unreal-engine), [licence](https://www.unrealengine.com/license); [raylib release](https://github.com/raysan5/raylib/releases/tag/6.2), [API source](https://github.com/raysan5/raylib/blob/6.2/src/raylib.h), [model source](https://github.com/raysan5/raylib/blob/6.2/src/rmodels.c), [licence](https://github.com/raysan5/raylib/blob/6.2/LICENSE); [Jolt release](https://github.com/jrouwe/JoltPhysics/releases/tag/v5.6.0), [platforms/licence](https://github.com/jrouwe/JoltPhysics/tree/v5.6.0), [CharacterVirtual](https://github.com/jrouwe/JoltPhysics/blob/v5.6.0/Jolt/Physics/Character/CharacterVirtual.h).

##### What would disqualify the recommendation

Godot loses my recommendation if a slice-relevant contact defect persists in a minimal scene after separating our grounding policy from the lower-level collision query; if ordinary device input/frame pacing remains unsuitable after a measured scheduling correction; or if the required art cannot meet the chosen presentation/performance target on real hardware. Choose the target hardware, viewport and display cadence before that check. Passing on llvmpipe is not a substitute. Windows remains a delivery risk until a native run verifies input, capture/focus, save paths and rendering.

If the problem is high-level grounding, replace that layer inside Godot first. This is a competing implementation, not an obligation to save the engine. If lower-level collision is the reproduced blocker, the strongest bounded challenger is raylib/Jolt: reproduce the offending contact block, one ordinary jump/turn/recovery sequence, one representative textured view and the same tape protocol. Its material proposed benefit is a different contact implementation with explicitly owned scheduling. Refute the port if the defect persists, ordinary input differs unpredictably, or obtaining the visual/native-delivery result requires rebuilding more infrastructure than the benefit warrants.

If the blocker is specifically art workflow, Unity is the stronger challenger to prove on that same representative slice. Unreal deserves the same opportunity if its rendering capabilities solve the named visual need. Neither gets credit from a template screenshot or a port of acceleration equations alone. Do not build the full dam in every engine. This proposal requires no account, purchase, installation or service; any challenger implementation needing unavailable tooling is explicitly untested. An unresolved prerequisite is not evidence against that engine, and not permission to claim migration has passed.

#### The smallest useful AI loop

Implement one original finite tape executor and evidence recorder in the experiment build. Extend the existing helper rather than install a framework first. This is my selection from [AI-testing feasibility research](research/ai-game-testing.md), not an assumption that its proposed harness already exists.

The tape contains ordered key edges and relative mouse deltas with declared time/tick coordinates. Apply through ordinary input before the motor; acknowledge actual application and sample after motion. Never steer toward recorded yaw or waypoints. Fixture setup can seed exact state once and is explicitly separate from normal-spawn route evidence. Freeze the external helper with the pack; hashing only the PCK leaves a live-script hole.

| Evidence loop | Observation and action | What it earns |
| --- | --- | --- |
| Exact-state fixtures | Evaluator sees position, requested/resolved velocity, displacement and contacts; ordinary input after labelled setup | Policy/contact diagnosis and invariants. No discovery or enjoyment claim. |
| Open-loop tapes | Executor has only its finite schedule, including independent key timing and changing mouse rate | Reproducible transitions, sensitivity and perturbation effects without perfect state steering. |
| Pixel-only discovery | Fresh actor sees timestamped viewport history and permitted visible HUD, then proposes short tapes | Evidence that this actor can find a landing and recover. It receives no source, route arrays or evaluator files. |
| Adversarial exploration | Seeded mutations target the named contact/transition boundaries; evaluator minimizes failing tapes | Reproducible exploits and fragility. No population success rate or completeness claim. |
| Human judgment | Mike optionally plays distinct asynchronous builds with equivalent settings | His comparative enjoyment, comfort and preferences. Currently unverified. |

Keep paused planning and uninterrupted execution distinct. Pausing while a model thinks is useful for discovery. The first continuous loop should simply replay a finite tape with moving evidence; do not require model inference every tick. A future asynchronous visual actor needs measured observation age and action-arrival latency, a finite input lease and neutral input on starvation. It must report missed horizons rather than silently stop time.

Save submitted/applied events, motor boundaries, whole-step displacement, contact normals, camera pose, simulation/wall timestamps and timestamped frames. Record pack/helper/engine hashes, policy/geometry/presentation identities, renderer/adapter, sensitivity and input profile. Keep evaluator logs inaccessible to the pixel actor. Release owned controls on success, disconnect, timeout and cancellation; isolate profiles and displays. Replay stability is same-build evidence, not a claim of cross-platform determinism.

Stop the first implementation when it reproduces both a successful transition and a minimized failure, the deliberate input defects are detected, and normal completion/disconnect/timeout clean up correctly. If it adds no useful failure explanation over the current helper, claim reproducibility only. No aggregate score or arbitrary number of passed checks certifies the game.

I would defer Gua, RL training and general visual-agent frameworks. [Gua v1.1.2](https://github.com/gua-project/gua/releases/tag/gua-v1.1.2) is a real MIT-licensed Linux/Godot/Unity integration, but its [virtual clock](https://gua.orizika.com/virtual-clock/) explicitly does not control engine physics. The local research also identifies a relative-mouse-field integration concern. Unity's [ML-Agents installation](https://docs.unity3d.com/Packages/com.unity.ml-agents@4.0/manual/Installation.html) describes training setup and matched packages, not a pretrained Spillway tester. Neither is necessary to expose the next movement failure. Research-agent papers demonstrate methods under their own conditions; they do not supply enjoyment evidence for this game.

#### Presentation that makes the result legible

Begin policy comparison with shared camera, scale, light and truthful sound. Then run a presentation-only comparison on an unchanged motor/tape. Fixed FOV and restrained landing motion should remain available; do not mask poor turning with roll, shake or a widening lens. Input-to-camera CPU timestamps, render/present timing, physical device-to-photon latency and human comfort are different evidence. Ordinary capture-off runs on a real adapter can address some cadence questions; movie-mode simulation cannot.

Give concrete seams consistent physical spacing, handrails credible height, steel edges readable silhouettes and landings enough contrast against water. Preserve near-field structure for parallax. Keep decorative details out of collision proxies unless their solidity is visible. Use one restrained concrete/steel/water asset set with recorded source URL, licence, hash and scale changes. [Poly Haven's asset licence](https://polyhaven.com/license) permits CC0 reuse and redistribution; that does not make unrelated preview art or every marketplace asset interchangeable. Adopt assets individually rather than bulk-download a library.

Drive wind from measured travel speed and contact sounds from real supported motion/impact. Never add a celebratory acceleration cue when velocity did not increase. Use original sound or a verified redistributable source; listening quality remains unverified without listening. The finished slice should look and sound intentional, but its policy identity must remain visible so a nicer material does not become evidence for a better controller.

I would still change the revised brief to require an explicit choice of where speed is earned before selecting a motor: flat strafe technique, terrain, or a discrete traversal action.

## mike

No further input required for progress. This space remains available for steering.
