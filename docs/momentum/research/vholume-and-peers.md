# VHOLUME and modern movement references

Researched 7 November 2026 against `docs/momentum/BRIEF.md`. Recommendation: compare a forgiving run-and-hop motor with a wall-transfer motor. Keep a tether experiment as a third, materially different option. Drop mandatory surf and reference-physics fidelity as acceptance criteria. None of the proposed tuning below is a recovered commercial-game constant.

## What VHOLUME changes about the brief

The useful reference is **ordinary movement that already works, with faster ways through the same space**. Increasing top speed or reproducing an air-acceleration formula would not establish that quality. VHOLUME's developer explicitly describes a permissive exploration experience whose advanced techniques are optional. That is a stronger starting point for Spillway than requiring the player to learn a speed technique before the route becomes enjoyable. [Developer design discussion](https://steamcommunity.com/app/4131730/discussions/0/563659628006802205/#c567037624436463237)

Build the basic line first: move, turn, jump, land slightly wrong, correct, continue. Then reward a better approach with retained speed, a longer gap or a shorter route. The dam can support this through broad service walks, descending channels, walls and lower recovery shelves. This is a proposed design, not a description of VHOLUME's implementation.

## Evidence and limits

- **Documented:** a developer statement, official manual, publisher/developer store description or announcement. A developer-marked answer by a player is identified separately.
- **Observed:** visual inspection of extracted, timestamped sequences from official videos. I inspected dense sequences at three frames per second, plus broader trailer storyboards. I did not play these games, inspect their binaries, hear their audio or watch them interactively on Mike's desktop.
- **P:** an original design hypothesis for a playable experiment. Footage cannot establish input latency, acceleration, friction, collision rules, buffering duration or subjective satisfaction.

The exact reference is [VHOLUME, Steam app 4131730](https://store.steampowered.com/app/4131730/VHOLUME/), credited to Nathan Grange, Léonard Lemaitre and Niels Tiercelin, published by IronEqual. Its official page describes running, jumping, climbing and sliding, optional momentum shortcuts, ghosts and target times. That establishes the game and its intended scope, not its motor equations. The fan site `vholume.space` was used only to locate developer links.

## VHOLUME: what is supported

### The developer confirms forgiving inputs and optional mastery

Enol Cook, marked as a developer on Steam, confirms a short early-input buffer for **both ground and wall jumps**. The same reply recommends the optional crosshair flash as confirmation of a successful bhop and the speedometer for seeing velocity gain or loss. It supplies no frame count or duration. It does not establish unlimited held autojump, coyote time or Source-style air strafing. [11 June reply](https://steamcommunity.com/app/4131730/discussions/0/563659290304392873/#c563659290304443907)

In the design discussion, the developer says basic movement should complete levels, bunnyhopping should never be required, and progression should not demand a target time. Bronze ghosts avoid slide-jumps; gold ghosts demonstrate faster play. The advanced layer is intended for experimentation and community discovery. A **player-authored, developer-marked answer** describes well-timed hops in different stances as gaining speed. That supports intentional advanced acceleration, without proving a particular slide-boost equation. [Design replies and marked answer](https://steamcommunity.com/app/4131730/discussions/0/563659628006802205/)

There is also useful contrary evidence: in September, players reported unpredictable wall attachment, mantling and slide boosts. These are first-person complaints, **not verified physics defects**. The developer's response links community technique videos and confirms that ghost POVs have an input viewer on `I`; it does not establish the causes of those complaints. [Discussion and developer response](https://steamcommunity.com/app/4131730/discussions/0/592940247175724004/)

**P:** borrow forgiveness and replayable examples, but make every speed gain and state change explainable. An obscure trigger should not be mistaken for a skill ceiling.

### What I actually inspected

Official media came from the [Steam listing](https://store.steampowered.com/app/4131730/VHOLUME/) and its app-details media records. The release trailer is also on [LemaitreLogiciels' channel](https://www.youtube.com/watch?v=QtZTgap87Cw). The older `Gameplay 01` clip ends with a wishlist card, so its motion is historical reference footage, not proof of release-build tuning.

| Official clip and inspected interval | Visible sequence | What this supports, and what it does not |
| --- | --- | --- |
| `Gameplay 01`, 00:00–00:08, dense sequence | Narrow slabs span a shaft; the view approaches a lit doorway, turns back toward staggered ledges, travels beside a wall with visible roll, then crosses to another lit opening. | Several changes of travel direction fit within a compact space. Camera roll and wall proximity are visible; the attachment trigger and degree of retained velocity are unknown. |
| `Gameplay 01`, 00:16–00:24, dense sequence | A ledge follows a building around a corner; the view turns along it, crosses a gap to a doorway and emerges toward the next elevated slab. | The route alternates support, turn and transfer. This is more useful than a long straight speed tunnel. It does not measure steering authority. |
| `Gameplay 01`, 00:32–00:40, dense sequence | An elevated slab leads to a low, dark opening. View height lowers around entry; beyond it are successive offset slabs under an arched overhead structure. | A low passage interrupts the jump rhythm before the next sequence. The view-height change is consistent with sliding/crouching, but there is no input overlay proving which input occurred. |
| Official inline movement loop 2, full 4.7 seconds | The view clears successive projecting slabs, passes close to a wall and reaches a doorway. Hands and feet appear during transfers. | Dense contact-to-contact action, with the next support visible ahead. No HUD establishes the speed gained or lost at each contact. |
| Official inline momentum loop 3, first 8 seconds | Small concrete supports wrap around a large fan opening over water; the view repeatedly changes heading between them and continues onto a narrow ledge. | An irregular sequence of landing choices rather than identical repeated gaps. No evidence for a hidden turn assist or an energy-conservation rule. |
| Release trailer, broad storyboard across 00:00–00:38 | Traversal, wall-adjacent movement, other players, dialogue and several environments are intercut. | Confirms the breadth of the presentation. Cuts make it poor evidence for continuous speed. |

**P:** route rhythm should alternate a readable approach, a contact decision, a transfer and a chance to recover. Near walls, seams, railings and the edges of platforms provide motion references. Merely enlarging FOV would not replace them. Keep enough of the next landing visible during takeoff and descent; do not copy the reference's camera roll without testing comfort and aim control.

## Four useful contrasts

### Neon White: speed as a deliberate expenditure

**Documented:** director Ben Esposito explains that Soul Cards are both weapons and movement resources. Discarding Godspeed executes a forward dash; Purify can combine an explosion with a jump boost. Levels are short optimization problems, and rapid restarts were an explicit priority. He also describes haptic feedback for faster travel on water and confirms that airborne Katana parries can grant a speed boost. [Developer article](https://blog.playstation.com/2022/12/01/neon-white-is-coming-to-ps4-and-ps5-december-13/)

**Observed:** the official inline loop 2, inspected in full, cuts between two scenes. In the second, a blue card disappears, view travel surges through a pergola and past an enemy, then continues through an arch. The launch trailer at 00:16–00:22 rapidly intercuts downward attacks, upward travel and card changes. These show strongly marked actions, not uninterrupted momentum measurements. [Official store media](https://store.steampowered.com/app/1533420/Neon_White/)

**P:** a fast move can be earned by a discrete, legible action rather than by continuously building speed. A one-use traversal impulse could give Spillway intentional corner exits. Drop the card inventory, enemies and collectible resource sequence unless that direction wins a dedicated experiment. Do not add a free repeating dash on top of every other acceleration source.

### Cyber Hook: an anchor creates a new way to turn and recover

**Documented:** Blazing Stick's official listing describes a grappling hook, wall traversal, physics-based route breaking and time manipulation that can save a fall. It also offers in-game viewing of other players' runs. It does not publish tether stiffness, reel speed, air-control coefficients or a speed cap. [Official listing](https://store.steampowered.com/app/1130410/Cyber_Hook/)

**Observed:** the first official inline loop shows a tether to a frame above the route, movement through that frame, another attachment and a cut to a descending corridor. The second loop, 00:00–00:08, shows successive attachments to separated structures, travel below an overhead platform and a new forward line. A numeric speed display changes throughout. Its units are not established here, so I did not convert them into metres per second. [Official media](https://store.steampowered.com/app/1130410/Cyber_Hook/)

**P:** turning can be a deliberate interaction with the world. An anchor lets a player rescue a poor airborne line by choosing a target and release point. That is a substantially different game from merely increasing air acceleration. Drop combat, neon grids and the full time-warp system. A tether experiment needs its own anchor spacing and recovery layout; it cannot be judged on an unchanged bhop course.

### Hot Lava: contact choices can carry the challenge

**Documented:** Klei describes running, jumping, climbing, swinging, boosting and surfing, with shortcuts and skilled execution determining faster routes. A 2021 update added Vault Jump for extra reach, separated abilities from characters and split leaderboards by ability. A 2019 update explicitly allowed ledge/pole traversal by looking where the player wants to move and pressing forward, while retaining strafe input. These are historical design decisions, not a verified account of every current rule. [Official listing](https://store.steampowered.com/app/382560/Hot_Lava/), [Vault Jump announcement](https://steamcommunity.com/games/382560/announcements/detail/3048349794620814195), [Sports Day announcement via official news feed](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/2411028931137056471)

**Observed:** the launch trailer at 01:02–01:10 alternates third-person crossings, jumps between small green-topped posts, a narrow passage and first-person platforming behind other players. The inline loops are mostly edited external views. They show sharply distinguished support surfaces and hazards, but do not establish input feel, auto-bhop, acceleration or a respawn interval. [Official media](https://store.steampowered.com/app/382560/Hot_Lava/)

**P:** make the next useful contact obvious and let varied distances demand different approaches. The dam's water, service ledges and structural posts can provide that grammar. Drop unavoidable death on every miss: lower walks can preserve an imperfect run while costing time. There is no reason to retain surf merely because Hot Lava has it.

### Titanfall 2: walls extend the route beyond the floor

**Documented:** the official PC manual binds sliding to crouch while sprinting. It does not document slide-hop friction, wall-kick timing or advanced acceleration. Respawn designer Christopher Dionne's GDC session description explains how small playable action blocks supported level experimentation; I read that description, not the full talk. [Official manual, page 2](https://eaassets-a.akamaihd.net/eahelp/manuals/titanfall-2-pc-ww.pdf), [Respawn's action-block session](https://www.gdcvault.com/play/1025105/Designing-Unforgettable-Titanfall-Single-Player)

**Observed:** in the official multiplayer trailer at 00:32–00:35, a Pilot approaches the side of a building, rises alongside it and travels with a rolled view before the next cut. At 01:14–01:20, the view leaves a wall, crosses toward a roof while tracking another airborne Pilot, then drops toward an opening. Weapons remain usable during these transitions. The edited footage cannot prove the exact jump sequence or momentum retained. [Official Steam trailer](https://store.steampowered.com/app/1237970/Titanfall_2/)

**P:** a wall should be a useful onward route, with a visible destination and an intentional exit. Keep free look and aim available during travel. Drop combat, Titans, grappling and double-jump as a package deal. Begin with one wall-transfer rule that can be tested independently.

## What to transfer into the controller lab

All entries here are **P**, informed by the sources above. They are requirements to compare in play, not claims about any reference's code.

| Question | Concrete experiment | Drop or reject |
| --- | --- | --- |
| Does ordinary input satisfy? | Start from rest with forward input, jump early, land, then make a normal keyboard/mouse turn. The base line must work before any speed technique. | A slow basic gait whose only remedy is advanced tech. |
| Can the player turn? | Separate free camera yaw from velocity. Movement input changes travel direction with a declared steering policy; looking alone never secretly rotates the velocity. Test forward-plus-side input as well as classic strafe sequences. | A useful trajectory that depends on knowing to release forward, unless deliberately selected after comparison. |
| Where is speed earned? | In the first experiment, earn it through descent and better lines. In alternatives, identify a specific wall exit or tether action. Log each gain's cause. | Adding an impulse on every jump, contact, slide and state transition simultaneously. |
| How is speed kept? | Retain horizontal overspeed across a valid buffered hop. Compare tap-buffered rehop with a held-jump queue. A missed precision window must still produce an ordinary usable jump. | Frame-perfect contact requirements and unexplained speed resets. |
| How is speed lost? | Let braking, reversal and a square collision cost speed predictably. Inspect glancing contact separately from head-on impact. | Erasing the whole velocity for a graze, or silently preserving speed through a head-on hit. |
| Can a chain recover? | Miss a hop, land on a lower shelf, steer back and finish. Keep a fast line and an accessible line through the same section. | A compulsory restart for a small trajectory error. |
| Is speed visible? | Compare fixed and modest speed-responsive FOV with identical physical motion. Use near concrete seams/posts and truthful landing/slide cues; retain a debug speed trace. | Camera effects that imply acceleration after it actually happened, or obscure the landing. |
| Does the route have rhythm? | Mix broad approach, turn, staggered gaps, low passage and recovery shelf. Place alternatives where retained speed becomes useful. | Equal-spaced hops throughout, featureless straightaways and mandatory surf. |

## Three coherent original directions

### A. Run, carry and cut corners: recommended first experiment

Forward input gets to a useful ordinary run promptly. Jump has a short early-input buffer and a separately tested edge grace period. Airborne input can bend an imperfect approach without snapping travel to camera yaw. Ground release and reverse input provide understandable braking. A crouched slide reduces ground drag and clears low structures; it is not an automatic speed generator. Downhill travel and clean lines earn speed, and valid re-hops carry it.

Author descending service walks, broad bends, staggered slabs and occasional low gates. A faster runner can cut a corner or clear an extra gap; an ordinary runner can use the whole walk. A lower catch shelf costs time and gives the player a route back.

**Drop:** wall climbing, wallrun, tether and mandatory surf. No timed-hop acceleration bonus in this first version. Compare buffered taps with held rehop as an explicit accessibility/feel choice. Reject A if substantial air control makes every landing trivial, or if useful steering still demands expert inputs.

### B. Wall relay: the strongest contrasting experiment

Keep a competent basic run, then let airborne contact with suitable vertical surfaces become a short ride. Require an intentional approach toward/along the wall; facing a wall alone should not attach the player. Jump exits the ride. The exit combines an outward component with the player's intended direction, under a declared speed policy. It must not switch among unexplained launch directions. Contact permits redirection; it does not grant an accumulating free speed bonus.

Author alternating dam buttresses with visible outgoing ledges and floor routes below. Wall transfers offer shorter lines and recover a slightly poor jump. There should be a clearly testable difference between a head-on collision, a glancing ride and an intentional kick.

**Drop:** surf, endless vertical climbing, double-jump and tether. Keep wall entry/exit in the movement trace. Reject B if attaching reliably requires hidden angle knowledge, or if the wall system steals free look or repeatedly catches players who intended to land.

### C. Anchor and release: a speculative third option

Give the runner one held tether to clearly marked structural anchors. Holding bends travel around the anchor; releasing continues the resulting trajectory. The swing trades height and direction, while any reel-in assistance is a separate, explicit choice. It must not teleport velocity toward camera forward. A poorly aimed jump can be rescued by catching a reachable anchor.

Author open drops between buttresses, anchor pairs around broad corners and lower service walks. The high line depends on attachment choice and release timing. Keep ordinary running/jumping pleasant between swings.

**Drop:** wallrun, surf, combat and free dash. Do not add time-slow initially. Reject C if aim selection becomes the main frustration, if anchors require constant upward camera scanning, or if it displaces rather than improves the requested running experience. It is worth a bounded action block, not an automatic full-route commitment.

## What a useful playable comparison must show

Retain R12 as the comparison. Put A and B through a shared core block, plus a short wall extension for B. C needs its own anchor block. Label physics and map identity so an improvement is not accidentally attributed to a route change.

Use these same imperfect inputs as well as a precise driver:

1. Forward only from rest, a normal jump and an early jump before landing.
2. A broad turn using forward-plus-side input, then an intentionally late turn near a gap.
3. Several re-hops, one missed rehop, then a recovery without restart.
4. A slope-to-flat transition, a glancing wall contact, a square collision and deliberate braking.
5. An overshot landing onto a lower shelf, re-entry to the route and the finish.

Record the actual inputs, horizontal velocity, support/contact state and causes of discrete speed changes. Inspect native moving views for the next landing, trajectory correction and state-transition interruptions. Measure course success and recovery separately from best time. A fast perfect run cannot establish that the ordinary motor is satisfying.

Advance a direction when its base line survives the imperfect inputs and its faster line rewards a legible decision. Reject it when the explanation for a failure requires an undocumented special case. The playable reports should name what felt different, what caused speed loss and what remained recoverable. Mike's enjoyment remains the final evidence for fun.

## Study artifacts and provenance

Artifacts are outside Git at `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r13/research/vholume/`. `study-manifest.json` records source URLs, media identities, sizes, hashes and inspection scope. The directory contains video-only official reference clips, timestamped overview/dense sheets, Steam media records, developer-thread snapshots and the official Titanfall manual. Downloaded footage and the whole study folder remain below the authorized 250 MB cap.

Search limitations: DuckDuckGo returned a bot challenge; Bing returned unrelated results. Harness search found primary discussions and the correct EA manual. X exposed the developer profile but gated its posts. The old Cyber Hook publisher page returned 404. Steam's HTML news pages were often empty, so official announcements were read through Steam's public news API. No purchases, logins, game installations, desktop interaction or speaker playback were used.

These commercial images and clips are **study references, not licensed game assets**. No code or art was adopted. External assets for a chosen direction still need their own redistribution licence and provenance. The result calls for original movement experiments, not a commercial-game reconstruction or a UI redesign.
