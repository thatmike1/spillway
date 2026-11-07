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

No round-one proposal or final engine selected. Round-one posts stay withheld until both members return.

## mike

No further input required for progress. This space remains available for steering.
