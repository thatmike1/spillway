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
| `tether_rope_visual` | Slender cream cable with dark outline; slack sag capped at 1.8 m; warm load tint | off |
| `tether_attach_cue` | 0.18 s expanding endpoint ring and 90 ms synthesized latch click | off |
| `tether_reel_audio` | Real reel activity drives a quiet mechanism loop | off |
| `tether_tension_audio` | Applied grapple impulses and extension drive a low load tone | off |
| `tether_wind_audio` | Speed above 250 u/s raises a bounded wind layer | off |
| `tether_speed_fov` | Separate presentation lens, maximum +3° at 1.5°/s | off |
| `tether_anchor_readability` | Cream ring only for the cached ready anchor, capped near the camera | off |

No setting is part of movement or recording identity, and toggles must not restart attempts. Handle these keys before the generic host `change_setting`: assign the boolean, call observer.configure(settings), save, and return. The generic handler treats names ending in `fov` as a style discontinuity and reapplies runner settings, which is inappropriate for these presentation toggles.

## Verification

`tests/tether_feedback_identity.gd` runs a deterministic 384-tick mouse/strafe tape through the real Arc motor, with attach, reel, release and reset. It compares `var_to_bytes` for every transform, velocity, complete motion observation and rules hash with the layer on and off. It also checks the observation immediately before/after three render updates per physics tick. This is an isolated world test, not a claim of course completion or a replacement for lane 00's original-map parity gate.

Run through the pinned shared-lock wrapper:

```sh
python3 tools/play.py --headless --audio-driver Dummy --script res://tests/tether_feedback_identity.gd -- --out=/tmp/r22-04-swing-feel/identity
python3 tools/test.py --out /tmp/r22-04-swing-feel/fast
```

Output is external scratch; read results and remove it. Visual acceptance and play preference require captured first-person footage and Mike's reaction.

## Audio lifecycle and provenance

All four new sounds are synthesized by `scripts/audio/tether_sound.gd`; `assets/audio/tether/MANIFEST.json` records provenance. A private RNG seed leaves the global random stream untouched. Loop frequencies are integer multiples over one second, so each wrap is continuous. Gains follow volume, independently stop when toggled off, and all voices stop on observer reset/free, pause or invalid runner. Reel and load changes ease over about 0.125 s; they never delay physics. The existing release and break cues are untouched. The observer reads actual per-tick `grapple_pull`/`grapple_rope` impulses plus extension for load, and real `reel_active()` for reel state.

## Lens and anchor readability

The lens is a separate observer-owned Camera3D. It copies the source pose, projection, culling, environment, compositor and attributes, then adds up to 3 degrees across 400–1000 u/s with a slow response and a 1.5 degree/second rate limit. Disabling or resetting it restores the original viewport camera; if that camera was freed or detached during a map boundary, it requests the next registered camera instead. It never edits runner camera properties or `settings.fov`, which physics acquisition uses. There is no shake, blur, pose offset or FOV impulse on attach/release. Godot's [Camera3D API](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) defines the separate viewport camera selection.

The cream ready ring supplements, rather than replaces, the existing preview. It reads only the cached snapshot `ready` and position. No separate range estimate, raycast or target search can disagree with the runner's published candidate. A parallel-up guard keeps rings valid when looking directly above/below.

Additional checks: `tests/tether_feedback_audio.gd` covers all-off defaults, rope endpoints/sag, deterministic PCM and audio stop/reset; `tests/tether_feedback_lens.gd` alternates speed at 60 Hz and checks bounds, rate limit, source-FOV preservation and lens restoration. Run these with the same `tools/play.py --headless --audio-driver Dummy --script res://tests/NAME.gd` wrapper.

## Visual bounds

The cable has a 2 mm core radius near the hand with a 3.2 mm inverted-hull outline. At distance a restrained pixel floor keeps the connection legible against bright clouds: approximately 1.2 pixels for the core and 2.7 pixels for the outline at ordinary FOV, with at most 15% load widening. World radii remain bounded (core ≤57.5 mm, outline ≤103.5 mm). The outline culls front faces as documented in Godot's [BaseMaterial3D reference](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html#enum-basematerial3d-cullmode), so it frames rather than covers the core. Neither part casts shadows or changes collision.

Ready and attach rings shrink within 10 m of the eye, capping their angular radius at about six degrees even when passing close to an anchor. Ready still means exactly the cached physics candidate; it does not promise a future line or select a different anchor.

## Portable-map and recording proof

The identity test also writes two disposable fixture recordings through the production recorder, reads them through the production reader, and compares serialized motion columns bit for bit. Headers contain creation timestamps/run IDs and are deliberately excluded. Fixtures are not clean or finished runs and live only beneath the supplied external output path. Neither recorder nor reader implementation is changed.

Three temporary full-host catalog entries explicitly declare `grapple: true` and the unchanged shared Arc runner under different IDs. They check observer replacement, fresh runner binding, unchanged motor/attempt/identity on all toggles, lens handoff, pause reset and return to an original map with no observer. These are ephemeral capability-dispatch fixtures, not newly published levels or claims that another lane's route finishes. The host owns capability gating; the observer never tests map names.

The player end follows the current projection to sit just below the viewport, avoiding a loose endpoint inside the aiming view without inventing a hand or moving the camera. A projection test covers 45°, 80° and 120° FOV. Endpoint rings have an original dark inverted-hull contour for contrast against pale clouds; their total apparent radius, including the outline and full attach expansion, remains about six degrees or less.
