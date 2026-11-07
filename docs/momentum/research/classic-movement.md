# Classic movement: separate gaining speed from steering it

Researched 7 November 2026 against the [current brief](../BRIEF.md). R12 reproduces an important QuakeWorld/Source air rule, but that rule rewards a particular relationship between movement keys and velocity. It does not promise pleasant forward-key steering. Test a broad Quake III projection model, a separate speed-preserving steering model, and a downhill momentum model before choosing. Surf is unnecessary for all three.

This is source research and an isolated arithmetic check, not a native playtest or a proven explanation of Mike's dissatisfaction. All proposed values are **P / game choices**. No upstream implementation is copied into the project.

## The common equation has two different speed controls

Let horizontal velocity be **v**, unit wish direction **d**, requested speed **W**, projection allowance **C**, acceleration coefficient **a**, and timestep **h**. A projection accelerator adds an impulse along **d**, limited by both its acceleration budget and the available projection room:

**p = v·d; j = max(0, min(a·W·h, C − p)); v′ = v + j·d.**

This is a mathematical description, not upstream code. **C limits velocity along the input direction, not total speed.** An oblique input can add speed when total speed already exceeds C. For the actual impulse j, the energy relation is **|v′|² − |v|² = 2pj + j²**. Input opposite the velocity can brake; perpendicular input turns and increases speed; looking alone supplies no impulse. These consequences follow from the equation.

| Family, exact evidence scope | Projection allowance and impulse budget | What this means for input |
|---|---|---|
| **QuakeWorld**, id's released QW client movement | C = min(W, 30 engine units/s), but budget uses **uncapped W**. Its air path passes `movevars.accelerate`, despite the nearby commented air-acceleration default. W is limited by server maxspeed before this. [QW air and caller][qw-air] | Small-cap strafing: sustained speed gain needs wish direction near sideways to velocity. It is not a camera-heading follower. |
| **Quake III Arena**, released base game | C = W; no separate 30-unit air cap. Base air coefficient is 1, versus ground 10. Normal command scaling prevents a free diagonal magnitude boost. [Q3 constants][q3-constants], [accelerator/input][q3-acc], [air][q3-air] | Forward plus strafe can contribute at smaller angles to velocity. Further gain at high speed needs increasingly oblique input. There is no separate speed-preserving turn function. |
| **Source SDK 2013 common movement**, not an exact CS release | C = min(W, `GetAirSpeedCap()`), default 30. Budget uses **uncapped W**, times surface friction. `AirMove` limits W to player maxspeed. [Source air][src-air], [cap declaration][src-cap] | Same important capped/uncapped distinction as QW. Raising acceleration and raising C do different things. This source does not establish CS-specific stamina, weapon speeds, or server settings. |
| **CPMA**, maintainer-hosted movement guide | Describes single-key control, Q3-style forward-plus-strafe, double jumps and ramp jumps. The underlying guide dates to 2003, with edits noted in 2017; it is not a current formula specification. [CPMA guide][cpm-guide] | The documented distinction between one-key steering and two-key strafe jumping is a useful design fork. Do not attribute Warsow's constants to CPMA. The maintainers distinguish modern CPM, classic PMC, CQ3 and VQ3 rulesets. [Rulesets][cpm-modes] |
| **Warsow upstream development source**, feature-dependent branches | Has ordinary Q3-like acceleration, a side-only capped-W high-acceleration path, and a separate `PM_Aircontrol`: when eligible and pointing into the forward hemisphere, bend horizontal velocity toward wish direction then restore its previous magnitude. [Warsow air branches][wsw-air], [turn function][wsw-turn] | Steering can be granted without minting speed. In this implementation side input excludes the separate turn function; forward-plus-strafe and forward-only are materially different. This is evidence about the pinned upstream branch, not a claim that every retail version or player class selects it. |

**Capped versus uncapped acceleration is a design decision.** Replacing W by C in the impulse budget preserves the projection restriction but greatly weakens acceleration when C ≪ W. Conversely, increasing a cannot open room when p ≥ C. Neither modification alone creates forward steering. R12 currently uses the uncapped-W form. [R12, lines 290–300](../../../scripts/spillway_player.gd)

## Landing, braking and slopes change the whole game

| Policy | Primary-source comparison | Implication for Spillway |
|---|---|---|
| **Jump before ground friction** | QW processes jump before friction; Q3 checks jump before the walking friction path; Source common walking checks jump before friction and skips ground friction after successful takeoff. [QW order][qw-order], [Q3 walking][q3-walk], [Source order][src-order] | R12's held or buffered hop before its ground update is consistent with this broad principle. It is an accessibility extension: QW/Q3/base Source also have held-button guards, so automatic held hopping is a separate policy. A missed jump and a successful hop must be measured separately. |
| **Ground friction** | QW/Q3/Source use a speed-scaled drop with a stop-speed floor, then accelerate; QW also increases friction at a dropoff. [QW friction][qw-fric], [Q3 friction][q3-fric], [Source friction][src-fric] | R12 instead moves the whole vector toward a target at 28 m/s², or 34 for release/opposition, with separate 8 m/s² overspeed decay. A 90° correction, release and countersteer therefore have a different relationship to one another. |
| **Intentional braking** | Projection acceleration accepts negative p, so opposite input can remove momentum. Warsow additionally selects a larger air deceleration coefficient for eligible opposing input. [Warsow branches][wsw-air] | Releasing input in R12 air does nothing; an opposing key can brake strongly. This can be correct yet poorly discoverable. Test deliberate S, accidental S, release and counterstrafe rather than judging only forward progress. |
| **Walkable versus steep slopes** | QW uses ground-normal up component 0.7 as its steepness boundary. Q3 clips walking motion onto the ground plane, restores its speed, and treats steep ground planes through air movement. [QW categorization][qw-ground], [Q3 walking][q3-walk], [Q3 air][q3-air] | A surf surface is a collision/grounding policy, not a necessary consequence of air strafing. R12 uses 46° floors, a designated 46–75° surf interval, snapped floor movement, a crouch-slide motor, and its own feasible-contact projection. These are substantive differences, not proof of engine equivalence. |
| **Limits** | QW/Q3 air wish limits do not enforce that same number as total horizontal speed. Source also has an independent per-component `sv_maxvelocity` clamp. [QW air][qw-air], [Q3 air][q3-air], [Source validation][src-limit] | R12's 30 m/s horizontal limit before movement and proportional full-vector rescaling after high-energy contact are additional policies. A cap can erase earned gain and alter vertical motion after a ramp impact. Log cap activation, not just displayed speed. |

Do not collapse **Counter-Strike, bhop servers and KZ** into one specification:

- Valve's public **Half-Life/GoldSrc SDK** has the 30-unit projection cap and uncapped-W budget, but also `PM_PreventMegaBunnyJumping`: above 1.7× player maxspeed it scales speed down to 65% of that threshold. That is evidence for this SDK, **not proof of CS 1.6's exact implementation**. No authoritative public CS 1.6 movement implementation was established here. [GoldSrc air][hl-air], [jump limiter][hl-limit]
- The **CS:GO GOKZ maintainers** ship distinct movement modes. Their Vanilla settings use air acceleration 12, cap 30, bunnyhopping disabled and nonzero jump/landing stamina costs. SimpleKZ uses air acceleration 100, cap 30, bunnyhopping enabled and zero stamina costs, plus authored prestrafe rewards. KZTimer also uses 100/30 but explicitly caps perfect-hop horizontal takeoff at 380 units/s. These are mod policies, not interchangeable engine defaults. [Vanilla][kz-vnl], [SimpleKZ settings][kz-skz], [prestrafe rewards][kz-pre], [KZTimer][kz-kzt]
- **Shavit's bhop timer** exposes per-style air acceleration, autobhop, stamina-reset relief, bunnyhopping and velocity limits; its normal style enables autobhop and bunnyhopping with an unlimited style velocity setting. Therefore “CS bhop feel” may mean a modified server contract. Its recommendation of ramp/slope fixes also shows why the common air equation alone does not establish surf contact quality. [Style configuration][shavit-style], [maintainer README][shavit-readme]

Modern CS2 internals, the exact server Mike remembers, and retail Warsow's active feature set remain unverified. None is needed to authorize an original controller.

## Units and ticks: preserve relationships, not famous numbers

Spillway uses metres/seconds and [120 Hz physics](../../../project.godot); the upstream constants above use engine distance units. A coefficient multiplying wish speed has inverse-time units; R12's ground ACCEL/BRAKE are already distance/time². Copying “100 air acceleration” or “320 speed” without the equation, scale, timestep and input policy is meaningless.

The engines multiply acceleration/friction by elapsed time, but discrete caps, input sampling and contact order still affect results. QW derives h from command milliseconds. Q3 subdivides commands, optionally by `pmove_msec`, and snaps velocity at the end of movement. [QW order][qw-order], [Q3 timestep][q3-time] GOKZ explicitly requires 128 tick; its prestrafe implementation contains per-tick constants and grace ticks. [GOKZ requirements][kz-readme], [SimpleKZ][kz-skz] An original Godot implementation need not reproduce historical rounding or tick quirks.

**R12-specific derivation:** full input gives a budget of 12×8.5/120 = **0.85 m/s per tick**, already greater than C = **0.75**. Perpendicular input therefore fills the projection allowance in one tick. Raising a from 12 to 100 cannot increase that perpendicular impulse. It can change opposing-input response and other angles.

With optimally chosen free-air wish direction each tick, the maximum squared-speed increase is C² per tick when aWh ≥ C; otherwise it is 2(aWh)C − (aWh)². For unchanged R12 parameters this gives **33.75, 67.5 and 109.65 m²/s³ at 60, 120 and 240 Hz**, respectively. These are derived ideal upper bounds before the global limit, not measured human gains. Multiplying by delta does not make this capped discrete system tick-invariant. Keep 120 Hz fixed for the first comparison; later replay time-based input at other rates as an explicit robustness check.

## What R12 gets right can coexist with poor feel

Inspected [spillway_player.gd](../../../scripts/spillway_player.gd), SHA-256 `b1b119b2e178e5eea56dd1fffcf7b90abffb0e8839a633c24c642adec07c01e9`. This is the observed R12-policy baseline; another agent may subsequently change the working script.

- **A faithful small projection cap can reject an ordinary steering intention.** At 8.5 m/s, wish direction must be more than acos(0.75/8.5) ≈ **84.94°** away from travel before acceleration becomes available. At 20 m/s it is **87.85°**. W plus a gentle look turn can thus preserve momentum perfectly while providing no steering. Keeping W during a strafe adds a 45° input offset rather than the nearly perpendicular direction the rule rewards.
- **Ground carry is not independent of steering.** R12 sets a target in wish direction at the carried speed, then approaches that vector. Turning takes a chord through velocity space and can shed speed; straight held input sheds overspeed at 8 m/s². A slide instead rotates its vector at up to 90°/s before drag, and jumping switches back to projection acceleration. Mode transitions can change the meaning of the same key/mouse gesture. [R12 lines 195–235](../../../scripts/spillway_player.gd)
- **Jump forgiveness does not forgive aim.** Autohop, 120 ms buffering and 100 ms coyote time remove timing failures, while the small-cap air rule still rewards a specific key relationship. Neither perfect hopping nor a state-aware strafe driver's completion proves the normal route feels controllable. [R12 constants and hop decision](../../../scripts/spillway_player.gd)
- **Contact correctness is narrower than enjoyable contact.** R12 projects velocity onto a feasible contact cone and preserves resolved horizontal landing velocity, but floor snap, capsule contacts, classification and hard speed limits remain part of the result. Passing nonpenetration or speed-retention assertions is compatible with an unhelpful launch direction or difficult next correction. [R12 lines 255–397](../../../scripts/spillway_player.gd)

An isolated Python arithmetic replay of R12's horizontal equation used **86 ticks (0.717 s)**, initial velocity along heading 0°, full digital input, and an open-loop rightward camera turn of 60°/s. It contained no collision, floor, controller feedback or route. Results:

| Input during the replay | Start 8.5 m/s: final speed / travel heading | Start 20 m/s: final speed / travel heading |
|---|---:|---:|
| W plus mouse turn | 8.500 / 0.00° | 20.000 / 0.00° |
| W+D plus mouse turn | 8.538 / 3.04° | 20.002 / 0.15° |
| D plus mouse turn | 9.059 / 47.75° | 20.503 / 45.10° |
| W for first 100 ms, then D, same mouse turn | 8.922 / 47.82° | 20.267 / 45.12° |
| Release keys | 8.500 / 0.00° | 20.000 / 0.00° |

Reproduction specification: on tick i = 0…85 use camera yaw = (i+1)×60/120 degrees, wish offset W=0°, W+D=45°, D=90°, then the equation above with W=8.5, C=.75, a=12, h=1/120 and a 30 m/s magnitude clamp. This is original arithmetic, not ported game code. **It establishes a large input-policy difference, not a subjective diagnosis.**

## Three reversible experiments for our game

Use separately selectable motors in one plain movement lab, identical camera/body and geometry, a retained R12 option, and separate records. Initially disable surf, mantle and crouch-slide so they cannot conceal the motor difference. Keep held jump and the existing buffer/coyote allowances. Log input/yaw, actual displacement and velocity, ground/contact normals, speed removed by friction/braking/caps, and takeoff/landing events. All constants below are starting hypotheses, not reference-game claims.

### A. Quake III-style broad projection: gain through oblique input

**Policy:** C = requested run speed (8.5), air a = 1.5/s. No independent air rotation. Replace ground target-vector chasing with speed-scaled friction and projection acceleration: start at friction 5/s, stop speed 2 m/s, ground a = 8/s. Use a clearly logged 48 m/s emergency lab limit, with test lines below 30. Walking slopes redirect motion tangentially without a downhill boost; steep faces are walls.

**Expected ordinary feel:** W+D and imperfect shallow turns can add useful motion immediately at run speed; high speed still requires oblique wishes. W-only turning gains some authority rather than the R12 near-right-angle dead zone. Releasing on the ground may coast longer; landing without a hop now loses a speed-scaled amount. Bhop remains a technique for carrying speed.

**Tradeoff:** diagonal strafe jumping becomes more useful than Source-style side-only strafing. It is less precise as a high-speed direction follower. Unchecked long chains can outrun the level; measure before choosing a production ceiling.

**Falsify:** replay W, W+D and D at camera rates 30/60/90°/s, starts 8.5/20 m/s, and 0/100/200 ms key-switch delay. At 8.5, W+D with 60°/s should turn travel at least **15° during one 0.72 s hop**, compared with R12's ~3°. Reject this tuning if it misses that floor, or if straight no-turn W chains grow above run speed. Also measure landing losses after 0/1/4/12 grounded ticks and released-key stopping distance.

### B. CPM-inspired steering plus a separate strafe skill

**Policy:** retain a small projection accelerator, but add an original speed-preserving horizontal rotation toward forward wish when it lies within the velocity's forward hemisphere. Start with angular rate limited by **min(120°/s, 30 m/s² ÷ speed)**. Blend steering by the forward contribution to input so accidental W+D overlap gives partial steering rather than switching it completely off; side-only input retains the strafe accelerator. Opposing intent gets a separate 24 m/s² brake, without a 180° rotation shortcut. Use the same ground policy as A to isolate the air change.

**Expected ordinary feel:** hold W, hop and look through an upcoming bend while carrying speed. Advanced side-only strafes can still earn speed. Small mouse corrections should change direction without requiring extra energy. This borrows the documented separation of steering and acceleration, **not CPMA/Warsow's formula or exact key gates**.

**Tradeoff:** less punishment for imperfect strafing, more ability to rescue an approach. Speed-preserving steering can make narrow levels trivial; the acceleration-based turn limit makes the radius grow with speed. Input blending must not create an abrupt response when W is released.

**Falsify:** at 20 m/s, a W-only 60°/s turn for 0.72 s must change travel heading by **at least 25° while retaining ≥95% speed** before collisions. Repeating the turn at ±20% yaw rate and introducing 100 ms side-key overlaps must keep endpoint error within **2 m** of the clean replay. With projection gain disabled for diagnosis, ten seconds of steering must not increase speed by more than **0.5%**. S must bring 20 m/s below 2 m/s within 0.9 s, with no instant reversal.

### C. Original downhill momentum: steer by spending speed

**Policy:** abandon flat-ground strafe speed building. In air, approach a wish-direction target whose magnitude is **max(run speed, current speed)**, using a bounded vector acceleration, initially 24 m/s². At overspeed, turning follows a chord and costs speed; straight input and no input preserve it. A separate opposite-input brake starts at 30 m/s². On supported slopes apply tangent gravity, limited ground drag and terrain-following contact; jumping carries the actual tangent velocity. No fixed landing boost and no speed reset. Uphill motion pays energy; downhill motion earns it. Start with drag 0.5/s and retain the logged emergency limit.

**Expected ordinary feel:** W plus mouse steers directly, tight turns scrub momentum, broad lines keep it. Hopping downhill preserves earned speed without demanding synchronized A/D alternation. A missed hop may remain playable on a ramp; the terrain and chosen line become the main skill.

**Tradeoff:** this may be enjoyable while failing Mike's preferred CS bhop fantasy. Flat sections cannot sustain indefinite speed growth. Slope transitions need more collision scrutiny, and route design must provide space to brake and rebuild momentum. Warsow's separate forward-bunny target-velocity branch is evidence that projection acceleration is not the only historical approach; its soft speed target is not adopted here. [Warsow forward branch][wsw-forward]

**Falsify:** after earning 20 m/s on a descent, a 60° open-loop turn should lose more speed than a 20° turn, with **no flat straight-line gain above entry speed**. A 10 m frictionless height drop should conserve total kinetic-plus-potential energy within **5%**, including ramp transitions, so numerical boosts cannot pass as momentum. On a broad downhill S-bend, W-only traces with ±20% mouse-rate error and a jump 100 ms late should finish with ≥70% of the clean trace's speed and no restart. Reject or change geometry when that recovery floor fails.

**Compare native moving views next.** Give each motor a straight launch, two bend radii, flat and sloped landings, a short overshoot/braking area and a recoverable miss. Use recorded human-like key/yaw traces, no velocity-aware correction, alongside a precise driver. Metrics can eliminate failures; they cannot select which feels fun. B is the strongest first hypothesis for ordinary steering while preserving earned speed. A and C are meaningful alternatives, not parameter insurance around B.

[qw-air]: https://github.com/id-Software/Quake/blob/0023db327bc1db00068284b70e1db45857aeee35/QW/client/pmove.c#L412-L551
[qw-fric]: https://github.com/id-Software/Quake/blob/0023db327bc1db00068284b70e1db45857aeee35/QW/client/pmove.c#L324-L380
[qw-order]: https://github.com/id-Software/Quake/blob/0023db327bc1db00068284b70e1db45857aeee35/QW/client/pmove.c#L862-L903
[qw-ground]: https://github.com/id-Software/Quake/blob/0023db327bc1db00068284b70e1db45857aeee35/QW/client/pmove.c#L573-L610
[q3-acc]: https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c#L240-L310
[q3-constants]: https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c#L33-L47
[q3-air]: https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c#L601-L650
[q3-walk]: https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c#L692-L807
[q3-fric]: https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c#L172-L230
[q3-time]: https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c#L2014-L2059
[src-air]: https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/shared/gamemovement.cpp#L1705-L1788
[src-cap]: https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/shared/gamemovement.h#L104
[src-fric]: https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/shared/gamemovement.cpp#L1610-L1676
[src-order]: https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/shared/gamemovement.cpp#L2023-L2130
[src-limit]: https://github.com/ValveSoftware/source-sdk-2013/blob/7191ecc418e28974de8be3a863eebb16b974a7ef/src/game/shared/gamemovement.cpp#L3047-L3087
[hl-air]: https://github.com/ValveSoftware/halflife/blob/0fc8913c542d6ba129ca8bede1505e7d2e8b4b4b/pm_shared/pm_shared.c#L1279-L1316
[hl-limit]: https://github.com/ValveSoftware/halflife/blob/0fc8913c542d6ba129ca8bede1505e7d2e8b4b4b/pm_shared/pm_shared.c#L2436-L2467
[cpm-guide]: https://www.playmorepromode.com/guides/cpma-tdm-gameplay
[cpm-modes]: https://www.playmorepromode.com/guides/cpma-server-settings
[wsw-air]: https://github.com/Warsow/qfusion/blob/ac5fb37426212b362185eec28435e67b4bc88dcc/source/common/facilities/gs_pmove.cpp#L824-L936
[wsw-turn]: https://github.com/Warsow/qfusion/blob/ac5fb37426212b362185eec28435e67b4bc88dcc/source/common/facilities/gs_pmove.cpp#L641-L678
[wsw-forward]: https://github.com/Warsow/qfusion/blob/ac5fb37426212b362185eec28435e67b4bc88dcc/source/common/facilities/gs_pmove.cpp#L587-L638
[kz-vnl]: https://github.com/KZGlobalTeam/gokz/blob/df081612e7556df7b0ab974d389ec2e6bd333c6d/addons/sourcemod/scripting/gokz-mode-vanilla.sp#L31-L57
[kz-skz]: https://github.com/KZGlobalTeam/gokz/blob/df081612e7556df7b0ab974d389ec2e6bd333c6d/addons/sourcemod/scripting/gokz-mode-simplekz.sp#L28-L61
[kz-pre]: https://github.com/KZGlobalTeam/gokz/blob/df081612e7556df7b0ab974d389ec2e6bd333c6d/addons/sourcemod/scripting/gokz-mode-simplekz.sp#L436-L528
[kz-kzt]: https://github.com/KZGlobalTeam/gokz/blob/df081612e7556df7b0ab974d389ec2e6bd333c6d/addons/sourcemod/scripting/gokz-mode-kztimer.sp#L624-L638
[kz-readme]: https://github.com/KZGlobalTeam/gokz#server-requirements
[shavit-style]: https://github.com/shavitush/bhoptimer/blob/2c87128446302f534e1fd0147090b83be3256a6e/addons/sourcemod/configs/shavit-styles.cfg
[shavit-readme]: https://github.com/shavitush/bhoptimer#recommended-plugins
