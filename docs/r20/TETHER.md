# R20 Tether Yard

Hold **LMB** to acquire a marked ring and keep its rope. Release LMB to coast. Hold **RMB** while attached to reel; RMB alone cannot acquire. The pause sheet offers **Reel on right mouse** and **Reel automatically while attached**, plus three named models. Classic with manual reel is the default. **E remains Movement Lab's original binding and cannot attach in Tether.** Space jumps, A/D and mouse air-strafe, Ctrl/C crouches, R restarts, F practices the last checkpoint and Esc pauses.

Tether stays under Experiments with a fixed grapple-only runner. Wall jump, slide and old loadout toggles are disabled. The original course's 30 collision pieces, all three anchors, catch court, return ramps and Look C remain. New inherited-level code changes the control lettering and hints only. The original R19 Tether files stay byte-identical reference code.

## The three models

All are experimental game choices, rather than claims about another game's physics. Units below are Source units, with 1 u = 0.0254 m.

| Model / law | Player note | Behavior and tuning |
|---|---|---|
| Classic / `r15-lab-grapple-1` through `r20-tether-mouse-1` | Bounded spring and radial catch; both buttons reproduce R19 E. | Exactly the old reeling expression when RMB or automatic reel is active. Cancel outward radial velocity when taut, then spring stiffness 30, pull capped at 1300 u/s² and speed capped at max(previous speed, 650 u/s). 3 s attachment limit. Without reel, keep rest length rather than ratcheting it inward. |
| Pendulum / `r20-pendulum-1` | Fixed rope, taut catch, no spring; no added speed cap. | Keep rest length without reel. When taut, add only the inward radial correction needed for radial speed >= excess length / dt. Never add spring pull. RMB or the automatic preference shortens the rope. 5 s limit. No extra grapple speed cap; the unchanged Source motor's own component bounds remain. |
| Elastic / `r20-elastic-1` | Spring and damping with slack; stronger 1800 u/s² pull. | No hard radial cancellation. At/above rest length use inward acceleration min(1800, 90*extension + 10*max(outward radial speed,0)), integrated over dt. Slack exerts no force. Cap resulting speed at max(previous speed,650 u/s), using the same quadratic share calculation. 5 s limit. |

Shared acquisition is the old eye ray, nearest view-centre anchor within 9 degrees and 1181 u (29.9974 m). Shared reel rate is 260 u/s. While reeling, rest length becomes max(96, min(previous length, current centre distance)-260*dt). A 96 u (2.4384 m) rest length is a **reel floor, never a detach condition**. Alternative timeout, pull and speed-cap differences are stated in the actual pause controls. The full numerical tuning is also embedded in recording mechanics identities.

The old law receives grounded state but does not branch on it. In the R19 playtest and component's recreated sequence, reeling on the ground pulls the player horizontally under the anchor while feet remain at deck height; a subsequent real Space jump lifts into the rope. That is observed combined rope/contact/motor behavior, not an invented ground-only grapple rule and not a guarantee for every possible entry.

## Predictable release and re-arming

On each classic attached step, priority is: mechanic disabled, LMB no longer held, elapsed attachment ticks, centre distance, then centre-to-anchor line of sight. Both buttons use the old arithmetic and branch order. At F2, 384 attached force steps remain allowed; step 385 detaches for time. The alternative time limit is 640 steps, followed by release on step 641.

| Reason | Rule / player feedback |
|---|---|
| `released` | LMB is up at the next physics step. A short soft cue accompanies “Released · coast”. |
| `time` | Classic has consumed 3 s, alternatives 5 s. Falling tone, “Line expired”, visible remaining time before release. |
| `range` | Centre distance exceeds 1261 u (32.0294 m). Rising double contour, “Line broke · beyond 32.03 m”. |
| `obstructed` | Centre ray is blocked; a hit within 0.3 m of the anchor counts clear. Broken/pulsed tone, “Line blocked · centre ray hit”. The eye ray is only the acquisition rule; the aim cone is not re-tested on an attached line. |
| `off` | Inherited disabled-move rule remains, but production Tether cannot disable its fixed grapple. |

Automatic breaks retain the old fresh-press latch. Continuing to hold the mouse cannot reacquire. Release LMB and press it again; RMB alone cannot bypass the latch. Failed acquisition can still become valid while LMB remains held, matching old E acquisition behavior. No minimum-distance, low-speed, aim-cone or ground-only detach was added.

Pause, restart, practice, respawn, map selection, applied preset, changed rope model/reel preference and quit clear any live line. Pause freezes motion and releases the rope; resume requires release of the mouse buttons and a fresh gameplay LMB press. Menu clicks and held buttons across these boundaries cannot attach. Unchanged/rejected model or preference calls do nothing. The HUD distinguishes armed, blocked-until-release, attached/swinging/reeling, remaining time and the last release reason.

Cues are original procedurally generated mono 22050 Hz signed 16-bit PCM. `TetherReleaseCue` is a real AudioStreamPlayer. Its activation, chosen stream, PCM SHA256 and reason are observed on Dummy. That proves resource activation, not that anyone heard or liked the sound. Volume follows the inherited volume setting, including mute.

## Production, persistence and compatibility

`scenes/r20.tscn` loads `r20_main.gd`; its real registry routes only `tether-yard` to `r20_tether_level.gd` and `r20_tether_player.gd`. `_new_hud` supplies `r20_hud.gd`, which extends the R19/R18 sheet and keeps the existing Experiment cards. Nothing remaps InputMap mouse actions globally.

The existing profile's settings section gains `tether_model` (classic/pendulum/elastic, invalid values become classic) and `tether_auto_reel` (boolean, default false). Load happens before runner creation. Actual menu selection saves them. A fresh scene reloads them through the normal startup path. Controls are visible only in Tether and cannot modify those settings on other maps.

Changing either setting records a loadout boundary, discards unbanked directional style before sealing, clears the rope, refreshes the motion key, and restarts from spawn. A paused preference change keeps the pause sheet open. A different model or automatic-reel preference adds a different complete `tether_identity()` entry to mechanics; runner/version and mechanics enter the existing full time/ghost key. Old R19 E ghosts and other rope identities are rejected by the unchanged ghost loader, even though classic both-button physical motion is equivalent. The pause sheet states this incompatibility. All eight original map full motion/record identities and the six F2 pins remain unchanged.

The frozen session, recorder, readers, ghost loader, Source motor and original map files are untouched. No scoring rules changed in this component; the accepted R20 directional lifecycle wrappers remain in place.

## Recording diagnostics

The binary container stays version 1. It already records every ordered key/button/action/motion input column, including both `relative` and `screen_relative`. Mouse held masks alone are insufficient. The component extracts raw key/button/motion rows from an actual sealed recording, replays them through the production host, regenerates action rows normally, then requires exact equality of **all tick columns and the entire ordered input table**. Both original strict readers must agree on headers, seals, events, input columns and motion columns.

The new runner emits a read-only `tether_diagnostic` signal. The R20 host forwards it as recorder event kind `tether`, source `event`, never as scored style. Payload: `v=1`, `kind=attach|release`, `reason`, `model`, `automatic_reel`, `attached`, `length_u`, and attached age `ticks`. Release also includes `attached_ticks`, `anchor` and `cue={serial,reason,active,pcm_sha256}`. `active` is the AudioStreamPlayer state immediately after `play()`, not a claim that the stream is still playing later. Outer recorder `t` supplies the session tick; a pre-seal lifecycle release can occur between motor samples.

Read-only `get_motion_state().experiment.tether` supplies `model`, `automatic_reel`, `reeling`, `blocked_until_release`, `armed`, `left_s` and `last_cue`. Existing grapple/impulse/event/count dictionaries retain their meanings. This richer motion object is available to observers; the unchanged recorder does not serialize every arbitrary motion field, so persisted release/model diagnostics use the explicit supported event stream.

## Reproduction and evidence limits

From this project directory:

```bash
python3 -I tests/r20_tether_check.py --out=/tmp/r20-tether-independent
```

Use a fresh output directory. The helper uses the pinned `/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`, sequential headless engines with Dummy, isolated XDG data/config/cache, a bounded source/import snapshot, a 350 MiB scratch cap and a 15,000,000,000-byte HOME floor. `--keep-source` retains the snapshot temporarily. `--only=component` or `--only=routes` is focused verification, not full acceptance. `--audit-only` reconciles an already complete run while its source snapshot exists.

The exact independent reference is `r19_tether_player.gd` extracted byte-for-byte from `065f7b27993df7ae2511eb34eb665d271dded13c`, with its frozen R15/R16 ancestors checked against Git. Compare physical samples and per-cause rope/pull impulses, not an old-looking wrapper around the new law. Ground, jump, minimum-length, timeout, blocked-eye/centre-ray and range stress fixtures also pair to that old E implementation. The range fixture explicitly starts with extreme tangential velocity in collision-free bounds; its identity labels that setup. It proves the real range branch, not an ordinary player line.

Other acceptance covers actual pause controls by keyboard and pointer, saved preference reload, pause/held/restart/map/practice/respawn/preset/quit isolation, real pending-style discard, ghost refusal, alternative LMB swings, and a clean input-earned route/replay for every model. Route finding is coordinate-aware; replay reads saved inputs without feedback. Setup may establish identified collision fixtures and initial stress velocity. No body poses, velocities, camera, progress, score or statistics are written after fixture setup, except the production lifecycle methods being tested.

All failed attempts are retained and classified in the external contract. Clean route timings demonstrate existence, not fastest lines, discoverability or enjoyment. Headless HUD/cue evidence does not establish native appearance, listening, native Windows execution or final package/release acceptance.

## Parent native seam

Use the same isolated source/import procedure. For earned moving views, run the pinned engine on the parent's private display with `--windowed --resolution 1280x720` (or 1920x1080), `--fixed-fps 128`, `--path ABS_SOURCE`, `--script res://tests/r20_tether_native.gd`, then user arguments `--out=ABS_DIR --size=1280x720 --model=classic` (or pendulum/elastic). Add `--tape=ABS_RECORDED_TAPE` for the actual saved-input line. It saves route/release frames and the same full trace/recording proof. It never poses the body or view.

For the actual preference pointer control, run `tests/r20_tether_boundaries.gd` with `--out=ABS_ROUTE_ROOT/boundaries-native --native --size=1280x720`. That root must contain the five earned route summaries and their referenced recordings: classic, pendulum, elastic, old_e and automatic. It saves `pause-preference.png` and the actual generated `cue-time.wav`, `cue-range.wav`, `cue-obstructed.wav`, `cue-released.wav` for parent listening. No native display or speaker is opened by this component run. The compact `look/evidence/r20-tether-component/CONTRACT.json` binds final sources, results, exact commands, raw proof hashes and these remaining parent checks.
