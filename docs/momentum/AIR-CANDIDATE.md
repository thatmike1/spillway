# CARRY air candidate

One original air-control challenger on the unchanged CARRY runner, 7 November 2026. It is not a
Source or CS reconstruction and keeps no projection allowance. All values are P hypotheses.
Nothing here claims fun or GPU pacing. Godot 4.7.2 (ed1daf0bf), 120 Hz physics, headless and
llvmpipe only. Evidence lives outside Git under `checkpoints/spillway/r13/carry-air-candidate/`;
`STATE.md` there is the resumable log.

| File | Role |
| --- | --- |
| `scripts/momentum_carry_air_candidate.gd` | extends `momentum_carry_player.gd`; overrides only `_carry_air` plus view-turn bookkeeping and the motion report |
| `scripts/momentum_carry_air_lab.gd` | SceneTree launcher and inner `Game`, CARRY's factory with `player_script` = candidate and `level_script` = `CalibrationBlock` |
| `tests/test_carry_air_candidate.gd` | input-driven fixtures and comparison summaries: 134 result records, 42 gates, the same fixtures for broad and narrow, and bad-policy rejection |

No existing file, project setting, default game, HUD, persistence or helper changed.

## Commands

From `projects/foldrunner`, with `G=$HOME/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`:

```sh
$G --path . --script res://scripts/momentum_carry_air_lab.gd               # play the calibration block
$G --path . --script res://scripts/momentum_carry_air_lab.gd -- --steady-camera --no-hud
$G --headless --fixed-fps 120 --path . --script res://tests/test_carry_air_candidate.gd -- --out=DIR [--only=GROUPS] [--air=key:value]
python3 tools/momentum-tape.py run TAPE --out DIR --game-script res://scripts/momentum_carry_air_lab.gd --game-class Game
```

Groups: fixed, look, mouse, cadence, farm, brake, correct, mirror, game, reject. `--air` runs
a labelled tuning variant; the suite exits 1 on any gate failure. Baselines through the same
helper use `--game-script res://scripts/momentum_carry_lab.gd --game-class CalibrationGame
--motor broad|narrow`: the same block, normal spawn, camera defaults and sensitivity.

**Labels.** The runner exposes `air_policy = "carry-air-candidate"`. The motion report sets
`air_policy` and `air_profile` to it and keeps `base_air_profile_unused = "broad"`: the base
setter requires a profile name, and the candidate never reads its constants. The window title,
subtitle, pause panel and controls text name the candidate. CARRY's own startup line still
prints `air=broad`, followed by a line from the lab that corrects it.

## The air rule

Mechanic choice: **an original speed-neutral air bend, plus a small synchronised carve.**
Height and clean hops on CARRY's shared ground policy remain the main source of earned speed.

- **Keys bend the flight toward where they point.** W points at the view, A/D at the view's
  side and W+A between them. S takes no part in the bend. The bend is a bounded sideways
  acceleration that never changes speed: 14 m/s² for W, 9 m/s² for a side key alone, blended
  by each key's share of the wish. Authority is full while the wish is within 90° of travel,
  then fades with its sideways share (sin), so a wish far behind the flight still bends it
  gently and never brakes it. The turn rate is capped at 4 rad/s.
- **No keys keeps the ballistic line**, so looking around is free.
- **S brakes** the part of travel along the view at 5 m/s² and never reverses it.
- **Below run speed** any held key brings a flight up to 8.5 m/s at 6 m/s², never above.
- **Carve.** A side key held while the view turns its way banks that view turn (net, capped at
  ±0.6 rad, reset on a key change or any ground step). The flight's bend toward the same side
  spends the bank and pays 1.0 m/s per radian: in full up to 12 m/s, fading to zero at 16 m/s.
  The pay depends on how far the view and the flight both turned, not on how the mouse
  delivered the turn. With a fixed view nothing is banked, so nothing is paid.

Ledger causes added: `air_bend`, `air_carve`, plus CARRY's `air_low_push` and `air_brake`.
Every write is booked; the suite flags any residual over 1e-4.

**Shared and unchanged:** ground, slope, take-off, landing, body, contacts, camera,
interpolation, gravity, jump, buffer/coyote/autohop and the 30 m/s safety envelope. With only W
and no view offset past 45°, the candidate's air step is arithmetically CARRY's: the
calibration line differs from broad by 0.000000 m at every tick. So **W placement within 45°
is inherited, not new.** What changes: W with the view 45–135° off, every side key, and the gain.

## Measurements (pre-patch, base at 390cb022)

Seeded fixtures place the runner once with a labelled velocity; everything after is key and
relative-mouse events. All values come from finite-difference travel. Suite output is in
`test-pre-base-patch/` (`summary.json`, per-episode traces) and `test-pre-base-patch.log`.

**Fixed view, seeded 13 m/s, after 0.6 s (about one flat hop):**

| Input | Candidate | Broad | Narrow |
| --- | --- | --- | --- |
| A, lateral / turn / gain | 1.62 m / 23.5° / 0.000 | 0.73 m / 10.3° / +0.22 | 0.45 m / 0° / 0.000 |
| W+A | 2.05 m / 30.0° / 0.000 | 2.25 m / 31.2° / +0.32 | 2.16 m / 26.1° / +0.004 |
| S | −2.96 m/s, no reversal | same | same |
| S+A | −2.06 m/s, 1.09 m lateral | −1.97, 0.48 m | −2.07, 0.45 m |
| No keys, or a 90°/120° look with no keys, or a 50° glance with W released | exactly unchanged | same | same |

**W with the view offset by one mouse event, 12 m/s, travel turn in 0.6 s:** 20° → 19.4°,
45° → 39.6° in all three. At 90° the candidate turns 39.6° and at 135° it turns 34.2°. Broad
and narrow turn 0° at both, because CARRY's W assist fades to nothing at 90°.

**Side key turned with the mouse, seeded 10 m/s, 1.2 s, speed change by view rate:**

| View rate (rad/s) | 0.3 | 0.75 | 1.5 | 3 | 6 |
| --- | --- | --- | --- | --- | --- |
| Candidate, A | +0.36 | +0.89 | +0.94 | +0.37 | +0.57 |
| Broad, A | +0.29 | −1.09 | −3.00 | −2.38 | −0.89 |
| Narrow, A | +0.26 | +0.64 | +1.22 | +2.19 | +3.27 |

W+A: candidate is never negative (best +1.34); broad's worst is −3.31. W with the mouse gains
exactly 0 at every rate in all three. Fast turns make wider arcs in the candidate: at 6 rad/s,
A's flight follows about 14° of 412° of view turn, at no speed cost.

**Mouse cadence.** The same 1 rad left carve over 0.8 s, constant and smoothstep, at 120, 60
and 30 events per second in every phase:

| | Gain at 120 | at 30 | Max spread |
| --- | --- | --- | --- |
| Candidate | 0.892 | 0.891 | 0.019 (2.1%); heading 0.19° |
| Narrow | 0.694 | 0.535 | 0.191 (27%) |
| Broad | −1.619 | −1.667 | 0.047 (loses speed) |

**Boundedness, seeded 10 m/s with held hops on flat:**

- Fixed-view W+A for 20 s: candidate holds exactly 10.000; broad holds 10.421; narrow 10.023.
- A fixed-view A/D weave, swapping every 0.4 s for 20 s, with no mouse: candidate 10.000. The
  rejected unsynced variant reaches 15.71.
- D with a ±0.3 rad mouse wiggle and no net turn, 10 s: candidate 10.300, one bank. Broad
  reaches 14.58.
- A continuous carve circle (D with a 1.2 rad/s right turn, 20 s): candidate reaches 15.22,
  below its 16 m/s ceiling. Narrow reaches 25.84; broad decays to 8.65.

**Correction and overlap.** The tables are W-only here, so all three are identical. A W
overshoot (60° left, then 40° back) settles on the final view by 1.25 s at no speed cost. A
late D pressed over a held A: the overlap leaves W alone, which bends back toward the view at
72.9°/s, inside the bend limit, at no speed cost. Narrow's projection snaps at 431°/s with
−0.25 m/s; broad gains +0.09. Mirrored strafe, W turn and W+A turn give mirrored travel
(x sums under 1e-3).

**Game factory.** On the calibration block, W and three timed hops finish in 7.408 s, peak
13.17 m/s, with no safety intervention. The HUD speed equals actual travel on every tick.

**Rejection.** Each discriminating claim fails a control it should exclude: fixed-view lateral
correction fails narrow; "never loses speed when turned" fails broad; under 5% cadence spread
fails narrow; the fixed-view weave fails the unsynced variant. Seven claims (ballistic line,
free look, W neutrality, S, W+mouse, carve ≥ 0.2, W at 45°) pass every control too. They are
reported as non-discriminating findings, not counted as candidate advantages.

## Tape matrix (pre-patch)

`tools/make_tapes.py` authors seven open-loop tapes as key edges plus continuous strokes. It
then delivers the mouse at 120, 60 (phases 0 and 1) and 30 (phases 0 and 2) events per second.
Each event carries all motion since the previous poll, as a device reports it. Key edges never
move. Physics stays at 120 Hz. Each tape ran on the candidate, broad and narrow through the
committed helper, in headless source mode: 105 runs, all with clean delivery, 1,100 to 2,300
counter-verified ticks each, and clean cleanup. Results are in `runs/headless/summary.json`;
`tools/analyze.py` reads only recorded telemetry.

| Tape (v3) | Candidate | Broad | Narrow |
| --- | --- | --- | --- |
| w-placement and its mirror: view drifts 9° on the descent, W+mouse correction, overshoot, released glance | 5/5 finish, 7.64–7.80 s | identical (W only) | identical |
| side-correct and its mirror: off-line start, fixed-view A correction, W+A then D overlap, A held a whole flight | 5/5, 7.99 s; x 3.75 → 2.00 m in flight 1 | 5/5, 7.84 s; 3.75 → 1.84 | 5/5, 8.04 s |
| hops-brake: buffered early press, held autohop, late kicker press, S in the last flight | 5/5, 7.33 s | identical | identical |
| carve-weave: A/D strafe weave with mouse strokes, net zero turn | 5/5, 7.09–7.11 s, peak 13.67, carve +0.83 | 5/5, 7.40–7.43 s, peak 13.14 | 5/5, 6.94–7.08 s, peak 14.20 |
| poor-landing-recover: overshoot onto the catch floor, ramp walk back, finish | 5/5, 17.67–17.73 s, 0 respawns | 0/5 | 5/5 |

- **Cadence spread on carve-weave** (positions before the finish / peak speed): candidate
  0.15 m / 0.042 m/s, narrow 1.35 m / 0.416 m/s.
- **W-placement** spreads 1.30 m in all three. That is the shared W assist following a view
  that arrives up to 3 ticks later at 30 Hz.
- **Bias.** poor-landing-recover was authored by iterating on the candidate. Broad's different
  strafe lands elsewhere, so the same open-loop walk misses the ramp. That 0/5 is not evidence
  about broad's own recoverability. The other tapes were retimed only for key releases that
  every policy shared.
- **Retained earlier versions:**
  - `tapes-v1`, `runs/headless-v1-side14`: the candidate at side bend 14. A full-flight A hold
    ran off the deck for the candidate and for broad, and W was released before the finish box.
  - `tapes-v2`, `runs/headless-v2`: tapes ended 0.3 m short of the box. hops-brake released
    autohop before the 0.25 m lip.
  - `runs/failed-relative-out`: helper refusals from a relative output path.

## Rejected variants

- **Side bend 14 (the first default).** A alone turned 36.5° and moved 2.47 m per hop, more
  than W with a 45° view offset. A full-flight hold left the 12 m deck. At 9 the side keys still
  correct twice as far as broad, while W and the view stay the main turning tool.
- **Unsynced carve.** Paying any side-key turn lets a fixed-view weave farm 10 → 15.7 m/s.
  Kept only as the `carve_unsynced` diagnostic that the tests must reject.
- **Speed-neutral only** (`carve = 0`). A valid, simpler loop, but it leaves no air mastery
  beyond hop timing. Not chosen. Root can compare it with `--air=carve:0` in one run.
- **A pure force law** (sin fade from 0°, no full band). Small corrections converge
  exponentially and slowly, a 0.9 s time constant at 13 m/s. Rejected on that analysis; not
  run as code.

## Tradeoffs and failures

- **W placement is not new.** Within 45° it is CARRY's W assist. If Mike's objection is
  W+mouse placement itself, this candidate does not address it.
- **W stays bending past 90°.** Holding W while looking behind curves the flight around
  (34° per hop at 135°). Players used to W doing nothing at large offsets may find that
  surprising. A W-held glance is not free; a glance with keys released is.
- **The carve is modest.** About 0.9 m/s per second of continuous synced turning at ordinary
  speed, against narrow's up to 3.3. A CS strafe player will find it gentle. The ceiling of
  16 m/s is a P choice.
- **Fixed-view side correction gains nothing**, so broad's A sometimes finishes a few tenths
  sooner on the same tape.
- **Cadence is not fully invariant.** The 2.1% carve spread and 0.15–1.3 m path spreads come
  from the view itself arriving later at low event rates.

## Inherited contact faults encountered

- **The 0.25 m lip is a dead stop.** hops-brake v2 ran into it at 12.6 m/s and stopped from
  12.57 to 0.00 m/s, with a 0.7 s stuck window, identically for all three policies. This is
  CARRY's known ≥15 cm lip stop, not air policy.
- **Sol's stale-floor double hop** on a fast descending take-off beside a rail is in the shared
  base. Root is patching it. The calibration tapes never reported a duplicate jump: fired jumps
  equalled presses or buffered presses in every run. They do not include a rail.

## Native evidence (pre-patch)

`native/pre-base-patch/<policy>-<tape>/`: helper runs on private Xvfb `:160`, Dummy audio,
isolated XDG profile, Godot's movie writer at 30 fps, actor frames and contact sheet, with
`run.json` source and engine hashes.

- **`candidate-poor-landing-recover-m60p1`**: 2,300 ticks, 585 movie frames, finish at
  17.69 s with no respawn. Its trace equals the pre-patch headless run of the same tape at every
  tick (0.0 m difference). I inspected `inspect/strip-1s.jpg` (one frame per second) and
  `inspect/jump-turn-miss.jpg`:
  - approach and descent
  - the A plus left-stroke overshoot off the lower deck's left edge, and the drop past the lip
    deck onto the catch floor, with the HUD's miss hint
  - the walk up the return ramp, the turn onto the landing deck, the held-hop run over the gap,
    lip and kicker, and the finish panel

  Movement reads clearly. Deck and catch floor are low-contrast pale blue on llvmpipe; that is
  the calibration fixture's palette, not final art.
- **Not captured pre-patch.** The broad baseline for the same tape started after the shared
  base changed in the working tree (uncommitted `1c3a4f9d…`). It is kept, labelled, in
  `native/mixed-base-1c3a4f9d/` and is not used as evidence. I stopped the sequence there, so
  the planned native candidate side-correct and carve-weave runs and the broad side-correct
  baseline wait for the committed base.

Software rendering and fixed-fps movies say nothing about GPU pacing, latency or enjoyment.

## Source identity (pre-patch)

`source-pre-base-patch/sha256.txt`, at HEAD 390cb022:

- engine `8d106cbe…f71e`
- `momentum_carry_player.gd` `280be87c…306a`
- `momentum_carry_game.gd` `c544202b…c09c`
- `momentum_carry_lab.gd` `e803957b…1131`
- `spillway_player.gd` `b1b119b2…e9`
- helper `momentum-tape.py` `f8cc2e2d…106e`

Candidate files are in the same manifest. Every helper run also records its own hashes in
`run.json`. After root's base patch, results go to separate `post-base-<hash>` directories and
are reported beside these, never merged.

## Root integration after the support fix

Root reran the complete suite on committed base `fd38b1e9`, motor SHA-256
`1c3a4f9d4687c62c53fc4ec10efbbf09cf31fc43ba34d3cc7850ff13011276b9`.
All 42 gates pass, with 134 result records, 21 disclosed findings and no input/order
violations. Evidence is in `root-post-fd38b1e9/test/` under this experiment's evidence
directory. Entries include comparison summaries, so they are result records rather than
134 physical episodes. Root corrected the output label after the run; that changes no
test or motor behavior. The independent challenge and complete post-fix native comparison
remain pending. No final game policy or enjoyment claim follows from these checks.

## For root

Integrate the three scripts, their UIDs and this document. Rerun the suite and the matrix on
the patched base. Then compare on Overflow's neutral block and holdouts. The open choice is
broad / narrow / candidate, with speed-neutral-only as a one-flag variant. The tests show the
candidate's claims hold and that they discriminate where noted. They do not show that the
candidate is fun.
