# Pre-mortem: Opus 5.5

Scope: COUNCIL.md only. One leak to declare: opening the brief auto-injected the project's `projects/foldrunner/AGENTS.md`, which every member will also load (see 1.6).

## 1. The answer this brief makes most likely

**Likely answer:** keep Godot and write a new Quake/Source-style air-strafe motor that loosens the projection cap for forward-key steering. Test it with deterministic fixtures plus imperfect input tapes. Mention Unity or Unreal as "revisit for the final product" and drop them.

What pushes toward it:

1. **"Choose an engine ... for the next playable Spillway iteration"** (Decision). Mike asked to reconsider Godot *for the final product* (Settled). Swapping in "next iteration" means a short-horizon question, and over a short horizon the engine already in place always wins.
2. **"name the smallest experiments that distinguish its recommendations"** together with **"must lead to a playable comparison"**. The smallest playable experiment is a motor edit in the existing scene. A rule that sounds neutral ends up ranking forks by how cheap they are to build in Godot.
3. **"R12's small projection cap can preserve speed while denying gentle forward-key air steering"**. It is the only causal diagnosis in the brief, it names a single parameter, and that parameter is engine-agnostic. Members will read it as "the problem is a constant, so the engine is irrelevant". It also fixes the motor family (classic projection-capped air acceleration) before anyone has asked whether VHOLUME uses that model.
4. **"A new motor inside Godot might be the cheapest way to test the control problem"**. It is labelled a hypothesis but worded as the default, and calling it "the control problem" narrows the failure to the motor.
5. **Asymmetric detail.** Godot gets version, renderer, tick rate, packages, export pipeline and a full materials list (every listed script is GDScript). Unity and Unreal get one vague line each ("appropriate custom or available kinematic controller", "suitable movement implementation"). Members can only reason concretely about one candidate.
6. **Hidden Godot anchor outside the brief.** The auto-loaded project AGENTS.md states "Godot4.7.2, GDScript, Compatibility rendering ... 120Hz physics" and "spillway_player.gd owns collision" as standing project rules, not as R12 history. The brief's "facts about cost, not vetoes" line is contradicted by a file members treat as instructions.
7. **"More accessible forward steering might help"** pushes toward accessibility and away from preserving a bhop skill ceiling, even though Mike's only positive reference (bhop-like VHOLUME) is a skill-expressive model.

Counter-biases are present but weaker:

- "reconsider Godot" and "a different engine might make collision, rendering or test harnesses substantially better" invite migration for its own sake. That second line lumps three unrelated axes into one vague promise.
- The testing fork list is long and the title contains "agent testing", so a member can make the harness the deliverable.
- "A successful exact-state bot is not proof of satisfying handling" is the right warning. But no human test appears among the testing forks, and the autonomy rule ("without stopping to ask for a live review") removes the only human judge. By default, bot metrics will become the acceptance signal (see 3.2).

## 2. Constraint classification

**Observed facts** (checkable in the repo or evidence, though I have not checked them):

- R12 runs on Godot 4.7.2, GDScript and the Compatibility renderer, at 120 Hz physics, on a procedural dam.
- The Linux and Windows packages and the source are archived.
- Tests and native scripted runs passed "specified R12 gates". *The gates and their numbers are not given, so members cannot judge what passing proves.*
- Captures ran on llvmpipe, not a desktop GPU.
- Native Windows play is unverified.
- The agent helper works in paused screenshot steps: key holds up to 3 s, one mouse displacement per request, no continuous mouse.
- The exact-state route drivers know the authored geometry.
- An export pipeline exists.

**Mike's settled decisions** (all relayed as the author's paraphrase; members cannot verify any of the wording):

- He is unsatisfied with movement and momentum, and he wants broad research plus continued work (7 Nov).
- He enjoyed VHOLUME, which he finds resembles CS bhop. *That resemblance is his perception, not a mechanic of the game. VHOLUME's actual movement model is unknown.*
- He permits an original motor, external assets and textures, and dropping surf. *"Disliked surf here" is ambiguous: surf as a mechanic, or this implementation of it?*
- The delegate budget is unlimited today. *"Today" is a temporary limit, and the brief gives no budget for a migration that outlasts today.*
- He asked to reconsider Godot for the final product, and he asked for a council.
- He asked for Opus plus Sol at high effort (stated as an earlier request).
- Standing autonomy: decide without a live review. *Unclear whether this also bars sending Mike a build to play asynchronously.*
- "Rejected R12 feel": the verdict is settled, but its content is not recorded anywhere (see 3.1).

**Author's assumptions and framing presented as structure:**

- The decision covers the "next playable iteration" rather than the final-product engine (1.1).
- Engine, motor and testing method are bundled into one decision.
- The four engine forks and the testing-fork taxonomy are the author's own enumerations.
- "Smallest distinguishing experiments" and "must end in a playable comparison" are process choices that bias toward incumbents (1.2).
- The projection-cap diagnosis is a derivation. It is labelled "isolated arithmetic", which is honest, but it is still the only diagnosis offered.
- "Existing evidence establishes execution, not satisfaction" is a sound inference, but it is not an observation.
- "Language experience" as a cost fact is unclear: whose experience? Mike's, or that of the agents writing the code? It is unverifiable as written.
- "The Opus lab is an experiment, not a default motor" is a status claim. The brief does not say which engine the lab uses. If it is Godot, it is sunk-cost pressure in practice.
- World scale and surface detail affecting perceived speed is a hypothesis, and plausible.
- Moderator and Root authority: "revise under Mike's explicit autonomy" is relayed authorization.

## 3. Missing considerations and a sharper question

1. **Nobody has written down what felt wrong.** Possible culprits include speed gain, air control, ground friction or bhop timing windows, landing, camera, sense of speed, and mouse response. Without a symptom list, every member optimizes a guessed variable, and the projection cap fills the gap (1.3). The moderator should reconstruct Mike's actual complaints from earlier sessions before proposals, and label whatever cannot be recovered as unknown.
2. **There is no human in the testing loop.**
   - The core bhop skill is continuous, mouse-synchronized strafing. The current helper structurally cannot perform it.
   - Bots can measure proxies:
     - speed gain against strafe-quality curves
     - how outcomes vary under input noise
     - recovery after mistakes
     - how clearly skill is rewarded
   - Proxies cannot measure satisfaction. The council should say who judges feel and when.
   - Recommendation: ship a small set of A/B builds plus R12 as the control, for Mike to play asynchronously. That needs a new channel, not a stop, so it respects his autonomy rule.
3. **Feel lives partly outside the motor.** Candidates:
   - physics/render interpolation at 120 Hz against the display rate (jitter)
   - input latency and frame pacing on a real GPU
   - raw mouse input, sensitivity and acceleration
   - FOV, camera smoothing, audio
   - course layout that rewards strafing (bhop feel needs a level built for it)

   llvmpipe evidence can see none of these. This is where engines genuinely differ. Motor math ports to any engine in a few hundred lines, so the engine question should hinge on these factors plus collision queries, not on the motor.
4. **The final-product criteria are absent.** Missing:
   - Steam and platform delivery
   - real-GPU performance
   - licensing terms
   - asset pipeline
   - long-term maintenance
   - **how well agents can write and test code in the engine**: text-based scenes, headless runs, deterministic stepping, CLI builds. In a project built mostly by agents, that is a first-order criterion.
5. **Dropping surf lowers the collision demands.** Bhop needs ground detection, step-up, slope handling and jump buffering, but not the robust sliding along steep surfaces that surf needs. That weakens the "another engine has better collision" argument unless a member points to a specific failure seen in R12.
6. **There are no kill criteria and no horizon.** Missing:
   - which result ends the exploration
   - what migration costs beyond today's delegate budget
   - which result would justify a port after the vehicle test

   Without these, the board risks becoming an engine shopping list, which the brief itself forbids.
7. **There is no reference measurement.** Nobody can measure VHOLUME. At most Mike can describe it. The brief should forbid any claim that something "matches VHOLUME" beyond his own report.

**Sharper decision question.** Split the bundle into two linked questions:

> **A. Vehicle:** Which cheapest set of playable builds (R12 as the control) separates whether Mike's rejection comes from (i) the air or ground motor model, (ii) the input, camera and frame-pacing pipeline, or (iii) course affordance? What bot proxy and what human signal would each build be judged on?
>
> **B. Final engine:** Does any engine other than Godot remove a blocker that has been **measured** in R12 or in A's builds (latency, interpolation, collision failure, agent testability, delivery), and is that blocker worth the port? If no blocker is measured, the answer is "stay on Godot until one is", and that answer is recorded together with the result that would overturn it.
