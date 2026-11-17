# Gantry

Gantry is a tidal crane runway where long concrete aprons feed two flooded transfer slots. One continuous dark portal crane is the landmark, its high crossbeams carrying the orange attachment rings. From spawn the player sees a pale runway ending at the first water slot and the receiving apron through the portal. Concrete piers run down into the water and the crane legs stand on their own side quays. The route alternates room to build hop speed, an Arc transfer, a receiving runway, another Arc transfer and a final dispatch apron.

The course uses the existing grapple runner and unchanged Arc law. Motor parity and earned route evidence are recorded by the gantry tests; human enjoyment remains untested.

## Movement evidence

`tests/gantry_runner.gd` runs both real collision adapters over the same flat slab with the rope idle and F2 settings. It compares positions, velocities, jump counts and landing counts at every tick. The 1,024-tick comparison passed exactly: 11 jumps and final horizontal speed 362.317167867826 u/s on each runner. Grapple inherits the course motor through the lab chain; the disabled slide and wall-jump hooks make no change. A separate earned route check uses normal spawn and ordinary commands for both paths.

## Measured ground modules

Longitudinal pads and clear gaps are both 1.6256 m (64 Source units), with 3.2512 m centre pitch and no height change. These values come from lane 12's independently checked Eazy t1818 row. Gantry uses nine pads after the first run-up apron, then seven after each receiving apron. Pads are broadened to 13.0048 m (eight 64-unit modules) for air-strafe space; this is an original arrangement, not an imported map. Each pad extends into the tidal water and has matching visible and collision geometry. The two rope slots remain 18 m clear and use Gantry-specific anchors.

The source row establishes adjacent support spacing, not one jump per pad or F2 difficulty. Gantry's tapes skip pads according to earned speed. No external BSP, screenshot or concept image enters the repository. Materials and sky reuse the project's existing assets and shaders.

## Authored look

`own_look: true` keeps the map's sky and materials instead of the inherited Practice fallback. The concrete shader and its provenance are under `assets/maps/gantry/`; existing project sky, wear and water resources are reused. Receiving aprons carry continuous orange edge paint, while ordinary hop pads remain pale. Cross-bearings connect the pads to the crane quays below the route tops; gantry foot plates make the post connections visible. Those bearings are collision geometry with the structure role, not extra route platforms. The Gantry-only rope stroke copies the runner's visual mesh at a smaller radius and never writes motor settings or force coefficients.

## Earned hop and swing comparison

Both ordinary-event tapes finish in the production host with zero respawns, then replay exactly through that host. The host timer reads 10.4375 s for basic air strafing and 7.8359375 s for the faster technique. Input durations including the run-up before the timer starts are 1,360 ticks (10.625 s) and 1,027 ticks (8.0234375 s). Basic starts hopping after tick 50 and releases 14 m past the takeoff edge; faster starts after tick 80 and releases 12 m past it. Basic stops adding air-strafe speed around 350 u/s; faster continues. These are two complete techniques, not an isolated single-variable trial. No position, velocity or view angle is injected: buttons/actions and relative mouse events drive the real host and motor.

| Transfer | Basic entry / exit (u/s) | Faster entry / exit (u/s) | Basic / faster attached ticks |
| --- | --- | --- | --- |
| First slot | 351.65 / 493.37 | 568.80 / 613.68 | 184 / 130 |
| Second slot | 494.19 / 494.27 | 763.94 / 723.36 | 160 / 105 |

The rope adds speed too, so swing speed is not hop speed multiplied by a fixed factor. Faster ground entries retain higher horizontal exit speed through these Arc transfers. Arc preserves incoming speed above its 650 u/s pull limit. Release timing also affects duration and exit speed. This is scripted verification, not a claim about human difficulty or enjoyment.

`tests/gantry_routes.gd` boots the production host, calls its public normal-spawn restart after warm-up, and records/replays actual input transitions with zero-based tick/128 timestamps. It checks the host's finish flag, zero respawns and exact replay ticks. `tests/gantry_runner.gd` is the separate flat-ground motor parity check. Earlier captures using an unsettled/warmed spawn and a wrapper that collapsed early input ticks were rejected as finish evidence; no motor tuning was used to reconcile them.

Run `python3 tools/play.py --headless --editor --import --quit` before local direct tests, then `python3 tools/play.py --headless --audio-driver Dummy --script res://tests/gantry_runner.gd` and `python3 tools/play.py --headless --fixed-fps 128 --audio-driver Dummy --script res://tests/gantry_routes.gd -- --out=/tmp/r22-03-hop-into-swing/routes`. Generated JSON tapes and evidence belong outside Git. All commands use the pinned engine lock.
