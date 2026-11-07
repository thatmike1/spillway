# AI game testing that can improve Spillway

Research checked 7 November 2026. This is feasibility research and a proposed acceptance experiment, not a report that any external agent has played Spillway. No framework was installed, no training was run, and no runtime was changed.

## Implement a timed input tape and moving evidence first

The smallest useful improvement is an engine-local executor for **time-varying keyboard and relative-mouse tapes**, with input-only replay, moving visual evidence, and explicit observation privileges. Keep both paused planning and uninterrupted playback. Use the existing subscription CLI/T3 model to propose short tapes and review image sequences; do not make model inference responsible for every physics tick.

This directly addresses the gap exposed by R12: a state-aware route can complete a motor that Mike does not enjoy. It also gives the new movement lab a common experiment format without deciding the engine. A migrated engine should implement this same external contract and run the same imperfect tapes.

**Gua is the most relevant downloadable integration to consider next**, especially for menus, practice, restart, records and semantic QA. It is not a ready-made movement judge. Godot RL Agents and Unity ML-Agents are training/environment toolkits, not pretrained playtesters. SIMA/SIMA 2 supply valuable design evidence but no public, locally runnable agent was established from the official sources reviewed. NitroGen does release weights, but its supplied Windows/gamepad runner and research-only licence make it a poor immediate match.

## What our tools actually do

Read against the working tree, including the momentum brief, all five requested helpers, the route driver, player motor and project settings. Copies and hashes are retained outside Git under `checkpoints/spillway/r13/research/ai-testing/sources/local/` in the outer build directory. The manifest identifies the inspection snapshot; a Git HEAD alone would not identify simultaneous working-tree edits.

| Surface | Verified live capability | Remaining limitation |
| --- | --- | --- |
| [visual-play.py](../../../tools/visual-play.py) | One held-key set, total mouse displacement and duration per request. Duration is rounded to 1–90 rendered frames at 30 fps, nominally up to 3 simulation seconds. | No different key edges or mouse curve inside a request; the shortest requested interval is a rendered frame, not a 120 Hz physics tick. |
| [visual-play.gd](../../../tools/visual-play.gd) | Applies `active.mouse / active.frames` on **every active `_process`**. This is a constant-rate continuous turn sampled at 30 rendered fps, not an instantaneous flick. Keys remain held across requests unless the next set releases them. | Captures only the ending decision view, then uses ordinary pause input and disables rendering while waiting. No uninterrupted observation/action loop or within-batch visual feedback. |
| [visual-play.sh](../../../tools/visual-play.sh) | Frozen PCK, external working directory, isolated `XDG_DATA_HOME`, dummy audio, offscreen native renderer, `--fixed-fps 30`. | The controlling GDScript is loaded from the live checkout outside the frozen PCK. Pack hash alone is insufficient provenance. Fixed-FPS execution and render suppression cannot measure ordinary wall-time performance. |
| [capture-route.gd](../../../tools/capture-route.gd) | Runs an input-driven route, captures moving output, holds three simulation seconds after finish, and optionally verifies real record persistence in a fresh profile. | Its route is privileged. Optional finish-look reads the wheel/camera/body geometry to aim ordinary mouse input. Useful evidence, but not visual discovery. |
| [surf_motor_driver.gd](../../../tests/surf_motor_driver.gd) | Generates ordinary action/mouse events; exact 120 Hz stepping; detailed contacts and state; records samples and offers replay. | `strafe`, `surf` and targeting read exact velocity, position, constants or targets. `replay()` reads current yaw/pitch to reach recorded **absolute orientations** each tick. It is not yet a tape of the original relative mouse deltas. |
| [spillway_driver.gd](../../../scripts/spillway_driver.gd) | Uses ordinary input, perturbs approaches and logs outcomes. | Reads `level.routes`, checkpoint geometry and exact body state. Its own log describes distance-triggered route progression rather than time replay. Input-only actuation does not imply human-like knowledge. |

Three consequences matter:

1. Preserve the helper's existing constant-rate turning. The missing capability is time-varying turning, independent key timing and continuous evidence, not simply “add mouse input.” At 120 Hz physics and 30 Hz rendering, several physics steps can share one camera update. Record that cadence rather than equating a render frame with a physics tick.
2. The Python response filters out feet, velocity and orientation, but `response.json` and `input-and-state.jsonl` retain them. A screenshot-only actor that can read those files still has privileged information. Separate actor observations from evaluator logs and deny access, rather than relying on a filtered terminal printout.
3. `await tree.physics_frame` resumes at a signal documented as occurring **before** node physics processing. Establish explicit pre-input/post-motor sampling boundaries; do not assume the existing `_record()` is a post-step observation. This is an ordering concern from the source, not a measured R12 failure. [Godot SceneTree contract][godot-tree]

## Available tools: what is executable and what is a result

“Feasible here” below means the published interface and platform fit a bounded local integration. It does not mean installed or verified in Spillway. Source pins, licences, paper text and selected documentation captures are in the outer source-study directory.

| Candidate | Distribution and licence verified | Engine/platform and interface | Decision for Spillway |
| --- | --- | --- | --- |
| Our small tape executor | Original project code; no new service or model dependency | Existing Godot Linux/native pipeline; versioned JSON input and evidence | Implement first. Supplies the missing control/evidence experiment directly. |
| **Gua** | MIT; latest GitHub release found: `gua-v1.1.2`, including Godot add-on and native Linux x64 packages. Public docs still label themselves v1.1.0. | Godot 4.7 GDScript + GDExtension; Unity 6000.5+ Mono desktop. WebSocket, MCP, WebMCP and .NET testing. | Best external candidate for semantic QA; source-level mouse compatibility issue and timing limits need a spike. |
| **Godot RL Agents** | MIT Python library and Godot plugin; public source/examples | Godot 2D/3D; Python/TCP environment, custom sensors/actions, several RL backends; Windows/macOS/Linux documented | Useful if we later need many learned adversarial policies. Integration and reward design are substantial; no ready Spillway policy. |
| **Unity ML-Agents** | Apache-2.0 toolkit; Unity itself has separate terms. Official package docs reviewed identify 4.0.3 / Unity 6000.0+. | Unity, C# Agent/sensors/actions, Python low-level API, local training and embedded inference; desktop workflows documented | A real Unity advantage for learning infrastructure, not an engine-selection argument by itself. Does not instrument Godot. |
| **AltTester CLI / AI Extension** | Unity SDK has GPL-3 and commercial non-GPL options; CLI/AI extension requires a supporting commercial licence, currently Pro. | Instrumented Unity/Unreal, CLI/MCP/SDK. Linux server/CI paths documented; desktop download links reviewed are Windows/macOS. | Consider only for an engine change plus commercial tooling decision. No documented Godot SDK in the reviewed product docs. |
| **GameDriver** | Proprietary subscription/EULA; download portal requires sign-in and EULA acceptance | Embedded plugin, remote API, hierarchy/property access and Test Assistant MCP. Official site claims Godot; current public compatibility matrix/downloads do not establish its Godot version/platform package. | Godot support remains a **vendor claim with incomplete practical evidence**, not “unsupported” and not “ready here.” |
| **Cradle** | MIT framework/source; shipped model providers require API credentials | Screens/video to keyboard/mouse skill code; per-game configuration. Supplied window-control code supports Windows/macOS and rejects Linux paths; RDR2 setup is Windows-only. | Borrow action chunks, memory and reflection. Adopting it here requires platform/game/provider work and would otherwise add paid APIs. |
| **SIMA / SIMA 2** | Papers, project material and demonstrations; no public trained-agent download or usable local runtime licence established | Research agents consume images/instructions and emit keyboard/mouse actions; commercial and research environments | Architecture evidence, not an installable test dependency. SIMA 2's official announcement describes limited research access. |
| **NitroGen** | Public code and downloadable `nvidia/NitroGen` weights. NVIDIA licence restricts use to non-commercial research; not MIT/Apache. | Pixel-to-gamepad model. Supplied game runner Windows-only; inference server can be Linux. | Stronger availability than SIMA, worse control/platform fit for Spillway. No new Windows/gamepad/training project in the critical path. |
| **Hypothesis, optional** | MPL-2.0 Python property-based testing library | Engine-independent generator/shrinker; our runner would execute generated tapes | A smaller adversarial-testing option than RL once replay and objective failure signals work. Not a visual player. |

Distribution evidence: [Gua release][gua-release], [Gua licence][gua-license], [Godot RL README/licence][gdrl], [Unity licence][unity-license], [Unity installation][unity-install], [AltTester pricing/licensing][alt-pricing], [AltTester CLI][alt-cli], [GameDriver technology][gdio-tech], [GameDriver compatibility][gdio-pam], [Cradle repository][cradle], [SIMA 2 announcement][sima-blog], [NitroGen repository][nitro], [NitroGen model/licence][nitro-model], [Hypothesis licence][hyp-license].

### Gua is a useful semantic layer, with two movement-specific traps

Gua exposes a semantic UI tree, explicitly published world objects, opt-in gameplay actions and raw keyboard/pointer/gamepad input. The Godot adapter injects raw input through `Input.parse_input_event`. A Player profile limits approved information/actions; a Debug profile is intentionally richer. Native MCP can connect an existing model toolchain without requiring a new hosted model API. Semantic access is still privileged relative to screenshots, even when named “Player.” [Input guide][gua-input], [Godot integration][gua-godot]

**Source-level compatibility trap:** the released v1.1.2 Godot pointer-relative branch assigns `motion.relative`, then parses the event, without assigning `motion.screen_relative`. Spillway's `_unhandled_input` reads `screen_relative`. Godot's setters keep these fields separately. A tiny headless event-object probe on the installed `4.7.2.stable.official.ed1daf0bf` confirmed that setting `relative = (120, -40)` leaves `screen_relative = (0, 0)`; assigning both fields preserves the requested values. The probe and output are in the outer source-study directory as `mouse-field-probe.gd` / `.log`. It loaded no game, injected no input and operated no desktop devices. This corroborates the source concern, but this research did not execute Gua itself. Treat that path as an unresolved camera-input integration defect until a native integration test proves requested relative motion produces expected yaw and pitch. [Released adapter, around line 1202][gua-adapter], [Godot setter source][godot-input-source]

**Timing trap:** GuaClock only controls logic migrated to its clock. Official docs explicitly exclude physics, animation, audio and native timers unless appropriate logic is migrated. It cannot pause or step Spillway physics merely by installing a clock. Ordinary recording/MCP replay waits for each completion. Its explicit .NET Timed Segment extension separates scheduled send offsets from completion waits, with FIFO ownership, finite budgets and cleanup. The stock local runtime host supports realtime game input; the contract rejects unsupported simulation time, strict application timestamps and same-tick atomicity. It is not a ready remote tick-tape API for our Godot external test client. [Clock scope][gua-clock], [Recording guide][gua-record], [Timed Segment contract][gua-timed]

Adoption gate: verify Linux add-on loading, restart/practice/record selectors, raw relative-mouse response, disconnect releases, and which actual input-application timestamps are observable. Pin add-on/native/npm/.NET versions together. Use Gua for semantic regression if this reduces maintenance; do not replace the working movement runner solely to obtain MCP.

### RL toolkits can discover exploits, but their default environment changes the question

Godot RL Agents supplies custom observations, rewards, reset logic and actions; observations can be vectors, raycast sensors or RGB cameras. We choose whether those actions call the ordinary player input path or directly control a body. Only the former tests the player controller. Its stock Sync pauses the tree to exchange actions and repeats actions over physics steps. Both the inspected current plugin and the older plugin commit referenced by the Python repository set `Engine.physics_ticks_per_second = speedup * 60` and `Engine.time_scale = speedup`. Spillway is configured for 120 Hz. Preserve that motor contract explicitly before comparing results. The Python checkout's submodule pin and plugin default branch differ, so do not assemble an arbitrary combination. [Custom environment][gdrl-custom], [Current Sync][gdrl-sync], [Python checkout's pinned Sync][gdrl-pinned]

Unity ML-Agents similarly offers vector/visual sensors, discrete/continuous actions, action repetition and model inference. Python `env.step()` advances until an agent needs a decision; it is not one Unity `Update` or `FixedUpdate`. Its engine configuration channel controls time scale/rendering, and the source warns increased time scale can break physics. A learned policy can eventually run locally without a language-model call per action, but training, state/action instrumentation and a reward that does not reward exploitative nonsense must first exist. No cloud training is inherently required; no trained Spillway policy is provided. [Agent design][unity-agents], [Low-level API][unity-llapi], [Configuration source][unity-config]

For this run, seeded tape mutations plus objective invariants offer a shorter route to boundary failures. If later training is justified, keep training layouts/rewards separate from final holdouts, disclose state privileges, and replay discoveries through ordinary input in the unmodified playable build. A route-perfect policy establishes neither readable landings nor approachable controls.

### Commercial automation is mostly semantic control, not autonomous feel testing

AltTester CLI can inspect scenes/properties, hold/release keys, move a cursor and set time scale. Its AI extension adds skills/MCP to an instrumented Unity/Unreal app. Cursor screen-coordinate movement is not evidence of correct captured relative FPS camera motion. Time scale is not a guaranteed fixed-step/replay contract. Both need validation in the chosen engine. The licence/account requirement is a new prerequisite; it is not covered by a model subscription. [CLI commands and AI licence notes][alt-cli], [Plans][alt-pricing]

GameDriver's published technology is an embedded plugin with access to hidden runtime state; its MCP includes generic API dispatch and property exploration. This is valuable semantic QA and potentially useful input control, but its engine/platform-specific timing and raw-camera guarantees need proof. Its public 2026.08 matrix lists Unity/Unreal, while marketing and an MCP API description mention Godot. The download portal reviewed exposes Unity/Unreal packages and Windows/macOS Test Assistant, with sign-in/EULA required. Ask for the actual Godot 4.7 Linux package/API/timing demonstration before costing it into an experiment. No contact or account creation was performed. [Technology][gdio-tech], [MCP documentation][gdio-mcp], [Availability matrix][gdio-pam], [Download portal][gdio-downloads]

### Research agents provide patterns, not a free tester we can summon

Cradle's paper explicitly says RDR2 and Stardew Valley were paused during model inference/communication; other environments ran continuously. It records observations at 2 fps and plans executable keyboard/mouse skills, with reflection and memory. This supports a slow planner over fast action chunks, not a claim that a general VLM can continually steer a high-speed first-person motor. The public repository requires configured API providers and a new-game migration. A subscription CLI adapter would be our work. [Authors' paper, implementation details][cradle-paper], [Repository/setup][cradle]

SIMA demonstrates screen/instruction-to-keyboard/mouse learning, with latency-aware training and buffered scheduling in environments that run asynchronously. SIMA 2 consumes 720p images and emits action chunks; it is a specially trained Gemini Flash-Lite-based agent, not ordinary Gemini with a play-game prompt. Both papers separate ground-truth/programmatic/human evaluation. SIMA 2 still reports limitations in precise low-level control and long-horizon tasks. These are useful precedents for separating actor observations from evaluator privileges and for measuring asynchronous latency. No public weights/SDK suitable for local Spillway use was established. [SIMA report, §§3.4–3.4.1][sima1], [SIMA 2 report, §§3.2–3.4 and limitations][sima2], [Access statement][sima-blog]

NitroGen is a concrete counterexample to “all this is closed research”: its weights and inference code are public. However, the authors describe the current 500M model as last-frame-only, without long-horizon planning or end-to-end play of completely unseen games. It predicts gamepad trajectories. The provided `GamepadEnv` asserts Windows and the supplied play loop pauses between chunks/inference. Linux inference hosting does not turn it into a Linux game runner or prove wall-time real-time control. Using it would require a new gamepad mapping, runner and measured inference performance, with research-only licensing. [Repository limitations][nitro], [Runner source][nitro-runner], [Play loop][nitro-play], [Model card][nitro-model]

Two additional sources sharpen the test design rather than add a framework:

- GameLogicBench's authors use per-tick assertions, hidden scenarios and deliberately defective variants to check that judges reject incorrect behavior. Their public repository exists, but no repository licence was declared in the metadata/root files reviewed. Borrow the evaluation principle, not unlicensed code. It assesses game logic, not motor enjoyment. [Paper][logic-paper], [Authors' repository][logic-repo]
- Hypothesis can generate and shrink stateful action sequences. Our tape format and failure oracle would provide the game-specific integration. It cannot identify a collision or perception defect without a trustworthy assertion, and shrinking a timing-sensitive bug must preserve its reproduction conditions. [Official stateful testing docs][hyp-stateful]

## Six methods answer six different questions

| Method | Actor sees / does | Evidence it can supply | What it cannot establish |
| --- | --- | --- | --- |
| **1. Physics invariants** | Exact state, known fixture geometry; controlled initial conditions and player input | Finite state, collision envelopes, acceleration/braking response, landing/contact continuity, input-to-displacement causality | Route legibility, discovery, ordinary error tolerance, enjoyment. Test setups must be labelled if they place/reset a body. |
| **2. Imperfect open-loop tapes** | Fixed relative mouse deltas and key edges, chosen before execution; no live state correction | Repeated actual-input behavior, sensitivity to late jump/overshoot, recovery, camera/motor coupling, regressions across candidates | Intelligent adaptation or first-time discovery. A perfect bot's recorded tape remains a bot-derived example, even when replay is open-loop. |
| **3. Screenshot/video-only discovery** | Player viewport/history and permitted visible HUD; ordinary input only | Whether one model finds a route, notices landings/hazards, recognizes being stuck and recovers within a stated budget | Population playability or enjoyment; model failure may be perception/planning failure. Paused inference cannot establish live reaction ability. |
| **4. Semantic/privileged QA** | Named UI/world objects, logs and approved internal state; sometimes setup/state writes | Restart/practice/finish/save flows, UI regression, lifecycle correctness, failure diagnosis | Visual readability or source-blind discovery. Knowing a hidden landing position defeats that question. |
| **5. Adversarial boundary exploration** | Seeded tape mutation or a policy optimizing a failure/novelty signal; privileges declared | Stuck corners, seams, high-speed clipping, early/late transitions, surprising state combinations and minimized repros | Representative human behavior or completeness. A coverage/reward measure can be gamed too. |
| **6. Real performance, latency and human feel** | Uninterrupted normal build, actual event/render timing, eventually Mike's ordinary play | Frame/input timing, sustained rendering, reactions/recovery in wall time; human comparative judgment | Offscreen fixed-FPS movies cannot certify native display/input latency, Windows execution or enjoyment. AI completion alone cannot certify fun. |

These should remain separate result fields. Do not combine them into a single “AI playtest passed” flag. Preserve useful R12 invariants while retiring surf-specific assumptions that no longer express the chosen motor.

## A minimal implementable control/evidence contract

This is a proposed extension of the existing runner, not an implementation already present.

### Execute time-varying input without perfect steering

- Accept a versioned finite tape containing a tick rate, initial input state, and ordered events: tick/offset, key press or release, relative `dx/dy` in screen pixels. Optional piecewise curves must expand to explicit per-tick deltas **before** execution. Log both the submitted plan and the applied events. Apply input before the motor and sample state after it, with an ordering check.
- Preserve two labelled input profiles: the existing 30-render-fps constant-rate path for baseline parity, and a 120 Hz scheduled tape for independent key edges and mouse curves. A richer executor must not silently change the sampling assumptions of an old test.
- Replay the **applied relative input**, not recorded absolute yaw, velocity or waypoints. Sensitivity, pitch clamp and normal camera processing remain part of the tested build. Record initial orientation and sensitivity as setup metadata, but do not correct orientation every tick. Clip the same way real input does; never normalize a future tape using the body's current speed or aim.
- Include a smooth turn with acceleration/deceleration, a brief mouse stop, an overshoot and correction, and key edges that do not coincide with camera segments. Add seeded timing/aim perturbations to those tapes. “Human-like” is a hypothesis about these imperfections, not a claim that random noise reproduces humans. Eventually record real human tapes through the same event contract when Mike chooses to play.
- Allow restart/practice only as logged control events or declared fixture setup. No runtime pose/velocity/finish writes in the input executor. Keep exact-state fixture setup as a separate method.

Godot supports event injection and has explicit accumulated-input behavior; `screen_relative` avoids stretch-scaling changes in captured mouse aiming. Engine-level injection still bypasses the OS/device path, so it does not test real pointer capture, keyboard layout, focus or high-poll-rate hardware behavior. Pin those assumptions and verify the ordinary device path separately. [Input reference][godot-input], [Mouse-motion reference][godot-mouse]

### Keep world time, model time and observation time explicit

Provide two execution modes using the same tape:

1. **Paused planning:** capture a short visual history, pause at an acknowledged physics boundary while the model thinks, then run a finite tape with normal physics. Model inference time is excluded from simulation time and reported separately. This is useful visual reasoning under relaxed reaction time.
2. **Uninterrupted:** execute locally without per-request pauses, with bounded input leases, asynchronous frame capture and a finite queued tape. The planner can propose the next chunk while the executor runs. If no approved chunk arrives in time, neutralize input and record starvation; do not silently freeze the world or hold W indefinitely. The run is unsuccessful as a real-time control trial if inference repeatedly misses the horizon.

The first useful continuous mode is **uninterrupted tape replay with continuous evidence**. Real-time closed-loop visual steering is an additional capability requiring measured inference latency, not a prerequisite for implementing replay.

For perception, retain a rolling sequence of timestamped viewport frames; send a modest ordered sample/contact sheet to a model that accepts images. Encode full-rate video as review evidence if practical. Do not assume the subscription CLI accepts arbitrary video; an ordered set of image frames is enough for the first version. Associate every frame with simulation tick and capture wall timestamp. Record requested capture time versus completed readback, dropped frames and encoding load. Capture can affect performance, so benchmark capture-on against capture-off.

Measure image capture → submission → first usable action → host application, with median/p95 latency and observation age at application. No inference speed for the existing subscriptions was measured here. An illustrative 0.2 seconds at 25 m/s is already 5 metres of travel; 2 seconds is 50 metres. Scheduling can preserve a preplanned turn during that delay; it cannot discover a new obstacle from a future frame. A local fast policy/controller may later close that gap, but its observation privilege and training remain separate claims.

### Measure actual movement and bounded recovery

Record requested/applied input, position before/after the motor, actual displacement over the step, requested/post-collision `velocity`, `get_real_velocity()` / `get_position_delta()` where applicable, contacts, camera transform, simulation delta and wall delta. Godot explicitly distinguishes requested velocity from the real diagonal motion produced on a slope. Spillway also edits velocity after `move_and_slide`, making whole-tick finite differences useful alongside engine getters. Speed HUD/`get_speed()` alone is not a displacement measurement. Separate reset/respawn discontinuities from physical travel. [CharacterBody3D contract][godot-body], [Current motor](../../../scripts/spillway_player.gd)

Stuck detection should be evidence-specific: the evaluator can flag sustained movement input with very low actual displacement over a bounded interval, excluding pauses, deliberate braking, landings and menus. The screenshot actor can independently flag near-identical views or repeated failed actions. Log which detector fired. Looking around is not world progress. Save the preceding visual/input window, allow a bounded recovery attempt, then stop or restart visibly. Do not quietly teleport out, retry until success, or discard failed attempts.

### Make the result attributable and clean up reliably

Each run needs a fresh evidence directory and profile, separate from Mike's records and R12. Record build identity, source manifest/dirty diff, PCK/executable/engine hashes, **external controller-script hash**, tape schema/hash, perturbation seed, observation policy, model/effort when used, timing mode, physics rate, renderer, viewport, sensitivity and platform. Prefer freezing the helper beside the pack; never infer that a frozen pack freezes a live external script. Label normal-spawn runs separately from practice/fixture starts.

Give an actor only images and permitted feedback. A fresh actor context must not receive controller source, route arrays, exact state logs or holdout design. Evaluator logs may retain all that for diagnosis. A source-reading agent cannot become an independent novice merely by promising not to use what it has read. Use fresh held-out layouts/tapes and separate evaluators for independent claims.

At success, failure, timeout, cancellation, disconnect and quit: release every owned key/button, clear queued motion, flush/close logs, stop only the owned process group, and confirm the child exited. Use an isolated display rather than global desktop input. Set a wall-time deadline as well as a simulation budget; a paused world must not disable cleanup. Do not alter the user's display/audio settings. Any future Gua/MCP listener belongs in an explicit test build/profile, bound locally and closed afterwards.

## Acceptance experiment: prove a better harness, not a fun game

Freeze the runner protocol and these criteria before tuning the motor to their results. The movement lab can supply the scenes; it should not need to change its movement policy to make the harness pass.

### Baseline, richer input, then discovery

Use R12 plus one new candidate with distinct build IDs. Use four short cells: flat acceleration/braking; a turning slope; jump/landing with an imperfect approach; and collision/recovery near a seam or boundary. Establish ordinary input starts, not a bot's solved route. Keep two cells public for development and two independently prepared variants hidden until evaluation. Holdouts should change an approach/geometry/visual cue, not merely rename a seed on identical authored guidance.

Run three paired conditions:

| Condition | Input and timing | Purpose |
| --- | --- | --- |
| A: current helper | Existing held-key/constant mouse batches and paused ending screenshots | Preserve the honest baseline and count requests/observations. |
| B: new tape, paused planning | Same simple batches first, then variable mouse/key tape; pause only between finite chunks | Verify compatibility, richer control and moving evidence without conflating model inference latency. |
| C: uninterrupted replay | Replay B's **applied event tape**, normal wall-time advancement, moving capture | Expose temporal transitions and prove the local loop does not depend on waiting for a model. |

For baseline-compatible actions, first match the existing render/input cadence in B. Require the same effective applied-event sequence and equivalent post-step results within a predeclared numerical tolerance. Resolve boundary/order discrepancies instead of attributing them to the motor. Then evaluate the 120 Hz tape as a separate input profile. The old helper could approximate a rich tape with many tiny requests; the measurable benefit is expressing it once, keeping playback uninterrupted, and retaining the transitions, not claiming the old helper cannot turn.

Use five predeclared perturbation seeds per cell/build/condition, including early/late jump, delayed strafe release and an overshooting mouse curve. Count every attempt. Re-run representative identical tapes three times to establish actual replay stability; do not assume cross-platform floating-point determinism. Freeze the accepted equivalence tolerance after measuring an unmodified repeated baseline, before comparing candidate improvements.

Next, run fresh screenshot-only actors on the public cells and independent holdouts. Give each condition the same instruction, model/effort, maximum simulated exposure and a budget of 12 plan revisions per episode, with three independent episodes. A may receive up to the same number of visible frames as B, but only those the current helper can capture. Actors get no lab coordinates or motor source. Their job is to attempt a visible landing and recover, not maximize a hidden score. Compare first-attempt progress, failures/recoveries, stuck events, action count, simulated time, wall time and evaluator-verified outcomes. This is evidence about this model/interface, not a human success rate.

### Objective harness acceptance

- **Control:** an input-only tape performs a time-varying turn and independent jump/strafe edges with no state steering; the trace proves when they were applied. Tick-mode input applies at its declared boundary. Wall-time mode reports late events rather than claiming tick accuracy.
- **Replay:** the saved applied tape reproduces its failure/success on the same frozen build/profile across repeated runs within the declared tolerance. Changed sensitivity must change the resulting view as ordinary relative input would; it must not be corrected back to recorded yaw.
- **Evidence:** moving capture shows the approach, contact and recovery, with synchronized actual displacement. A stationary-against-wall case cannot count as progress solely because a velocity/speed value is high.
- **Negative controls:** in isolated disposable test variants, deliberately drop a key-release edge, omit mouse `screen_relative`, and create a false progress/speed report. The harness must distinguish input-delivery/timing failure from movement failure, detect the camera mismatch, and reject the false progress claim. These variants are proposed judge validation, not edits made by this research.
- **Cleanup:** normal end, client disconnect and wall-time timeout each leave neutral input and no owned game process/listener. Profile hashes confirm Mike's records and preserved R12 were untouched.
- **Value over A:** retain at least one reproducible transition/input/perception failure or candidate difference that A's ending snapshots did not explain, with a minimal tape and moving evidence. If no such case appears, report improved reproducibility/control only; do not claim better discovery or movement.

For an asynchronous model trial, first measure latency using real observations. Run with a stated finite action horizon, record starvation/staleness, and accept “not real-time feasible with this model cadence” as a valid result. Uninterrupted tape playback passing does not imply uninterrupted visual control passed.

The final artifact should be a small comparison with linked clips, exact tapes and failure counts, including unsuccessful episodes. AI completion, a higher coverage score or more motor speed is not an enjoyment acceptance gate. Mike's eventual comparison of playable candidates remains the feel judgment; work need not wait for that judgment to improve the evidence.

## Engine implications for the council

**Testing does not presently force an engine switch.** Godot already exposes the input/render/physics surfaces needed for the smallest proposed loop, and Gua explicitly targets Godot 4.7. The unresolved work is accurate scheduling, observation isolation and trustworthy evidence, which survives any engine choice.

Unity offers a maintained first-party RL toolkit, visual/vector sensors, local inference and a broader documented commercial automation route. That matters if learned adversarial agents become central. It does not eliminate reward design, grant access to SIMA, or prove the resulting controller feels better. Unity itself, packages and build tooling introduce their own prerequisites.

Unreal has native Automation Driver keyboard/mouse simulation and Experimental Learning Agents for reinforcement/imitation learning. These are concrete integration surfaces, not a pretrained tester or a guarantee about Linux/captured-mouse behavior. The current Learning Agents API still identifies the plugin as Experimental; old Windows-only tutorial statements must not be promoted to a current platform verdict. Verify the exact chosen release/platform in a spike. [Automation Driver][ue-driver], [Learning Agents API][ue-learning]

An original/custom engine can implement the same small tape/viewport/state-evaluator protocol, but must supply its own capture, scheduling, lifecycle and collision evidence. Engine-independent screenshots avoid an SDK dependency; semantic adapters and RL environments remain engine-specific work.

For each serious engine candidate, ask for the same bounded proof: ordinary relative mouse/key tape; post-collision actual displacement; native moving capture; fresh-profile replay; an unanticipated boundary failure; and a capture-off wall-time check. Compare motor/collision authority and iteration with that evidence. Do not score engines by marketing integrations, by a privileged bot finishing, or by whether a paper happened to use that engine.

## Sources and reproducibility

Primary sources were read through `oc`, official source downloads and the authors' papers. DDG returned a bot challenge and Bing returned unrelated results; harness search was used to locate primary pages. Repository pins and downloaded-file hashes are retained in the outer `checkpoints/spillway/r13/research/ai-testing/sources/` directory. Bulky paper PDFs were removed after text extraction; their URLs and original download hashes remain in `supplementary-sources.json`. The only execution was the isolated headless mouse-field value probe described above. This research did not validate vendor performance claims, install SDKs, create accounts, use paid APIs or run gameplay/training.

[gua-release]: https://github.com/gua-project/gua/releases/tag/gua-v1.1.2
[gua-license]: https://github.com/gua-project/gua/blob/gua-v1.1.2/LICENSE
[gua-godot]: https://gua.orizika.com/godot/
[gua-input]: https://gua.orizika.com/game-input/
[gua-clock]: https://gua.orizika.com/virtual-clock/
[gua-record]: https://gua.orizika.com/recording/
[gua-adapter]: https://github.com/gua-project/gua/blob/gua-v1.1.2/examples/godot-gdscript/addons/gua/gua_auto_adapter.gd#L1192
[gua-timed]: https://github.com/gua-project/gua/blob/gua-v1.1.2/protocol/specs/timed-segment-v1.md
[gdrl]: https://github.com/edbeeching/godot_rl_agents/tree/207b6f476f5846f33d08b92c7a350147e7b78bf5
[gdrl-custom]: https://github.com/edbeeching/godot_rl_agents/blob/207b6f476f5846f33d08b92c7a350147e7b78bf5/docs/CUSTOM_ENV.md
[gdrl-sync]: https://github.com/edbeeching/godot_rl_agents_plugin/blob/998c357a0cd09b37f40a36d70c7867fc9f682338/addons/godot_rl_agents/sync.gd
[gdrl-pinned]: https://github.com/edbeeching/godot_rl_agents_plugin/blob/3984fd124a2b941a446f4614bb0eacd09a2468f5/addons/godot_rl_agents/sync.gd
[unity-license]: https://github.com/Unity-Technologies/ml-agents/blob/4649106d09088a6135397e0f8ed7015ec600834a/LICENSE.md
[unity-install]: https://docs.unity3d.com/Packages/com.unity.ml-agents@4.0/manual/Installation.html
[unity-agents]: https://github.com/Unity-Technologies/ml-agents/blob/4649106d09088a6135397e0f8ed7015ec600834a/com.unity.ml-agents/Documentation~/Learning-Environment-Design-Agents.md
[unity-llapi]: https://github.com/Unity-Technologies/ml-agents/blob/4649106d09088a6135397e0f8ed7015ec600834a/com.unity.ml-agents/Documentation~/Python-LLAPI.md
[unity-config]: https://github.com/Unity-Technologies/ml-agents/blob/4649106d09088a6135397e0f8ed7015ec600834a/ml-agents-envs/mlagents_envs/side_channel/engine_configuration_channel.py
[alt-cli]: https://alttester.com/docs/desktop/v.2.4.0/pages/alttester-cli.html
[alt-pricing]: https://alttester.com/pricing/
[gdio-tech]: https://gamedriver.ai/technology
[gdio-pam]: https://kb.gamedriver.ai/gamedriver-product-availability-matrix
[gdio-mcp]: https://kb.gamedriver.ai/gamedriver-mcp-configuration
[gdio-downloads]: https://portal.gamedriver.io/downloads
[cradle]: https://github.com/BAAI-Agents/Cradle/tree/d7752fccf890d8d3818cd1d435f3705f604a1339
[cradle-paper]: https://arxiv.org/abs/2403.03186
[sima1]: https://arxiv.org/abs/2404.10179
[sima2]: https://arxiv.org/abs/2512.04797
[sima-blog]: https://deepmind.google/blog/sima-2-an-agent-that-plays-reasons-and-learns-with-you-in-virtual-3d-worlds/
[nitro]: https://github.com/MineDojo/NitroGen/tree/32608444660950ffda95e1e57c79632ad65bea10
[nitro-model]: https://huggingface.co/nvidia/NitroGen
[nitro-runner]: https://github.com/MineDojo/NitroGen/blob/32608444660950ffda95e1e57c79632ad65bea10/nitrogen/game_env.py
[nitro-play]: https://github.com/MineDojo/NitroGen/blob/32608444660950ffda95e1e57c79632ad65bea10/scripts/play.py
[logic-paper]: https://arxiv.org/abs/2609.21562
[logic-repo]: https://github.com/NJU-LINK/GameLogicBench
[hyp-license]: https://github.com/HypothesisWorks/hypothesis/blob/master/LICENSE.txt
[hyp-stateful]: https://hypothesis.readthedocs.io/en/latest/stateful.html
[godot-input]: https://docs.godotengine.org/en/4.7/classes/class_input.html
[godot-mouse]: https://docs.godotengine.org/en/4.7/classes/class_inputeventmousemotion.html
[godot-input-source]: https://github.com/godotengine/godot/blob/4.7.2-stable/core/input/input_event.cpp#L944
[godot-body]: https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html
[godot-tree]: https://docs.godotengine.org/en/4.7/classes/class_scenetree.html#signals
[ue-driver]: https://dev.epicgames.com/documentation/unreal-engine/automation-driver-in-unreal-engine
[ue-learning]: https://dev.epicgames.com/documentation/en-us/unreal-engine/API/PluginIndex/LearningAgents
