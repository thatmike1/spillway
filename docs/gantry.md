# Gantry

Gantry is a tidal gate service dock beside an open water channel. Its landmark is a raised caisson, suspended in guides from an overhead crane rooted in two long working quays. From spawn, two smaller swing portals frame the running channel while the gate chamber stands to the right. A walkable service ramp connects the right quay to the gate dock, and a broad dispatch court catches the runner beyond the timed finish. Pale concrete, weathered blue-green sides, restrained working-edge orange and a painted cloud sky carry the place.

The course uses the existing grapple runner and unchanged Arc law. Motor parity and earned route evidence are recorded by the gantry tests; human enjoyment remains untested.

## Movement evidence

`tests/gantry_runner.gd` runs both real collision adapters over the same flat slab with the rope idle and F2 settings. It compares positions, velocities, jump counts and landing counts at every tick. The 1,024-tick comparison passed exactly: 11 jumps and final horizontal speed 362.317167867826 u/s on each runner. Grapple inherits the course motor through the lab chain; the disabled slide and wall-jump hooks make no change. A separate earned route check uses normal spawn and ordinary commands for both paths.

## Measured ground modules

Longitudinal pads and clear gaps are both 1.6256 m (64 Source units), with 3.2512 m centre pitch and no height change. These values come from lane 12's independently checked Eazy t1818 row. Gantry uses nine pads after the first run-up apron, then seven after each receiving apron. Pads are broadened to 13.0048 m (eight 64-unit modules) for air-strafe space; this is an original arrangement, not an imported map. Each pad extends into the tidal water and has matching visible and collision geometry. The two rope slots remain 18 m clear and use Gantry-specific anchors.

The source row establishes adjacent support spacing, not one jump per pad or F2 difficulty. Gantry's tapes skip pads according to earned speed. No external BSP, screenshot or concept image enters the repository. Materials and sky reuse the project's existing assets and shaders.

## Authored look

`own_look: true` keeps the map's sky and materials instead of the inherited Practice fallback. `scripts/art/gantry_drydock.gd` builds the supported crane, raised gate in its open channel, connected quays, servicing hall and continuous distant coast. The service ramp and working quay/pylon collision proxies sit outside the original timed footprint. All 58 original collision solids remain unchanged. `gantry_arrival.gd` adds a run-out beyond the original finish without moving its box, pads or anchors.

The map-local concrete/water/outline shaders and provenance live under `assets/maps/gantry/`. Existing project sky, wear and structural-ink resources are reused. Lighter architectural concrete distinguishes the crane and hall from darker channel walls. Receiving aprons keep orange lips; ordinary hop pads stay pale. Cross-bearings, receiver piles and gantry foot plates explain the structural connections.

The rope stroke copies the runner's visual mesh and tapers its projected diameter to about two pixels, with the previous 6 mm world radius as a maximum. Its visual endpoint clips before the camera near plane when the anchor passes behind the view. It never writes the attached anchor, motor settings or force coefficients. `tests/gantry_rope.gd` exercises the actual runner's render transform and checks projected widths plus complete motion-state preservation.

## Earned hop and swing comparison

Both ordinary-event tapes finish in the production host with zero respawns, then replay exactly through that host. The host timer reads 10.4375 s for basic air strafing and 7.8359375 s for the faster technique. Input durations including the run-up before the timer starts are 1,360 ticks (10.625 s) and 1,027 ticks (8.0234375 s). Basic starts hopping after tick 50 and releases 14 m past the takeoff edge; faster starts after tick 80 and releases 12 m past it. Basic stops adding air-strafe speed around 350 u/s; faster continues. These are two complete techniques, not an isolated single-variable trial. No position, velocity or view angle is injected: buttons/actions and relative mouse events drive the real host and motor.

| Transfer | Basic entry / exit (u/s) | Faster entry / exit (u/s) | Basic / faster attached ticks |
| --- | --- | --- | --- |
| First slot | 351.65 / 493.37 | 568.80 / 613.68 | 184 / 130 |
| Second slot | 494.19 / 494.27 | 763.94 / 723.36 | 160 / 105 |

The rope adds speed too, so swing speed is not hop speed multiplied by a fixed factor. Faster ground entries retain higher horizontal exit speed through these Arc transfers. Arc preserves incoming speed above its 650 u/s pull limit. Release timing also affects duration and exit speed. This is scripted verification, not a claim about human difficulty or enjoyment.

`tests/gantry_routes.gd` boots the production host, calls its public normal-spawn restart after warm-up, and records/replays actual input transitions with zero-based tick/128 timestamps. It checks the host's finish flag, zero respawns and exact replay ticks. `tests/gantry_runner.gd` is the separate flat-ground motor parity check. Earlier captures using an unsettled/warmed spawn and a wrapper that collapsed early input ticks were rejected as finish evidence; no motor tuning was used to reconcile them.

Run `python3 tools/play.py --headless --editor --import --quit` before local direct tests, then `python3 tools/play.py --headless --audio-driver Dummy --script res://tests/gantry_runner.gd` and `python3 tools/play.py --headless --fixed-fps 128 --audio-driver Dummy --script res://tests/gantry_routes.gd -- --out=/tmp/r22-03-hop-into-swing/routes`. Generated JSON tapes and evidence belong outside Git. All commands use the pinned engine lock.


## Preserving the original course

`tests/gantry_preserved.gd` compiles external git-extracted wave1 map/art source from `9b6136d` and compares the actual generated collision manifests. Every original solid, original anchor position and checkpoint pose/bounds must remain exact. New solids must stay outside the old timed footprint, and Gantry's finish box must remain unchanged. The baseline source files stay outside the project. Run this script through `tools/play.py` with `--baseline-map=/absolute/old-map.gd`, `--baseline-art=/absolute/old-art.gd` and `--out=/tmp/r22-03-hop-into-swing/preserved` after the separator.

`tests/gantry_capture_check.py` checks earned native captures for zero respawns, at least two finish observations and stable support after finishing. A zero respawn counter alone is insufficient: the host can return a falling winner to the finish without incrementing that counter.


## Gantry Chain

Gantry Chain is a separate map identity. It reuses the original three ground sections and two transfers, then continues beyond dispatch into a 28 m water slot. The third ring is at (0,22,−110), above the takeoff. The outer receiving apron leads through four more 64-unit hop pads into a continuous dispatch court. Original Gantry retains its two-transfer finish. All three Chain anchors have Chain-specific IDs.

The earned Chain tape catches the third ring three motor ticks after a hop, at 806.8799 u/s, compared with 763.9361 u/s into transfer 2. It releases at 561.0380 u/s with feet 7.4707 m high, trading horizontal speed for height. It finishes in 11.515625 s (1498 input ticks including the initial run-up), with 11 jumps, zero respawns and identical replay finish/transfer events. This establishes a scripted line, not human difficulty or enjoyment.

The production-host comparison replays the original fast tape on both maps through the old finish. All 1,028 sampled positions, velocities, jump/landing counts and grounded flags match exactly, with worst position and velocity errors 0.0. The Chain course does not finish at the old destination.

A successful timer alone did not establish a supported arrival: an early prototype fell into its last pad gap after winning, then the host returned it to the finish without adding a respawn. The court now starts before that gap. `tests/gantry_coast.gd` retains ordinary held input for 160 additional motor ticks after the win; minimum feet height changed from −7.6514 m to 4.0172 m while the finish remained at tick 1498. The native capture checker independently checks support after winning.

Run the earned/replayed route with `python3 tools/play.py --headless --fixed-fps 128 --audio-driver Dummy --script res://tests/gantry_chain.gd -- --out=/tmp/r22-03-hop-into-swing/chain`. Use the same wrapper with `res://tests/gantry_coast.gd` for the additional coast check. Generated tapes and receipts remain outside Git.


The final scenery adds a raised caisson across a working water channel, quay access, rail-mounted portal trucks, lifting carriages and a connected harbour signal house. The dispatch court has a skylit roof and glazed harbour overlook. All geometry and shaders are original; the existing project sky and aggregate texture retain their manifest provenance.

The original basic tape earns its unchanged finish but can fall into a preserved hop-pad gap when forward/jump stay held for 160 more ticks. The fast original tape stays supported (minimum feet 4.017 m). This is a post-finish limitation, retained to preserve the original sections. Gantry Chain's new continuous final court stays supported over the same 160-tick coast check.
