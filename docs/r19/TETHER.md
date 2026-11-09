# Tether Yard

Aim at a marked overhead ring, reel across the gap, then release into the next transfer.

Tether Yard (`tether-yard`) is a small, experimental grapple course with three transfers, four cream decks, a broad lower catch court and four walkable return ramps. The transfer decks have room to change lines. Progress comes from actual deck contact and finish bounds; no hidden routes, score triggers or authored bonuses are present. The existing style service naturally scored three gap events on the earned route.

Controls: mouse to aim, hold **E** to attach and reel, release **E** to coast. Release before aiming at the next ring and holding again. **Space** jumps into a transfer, **WASD** moves and air-strafes, **Ctrl/C** retains ordinary crouch. **R** restarts and **Esc** pauses. Slide and wall jump are physically disabled in this runner. Number keys and mechanic setters cannot change its fixed loadout. The original Movement Lab remains a separate map with its original moves.

My expectation, not a player verdict: the short transfer rhythm should support repeat attempts and deliberate release timing. Three transfers offer limited variety, and the inherited rope can dip below deck height if entered late. The catch court and ramps make that recoverable. Coordinate-aware route finding proves a line exists; it does not show that a player will discover it, enjoy it or read every anchor clearly. Native visual review and Mike's feel verdict remain outstanding.

## Mechanics and identity

`scripts/r19_tether_player.gd` inherits the R16 experimental runner, retains the R15 bounded grapple law and supplies a fixed grapple-only policy. Movement version is `r19-tether-yard-grapple-only-1`; the map declares `r19-tether-yard-rope-1`, explicitly identifying its unchanged underlying `r15-lab-grapple-1` law. All tuning is recorded through `TETHER_LAW` and the inherited mechanics table: 30m reach, 9 degree aim cone, clear sight, 260u/s reeling, 96u minimum rope, stiffness 30, 1300u/s² pull cap, 650u/s speed cap and 3s attachment cap. Existing main maps still use the original R15 body.

The rope removes outward radial velocity when taut and applies the bounded spring pull before the inherited motor runs. E release coasts; blockage, range and time break the line. Attachment/pull/release are observed separately in the proof, rather than inferred from held E. The runner replaces inherited glowing cyan/orange materials with nonemissive ink rope and teal/orange targeting rings.

The geometry hash includes every physical prism vertex, role and stage; all three anchor positions; checkpoint/spawn/finish/kill positions and bounds; mechanic version and complete rope tuning; and decorative box placements. The runner path/version and physics fingerprint also enter the ordinary host recording identity. All 30 collision pieces were checked against their manifest vertices, with maximum per-axis extent 24m. The only gameplay collision is the deck/catch/ramp geometry; the slender gantries and anchor rings are visual markers.

## Integration owned by the parent

Register `r19_tether_level.MAP_ENTRY` under `MAP_ID` in the separate Esc Experiments section. It supplies `kind=experiment`, `experimental=true`, `name`, `theme`, `script` and the trusted `runner` path. Route this map through `_source_script_path()` to `res://scripts/r19_tether_player.gd`; leave other maps' runner selection intact. Treat it as experimental for title/HUD and the F2/F5 restriction, and return `{}` from `lab_moves()` on this map so the old Lab toggles stay hidden. Attach exactly one `R17Look` using the existing `practice` palette. The component adapter in `tests/r19_tether_host.gd` demonstrates these hooks while using the actual R19 main/session/progress/recording implementation.

The component does not register itself in production, edit `r19_main.gd` or `r19_hud.gd`, change the original Lab, or modify shared geometry/Source files. Final production registration, native presentation, all-map parity and release packages belong to the parent.

## Verified component evidence

The pinned Godot 4.7.2 headless runtime executed the actual R19 host through the component adapter. The final route finishes cleanly in **13.0390625s**, with zero respawns. It records 1728 ticks including 33 settling ticks; all 1695 retained input-route observations match the fixed-input replay exactly across every telemetry field. The recording's positions, velocity, yaw, pitch, time and checkpoint observations also match exactly after that 33-tick offset.

The route observes 596 attached ticks across the three anchors, 589 nonzero spring-pull ticks, 176 radial rope-correction ticks and three explicit E releases, with no automatic line break. It receives 2729 points from the ordinary style service. There are no body-travel/rate mismatches. Both original Godot and Python readers accept the clean recording. The Python reader also accepts all eight final route/replay/recovery/lifecycle recordings after normal Quit.

The lifecycle probe uses actual R and Esc inputs while attached. It verifies rope/progress reset, 20 exact frozen pause steps, resumed rope ticks, locked toggles, main-map R15 runner restoration, removal of all tether anchors, unchanged original Lab loadout, and a fresh tether body on return. The recovery probe releases early, lands on the lower court, then walks the catch, return ramp, landing and original start deck in 16.9375s without respawning. Each final engine process exits 0 through the inherited asynchronous `request_quit` drain; the test never calls an immediate tree quit. Final logs contain no script errors or ObjectDB cleanup warnings.

Canonical evidence is `/tmp/r19-tether/AUDIT.json`, `SOURCE.json`, `preservation-before.json`, and the `final/`, `replay/`, `recovery/`, `final-lifecycle/` subdirectories. `AUDIT.json` has 25 checks, source/recording hashes and exact replay results. Scratch remains below 250MiB; HOME reserve stays above 15,000,000,000bytes. R15/R16 original experimental bodies and protected Source files match the before hashes.

Reproduce from the project directory after staging source/imports under `/tmp/r19-tether/source`:

```bash
GODOT=/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --audio-driver Dummy --path /tmp/r19-tether/source --import
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-tether/source --script res://tests/r19_tether_route.gd -- --out=/tmp/r19-tether/final
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-tether/source --script res://tests/r19_tether_route.gd -- --out=/tmp/r19-tether/replay --tape=/tmp/r19-tether/final/events.tape.json
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-tether/source --script res://tests/r19_tether_recovery.gd -- --out=/tmp/r19-tether/recovery --max-ticks=5000
"$GODOT" --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r19-tether/source --script res://tests/r19_tether_lifecycle.gd -- --out=/tmp/r19-tether/final-lifecycle
python3 -I tests/r19_tether_audit.py --root=/tmp/r19-tether
```

Use clean output subdirectories when repeating; the recording reader audits all files present. The evidence uses an isolated source copy to bound imports and avoid live shared-checkout changes. See `SOURCE.json` for the executed source hashes.

## Assets and limits

All course geometry, signs and rings are original procedural primitives in the new scripts. Deck collision/meshes reuse the unchanged `r19_course_geometry.gd`. The presentation layer reuses `r17_look.gd`, `r17_contours.gd`, `shaders/look/`, the practice sky and painted wear. Their existing provenance stays in `assets/look/PROVENANCE.md`, `assets/look/MANIFEST.json`, `assets/look/r17/PROVENANCE.md` and `assets/look/r17/MANIFEST.json`; no new external asset or shader is introduced. R18 UI is inherited.

This is source/headless component acceptance only. Native appearance, sign/anchor readability in moving rendered views, Windows execution, final production menus and packaged replay are unverified here. Parent review/integration is still required. No Mike decision blocks that integration; his later decision is whether the grapple transfer rhythm feels worth expanding.

## Production integration refresh

The production R19 catalog now registers Tether Yard in Esc > Experiments. Its test host only selects that map; production owns the trusted runner, fixed-loadout policy and single Look C layer. Added map-specific instructions, E key hint, reticle and a read-only attached/aim status. Fresh production earned/replay/recovery/lifecycle runs pass all25 audit checks with the same13.0390625s finish. Both actual AMD/X11 old/new runs match all1695 samples exactly, also matching the production headless replay. Six actual camera frames per look were retained at1296x736, with actual-process GPU and unchanged desktop receipts. Parent inspected frame350 while attached and1200 approaching the final transfer. Native Windows, physical input latency, discovery and enjoyment remain unverified. Compact proof is outer look/evidence/r19-tether-integration/.
