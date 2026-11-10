# R20 directional style stacks

These are game choices. The style identity is `r20-style-stack-1`, event family 2, plus the SHA256 of the sorted Godot JSON rules table. Motion, time, original-map and ghost identities exclude style. Old style best sections remain separate; old time/ghost compatibility remains unchanged on unchanged geometry.

An eligible backwards hop earns a pending stack with unit 160; half-sideways uses unit 50. For `n` consecutive eligible landings, pending is `unit*n*(n-1)/2`. Hop 1 arms at zero, hop 2 adds one unit, hop 3 adds two units, and so on. There is no gameplay chain cap. Amounts use Godot's integer arithmetic.

| Eligible hops | Backwards pending | Half-sideways pending |
|---:|---:|---:|
| 1 | 0 | 0 |
| 6 | 2,400 | 750 |
| 12 | 10,560 | 3,300 |
| 20 | 30,400 | 9,500 |

Pending is excluded from score, scored-event counts and `by_kind`. A normal direction, flight or ground-continuity end banks exactly the pending amount once while actual horizontal speed remains at least 300 u/s. Banking neither extends nor uses the ordinary combo multiplier. It cannot multiply speed, gap, sync, edge, near-miss or crouch-save events. Those detectors retain their version-1 event schema and ordinary R19 combo behavior.

Actual speed below 300 u/s loses pending before any normal-end or inclusive-finish bank. Respawn, teleport, restart, practice, map, applied preset, changed loadout, look-setting change and quit discard pending. A deferred, invalid or unchanged preset/map/loadout request does not discard it. Volume and ghost visibility retain their inherited benign-setting behavior. A first finished sample can bank once; subsequent samples are sealed. A low-speed finish loses instead.

Pause suspends sampling and style time without paying or clearing earned evidence. Resume validates the next actual sample against the previous sample and flight. It does not fabricate a landing, restore an invalidated flight, skip a failed facing/speed check or grant a free hop. A look-setting change while paused still discards pending, and quitting before another capture must record that queued loss.

## Eligibility is the R19 rule

Every sampled step needs actual horizontal speed at least 300 u/s. Facing is the dot of normalized actual horizontal travel with `(-sin(yaw),0,-cos(yaw))`: backwards at dot <= -0.75; half-sideways at absolute dot < 0.75. A flight starts only on departure from observed ground with the motor's real `jump` event.

A complete flight needs 0.18 to 1.2 s, at least 3 m tracked horizontal travel, 0.25 m rise, 0.20 m descent from the peak, net progress at least 85% of tracked travel, and landing heading dot at least 0.5 against the previous eligible hop. Ground dwell over 0.06 s ends continuity. Each valid landing, including the zero-point first hop, reserves a 4 m horizontal novelty radius. Both direction categories share that history for the whole attempt. Discontinuities preserve it; a fresh attempt resets it. A failed hop does not become the first hop of another chain on that same landing.

The recorded R19 session disproves a universal once-only lock: 12 backwards awards occurred in six runs. `playtest-r19/ANALYSIS.md` and its `r20-analysis.json` are observation reconstructions, not engine replays. In `saltglass_server128_20261110-075138_718_fe5043e8.r16run`, ticks 676/772 arm/pay, tick 868 fails efficiency at 8.381/10.546 = 0.795, tick 963 fails at 0.769, and tick 1171 fails descent because peak equals landing height. Tick 1643 re-arms; 1739 fails heading. The separate `074540_173_ea236da7` run contains six valid landings and five awards. Curved travel, uphill contact and heading continuity explain these concrete failures. No missing re-press or exhausted universal award budget was reproduced. The playtest contains no sideways awards and cannot establish sideways feel.

## Service and lifecycle contract

The common post-step sample remains `docs/r16/INTERFACES.md`. The frozen session, recorder, both strict readers, ghost and motor files are unchanged.

- `reset(context={})` clears totals, pending, diagnostics, suspension, seal and attempt novelty.
- `step(sample, body, level)` returns a tagged recording stream. Scored events omit `record_kind`, use v1 or v2 below and enter `events`, score and `by_kind`. Non-scored entries use `record_kind="direction"` and never enter those scored collections. The inherited recorder already routes that discriminator. Consumers of the returned array must distinguish it rather than treating every capture as style.
- `discontinuity(reason)` loses pending and clears continuity while preserving attempt novelty and banked score. Pause/resume are the suspension exceptions described above. Loss diagnostics queue for the next capture.
- `drain_diagnostics()` returns and empties that queue without scoring.
- `discard_pending(reason)` applies the discontinuity and returns **all** queued diagnostics, including an earlier look-setting loss. The parent R20 host records each with `recorder.event("direction", diagnostic)` before the old attempt seals. Repeated nested map/restart calls cannot generate a second loss from an empty stack.
- `summary()` counts scored events only. The frozen session's finish/seal path uses this summary.

The parent-owned `r20_main.gd` calls `discard_pending` before restart, practice, valid different map, applied `_switch_to`, valid changed mechanic and quit. Its real pause edges call `discontinuity("pause"/"resume")`. Respawn and look settings retain their inherited lifecycle hook. The executed parent file hash is pinned by the external integration contract.

## Scored events

Every ordinary event is **v1**, with its original fields and bounds. R20 ordinary events have `direction_mult=1`; `mult=combo_mult`. Legacy bounds must not be widened to accommodate banks.

Directional banks use **v2**, with these exact fields:

| Field | Meaning |
|---|---|
| `v` | integer 2 |
| `kind` | `backward_bhop_bank` or `sideways_bhop_bank` |
| `tick` | current attempt sample tick, equal to outer capture event `t` |
| `time_s`, `elapsed` | style simulation time and host course seconds, snapped to 1e-6 |
| `points`, `base` | identical positive integers, exactly the triangular formula |
| `mult`, `direction_mult`, `combo_mult` | all 1.0 |
| `combo` | 0; the bank does not extend the combo |
| `label` | `Backwards banked` or `Half-sideways banked` |
| `m` | exact measurement object below |
| `geo` | empty object; direction is not a named obstacle award |
| `p` | actual feet `[x,y,z]` metres, snapped to 0.0001 |
| `clean` | sample's clean eligibility |

`m` contains `direction` (`backward_bhop`/`sideways_bhop`), `hops` (integer >=2), `unit` (160/50), `formula` (literal `unit*n*(n-1)/2`), `reason`, `start_tick` (first eligible landing), `last_hop_tick` (last eligible landing), and `end_ups` (actual horizontal speed on the bank sample). Bank reasons are `facing`, `ground_dwell`, `no_motor_jump`, `flight_timeout`, `flight_short`, `travel_short`, `rise_short`, `fall_short`, `efficiency`, `heading`, `novelty`, or `finish`.

The binary recording container stays version 1. It transports arbitrary JSON event payloads; scored-payload v2 is independent of the container version. Dense outer event order `q`, ticks, seals, style totals and both readers must reconcile. Bank events must never be split into fabricated capped v1 awards.

## Non-scored diagnostics and snapshot

A diagnostic has exactly `record_kind="direction"`, `v=1`, `kind` (`direction_pending`, `direction_banked`, `direction_lost`), `reason`, attempt-local `serial`, `tick`, `time_s`, `direction`, `hops`, `pending`, `unit`, `formula`, and `m`. It has **no** `points`, `base`, `mult` or scored-total meaning. A pending diagnostic's measurements are `air_s`, `track_m`, `progress_m`, `rise_m`, `fall_m`, `heading_dot`, and `landing_ups`; bank/loss diagnostics use an empty measurement object. An armed zero-point stack can end with a diagnostic and no scored award.

Capture diagnostics have outer `k="direction", s="capture"`; pre-seal lifecycle diagnostics have `k="direction", s="event"`. Queued loss diagnostics identify the last observed stack sample, so their inner tick/time may precede their next outer capture tick. The associated lifecycle event supplies the boundary. Never enforce scored-event tick equality on these diagnostics or include them in a scored tally.

The ordinary snapshot fields remain: `version`, `identity_key`, integer `score`/`combo`, ordinary `mult`, `combo_left_s`, `combo_window_s`, `last_combo`, scored-only `recent`/`last`, `by_kind`, clean/finished/sealed/best eligibility flags, `time_s`, `context`, and detector `diag`.

`snapshot().direction` contains `kind` (empty when inactive), `hops`, integer `pending`, `unit` (zero when inactive), `formula`, `suspended`, and `last` (empty or the most recent bank/loss diagnostic). `diag.direction` contains `last` (eligibility verdict/tick and optional measurements), `visited_landings`, and `flight` (empty or `from` as a numeric position array, `peak_y`, `track_m`, `air_s`). All are JSON-safe. Detailed rejection data lives here rather than adding always-visible debug text.

The R18 HUD shows direction, eligible hop count and `+pending`, including hop 1 at zero. Its score caption says `banked style`. A short banked/lost callout uses the existing callout slot and rank policy. The centre, ordinary combo indicator, clock, speed and strafe display remain available. Pause visibility and UI hotkeys stay inherited.

## Reproduction and native observer

From the project directory, run:

```bash
python3 -I tests/r20_style_check.py --out /tmp/r20-style-stack --only=stack,observer,ui720,ui1080,r16
```

Use a fresh output directory for independent acceptance. This copies source/imports into bounded external scratch, extracts the exact `065f7b27993df7ae2511eb34eb665d271dded13c` scorer, uses the pinned cached Godot 4.7.2 binary, isolated XDG profiles and one sequential engine process. `--keep-source` is for temporary parent inspection; remove it for automatic source/profile cleanup. `--cases=...` is a focused fixture mode, not full acceptance.

The actual `scenes/r20.tscn` is instantiated with an explicitly labelled collision-map registry entry and F2. Fixture geometry, record geometry identity, kill bounds and optional finish/wall/ceiling are configured before restart. All later motion is physical key input and float32 mouse counts. Public lifecycle methods are exercised directly. No body position, velocity, view, progress or stats are written after setup. The read-only check spans priority 998 to 1001 around the real session's priority-999 style step.

`tests/r20_style_audit.py` independently checks both decoded readers, scored totals/by-kind/seal/order, v1 bounds, exact v2 formula, diagnostics, and eligible landings reconstructed from raw recording observations using the R19 analysis rules. It verifies original motor/map/recording sources against exact Git bytes. The existing R16 style suite covers ordinary collision detectors. R19's multiplier/cap-specific assertions describe the intentionally superseded score lifecycle; their source is preserved.

The native Godot command also takes `--windowed --resolution 1280x720` (or `1920x1080`) before `--`; both flags are verified in the pinned binary help. The parent native seam is the same `tests/r20_style_stack.gd` entry point with `--native --size=1280x720` or `--size=1920x1080`, plus absolute `--out` and `--baseline` paths, passed after Godot's `--`. It runs two earned episodes, saves pending/banked/lost screenshots and a complete input tape/observation/recording set. `--observer` runs those same two episodes headlessly and supplies exact sample ticks and simulation times in `summary.json.native_markers`. Native rendering uses the parent's private display, never desktop `:0`.

The compact external `look/evidence/r20-style-component/CONTRACT.json` binds identity, exact executed source hashes, formula, schema/reasons, fixture results, raw proof hashes, frozen reference and native markers. Generate it with `python3 -I tests/r20_style_contract.py --run /tmp/r20-style-stack --out /home/thatmike1/foldrunner-build-2026-11-05/look/evidence/r20-style-component`. It is the integration input for parent parity/package auditors. Headless bounds at 720p/1080p prove logical layout and copy, including canvas scaling; they do not establish native GPU appearance or enjoyment. The parent owns native inspection and all release/package claims.
