# R14 legacy CS:GO reference and independent oracle

Research date: 8 November 2026. This is a public-rule reference, not a claim that a
new motor reproduces the CS:GO binary. R14 means airborne A/D with same-direction
mouse turns; R13's bounded W steering is outside this reference.

`tests/movement_oracle.py` imports only the Python standard library. Its equations
and numerical fixtures are original. No engine or plugin implementation is copied
into it. [Source metadata](reference/README.md) records the public download URLs,
SHA-256 hashes and fetch dates. Third-party snapshots are not kept in Git and are
not required to run the oracle.

## What the evidence establishes

| Reference | What was read and what it can establish |
| --- | --- |
| [Valve public Source2013 movement, pinned revision](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/shared/gamemovement.cpp) and [header](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/shared/gamemovement.h) | Primary published SDK evidence for projection acceleration, uncapped wishspeed budget, cap 30, ground friction, jump/gravity ordering and rising-air surface friction. It is **Source2013**, not CS:GO source. |
| [Valve shared movement defaults](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/movevars_shared.cpp) | Its generic defaults include acceleration 10, air acceleration 10, friction 4 and stopspeed 100. HL2 gravity is 600, multiplayer defaults use 800. These must not silently become CS:GO defaults. |
| [GOKZ CS:GO vanilla mode](https://github.com/KZGlobalTeam/gokz/blob/master/addons/sourcemod/scripting/gokz-mode-vanilla.sp), [mode documentation](https://github.com/KZGlobalTeam/gokz/wiki/Modes) | Primary evidence of the CS:GO plugin author's precise vanilla reference cvars, including the decimal values below. The plugin also hooks maximum speed, so its name does not prove an untouched Valve server. |
| [CS:GO console dump by its publisher](https://gist.github.com/eguven/779902f22124e5d69d1e76c138bbdfa2) | Confirms cvar names/descriptions, stopspeed 80, maxspeed 320 and maxvelocity 3500. The displayed value column truncates decimals: acceleration 5, friction 5, jump impulse 301, jump/land costs 0. Do not use that column to set those values. No binary/build provenance was established. |
| [Movement Unlocker, plugin author's 2015 explanation](https://forums.alliedmods.net/printthread.php?t=255298&pp=40) | First-party reverse-engineering explanation of the CS:GO jump clamp at 1.1 times player maxspeed and a separate grounded-speed restriction. Historical behavior evidence, not a verified late-legacy trace. |
| [MovementAPI, CS:GO-only project](https://github.com/danzayau/MovementAPI) | Author definitions distinguish perfect hops, jumpbugs and ground-contact artifacts. Its distbug explanation explicitly warns that landing positions/duration can differ by a tick. |
| [GOKZ server requirements](https://github.com/KZGlobalTeam/gokz/blob/master/README.md), [tickrate-enabler author](https://github.com/zer0k-z/tickrate_enabler_csgo) | 128 Hz is a real CS:GO KZ requirement; the enabler author lists both 64 and 128 as supported native rates. 120 Hz is not on that native list. |
| [shavit bhoptimer core](https://github.com/shavitush/bhoptimer/blob/master/addons/sourcemod/scripting/shavit-core.sp), [style configuration](https://github.com/shavitush/bhoptimer/blob/master/addons/sourcemod/configs/shavit-styles.cfg) | Primary plugin behavior and HUD-sync definitions. Default normal style uses AA 1000 and run speed 260, while Scroll uses AA 100 and 250. There is no universal “bhop server” configuration. |
| [Deadstrafe explanation by zer0k-z](https://gist.github.com/zer0k-z/808bc8bfc494e0bbb5a423c2b1ca6685) | First-party movement research attributes a rising-air slowdown to surface friction0.25, with worked CS:GO/CS2 examples. Its explanation is consistent with public SDK control flow; it is not a new external measurement performed here. |

No leaked CS:GO source repository was used as implementation evidence. Search results
containing leaks were skipped. CS2 command sites were also excluded as authority for
legacy CS:GO. Source2013 and CS:S are not interchangeable either: shared SDK defaults
and hulls may be overridden by a game's own rules.

## Exact recommended comparison configurations

These are explicit R14 configurations, with knife-like player wishspeed **250 u/s**,
standing, no duck, no walk, no inventory encumbrance, normal ground material. The
server `sv_maxspeed 320` is not the player's desired ground or air wishspeed, and
neither value imposes a hard total airborne speed ceiling.

| Setting | Vanilla reference | Chosen server-style fixture | Evidence / policy |
| --- | ---: | ---: | --- |
| physics rate | 64 Hz | 128 Hz | R14 comparison policy; 128 has direct GOKZ support, 64 is a supported native CS:GO rate |
| sv_accelerate | 5.5 | 5.5 | GOKZ vanilla value; retained for controlled comparison |
| sv_accelerate_use_weapon_speed | 1 | 1 | GOKZ vanilla; use a fixed 250 reference weapon |
| sv_airaccelerate | 12 | 100 | Vanilla reference / requested R14 server choice |
| sv_air_max_wishspeed | 30 | 30 | Present in GOKZ's CS:GO cvar list; generic Source2013 instead returns30 in its virtual air-cap method |
| acceleration budget | uncapped weapon wishspeed | uncapped weapon wishspeed | Legacy public Source behavior; capped-budget mode is a diagnostic comparison |
| sv_friction | 5.2 | 5.2 | GOKZ vanilla reference |
| sv_stopspeed | 80 | 80 | CS:GO public console dump |
| sv_gravity | 800 | 800 | GOKZ vanilla reference, in u/s² |
| sv_jump_impulse | 301.993377 | 301.993377 | GOKZ precise value, in u/s |
| sv_maxspeed | 320 | 320 | Server cvar; player fixture remains250 |
| sv_maxvelocity | 3500 | 3500 | Per-axis velocity safety limit; not a scalar run-speed cap |
| sv_enablebunnyhopping | 0 | 1 | Vanilla jump restriction / allow retained overspeed |
| sv_autobunnyhopping | 0 | 1 | Release/repress required / held-jump reissue |
| sv_staminajumpcost | 0.080 | 0 | Vanilla reference / explicit no-stamina choice |
| sv_staminalandcost | 0.050 | 0 | Vanilla reference / explicit no-stamina choice |
| sv_staminamax | 80 | 0 | Vanilla reference / disable penalty |
| sv_staminarecoveryrate | 60 | 0 | Vanilla reference / no remaining penalty to recover |

The names/values above are a configuration specification, not an executed console
session. Query the exact legacy build before applying it: the older rounded dump
omits `sv_air_max_wishspeed`, whereas CS:GO GOKZ directly looks it up. If unavailable,
retain the algorithm's 30 cap and record that it is fixed. Do not invent a CS:GO
`sv_fixed_airaccelerate` cvar from a Source SDK fix tutorial.

Vanilla still needs its real jump/stamina policy, not just AA12. Use the historical
**275 u/s takeoff clamp** (1.1×250) only as a labelled reconstruction until checked
against a chosen legacy build. Do not clamp every airborne tick to250 or275. Held
jump does not itself disable stamina or the clamp. Server-style no stamina must
also clear any existing penalty when switching into it; shavit's `easybhop` clears
`m_flStamina` on jump/landing, a plugin policy distinct from the vanilla cvars.

For air surface friction, expose/report the policy explicitly: public Source2013
categorization can use 0.25 while rising slowly, and the CS:GO research source
identifies the 0<vertical-speed≤140 interval. Preserve this in a fidelity comparison;
a constant1 air model is a useful labelled simplification. AA100 at 128 has sufficient
budget to reach the projection ceiling even at0.25; AA12 does not.

## Original air equations and discriminating numbers

Let `v` be horizontal velocity, `d` a normalized horizontal wish direction, `W` the
input wishspeed after the weapon limit (250 here), `h=1/rate`, `C=min(W,30)`, and `F`
the surface multiplier. With no input, leave horizontal velocity unchanged. Otherwise:

- current wish projection: `p = dot(v,d)`;
- legacy acceleration budget: `B = AA × W × h × F`;
- diagnostic capped budget: `Bfixed = AA × C × h × F`;
- applied addition: `a = max(0, min(B, C-p))`;
- new horizontal velocity: `v' = v + a d`.

The 30 cap limits acceleration along the wish direction, not total speed. Merely
turning the camera without input must not rotate momentum. Excess forward wish
projection prevents acceleration in that direction; A/left-turn or D/right-turn
moves the wish direction towards a near-perpendicular direction that allows gain.
Turn signs must be converted between Source and Godot coordinates, not compared as
raw yaw signs. W is released for these air fixtures.

For speed `s`, maximize `s'²=s²+2ap+a²`. Write `b=min(B,C)`. Once `s≥C-b`, optimum
projection is `p=C-b`, optimum angle `acos((C-b)/s)`, and squared-speed increment
`D=b(2C-b)`. Thus an ideal K-tick strafe arc ends at `sqrt(s²+K D)` for constant
budget. Below that threshold, use aligned input until it becomes reachable; the
oracle handles this initial segment in closed form. This is the maximum over
unrestricted yaw/input angles, not a promised human gain or prescribed mouse sensitivity.

Calculated at **250 u/s**, `W250`, `C30`, `F1`, stamina off, no collisions:

| Hz | AA | Budget mode | B (u/s per tick) | Optimum wish angle | Speed gain per tick (u/s) | End of16 ideal air ticks (u/s) |
| ---: | ---: | --- | ---: | ---: | ---: | ---: |
| 64 | 12 | legacy | 46.875 | 90° | 1.793566240 | 277.308492 |
| 128 | 12 | legacy | 23.4375 | 88.495813° | 1.708032438 | 276.063285 |
| 64 | 100 | legacy | 390.625 | 90° | 1.793566240 | 277.308492 |
| 128 | 100 | legacy | 195.3125 | 90° | 1.793566240 | 277.308492 |
| 64 | 12 | capped diagnostic | 5.625 | 84.404773° | 0.610972176 | 259.603062 |
| 128 | 12 | capped diagnostic | 2.8125 | 83.756736° | 0.321472998 | 255.094958 |
| 64 | 100 | capped diagnostic | 46.875 | 90° | 1.793566240 | 277.308492 |
| 128 | 100 | capped diagnostic | 23.4375 | 88.495813° | 1.708032438 | 276.063285 |

Sixteen ticks last 0.25 s at 64 and 0.125 s at 128, so these arc rows compare ticks, not
equal time. When `B≥30`, increasing AA no longer improves the ideal per-tick gain;
it still changes how much turning or correcting a poorly aligned strafe is possible.
At `F0.25`, AA12's B is 11.71875 at 64 and 5.859375 at 128. These are vector-addition
budgets, not 11.71875/5.859375 units of total-speed gain.

## Standing start, hop chains and jump timing

Defined start: stationary on level ground, full W until exactly 250 u/s, then release
W, immediately jump, use optimal A/D wish angle each air update, and re-jump without
any grounded friction tick. No stamina, no jump clamp, no collisions, unlimited yaw,
fixed 250 wishspeed, no velocity safety limit reached in these five-hop examples.
A hop ends at the first sampled plane-crossing tick; that tick gets an air update.
This deliberately fixes an order rather than hiding it in a collision engine.

The independent ground fixture below reaches 250 after 35 ticks at 64 (0.546875 s),
or 72 ticks at 128 (0.5625 s). These runup times are part of the defined mathematical
start, not externally measured CS:GO acceleration times.

For impulse `J=301.993377` and `g = 800`, continuous ballistic motion gives:
`z(t)=Jt-g t²/2`, `apex=J²/(2g)=56.999999845 u`, apex time 0.377491721 s,
equal-height airtime 0.754983443 s. This is 1.4478 m of vertical rise under the chosen
unit mapping. Sampling gives first nonpositive height at 49/64 or 97/128 seconds.

There is a material Source ordering caveat: public Source2013's standing jump adds
its impulse after a half-gravity step and applies another before the first drift.
With these chosen J/g values this produces `z_n=J n h-g h² n(n+1)/2`, equivalently
a sampled parabola with effective impulse `J-g h/2`. The oracle's separate
`source_standing_order` case derives from that ordering; it is **not verified to be
CS:GO's exact standing jump path**. Ducking and explicit vertical setters can differ.

| Timing case | Hz | Sampled apex (u) | Continuous equal-height time (s) | First plane-crossing tick |
| --- | ---: | ---: | ---: | ---: |
| ideal impulse | 64 | 56.997516 | 0.754983443 | 49 |
| ideal impulse | 128 | 56.997516 | 0.754983443 | 97 |
| Source standing-order sensitivity | 64 | 54.653766 | 0.739358443 | 48 |
| Source standing-order sensitivity | 128 | 55.825641 | 0.747170943 | 96 |

With constant F1 and standing-order air-update counts `K=48/96`, the maximum after
N completed hops is **`sqrt(250² + N K b(60-b))`**. Predicted pre-landing-policy
speeds, legacy uncapped budget:

| Hz | AA | Hop1 | Hop2 | Hop3 | Hop4 | Hop5 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 12 | 325.115364 | 385.875628 | 438.292140 | 485.077313 | 527.730992 |
| 64 | 100 | 325.115364 | 385.875628 | 438.292140 | 485.077313 | 527.730992 |
| 128 | 12 | 380.480781 | 476.477964 | 556.144653 | 625.749551 | 688.351745 |
| 128 | 100 | 385.875628 | 485.077313 | 567.186036 | 638.827050 | 703.206940 |

These are **no-stamina ideal mathematical maxima**, including the AA12 rows. They
are not vanilla hop-chain maxima. With the oracle's explicitly approximate midpoint
deadstrafe classification, hop 5 becomes 508.377570 (AA12/64),641.687025 (AA12/128),
and remains527.730992/703.206940 for AA100. Changing the flight model to the ideal
impulse changes K to49/97; run `python3 tests/movement_oracle.py` to regenerate
the full predictions as JSON.

For a declared takeoff-only275 clamp with no stamina, constant-F1 recurrence is
`L_n=sqrt(min(L_(n-1),275)²+K D)`, with first takeoff250. The Python function accepts
that sensitivity policy. It must not be labelled exact vanilla. The GOKZ authors
report that normal landing stamina with cost 0.05 can reduce a 250-speed knife landing
to about 183.05, and the next jump height from about 55 to 40. Those are **their
observations**, not ours or a complete stamina equation. MovementAPI separately
calls out perfect hops that retain speed. Neither justifies multiplying every
landing speed by one magic factor. **Exact vanilla N-hop maximum remains unresolved**
until jump acceptance, recovery, landing penalty and contact order are measured on
a specified legacy server. The oracle intentionally returns null for that claim.

## Ground friction and acceleration fixture

Flat material F1, weapon-like M250, acceleration A5.5, friction f5.2, stopspeed S80,
rate r. First reduce speed with friction:
`q=max(0, s-max(s,S) f/r)`. Add `max(0,min(A M/r,M-q))` along the forward wish
direction. No ground acceleration is added when the existing projection exceeds M.
These are the public shared acceleration/friction rules applied to a straight knife
fixture; game-specific encumbrance, walk/duck, surface and grounded clamps are separate.

Released input: above 80, each tick multiplies speed by `1-5.2/r`; below 80, subtract
`5.2×80/r` each tick down to zero. This yields a geometric segment followed by a
linear segment. The oracle computes it in closed form and checks against iteration.

| Rate | Ground acceleration budget/tick | First tick from rest | First released tick from250 | After32 released ticks |
| ---: | ---: | ---: | ---: | ---: |
| 64 | 21.484375 | 21.484375 | 229.6875 | 0 |
| 128 | 10.7421875 | 10.7421875 | 239.84375 | 65.273568 |

As with the air table, 32 ticks are unequal durations between rates. No damping is
applied to airborne horizontal velocity when the input is zero.

## Units, hulls and collision scope

P mapping: **1 Source u = 0.0254 m**, choosing the conventional inch-based scale.
It is a conversion convention, not a claim that a character's art is anatomically
to scale. Multiply coordinates, speeds and accelerations by 0.0254, keep seconds
and dimensionless coefficients unchanged. Gravity becomes 20.32 m/s², impulse
7.670631776 m/s, wishspeed 250 becomes 6.35 m/s, cap 30 becomes 0.762 m/s, and stopspeed 80
becomes 2.032 m/s. A 32×32×72 u standing hull becomes 0.8128×0.8128×1.8288 m.

The [CS:GO mapper reference](https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive/Mapper%27s_Reference)
is search-indexed with 32×32×72 standing and 32×32×54 crouched boxes. Its full page
was blocked by Anubis here, so treat the crouched 54 value as **indexed documentation,
not a freshly read or measured hull**. Proposed crouch height is 1.3716 m. Valve's
public [generic game-rules hull](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/gamerules.cpp)
uses standing 72 but duck 36, and generic eyes 64/28. Even the public AlliedModders
`hl2sdk` csgo branch's generic game-rules file retains those defaults. It does not
prove CS:GO-specific duck or eye dimensions. Do not transplant generic duck 36 into
a supposed CS:GO implementation. Standing height 72, half-width 16 and eye 64 are
reasonable explicit P starting values; eye 64 is 1.6256 m and still needs game validation.

Use an axis-aligned hull for fidelity experiments. A Godot capsule is an intentional
collision approximation: corner contacts, ledges, stairs, slopes, ground probes and
step height can differ even if the pure acceleration equations match. No runtime
hull, step, jumpbug, distbug or surf-plane validation was performed in this task.

## HUD sync is a chosen metric

In the sampled shavit core, `CalcSync` returns 100×good/eligible measures (or disabled
-1). Sampling requires airborne state, a nonzero yaw change and horizontal speed,
excludes ladders and water, and branches on facing relative to velocity. For normal
forward-facing play (within 22.5°), a good sample pairs turn sign with the **previous
command's** side input (threshold 100). There are separate half-sideways, sideways
and backwards branches. The stored variable's name `iGoodGains` does **not** mean
that actual velocity gain was measured. This is plugin-specific input/turn agreement.

R14 recommendation (P): label the HUD **A/D sync**, measure eligible airborne turning
ticks with a single nonzero A or D intent and horizontal speed, and count same-screen-
direction turns as good. Show an em dash when there are no eligible samples. Exclude
no-input coasting from the denominator, count opposite turns as bad, and document
that this simplified metric is not bit-identical to shavit's angle/style branches.
A 100% agreement score does not prove optimal yaw speed. A separate **gain efficiency**
can compare actual speed change to the optimal rule for that tick; do not call it
server sync. Jump gain should identify its endpoints: landing-before-penalty minus
takeoff speed for air gain, next-takeoff minus prior-takeoff for net chained gain.
Keep perfect-jump percentage separate too: [shavit's bhopstats API](https://github.com/shavitush/bhopstats/blob/master/scripting/bhopstats.sp)
counts jumps on the first eligible ground transition, not A/D sync.

## Commands, results and remaining limits

Executed from the prepared workspace:

```sh
python3 tests/movement_oracle.py --self-test
python3 tests/movement_oracle.py
```

Result: four mathematical test groups pass. Checks cover a36,001-angle brute sweep
for each speed/budget case, closed-form arc versus repeated optimal ticks,
closed-form friction versus recurrence, cap/budget discriminators and ballistic/hop
identities. They test the independent derivation, not the game implementation.

The original research produced oracle self-test output, JSON predictions, compressed
source snapshots, source metadata, a failure log and checksums. Those evidence files
are not retained in this repository. The [source metadata](reference/README.md)
preserves download URLs, hashes and fetch dates; the commands above regenerate the
original oracle's mathematical checks and predictions without those snapshots.
The research produced no rendered frames, movies or runtime traces because no game
was launched. No display/audio/profile was touched.

Failed trials: VDC fetches hit Anubis/403; GitHub tracking-history API returned503;
GitHub HTML reads stalled and were cancelled; several speculative raw paths gave404;
DuckDuckGo eventually challenged searches and Bing returned irrelevant results.
The first mathematical test run used an angle grid too coarse for its0.001 speed
error threshold; increasing the sweep from3,601 to36,001 points made the numerical
comparison resolve the analytic optimum. No physics rule was changed to pass it.
`beadside search foldrunner --scope open --json` failed because this prepared
worktree has no beads database. No issue state was changed.

No external CS:GO session, user trial, runtime equivalence, native Windows execution,
or enjoyment is claimed. The largest remaining fidelity gaps are vanilla stamina/
landing order, late-legacy air-surface timing, hull overrides and exact jump ordering.
