# R14 native acceptance, source mode

8 November 2026, prepared base `bae2d371` (Penstock Yard version 4 taper, Source contact
guard 3), clean apart from the two new test files. Godot 4.7.2, Compatibility, OpenGL 3 on
llvmpipe under a private Xvfb (:190), Dummy audio, isolated XDG profiles. This is rendered
source-mode evidence. It is not the final pack, Windows, hardware latency or enjoyment.

| File | Role |
| --- | --- |
| `tests/r14_native_acceptance.py` | each tape headless, then native at 1280×720, review encode with movie checks, tick-by-tick compare; `--tour` runs the tour below |
| `tests/r14_native_acceptance_tour.gd` (+ `.uid`) | input-driven preset tour on the runway, real launch scene, records off |

Runtime, maps, UI, packaging and existing tests are unchanged.

These captures predate the records-only fix in `8b25dbdf`. Persistence was off throughout,
so they establish rendered movement and HUD behavior, not final packed record saving.
Root inspected the advanced runway, vanilla finish, F2 hop and F4 W+A/D frames on integration.

## Complete runs through the actual R14 main

The unchanged version 2 tapes from outer `practice-source/v3/final/<label>/events.tape.json`
went through the unchanged executor. Arguments: `--game-class '' --motor server128|vanilla64
--warmup 32`, plus `practice-root/game.gd` (sha256 `f12a243c…c256c2`). That setup-only
subclass sets only `source_sensitivity_override = 5.729577951308232`, so the look scale
matches the tapes' 0.0022 rad/count. The product default is Source 2.5. The executor set the
physics rate from each tape. Nothing relabelled events or wrote pose or velocity.

| tape | rate | finish | ticks | jumps | native vs headless | movie |
| --- | ---: | --- | ---: | ---: | --- | --- |
| server-basic | 128 | clean 56.3515625 s, stages 0–6, 0 respawns | 7283 | 39 | identical | 1722 frames, 57.4 s |
| server-advanced | 128 | clean 28.609375 s, stages 0–6, 0 respawns | 3814 | 28 | identical | 909 frames, 30.3 s |
| vanilla-basic | 64 | clean 57.78125 s, stages 0–6, 0 respawns | 3732 | 44 | identical | 1772 frames, 59.07 s |

The finish times equal root's headless replays in `tail-return/map4-warmup32/`.

"Identical" is the executor's `compare`. Every common tick has maximum position, velocity and
yaw difference 0.0 (m, m/s, rad), no first-difference tick, the same applied events and the
same rate. Each run has counter-verified order on every tick, delivery ok, a rate ok with one
observed delta (1/128 or 1/64), and no movement or integrity flags. The input released to
neutral, and cleanup is clean, with the display socket removed.

The native timing row shows the game running far behind wall time (server-basic: 570 s of
wall for 56.9 s of simulation). That is software rendering under a loaded machine with a
fixed 30 fps movie clock. It is not a performance figure.

The game's log reads `records=off`, and no profile file was written. The finish card's "best"
line is in memory only.

## Movies and frames

The AVI and MP4 are 1280×720. `ffprobe` read both sizes, and the tour's `get_visible_rect` is
1280×720. The size comes from the product viewport. There is no fixture viewport override and
no 640×360 claim.

Each AVI was encoded with libx264 (preset slow, CRF 28, yuv420p) to keep the evidence inside
its budget; the executor's own `--mp4` uses CRF 18. The AVI was deleted only after five
checks passed: same frame count, same size, duration within 0.05 s, clean decode of both, and
encode exit 0 (`evaluator/movie-review.json`). Sizes went from 161/86/170/111 MB to
12.4/7.7/12.8/9.3 MB. `actor/` keeps 10, 8 and 8 evenly spaced PNGs plus a contact sheet.

The first and last actor frames are named `warmup`. They carry no sim time: one comes before
the tape, the last is the quit tail showing the finish card.

What the inspected frames show:

- **Every frame.** The top-left identity line reads "PENSTOCK YARD · F2 CS:GO bhop server ·
  128 Hz · AA 100". On vanilla it reads "F1 CS:GO vanilla · 64 Hz · AA 12 · vanilla cvars ·
  stamina reconstructed".
- **Finish cards.** "FINISH 00:56.35, first clean run with this preset" and "FINISH
  00:57.78", with stage splits.
- **Server-advanced.** On the runway, 556 u/s. Past the 80 m marker, 901 u/s with "A/D sync
  94 % (33/35)" and "last hop +50 u/s · sync 96 % (91/95)". Then 974 u/s at Weir gauges.
- **Weakness of the basic tapes.** They hop with W only and never strafe, so their HUD shows
  sync "—" and gain ±0 for most of the run. That is correct, but it is no evidence for the
  strafe HUD.
- **Contact sheets.** With 8 frames, two of the sixteen tiles are black.

## Preset tour on the runway (section 3)

Every step is an ordinary input event:

- F1–F5 key events switch the preset live;
- Esc opens the menu, and the stage picker is clicked and walked with arrows and Enter;
- **Practise here** is clicked through the viewport.

The real `scenes/r14.tscn` runs with `persist` off. The profile path it was handed was never
created.

Every preset gets the same pattern: 0.6 s of W, then six alternating A/D hops, with the mouse
turning toward the held key at 2 rad/s. The first hop turns at half rate, so the zig-zag
stays centred. F1 taps Space once per hop. The others hold it. F4 runs a second time with W
held through the hops, which is the Quake strafe-jump input. There is no finish and no
record write.

The native run passed 27/27 checks: each preset key switched, the picker stayed on the
runway, the identity named the slot and rate, nothing fell, the attempt stayed practice, and
no record file appeared. All six per-hop records are identical to a headless run of the same
script (`tour-headless/`).

| preset | input | gain per hop, u/s | takeoff → end speed |
| --- | --- | --- | --- |
| F1 vanilla 64 Hz | A/D, tap per hop | +22 +34 +33 +37 +33 +33 | 250 → 161 |
| F2 bhop server 128 | A/D, hold | +23 +40 +40 +34 +39 +38 | 250 → 464 |
| F3 R13 unchanged 120 | A/D, hold | +28 +24 −68 (contact −93) +38 +23 +26 | 335 → 407 |
| F4 Q3-inspired 128 | A/D only, hold | −1 −70 +67 −63 −24 (contact −17) +88 | 320 → 318 |
| F4 Q3-inspired 128 | W + A/D, hold | +133 +65 +34 +37 +18 +21 | 320 → 628 |
| F5 AA 1000 128 | A/D, hold | +23 +40 +40 +35 +39 +38 | 250 → 464 |

Readings, not feel claims:

- **F1** gains in the air like F2, but loses it again on the ground between manual hops.
  Successive takeoffs read 185, 193, 136, 159 and 176 u/s. That is the reconstructed stamina
  and landing clamp.
- **F2 and F5** differ only at hop 4 (34.38 vs 34.80). At this turn rate both are capped by
  the 30 u air wish, not by airaccelerate. The tour does not show where AA 1000 differs.
- **F4** reads as its own law. A/D alone gives alternating gains and losses, and W+A/D builds
  to 628 u/s. On the last hops it drifts into the left runway wall: contact −2 on hop 5, then
  "wall 3 ticks" with contact ±0 on hop 6. F3 loses 93 u/s to contact on hop 3, and the HUD books it as contact,
  not as air.

Frames in `tour/frames/` (19 JPEG at quality 0.9): `<slot>-a-runway`, `-b-hop3` and
`-c-end` for each preset. The intro control hint changes with the family. The F4 hint reads
"hold W with A or D", and the identity line reads "AA 1 · 320 u wish, not 30 u · not Quake".

**Sync semantics.** These are the HUD's directional definitions from PLAYABLE.md. An eligible
tick is an air tick with exactly one of A/D held, a nonzero view turn and speed above 1 u/s.
It counts as good when the turn goes toward the held key. The tour's input always turns
toward the key, so 100 % is true by construction. It says nothing about whether the turn rate
was right, and no optimality figure exists or is claimed. The authored advanced tape is the
one case with imperfect input: 94–96 %.

## Storage and cleanup

- **Free space.** /home was at or above 15 GiB before each render: 15.05, 15.13, 15.11 and
  15.23 GiB. Each raw AVI lived only during its own run.
- **Evidence size.** The evidence is 79.9 MB (76.2 MiB) in outer
  `checkpoints/spillway/r14/native-final-source/`. Mesa and Godot shader caches in the native
  profiles were removed as run scratch, logged in `REMOVED.txt` (server-basic by hand,
  the others by the driver).
- **Process and desktop cleanup.** No owned Godot or Xvfb process, socket or tmp profile
  remains. Desktop :0 answered xdpyinfo before and after every render. No Wayland or AMD route
  was used.
- **Driver versions.** `RESULTS.json` records the final driver's hash. server-basic ran on an
  earlier revision of the driver: identical run, encode and compare logic, but without the
  tour mode and the cache cleanup.
- **Hashes.** `SHA256SUMS` covers the movies and the results.

## Rerun

```sh
E=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/native-final-source
python3 tests/r14_native_acceptance.py --out $E [--only server-basic] [--actor-limit 8] [--wall-budget 2400]
python3 tests/r14_native_acceptance.py --out $E --tour --wall-budget 2400
```

A fresh checkout needs `godot --headless --path . --import` once. Each run refuses below
15 GiB free and requires fresh run directories.
