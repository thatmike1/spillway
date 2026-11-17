# Tether feedback

Optional r22 presentation layer. `scripts/fx/tether_feedback.gd` observes the existing grapple runner; it does not write runner properties, select anchors, raycast, inject input or advance readiness. The original release/break cues and target preview remain owned by the runner.

## Observed contract

`movement/grapple_player.gd` exposes `r21_acquisition_snapshot()`: state, stable ID, name, world position, eye distance, candidate serial, attached, assist and ready. This accessor copies cached state and does not run selection. Inherited public readings supply `grapple_length_u`, `grapple_count`, `velocity`, `U`, `input_enabled`, `camera`, `reel_active()` and the pure hull-centre accessor. `get_motion_state()` supplies the recording observation used in identity tests. Never use `_find_target()` or `_update_r21_candidate()` for presentation.

## Host integration

Create one observer as a host child after runner creation, then call `attach(player)` and `configure(settings)`. `attach` returns false for runners without the observational capability; there is no map-ID check. Process priority 100 observes the runner after its render callback. Call `reset()` at attempt/pause boundaries, and free/recreate the observer on map change. The observer also resets while paused, input-disabled or its runner is freed. It does not retain recordings or bests.

When the readable rope is enabled, the host should suppress the inherited straight `_tether` visual so a second straight line does not cross the sag. That presentation switch belongs in the host, never in this observer. Restore the inherited visual when disabled. The original preview is always retained.

Every setting is an independent boolean, missing means false:

| Setting | Effect | Default |
| --- | --- | --- |
| `tether_rope_visual` | Cream segmented line; slack sag capped at 1.8 m; warm tension tint | off |
| `tether_attach_cue` | 0.18 s expanding endpoint ring | off |
| `tether_reel_audio` | Pending slice 2 | off |
| `tether_tension_audio` | Pending slice 2 | off |
| `tether_wind_audio` | Pending slice 2 | off |
| `tether_speed_fov` | Pending slice 3 | off |
| `tether_anchor_readability` | Pending slice 3 | off |

No setting is part of movement or recording identity, and toggles must not restart attempts.

## Verification

`tests/tether_feedback_identity.gd` runs a deterministic 384-tick mouse/strafe tape through the real Arc motor, with attach, reel, release and reset. It compares `var_to_bytes` for every transform, velocity, complete motion observation and rules hash with the layer on and off. It also checks the observation immediately before/after three render updates per physics tick. This is an isolated world test, not a claim of course completion or a replacement for lane 00's original-map parity gate.

Run through the pinned shared-lock wrapper:

```sh
python3 tools/play.py --headless --audio-driver Dummy --script res://tests/tether_feedback_identity.gd -- --out=/tmp/r22-04-swing-feel/identity
python3 tools/test.py --out /tmp/r22-04-swing-feel/fast
```

Output is external scratch; read results and remove it. Visual acceptance and play preference require captured first-person footage and Mike's reaction.
