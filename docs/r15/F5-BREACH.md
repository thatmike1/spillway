# F5 Breakwater breach: proven headless controller line

On 9 November 2026 the first new input-only candidate finished the actual R15 main's
Breakwater clean in **33.9765625 s**, with ordered stages and **zero respawns**. One
open-loop replay of its unchanged input tape produced the same clean result. Exploration
stopped: **one candidate plus one replay, two full attempts total, no failed route trials**.

This is a state-aware controller line followed by one exact replay. It establishes neither
human play, imperfect-input robustness, packed acceptance nor feel. No native rendering or
export was performed. No agent was started.

## What the controller changed

The new `tests/r15_breakwater_f5_probe.gd` extends the existing actual-main driver. It keeps
Gate, Rows and Quay unchanged. Its end nodes are:

- `(-76, -125)`: hop toward the point, air-speed target 3000 u/s.
- `(-78.5, -248)`: keep hopping and strafing for speed across the runway and breach.
- `(-84.5, -256)`, then `(-80.5, -267)`: steer around the lighthouse's west side.

The inherited fitted landing before the breach is absent from this new controller route.
It does not apply the fitted-hop air brake. This is a controller change, with **no change to
F5, cvars, motor, geometry, game, HUD, progression or existing tests**. The main selects
`server128_aa1000` before its own normal labelled spawn. Thereafter the probe delivers only
W/A/S/D/Space key events and relative horizontal mouse events, through the inherited real
input-event path. There is no pose, velocity, camera, momentum or progress write.

The finish trigger is reached before the last navigation waypoint. The actual main, rather
than the waypoint count, certifies the clean finish and complete ordered stage times:
5.7421875 / 12.2734375 / 24.9921875 / 30.96875 / **33.9765625 s**.

## Actual breach flight

The final runway landing occurs at tape tick 4084, on `s4_runway_4`, at
`(-77.8782196044922, 0.017357662320137, -235.409378051758)` with horizontal
speed **987.832076906219 u/s**. Tick 4085 reports `perfect` and `jump`.

The flight lands at tick 4194 on **`s4_head_nw`**, at
`(-83.4551773071289, -0.962324738502502, -255.282073974609)`, with horizontal
speed **1031.94567162221 u/s**. Every intervening tick is airborne. Every flight sample
stays west of x = -71; no support anywhere in either run is the ordinary gangway.
The retained `probe.json` contains full-precision endpoints for every flight, while
`trace.jsonl.gz` retains the inherited rounded per-tick observations.

## Settings and replay verification

Actual R15 runner: `res://scripts/r15_source_player.gd`, 128 Hz, `sv_airaccelerate = 1000`.
Default Source sensitivity 2.5, m_yaw 0.022, 0.000959931088596881 rad/count;
33 idle physics steps before tape tick zero. No crouch or alternate mechanic was used.
Course key: `69631ffd4e89dcb1`. Both logs contain no engine warning or error.

Replay used the same actual main, preset, warmup and sensitivity with `--tape=`. The probe's
replay branch chooses no input from observed state. The audit verifies exact per-tick key
edges and summed relative mouse counts, the full physics fingerprint, ordered stages,
clean eligibility, zero respawns, no recorded sinks, and no gangway support.

All **4,375 common trace ticks** match exactly after excluding only the controller's
navigation-node index. This is equality at the inherited driver's recorded precision, not
a claim of full-precision whole-motor identity. All full-precision flight endpoints also
match exactly. Replay has one extra final neutral observation because tape duration
includes the neutral tick after controller termination. The finish tick is 4374 in both.
The inherited loader groups keys before mouse within each tick; a preliminary flat-list
comparison therefore failed. Per-tick key order and mouse sums are identical. The input
tape was not changed to satisfy the audit.

## Frozen resources and retained evidence

Only this document and the new `tests/r15_breakwater_f5_probe.gd` and `.py` were added to
source. **746 pre-existing runtime/resource/test files** match their baseline SHA-256s.
The original game/resources and existing tests were copied into an isolated `/tmp`
project; all imports and profiles stayed there. Scratch stayed below 250 MiB (168 MiB at
last measurement); HOME stayed above 15 GiB at each measured checkpoint. All scratch and
owned processes were removed after verification. The active root candidate, stage and
package evidence were untouched. No commit or push was made.

Evidence: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/f5-breach/`.
`attempt01/` and `replay01/` each retain summary, detailed flights, log, gzipped trace and
gzipped input tape. `RESULTS.json` contains every retained file hash and source hash;
`frozen-resources.sha256.json.gz` is the complete baseline. Total evidence is below 5 MiB.

Run the retained audit from the project directory:

```bash
python3 tests/r15_breakwater_f5_probe.py --evidence=/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r15/f5-breach --source=.
```

The driver accepts the inherited `--out=`, `--preset=server128_aa1000`, `--route=earned`
and `--tape=` arguments. It must run with pinned Godot 4.7.2 in a fresh isolated project
copy, headless with Dummy audio, `--no-records` and scratch XDG directories. The replay
tape must first be decompressed outside source. No existing driver needs modification.

Exact SHA-256 identities:

| item | SHA-256 |
|---|---|
| geometry | `231b7675ad7dde95f4cf9afbf5a2a25eadf400fc08d232d522a6a7c8952058d3` |
| actual R15 main | `7335c615a6cdaf4b94a5f006598735e50934cb5c5899a3fa4aa02b971c96687c` |
| actual R15 runner | `e06a545d610da0c3bb35f61d14d8f3f24d9ddf4e36e1b87743060a5c48157019` |
| probe driver | `12eed440074bcb2cd3421f3d571a33204b9f87fd2fc5a2073414acfbab797edd` |
| audit script | `bc110be2bcfcb2c08ec92f87d95741fef9e87ec559f1d2a56feedf0f1768708c` |
| input tape, decompressed | `d5d719f19d721e518c58998d67a144fe96a2581d3c8c291ae600a81cf7cbc93b` |
| input tape, gzip | `c7dbd15d74a65a1e5ac463367ae297cb118fd4a0c10a2e9578d99a1007d9dc4a` |
| controller trace, gzip | `2e2e72a087f0fefa146c0c4e9d52b4132addc7eb2773c4cea60b901f7eab8661` |
| open-loop trace, gzip | `42578e995910134164d54e7527c6c2d422adf171673514b2a2eba3a7442f567e` |
| frozen-resource baseline, gzip | `e6f4e7160160008209a3ca3ed489bf1cf94dc56e91c9308886272bea84aed348` |
| pinned Godot runtime | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
