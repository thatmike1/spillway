# Independent crouch review of a37636bb

Default F2/F5 input trials did not reproduce a new unsafe stand-up, overlap, velocity
impulse or uncrouched movement difference. Two settings-interface faults reproduced.
Both require an explicit diagnostic change to the duck configuration while ducked;
neither is a demonstrated exploit of the default controls.

Reviewed commit: `a37636bbcd4f2b7186839c19630d316f7cd8d59a`. Godot:
`4.7.2.stable.official.ed1daf0bf`, binary SHA-256
`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.
Read BRIEF.md, INTERFACES.md, CROUCH.md, the new runner, its R14 base, presets,
input dispatch, and the existing main's record identity code. No production or existing
test file changed. This is a source review, not packed-game acceptance or a CS binary
fidelity/feel verdict.

## Ranked reproducible findings

### 1. P2, conditional: applying a larger duck hull bypasses fit validation

`r15_source_player.gd:76` delegates settings directly to the R14 setter, which calls
the virtual `_fit_hull`. With `ducked=true`, that resizes the active collision shape
without testing the proposed volume. The safe-release check is never involved.

Repro: start standing on the open floor, hold Ctrl+W to enter the 62 u tunnel, stop
inside it, then apply the otherwise unchanged settings with `duck_hull_height=70`.
The test's F7 is an explicitly diagnostic binding for this API call. It is not a game
control. The 70 u hull cannot fit between the floor and roof.

- **Headless red:** `diagnostic_hull_resize_low_roof`, tick 1010. Feet move from
  +0.045 u to -7.111 u; both `floor` and `low_roof` overlap the independently queried
  hull. Depenetration is 7.156 u. Reported motor velocity is zero, while actual travel
  reports -915.972 u/s vertically. Overlap persists through all 51 remaining ticks.
- **Control:** unchanged 54 u duck hull in `low_roof_release` remains clear, refuses
  release for 599 ticks, and stands after leaving the roof.
- **Native red/control:** `native-01/resize` and `native-01/control` repeat the setup
  with XTest keys and relative mouse. Control has zero overlaps in 937 sampled ticks.
  Resize has 36 overlap ticks out of 943; its first sampled overlap is the roof at
  tick 908, then floor and roof after the motor's recovery. The actor did not write
  pose or velocity. It uses observer coordinates to time its key presses, so this is
  a coordinate-aware OS-input proof rather than an open-loop route. Both processes
  rendered on AMD and exited zero.

This is relevant if the shell or future mechanics change hull settings in place. It
does not establish a fault when switching between the two unchanged default presets.
Reject/defer an unfit resize, or apply geometry changes only through a validated reset.
Keep movement and actual travel separate; the actual-travel report correctly exposes
the recovery motion here.

### 2. P2, conditional: a live anchor change makes an air duck/stand pair lose height

`air_lift_u()` derives the lift from the current settings. `_update_duck` uses it
both on press and on release, without remembering the lift applied at press.

Repro: jump at tick 1, crouch in air at 12 with the default center anchor, apply the
same settings with `duck_air_anchor="head"` at 20, release crouch at 40. F6 is the
diagnostic settings action. No pose, velocity, grounded flag or collision is seeded
after the initial setup.

- **Red:** `diagnostic_anchor_switch`. Press adds 9 u; release subtracts 18 u. At
  tick 40 the feet are 45.377285 u and cumulative compensation is -9.000002 u.
- **Control:** `air_pair`, with identical movement inputs and unchanged settings.
  Tick-40 feet are 54.377285 u and compensation is approximately zero. Both have
  exactly the same velocity, including vertical velocity 48.868362 u/s at that tick.
  The changed-anchor episode lands at tick 91; the control lands at 95.
- **Independent no-duck control:** `air_pair_control`; the unchanged-setting duck
  pair has identical per-tick velocity and rejoins its final resting position exactly.

Remember the outstanding lift, compensate safely when changing settings, or defer
anchor changes until standing. Repeated full-fixture runs reproduce the loss. Native
confirmation was reserved for finding 1; finding 2 is a deterministic collision/input
fixture result. No default F2/F5 setting changes this anchor.

## What the ordinary-input probes actually reached

The final suite contains 33 episodes, 25,226 motor samples including settle ticks,
and 125 checks: 123 pass, with the two diagnostic checks above deliberately red.
The process returns exit 1 for those findings. A count is not the verdict.

Each episode has one labelled settings/pose setup and 12 settle ticks. Subsequent
movement uses `InputEventKey` physical keycodes and `InputEventMouseMotion` through
`Input.parse_input_event`, sampled before and after the actual motor. R/F2/F5 input
routes call the public reset/preset methods. There are no mid-episode pose/velocity
rescues. The F6/F7 settings diagnostics are distinguished in source, trace and summary.
Independent overlap queries inset every hull face by 0.02 u to reject contact noise.

| challenge | observed result |
|---|---|
| Independent no-crouch controls | Four new episodes, F2 and F5 each with mouse/key hop/turn input and a separate walk off a 128 u edge to the catch floor. All 1,968 samples have exactly equal R14/R15 positions, velocities and events. Each hop/turn episode actually jumps three times; edge episodes reach the lower floor. |
| Landing duck spam | Eight phase offsets, toggling every two ticks through repeated hop/landing cycles. No queried overlap, extra jump impulse or unbounded height growth. Post-step jump velocity is always 292.618378 u/s. Peaks vary from 64.854 to 66.808 u; the standing held-hop control also varies from the first jump because R14 can mark ground within its 2 u probe. These peaks alone are not a new height-mint verdict. |
| Edge duck spam | Six phase offsets with an input-earned jump, elevated edge and lower catch floor. Each actually jumps once. No overlap or unsafe standing. An early fixture version accidentally overwrote some jump events; it was corrected to append events and the final suite checks the jump count. |
| Flat low roof release | Release inside the roof remains ducked for 599 ticks, then stands clear. |
| Falling sloped roof | Release at tick 1100 is refused for 579 ticks. Reversing direction earns clearance and standing at 1679. No queried overlap. |
| Parallel sloping floor/roof | The runner climbs to 68.079 u, releases beneath the roof and stays ducked for 468 ticks, then stands after backing out. No queried overlap. |
| Airborne release under a low roof | Input-earned crouch hop beneath the 62 u roof, release at tick 410 while airborne at feet 6.583 u. It stays ducked for 466 ticks and stands after the exit. No queried overlap. |
| F5/F2 while release is blocked | Release at 850 inside the tunnel; F5 at 870, F2 at 900. The 54 u hull remains safe, with 478 blocked ticks, then stands at 1328. |
| Reset while Ctrl is held | R resets the airborne ducked runner at tick 40. Its next held-Ctrl tick uses the air anchor at the reset pose, lifting feet to 9.476 u; it lands at 57 and stands at 58. No old jump pulse survives. This small reset drop is observable, not evidence of a clean standing-height reset. |
| Queued inputs | A Space press/release within one motor interval still jumps. An equivalent Ctrl tap produces no duck because crouch reads held state rather than a press latch. This is a measured difference, not a contract failure or a physical-device latency claim. |
| Camera/travel | No sampled camera point enters a solid in these fixtures. The largest position-vs-origin/travel/shift accounting error is 0.0000751 u. The default midair pair adds no velocity and rejoins its control. Headless frame samples do not establish visual comfort or high-refresh interpolation quality. |

Some first-attempt release timings happened before entering the obstacle, and the first
ramp approach did not connect to the slope. Those probes were corrected before the
final suite. Coverage checks require the release cases to actually block and then stand.

## Record identity and earlier evidence

The actual existing R14 main and the existing R15 tape adapter were instantiated with
persistence off on the same Overflow geometry. Their computed course keys are
`2840913fd2e2835f` and `0d5897a41d5a529c`. All six duck settings individually change
the adapter's actual computed key; sensitivity/FOV changes preserve it. Raw preset
settings omit duck keys, but the applied runner settings contain them and the existing
main fingerprints those applied settings. These checks exercise the real key code,
not just two hand-built JSON dictionaries.

The adapter still identifies its family version as `r14-source-motion-3`; its motion
state identifies `r15-source-crouch-1`. This is an existing integration requirement,
not a discovered collision between the tested keys. The final R15 shell must use its
own version/profile and verify save/reload. At the reviewed commit the default scene
and project identity are still R14, and no `r15_main.gd` exists. This review does not
certify final R15 records, checkpoint purity or profile persistence. The review's
isolated profiles contain no game record file.

Inspected the prior worker's `crouch/suite/summary.json` (95 checks),
`crouch/tape-parity/compare.json` (reported 6,279 exact ticks), and
`crouch/os-input-02/run.json` (19 checks and per-file identities). Its R15 and R14
runner hashes match this checkout. Some raw parity paths in that report point to
removed worker scratch. Those older counts remain attributed evidence, not independent
reruns by this reviewer. The four fresh no-crouch episodes above are this review's proof.

## Reproduction and evidence

Use the pinned binary under `~/.local/share/foldrunner/godot-4.7.2/`. Import a fresh
copy of this project, with private XDG data/config/cache/state directories. From that
copy, the complete headless invocation is:

```text
Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 128 --path . --script res://tests/test_r15_crouch_review.gd -- --out=ABSOLUTE_EVIDENCE_DIR
```

`--only=diagnostic_hull_resize_low_roof` or `--only=diagnostic_anchor_switch`
isolates a red case. `--only=air_pair` runs the air-pair control too. Full traces and
event schedules are retained as gzip JSONL and summary JSON.

Native red/control driver:

```text
python3 -I tests/r15_crouch_review_os_input.py --project ABSOLUTE_IMPORTED_COPY --out ABSOLUTE_NEW_EVIDENCE_DIR
```

Evidence root, outside Git:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/crouch-review/`.
`final-suite/summary.json`, per-episode gzip traces, `native-01/run.json`,
`native-01/{control,resize}/episode.json`, compressed native telemetry and
`RECEIPT.json` record the results and identities. Earlier attempts remain labelled.

Native work checked HOME free space above 15 GiB, used the checked display helper
with explicit displays 190-199, and recorded AMD activity and display cleanup. No
desktop display or Wayland game launch was used. Native engine logs have one X input
method initialization warning per process; XTest key and mouse delivery succeeded.
There are no engine errors, and the final headless suite has no engine warnings.
No movie or large render was made. Imports, profiles and owned processes are cleaned;
R14 delivery ZIPs and baseline files are untouched. Evidence remains below 25 MiB.

Excluded: final product shell, Breakwater, other maps, packed Linux/Windows execution,
new record persistence, CS binary fidelity, physical-device latency and human enjoyment.

Root follow-up: motor version 2 defers structural duck-setting requests until safe standing or reset. The unchanged 125-check review and original 95-check suite pass in a fresh copy, with no engine errors/warnings (`checkpoints/spillway/r15/crouch-repair/`). This is root's repair evidence, not a new independent or native review; the findings above describe a37636bb.
