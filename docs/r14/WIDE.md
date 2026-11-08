# A distinct extra comparison

The default target stays CS bhop. The additional experiment will compare broader
Quake-style projection acceleration and a separate CPM-style air-control option.
These are P experiments, not replacements for the requested Source baseline.

The first Quake profile should use the publicly documented projection rule with
the full requested speed as its ceiling, instead of Source's separate 30 u cap.
The released Quake III base game declares ground acceleration 10, air acceleration
1, friction 6, stopspeed 100, run speed 320 and gravity 800. Its jump impulse is 270.
Ground and air input magnitude must not gain a free diagonal multiplier. Forward
plus a side key is a distinct skill from Source's side-only strafe.

An air-control variant may add a separately accounted, speed-preserving turn when
its documented key/heading conditions hold. It cannot quietly mint speed through
mouse movement alone. Its controls must be described separately from Source.

Use the same metres-per-unit convention and collision/body adapter as the Source
experiment where practical, explicitly marking that as a comparison choice. Without
Quake's command subdivision, velocity rounding, full contact and ramp rules, call
it Quake/CPM-inspired, not a faithful recreation. It gets separate records and does
not alter either Source preset or R13.

Useful distinguishing inputs: side-only A/D turns, W+A diagonal turns, no-input
look-around, opposing input, and the same imperfect corner approach. A wider gain
window or an additional steering operation is an observable difference, not proof
of better feel. Both the practice map and Overflow remain the actual comparison.

Primary references:

- [id's released Quake III movement](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/bg_pmove.c)
  and [server defaults](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/g_main.c).
- [Maintainer-hosted CPMA movement guide](https://www.playmorepromode.com/guides/cpma-tdm-gameplay)
  describes single-key air control, Q3-style two-key movement, ramp and double jumps.
  Its [server guide](https://www.playmorepromode.com/guides/cpma-server-settings)
  distinguishes CPM, PMC, CQ3 and VQ3. Neither page is an exact modern formula spec.
- [Xonotic's own CPMA configuration](https://github.com/xonotic/xonotic-data.pk3dir/blob/master/physicsCPMA.cfg)
  documents its emulation choices, including gravity 750 to approximate historical
  125 fps velocity rounding, ground acceleration 15, side acceleration 70 and an
  air-control value 150. These describe Xonotic's reconstruction. They cannot be
  mixed into a supposed untouched Quake III or CS:GO baseline.

Downloaded reference hashes are in outer
`checkpoints/spillway/r14/wide-reference/SOURCES.json`. Source code is research
material only. The experiment must implement original equations, not copy it.

## First playable configuration experiment, 8 November

An external fixture now runs a Quake III-inspired configuration through the Source
adapter: full 320 u wish projection, air acceleration 1, ground acceleration 10,
friction 6, stopspeed 100, gravity 800 and jump impulse 270. It uses 128 Hz, the
shared Source hull/collision and P autohop. Deadstrafe and stamina are disabled.
This is a distinct acceleration comparison, not a Quake recreation or CPM air control.
The experiment is now selectable on F4 in the actual game. It retains Source
contacts and comparison choices rather than claiming a Quake/CPMA recreation.
See QUAKE.md for the product constants, limitations, records and native-route proof.

The independent closed-form fixture checks 64 combinations of rate, initial speed
and wish angle. All agree with the shared tick. At 320 u/s and 128 Hz the calculated
best one-tick gain is 2.480620 u/s, with a wish angle about 7.17 degrees from travel.
Source's separate 30 u ceiling instead rewards near-perpendicular wishes.

Four fixed four-second input tapes compare side-only and diagonal input, with a
slow smooth mouse turn. These are deliberately imperfect inputs, not optimal arcs.
The profiles begin at their own run speed, so this is not a matched-speed benchmark:

| Input | Source AA100, starts 250 u/s | Quake-inspired, starts 320 u/s |
| --- | ---: | ---: |
| A plus the recorded mouse turn, third landing | 256.35 u/s | 479.16 u/s |
| W+A plus the same turn, third landing | 250.00 u/s | 422.09 u/s |

The side-only tapes also ran natively at 480×270 on llvmpipe. All 512 position,
velocity and view samples match their headless counterpart exactly. The selected
frames show the different hop paths on the same checker fixture. Both runs finish
their tapes, release input and leave no owned processes. These frames establish
rendered motion only, not frame rate, latency, course suitability or enjoyment.

Evidence, original fixture/profile, oracle, input tapes, MP4s and compressed traces:
outer `checkpoints/spillway/r14/quake-prototype/RESULTS.json`. These runs predate the
pending Source contact repair and do not establish a final product preset.
