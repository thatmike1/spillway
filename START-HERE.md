# Start here: Spillway r21

Spillway is a first-person momentum game in Godot 4.7.2. Earn speed by hopping and air-strafing through checkpoint courses. R21 adds revised Saltglass surf exits and Tether Yard rope/anchor experiments around the approved F2 movement. This handover changes organization, not gameplay. Mike's R21 feedback is history and design input, not a request to tune anything during maintenance.

## Run, check, export

Use a Git clone, Python 3.11 or newer (verified with 3.14.8), and the official Godot **4.7.2** Linux editor. `tools/engine.py` verifies its SHA256. Set `GODOT` to your editor if it is outside the build machine's existing cache. For export, set `GODOT_TEMPLATES` to the folder containing the official release templates. There are no Python package dependencies.

```sh
python3 tools/play.py
python3 tools/play.py --editor
python3 tools/test.py
python3 tools/test.py --slow
python3 tools/export.py --out builds/linux
```

The ordinary check imports a fresh source snapshot, challenges real recording bytes and checks Saltglass production registration plus Tether geometry and force coefficients. The slow tier adds direction-stack/Through Line checks and **48 plays, 16 routes, 288 exact comparisons** against frozen original-map fixtures. Every original-map comparison must have zero differences. It checks recordings, motion, ghosts, observations, controls and finish, across old/new/toggle looks. Logs and snapshots go to an external temporary folder; `--out /absolute/new/path` keeps them at a chosen location. See [verification/README.md](verification/README.md).

The export tool builds a PCK and uses the pinned Linux release template. It starts that exact pack from an empty directory outside the checkout. `--platform windows` assembles a Windows build but does not execute it. New exports verify source; the published **r21** ZIPs are the exact previously verified delivery bytes. Release builds are distributed through this private repository's GitHub releases.

On the shared build laptop, all wrappers use `/tmp/spillway-r21-engine.lock`, including headless launches. Do not bypass it while capture work runs. The build workspace requires at least **15,000,000,000 bytes free on /home**; the replay also requires temporary headroom and caps its own allocated scratch at 600 MiB. Check the tmpfs user's quota as well as `df` before a large run.

## Follow one playable run

1. `project.godot` opens `scenes/r21.tscn`. Its stable `scripts/r21_main.gd` resource forwards to **`scripts/game.gd`**.
2. `game.gd` composes the final catalog and pause HUD. The inherited host chain (`r20_main` → `r19_main` → `r17_main` → `r16_main`) supplies shared menu, input, map lifecycle and physics-loop behavior. `r16_main.gd` owns `select_map`, runner creation and `_physics_process`; `r17_main.gd` adds the look layer. These are live modules despite their historical names.
3. **`scripts/maps/catalog.gd`** overlays the R20/R19 catalog and `r15_maps.gd`. The pause menu asks that catalog for playable IDs. A map entry selects geometry and a runner; changing maps closes the previous attempt before replacing them.
4. The F2/F5 runner's implementation is **`scripts/movement/course_player.gd`**, using **`source_motion.gd`** and the existing preset registries. `scripts/r15_source_player.gd` is its stable resource alias. Tether Yard selects **`grapple_player.gd`**; Through Line has its own runner.
5. **`scripts/recordings/session.gd`** observes the completed motor step. It feeds **`scripts/scoring/style.gd`**, the recorder and ghost. These services observe gameplay; they do not steer the player. **`scripts/ui/pause_menu.gd`** handles the current HUD additions; inherited R18/R20 UI supplies the rest.

Stable round-numbered aliases preserve resource paths used by recording identities and historical type checks. Edit their named implementation modules, not the forwarding files. The earlier files still reached by the live inheritance chain stay in `scripts/`. Frozen test executors and independent comparison code live in `verification/`, not in gameplay. The R15 host/launcher pair remains at its original paths for the retained comparison fixtures; it is not the current entry point.

## Maps and experiments

| Menu entry / ID | Geometry and runner |
| --- | --- |
| Breakwater / `breakwater` | `r15_breakwater_level.gd`, course player; `r19_course_revisions.gd` applies its optional passage revision |
| Whiteout Relay / `whiteout-relay` | `r15_whiteout_level.gd`, course player |
| Sunken Court / `sunken-court` | `r15_sunken_level.gd`, course player |
| Rainline / `rainline` | `r15_rainline_level.gd`, course player |
| Night Shift / `night-shift` | `r15_nightshift_level.gd`, course player |
| Penstock Yard / `practice` | `r14_practice_level.gd`, course player |
| Overflow / `overflow` | `momentum_overflow_level.gd`; F2/F5 or the advanced R13 comparison runner |
| Movement Lab / `experiment` | `r15_experiment_level.gd`, `r16_experiment_player.gd`; isolated slide, wall-jump and grapple loadouts |
| Saltglass / `saltglass` | **`maps/saltglass.gd`**, course player; surf/exits experiment |
| Tether Yard / `tether-yard` | **`maps/tether_yard.gd`**, **`movement/grapple_player.gd`**; six rope laws and optional anchor acquisition assist |
| Through Line / `through-line` | `r20_through_level.gd`, `r20_through_player.gd`; movement experiment |
| Shelved: Fall Line / `fall-line` | `r19_fall_line_level.gd`; retained as a catalog dependency, removed from the current menu |
| Shelved: Line Drive / `line-drive` | `r19_line_drive_level.gd`, `r19_line_drive_player.gd`; retained dependency, removed from the current menu |

Paths in this table are under `scripts/`. `r16_style_opportunities.gd` adds optional style passages around original courses. `assets/` has game skies and licensed asset kits with manifests; `shaders/` supplies their rendering. Retired prototypes, delivery verifiers and receipts are in Git history. Per-round briefs/results are under `history/rounds/rNN/`; the history timeline and images are curated separately.

## Controls and vocabulary

WASD and mouse move/look. Hold Space or use scroll to hop; release W and combine A/D with the same-direction mouse turn to air-strafe. Ctrl/C crouches. R restarts, F practises a checkpoint, Esc opens the menu, G toggles the fastest clean ghost and L compares the look. Movement Lab alone uses Shift for slide and E for grapple. Tether Yard uses LMB to attach/hold, RMB to reel and LMB release to coast.

- **F2 / server128:** the primary 128 Hz bhop preset, AA 100, autohop, no stamina/takeoff clamp. `server128` is its stable stored ID.
- **F5:** the same family at AA 1000. **AA** means air acceleration, not a global speed limit. F3/R13 and F4/Quake-inspired are advanced comparisons.
- **Preset:** a named motor law/configuration with its own timing and recording identity.
- **Style:** geometry-backed events and scoring, separate from fastest time. **Gap** measures an airborne passage between supports; **near-miss** measures a qualifying close obstacle passage. Proximity alone is not enough to score.
- **Attempt:** one recorded lifecycle beginning at spawn/restart/practice and ending at a finish or an explicit boundary such as map change or quit.
- **Ghost:** playback of the fastest clean, complete recording matching the current motion identity; independent of style best.

Settings/bests use `user://spillway_r16.cfg`; attempts use `user://r16_runs/` and `.r16run` files. Those names are persisted interfaces, not the release number. Analyze files with `python3 tools/analyze-runs.py PATH`; importing a friend's run bundle is the explicit, bounded `tools/import-runs.py` operation. Read [docs/recordings.md](docs/recordings.md), [docs/run-export.md](docs/run-export.md), [docs/tether-yard.md](docs/tether-yard.md), [docs/saltglass.md](docs/saltglass.md) and [docs/movement-reference.md](docs/movement-reference.md) as needed. [AGENTS.md](AGENTS.md) gives the change/parity/privacy rules.
