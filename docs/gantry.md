# Gantry

Gantry is a tidal crane runway where long concrete aprons feed two flooded transfer slots. One continuous dark portal crane is the landmark, its high crossbeams carrying the orange attachment rings. From spawn the player sees a pale runway ending at the first water slot and the receiving apron through the portal. Concrete piers run down into the water and the crane legs stand on their own side quays. The route alternates room to build hop speed, an Arc transfer, a receiving runway, another Arc transfer and a final dispatch apron.

The course uses the existing grapple runner and unchanged Arc law. Motor parity and earned route evidence are recorded by the gantry tests; human enjoyment remains untested.

## Movement evidence

`tests/gantry_runner.gd` runs both real collision adapters over the same flat slab with the rope idle and F2 settings. It compares positions, velocities, jump counts and landing counts at every tick. The 1,024-tick comparison passed exactly: 11 jumps and final horizontal speed 362.317167867826 u/s on each runner. Grapple inherits the course motor through the lab chain; the disabled slide and wall-jump hooks make no change. A separate earned route check uses normal spawn and ordinary commands for both paths.

## Measured ground modules

Longitudinal pads and clear gaps are both 1.6256 m (64 Source units), with 3.2512 m centre pitch and no height change. These values come from lane 12's independently checked Eazy t1818 row. Gantry uses nine pads after the first run-up apron, then seven after each receiving apron. Pads are broadened to 13.0048 m (eight 64-unit modules) for air-strafe space; this is an original arrangement, not an imported map. Each pad extends into the tidal water and has matching visible and collision geometry. The two rope slots remain 18 m clear and use Gantry-specific anchors.

The source row establishes adjacent support spacing, not one jump per pad or F2 difficulty. Gantry's tapes skip pads according to earned speed. No external BSP, screenshot or concept image enters the repository. Materials and sky reuse the project's existing assets and shaders.

## Earned hop and swing comparison

Both command tapes finish from normal spawn and replay at identical completion tick counts. Basic air strafing builds toward 350 u/s before coasting; the better tape continues air-strafing. Basic takes 1,359 ticks (10.6171875 s); better takes 1,026 ticks (8.015625 s), 24.50% less time. The basic tape starts hopping after tick 50 and releases 14 m past the takeoff edge; the better tape starts after tick 80 and releases 12 m past it. These are distinct complete techniques, not a controlled trial where only one input changes. Neither tape sets position or velocity.

| Transfer | Basic entry / exit (u/s) | Better hop entry / exit (u/s) | Basic / better attached ticks |
| --- | --- | --- | --- |
| First slot | 351.65 / 493.37 | 568.80 / 613.68 | 184 / 130 |
| Second slot | 494.19 / 494.27 | 763.94 / 723.36 | 160 / 105 |

The rope adds speed too, so swing speed is not hop speed multiplied by a fixed factor. Faster ground entries retain higher horizontal exit speed through these Arc transfers. Arc preserves an incoming speed above its 650 u/s pull limit. Release timing also matters: the solver rejected failed candidates rather than counting an attachment as a finish. These are scripted input comparisons, not a claim about human difficulty or enjoyment.

Run `python3 tools/play.py --headless --editor --import --quit` before local direct tests, then `python3 tools/play.py --headless --audio-driver Dummy --script res://tests/gantry_runner.gd` and `python3 tools/play.py --headless --audio-driver Dummy --script res://tests/gantry_routes.gd -- --out=/tmp/r22-03-hop-into-swing/routes`. Generated JSON tapes and evidence belong outside Git. All commands use the pinned engine lock.
