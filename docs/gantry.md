# Gantry

Gantry is a tidal crane runway where long concrete aprons feed two flooded transfer slots. One continuous dark portal crane is the landmark, its high crossbeams carrying the orange attachment rings. From spawn the player sees a pale runway ending at the first water slot and the receiving apron through the portal. Concrete piers run down into the water and the crane legs stand on their own side quays. The route alternates room to build hop speed, an Arc transfer, a receiving runway, another Arc transfer and a final dispatch apron.

The course uses the existing grapple runner and unchanged Arc law. Motor parity and earned route evidence are recorded by the gantry tests; human enjoyment remains untested.

## Movement evidence

`tests/gantry_runner.gd` runs both real collision adapters over the same flat slab with the rope idle and F2 settings. It compares positions, velocities, jump counts and landing counts at every tick. The 1,024-tick comparison passed exactly: 11 jumps and final horizontal speed 362.317167867826 u/s on each runner. Grapple inherits the course motor through the lab chain; the disabled slide and wall-jump hooks make no change. A separate earned route check uses normal spawn and ordinary commands for both paths.

## Earned hop and swing comparison

On the unchanged Arc law, both generated command tapes finish from normal spawn and replay at identical tick counts. Basic takes 1,568 ticks (12.25 s); better air strafing takes 1,063 ticks (8.3046875 s), 32.21% less time. Both hold Space after the initial run-up, attach and reel at both slots, and release 14 m past each takeoff edge. Neither tape sets position or velocity. The solver's initial release trials failed; they are not completion evidence.

| Transfer | Basic entry / exit (u/s) | Better hop entry / exit (u/s) | Basic / better attached ticks |
| --- | --- | --- | --- |
| First slot | 234.65 / 489.77 | 576.15 / 573.13 | 207 / 142 |
| Second slot | 490.59 / 486.64 | 730.53 / 583.08 | 161 / 126 |

The rope adds speed too, so swing speed is not simply hop speed multiplied by a fixed factor. Faster ground entries traverse the same Arc transfers sooner and retain higher horizontal exit speed. The Arc law does not clamp an already faster incoming runner to 650 u/s. These are scripted input comparisons, not a claim about human difficulty or enjoyment.

Run `python3 tools/play.py --headless --editor --import --quit` before local direct tests, then `python3 tools/play.py --headless --audio-driver Dummy --script res://tests/gantry_runner.gd` and `python3 tools/play.py --headless --audio-driver Dummy --script res://tests/gantry_routes.gd -- --out=/tmp/r22-03-hop-into-swing/routes`. Generated JSON tapes and evidence belong outside Git. All commands use the pinned engine lock.
