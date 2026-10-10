# Foldrunner

Original first-person parkour prototype: a rooftop facade unfolds into a bridge, a gravity ribbon takes you onto the underside of a roof, and an impossible window connects to another district. Inspired by the folding architecture of Control Resonant / Doctor Strange and Mirror's Edge's traversal rhythm. No extracted game assets or copied game code.

This is a compact mechanics slice, not a finished game. The scripted sprint route completes in approximately eight seconds. A longer authored route and a visual/feel pass come after this foundation.

## Play on this Windows machine

When ready to use the GPU, double-click **Play Foldrunner.cmd** or run:

```powershell
./tools/run.ps1
```

Godot 4.7.2 is installed under `%LOCALAPPDATA%/Foldrunner/tools/godot-4.7.2`, outside the repository. The launcher caps the game at 60 FPS. It does not cap GPU utilization; actual load is unmeasured.

On another machine, run `./tools/setup.ps1` first or pass `-Godot <engine-path>` to the scripts. Setup downloads the pinned official Windows release and verifies its published SHA256 when available.

Click **Continue** to capture the mouse. Follow the amber marks. Sprint toward the first roof edge; the facade unfolds automatically. Jump the gap near the end of the bridge, follow the curved ribbon onto the ceiling, run through the dark amber-framed window, then reach the green finish strip. Falling returns you to the latest checkpoint. R starts a fresh run.

| Input | Action |
|---|---|
| WASD / arrows | Move |
| Mouse | Look |
| Shift | Sprint; airborne movement beside a wall can wall-run |
| Space | Jump; vault a nearby low obstacle; jump off a wall |
| Ctrl | Crouch |
| R | Restart entire run |
| Escape | Pause / release mouse |

Pause includes a camera-roll comfort slider. Head bob defaults off. The start roof has a crate and wall for practicing vaults and wall-runs.

## Browser build

The Compatibility-renderer, single-threaded Web export succeeds. The current build is in `builds/web/` (ignored build output). To serve it locally without opening any graphics:

```powershell
python tools/serve_web.py
```

Then open `http://127.0.0.1:1348/index.html` when ready to play. Stop the server with Ctrl+C. Do not open the HTML directly from the filesystem. Browser rendering, pointer lock, audio/browser behavior and performance remain unverified.

To rebuild:

```powershell
./tools/export-web.ps1
```

The four web templates for Godot 4.7.2 are installed under `%APPDATA%/Godot/export_templates/4.7.2.stable`. For a fresh installation, download the official `Godot_v4.7.2-stable_export_templates.tpz` from https://github.com/godotengine/godot/releases/tag/4.7.2-stable and run `python tools/install_web_templates.py <archive>`.

## Checks without using the GPU

```powershell
./tools/check.ps1
```

All engine calls in that script use `--headless`, including import. Suites cover:

- Player: 31 assertions on actual physics movement, jumping, vaulting, crouch clearance, wall-running, moving-platform transport, rotated gravity, portal/reset state, camera validity.
- World: 34 assertions on folding transforms, rigid portal mappings, swept crossings, cooldown/reset, and a real rider on a rotating platform.
- City: geometry, actual collider normals, route bounds, correct collision layers and actual player overlaps, plus HUD state.
- Integration: 23 assertions on progression, checkpoint/reset, pause stopping architecture/time, finish, and idle-spawn safety.
- Traversal: actual scripted forward/sprint/jump input reaches checkpoint, ceiling, portal and finish. No waypoint teleports are used. It validates one ideal line, not every possible player action.

Last first-pass results: all five suites passed; single-threaded Web export passed. **No graphical run was performed because Mike was gaming.** Headless results do not prove visual quality, camera comfort, browser gameplay, or subjective movement feel.

## Known limits / next playtest

- Portal aperture is opaque and hides the spatial transition; there is no visible recursive view into the destination.
- Foreground anomaly is one unfolding rigid facade plus an authored gravity arc. It is not yet a continuously folding city with arbitrary deforming collision.
- Vault destinations are for stationary low obstacles; moving obstacles do not update the vault target.
- No coyote time/jump buffering, visible body, traversal animations, combat, soundscape or save-game progression.
- Test startup, pause/resume, mouse capture, HUD layout, lighting, route readability and camera roll visually before calling this ready to share.
- Check GPU/frame times on Mike's RTX 2070 SUPER only after he says the gaming session is over.

## Agent handoff

Read `docs/BRIEF.md`, `docs/CONTRACT.md`, then `AGENTS.md`. Main owns integration; movement/world/city are separate systems with agreed world-space velocity and gravity conventions. Scene geometry is generated from built-in meshes and shapes; the route is authored, not randomly generated.

Tracking: first pass `ccChat-general-9mga`; pending visual QA and expansion are recorded in beads. Never infer permission for GPU rendering from a new background session: the current restriction remains until Mike says he is done gaming.
