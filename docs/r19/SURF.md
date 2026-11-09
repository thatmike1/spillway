# Saltglass

Saltglass is the R19 bhop and surf course, map id `saltglass`, level id `r19-saltglass`, version **1**. The unchanged F2 `server128` preset and `r15_source_player.gd` run it at exactly 128 Hz. It is a course, with no experimental motor, surf assist, boosts or authored scoring triggers.

The earned reference route takes **61.265625 s**. It starts at rest at the authored spawn, surfs both fins, hops through the crescent and salt steps, and finishes clean with no respawns. This proves one coordinate-aware input line, not discovery, human difficulty or enjoyment.

## Route and recovery

The headrace starts with a clear standing hull at (2, 6.04, 16) and runs out onto the west fin. Release W after its lip and press D into the face. Turning slightly away reduces the climb and builds forward speed. The measured line turns one degree away. A 56.3099-degree face is too steep to stand on: normal.y is 0.5547002, below the unchanged 0.7 walkable threshold.

The west exit has a low mouth and a walkable rise into the crescent. Four real gaps and descending terraces turn the route back toward the east fin. Its matching exit carries into a second descending, offset hop chain to the salt house. Wide decks leave room for faster lines, imperfect landings and emergent cuts. Progress uses ordinary visible terraces and the inherited host rules. There is no invisible route corridor or skip trigger.

Lower service decks catch a released fin, and ramps return to the exit. Lower courts beneath the crescent and salt steps also have physical return ramps. Falling outside the whole structure invokes the ordinary host checkpoint recovery. The input recovery check deliberately releases the west fin, lands on its catch, walks the return incline and reaches the flat west landing in **16.2578125 s**, without a respawn. It does not claim an earned test of every possible miss or every return ramp.

## Geometry and identity

There are **60** collidable convex pieces. Every piece is represented in `manifest`, with all world vertices, role, stage and kind. `tests/r19_surf_geometry.gd` compares each manifest vertex to the actual placed convex collision shape, verifies all eight steep pieces and checks the maximum axis extent. The largest extent is **28 m**, below the 32 m guidance. Meshes use the same vertices with outward normals and clockwise front faces. No `Area3D` is authored.

Each fin has four 21 m pieces. Exact coplanar joins produced engine end-edge collisions in the opposite-direction fin. Centring the convex vertices alone did not cure them. The retained geometry lowers each successive piece **2 cm**, a total 6 cm over a fin. This places incoming end faces below the outgoing face, without changing any movement law. The successful line crosses all six internal joins with no blocking vertical end-face hit. The engine reports three nonblocking outgoing-face contacts at the last west seam, all on one tick; these face away from travel and do not clip velocity. All six measured joins gain a fraction of a unit; the smallest change is **+0.014343 u/s**. No join loses speed on this reference line. These are small physical downward steps, not a claim of mathematically coplanar collision.

The all-piece geometry hash is:

```text
039ea8f5da3ef1c820c71b9253669b3b0c8943563b97551d2b606575e293fce8
```

It also includes the centred-convex policy, checkpoint poses/bounds, spawn, finish position/bounds, kill bounds and level version. The inherited identity adds map id, version, variant, preset, runner, motor fingerprint, rate and timing. Saltglass shares no best/ghost identity with an existing map.

## Measured motion, flow and style

| observation | west fin | east fin |
| --- | ---: | ---: |
| actual steep-contact ticks | 1,059 | 1,024 |
| first contact speed, u/s | 252.66 | 252.66 |
| last contact speed, u/s | 448.07 | 448.07 |
| travel between first and last contact, m | 81.11 | 81.11 |
| grounded during steep contact | 0 | 0 |

There are **36** observed hops. The full route has no recorded rate mismatch, no body-travel mismatch, no respawn, and no speed sample below 150 u/s after its first second. Maximum actual speed is about **449 u/s**. The driver contains no wait inserted to make the course clock longer. Its 33 setup ticks settle the normal spawn before input, and the host owns the actual course start.

The unchanged R19 style service awards **1,374** points: ten gap events, two edge events and one speed event. Two repeated edge opportunities are farm-blocked. Geometry never calls the style service. These points describe the executed line, separately from speed and route continuity.

All six protected motor/law/preset/strafe source files match the R18 `640d06e6539b53da752f03bfddb64fb46310abb7` baseline byte for byte. Receipt: `/tmp/r19-surf-course/preservation.json`. The feasibility result predates course authoring and remains in `/tmp/r19-surf-proof/RESULT.json`; its committed source is `tests/r19_surf_proof.gd`, owned by the parent.

## Look C and integration

The level supplies original neutral materials and an environment. R17's existing **practice** palette supplies cream deck tops, darker sides, orange jump lips, structural ink, flat light bands, painted wear and a calm sky. The fin crest has separate structural ink. No new concept image or external asset is needed.

Reused art is `assets/look/r17/practice-sky.png` and `assets/look/painted-wear.png`, through the existing shaders. Their authored-generation provenance and hashes are in `assets/look/r17/PROVENANCE.md`, `assets/look/r17/MANIFEST.json`, `assets/look/PROVENANCE.md` and `assets/look/MANIFEST.json`. No private reference art is shipped.

The parent must make these two changes, demonstrated together in `tests/r19_surf_host.gd`:

1. Before the R19 host's inherited `_ready()`, copy `MAPS.make()` and append `r19_surf_level.gd`'s `MAP_ENTRY` under `MAP_ID`, in both catalog and order. Keep kind `course`. Preserve all existing entries and the default map.
2. After the inherited `_build_level()`, for `saltglass` attach `PRESENTATION.new()` to the level, assign it to the host's `look_layer`, call `attach(level, "practice")`, then `set_enabled(look_enabled)`. The frozen R17 hook only attaches automatically for its own `MAPS.ORDER`, so registry registration alone is insufficient.

No edit to `r19_main.gd`, `r19_hud.gd`, registries or `project.godot` is part of this component. The parent owns those edits and final packaging. The test adapter subclasses the actual R19 host; it changes registration/presentation only, while the normal host creates the session and the actual R15 body.

The headless look check reports 67 material swaps, 68 generated ink segments and 18 jump lips. The real inherited L key turns the look off and on while preserving feet, geometry and motion identity. These counts and state checks do not prove visual quality.

## Reproduce and inspect evidence

The pinned editor is `/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`, SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. Source, imports, profiles and evidence are isolated under `/tmp/r19-surf-course`, below 350 MiB. No user profile or delivery is modified. Check `/home` has more than 15,000,000,000 bytes free before imports/builds.

Commands used on the isolated snapshot, with `XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_CONFIG_HOME` set to subdirectories of the evidence root:

```bash
GODOT=/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --audio-driver Dummy --path /tmp/r19-surf-course/source --import
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-surf-course/source --script res://tests/r19_surf_route.gd -- --out=/tmp/r19-surf-course/spawn-clear
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-surf-course/source --script res://tests/r19_surf_route.gd -- --out=/tmp/r19-surf-course/spawn-clear-replay --tape=/tmp/r19-surf-course/spawn-clear/events.tape.json
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-surf-course/source --script res://tests/r19_surf_recovery.gd -- --out=/tmp/r19-surf-course/spawn-clear-recovery --max-ticks=5120
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-surf-course/source --script res://tests/r19_surf_look.gd -- --out=/tmp/r19-surf-course/spawn-clear-look
python3 -I tools/analyze-r16-runs.py /tmp/r19-surf-course/spawn-clear-replay/recordings --json /tmp/r19-surf-course/spawn-clear-replay/python-reader.json --quiet --strict
python3 -I tests/r19_surf_audit.py --run /tmp/r19-surf-course/spawn-clear-replay --replay /tmp/r19-surf-course/spawn-clear --out /tmp/r19-surf-course/AUDIT.json
```

`spawn-clear` is the coordinate-aware earned route; `spawn-clear-replay` is open-loop replay of its fixed input on the same final source. The final spawn is clear of the overhead hop island, with a standing-hull clearance assertion before input. The audit compares **every telemetry field on every tick** against the earned route. Both original readers accept the complete recording; the Python audit also matches every retained position to the recording columns, including the setup offset.

Each run retains `events.tape.json`, full per-tick `trace.jsonl.gz`, `summary.json`, an every-piece `geometry.json` for route runs, and the original `.r16run` recording. `SOURCE.json` records the executed source/editor hashes. `AUDIT.json` separates motion, flow, style, source-write checks and limits. Failed bounded hypotheses remain in `trial1` through `trial6`; `trial7` is the first successful route. The canonical decision trail is `/home/thatmike1/foldrunner-build-2026-11-05/look/decisions.tsv`.

Native safety command:

```bash
python3 tools/r14_native_display.py probe --evidence /tmp/r19-surf-course/native
```

It refused with `desktop :0 does not answer before the private session; nothing was started`. The guard was not weakened and no desktop display was used. After a private display passes the approved safety checks, use the existing `NativeDisplay` context and its `child_env` with this same host/driver, remove `--headless`, and run the original L comparison and full route under the private checked AMD/X11 display. Native legibility, physical input, export acceptance, final all-map parity, release packaging and Windows execution remain parent responsibilities. No native screenshots or visual acceptance are claimed here.

## Model read and attention

The two fins connect into distinct hop sections, and the faster surf line has useful physical exits. I expect it to read as an introductory surf course: the 2 m gaps and broad terraces are forgiving, while the long fins ask for sustained control. That is a model judgement, not a playtest verdict. Mike should judge the surf feel, the length of the fins and whether the crescent and salt steps offer enough variation after native/release integration.

The trail has a self-audit only. This implementation child was explicitly forbidden to start other agents, so the show-me-your-work skill's independent cross-family review was not run. Scrutinize the directional 2 cm seam relief, recovery coverage and unverified native presentation when integrating.

## Production integration checkpoint

The R19 configured scene now registers Saltglass beside the original eight maps and attaches exactly one Look C layer. `tests/r19_maps.gd` passed 13 integration checks on the actual configured scene: default registry preserved, approved F2 runner, clear standing spawn, painted sky, actual L off/on with identical feet and motion identity, Lab experimental title, faithful runner after leaving Lab, and return to the same Saltglass identity. Normal asynchronous Quit exited zero without warning/error logs. This is source integration, separate from the component route, native visual and final portable gates.
