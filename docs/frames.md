# First-person frames

1. Use `python3 tools/shot.py --map breakwater --route basic --out /tmp/r22-playtester/example`.
2. Add `--checkout /absolute/checkout` to capture another checkout without modifying it.
3. `--seconds 12 --every 1` controls simulation duration/spacing; `--size 1920x1080` changes frame size.
4. `--tape /absolute/input.json` replays real input from normal spawn instead of a named route.
5. `--poses /absolute/poses.json` captures static camera views, explicitly separate from playable evidence.
6. The output directory must be new and outside every Git checkout.
7. Open `contact-sheet.png`; individual images are `frame-00000.png` onward.
8. `frames.jsonl` records capture times/positions; route-driver JSONL records route progress and failure.
9. `engine.log`, `display.log`, `import.log` and `capture.json` identify the rendering run.
10. Use `--look old` for matched L-off frames; `python3 -B tests/test_shot.py` checks safety/validation without launching a display.

Captures use the pinned Godot 4.7.2 Compatibility renderer and Mesa llvmpipe software rendering on Xvfb. These are appearance evidence, never frame-time or hardware-performance evidence. Logic advances at fixed 128 FPS with the host’s ordinary 128 Hz physics. Automatic rendering is disabled; `RenderingServer.force_draw()` renders only the requested sample frames. This avoids spending minutes drawing frames that are never saved. Shaders and other render-time effects are sampled at the capture interval, so this is not evidence of animation smoothness. Vector-only route hints are adapted into one-metre steering waypoints with no invented jump inputs; such hints may be insufficient to finish a course. Authored dictionary waypoints retain their jump/crouch flags. A named route starts at the ordinary spawn and uses the existing `spillway_driver.gd` input controller. Route failure is recorded by the driver and does not invalidate images; inspect its result before claiming a finish. A bounded capture may end before the route finishes.

Input tapes are ordered JSON arrays. Times are simulation seconds; action names must match the game's input map. Keyboard events use `{"time":0,"key":"Escape","pressed":true}` for menu inspection. Mouse buttons use `{"time":0,"button":1,"pressed":true}` (1=LMB, 2=RMB). Mouse values are relative pixels, as in the native route driver:

```json
[{"time":0,"action":"move_forward","pressed":true},
 {"time":0.3,"mouse":[20,-5]},
 {"time":0.5,"action":"jump","pressed":true},
 {"time":0.6,"action":"jump","pressed":false},
 {"time":2,"action":"move_forward","pressed":false}]
```

Pose arrays use camera world positions and degrees (`yaw`, `pitch`, default zero). They freeze the player/host physics and move only the active camera. They do not demonstrate traversal, reaching an anchor, or a playable landing:

```json
[{"position":[0,3,0],"yaw":0,"pitch":-10}]
```

The wrapper snapshots the checkout, imports it headlessly and uses a new private profile. It holds the shared engine lock throughout private-display startup, capture and cleanup. Display numbers are restricted to 190–199; filesystem locks, filesystem sockets and abstract X sockets are checked before selecting one. It never launches on or auto-selects `:0`. The desktop's `:0` response is checked before and after; an existing unresponsive desktop socket blocks capture. If there is no desktop `:0`, it must remain absent. Only the Xvfb child this invocation created is terminated. Scratch source, imports and profile are deleted on exit; retained evidence stays in the requested external folder. PNGs come from Godot viewport readback, not ImageMagick's stale `import` path. The contact sheet uses the installed ImageMagick `montage` utility.

Use repeated `--setting 'KEY=JSON'` switches for public host settings, for example `--setting 'tether_model="elastic-arc"' --setting 'tether_rope_visual=true'`. Settings are applied through `change_setting` before inputs begin, only in the disposable profile. Frame JSONL includes the runner's `get_motion_state()` observation when available, so a swing can be checked for attachment rather than inferred from an image. Private profile isolation prevents best/recording changes in the source checkout.

Rendering lifecycle follows the official [RenderingServer reference](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-property-render-loop-enabled): disabling the render loop retains engine logic, and `force_draw` draws viewports from the main thread.

Static pose mode hides the HUD so the stationary start card cannot cover map comparisons. Route and tape modes preserve the normal HUD for gameplay/menu review. Use tape mode for UI checks.

Tape events run in a physics callback at priority -100, before the ordinary motor, using 128 Hz simulation time. This preserves sub-frame action ordering when rendering is sparse. Captures observe the result; they never reposition the runner in route/tape mode.

Capture spacing and duration use a dedicated physics clock, matching tape timestamps, rather than accumulated render-process deltas. Sample times are simulation seconds, including while the game is paused for menu inspection.

Snapshots omit only `tests/fixtures` for frozen recording payloads, alongside generated caches/builds. Other directories named `fixtures` and authored `.import` settings remain included.
