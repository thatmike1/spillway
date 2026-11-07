# Movement, engine and agent testing council

## Decision

Choose an engine and control/testing approach for the next playable Spillway iteration after Mike rejected R12 feel. The engine and original movement policy are open. The council must name the smallest experiments that distinguish its recommendations and what result would change its mind.

Named forks, none selected:

- Keep Godot and replace control/collision policy where needed, retaining or changing the current scene.
- Build the representative slice in Unity with an appropriate custom or available kinematic controller.
- Build it in Unreal with a suitable movement implementation.
- Use a smaller native or web engine/custom controller, or another justified candidate.

Testing forks may combine: state-aware deterministic fixtures/replay, imperfect open-loop input tapes, screenshot/video-only navigation, semantic game inspection, learned/real-time agents and adversarial exploration. Explain which questions each can answer. A successful exact-state bot is not proof of satisfying handling or human enjoyment.

## Settled by Mike

On 7 November he said he remains unsatisfied with movement and momentum and asks for broad research and continued work. He enjoyed VHOLUME as a reference resembling CS bhop. He permits our own implementation, dropping surf (which he disliked here), external assets/textures and anything useful to advance the game. Delegate budget is unlimited today. He asks to reconsider Godot for the final product and put a council to work. Earlier autonomy remains: make decisions without stopping to ask for a live review.

These are his decisions. No exact movement constants, engine, required surf mechanic, visual reference reconstruction or hard new completion-time target is settled.

## Facts and existing evidence

R12 is a working portable Godot 4.7.2/GDScript/Compatibility implementation, with 120 Hz physics and an original procedural dam. Its archived Linux/Windows packages and source remain available. Tests and native scripted runs passed specified R12 gates; Mike still rejected its feel. Existing evidence therefore establishes execution and regressions, not satisfaction. Root's captures used Linux llvmpipe, not desktop GPU measurements. Native Windows play remains unverified.

The classic-model research derives that R12's small projection cap can preserve speed while denying gentle forward-key air steering; its imperfect-input comparison is isolated arithmetic, not an in-engine playtest. A new Opus lab is being built separately from the active game; it is an experiment, not an engine decision or default motor.

The current agent helper advances paused native screenshot decisions, up to three seconds of key holds, with one mouse displacement per request. It can find routes but does not reproduce continuous human mouse motion. The exact-state route drivers know authored geometry. These are capabilities/limitations to inspect, not constraints to preserve.

A working export pipeline, current geometry and language experience are facts about cost, not vetoes on migration. Conversely, a fashionable engine or impressive framework does not establish better control. Missing measurements must be labelled and tested rather than silently resolved by preference.

## Author hypotheses, deliberately unapproved

A new motor inside Godot might be the cheapest way to test the control problem. A different engine might make collision, rendering or test harnesses substantially better. More accessible forward steering might help. World scale and surface detail might influence perceived speed. None of these is a premise the council must accept.

## Materials

- docs/momentum/BRIEF.md and research/classic-movement.md
- scripts/spillway_player.gd, spillway_main.gd, spillway_course.gd
- tools/visual-play.py, visual-play.gd, visual-play.sh, capture-route.gd
- docs/surf/RESULTS.md and the preserved R12 report/evidence under the outer build directory
- Official reference page: https://store.steampowered.com/app/4131730/VHOLUME/

Use current primary engine/framework sources for external technical claims. Distinguish a paper's research result, a downloadable usable tool, a commercial product claim, a local experiment and an inference. Do not invent reference-game constants or report a local baseline measurement as human feel.

## Process and members

Use Opus 5.5 and GPT-6.1 Sol at high effort, the two-family combination Mike previously requested. Moderator is the current Codex lead. The brief first receives separate Opus/Sol pre-mortems: likely forced answer, fact/decision/assumption classification, omissions and sharper question. Root revises the board under Mike's explicit autonomy instead of requesting another approval round.

Round 1 proposals are independent and withheld from the other member until both are back. Round 2 members see the full board and challenge one another. Each round is a fresh watchable T3 task. The synthesis records the choice, continuing disagreements and falsifiable experiments. It must lead to a playable comparison, not end at a score or engine shopping list.

## Pre-mortem

Pending. No proposal or engine selected.

## mike

No further input required for progress. This space remains available for steering.
