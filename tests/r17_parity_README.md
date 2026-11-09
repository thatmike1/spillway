# R17 exact behavior parity

`tools/check-r17-parity.py` freezes source from delivered R16 `7261ba593` and R17
`7c82e0877`, copies only `tests/r17_parity.gd` into those external snapshots, and
replays every route named by the retained R16 delivery `VERIFICATION.json`.
It never changes the original source/import cache, profile or accepted tapes.

```sh
python3 tools/check-r17-parity.py --out /absolute/new/evidence-directory
python3 tests/r17_parity_audit.py /absolute/completed/evidence-directory
```

Use `--routes breakwater-basic` for a bounded first check. `--r16` and `--r17`
pin other commits explicitly. Run with the pinned Godot 4.7.2 editor installed
at the path declared in the checker. These are source-only, headless checks.
They do not accept a packaged build, native visuals or player enjoyment.

Each complete retained tape runs five ways from the authored spawn:

1. Actual R16 host, no pre-existing ghost, producing a clean reference recording.
2. Actual R16 host, discovering that same complete recording at startup.
3. R17 with `--look=old`, discovering the same reference recording.
4. R17 with its new look, discovering the same reference recording.
5. R17 with real `Input.parse_input_event` L dispatch during movement and pause,
   discovering the same reference recording.

Only map/preset/sensitivity and isolated recording-directory configuration are
set before the actual host's ready callback. No test writes body position,
velocity, view, checkpoints or finish. The existing tape driver's Early/Late
input order is retained. Fixed physics warmup arming follows the retained
native acceptance helper. The full input tape continues after its earned
finish; no finish is forced and no closed-loop bot is regenerated.

The checker compares every tick's actual position/velocity/view, motor state,
input edges and held actions, course state, style/stats and complete motion
identity exactly. It also compares against the retained acceptance trace.
A complete recording's columns, inputs, events, metadata, outcome and identity
are compared through the independent Python reader. Its frames, views, inputs,
flags, held actions and style total are independently aligned with the actual
host trace. Only `header.run_id`, `header.created_unix`, `header.created_utc`
and `seal.ended_unix` are excluded as the documented file-label/wall-clock
metadata. `seal.counts.bytes` is checked against the physical pre-seal offset
and reduced by the actual header length, so varying timestamp text length
cannot change the compared compressed gameplay payload byte count. Numerical gameplay values have no tolerance or exclusion.

Live ghost telemetry compares R16 with a discovered ghost against each R17
look and moving L toggles. It includes loaded/shown/visible state, interpolated
pose, body position/visibility and fade on every tape tick. Fractional-time,
pre-start and post-finish interpolation probes use the same golden bytes and
actual expected identity. The adapter asserts no ghost collision objects and
no gameplay writes from interpolation. A subsequent actual-input tour exercises
R, G, Escape pause/resume, F practice, F5, F2 and the real pause menu map button.
The audit additionally validates and compares every completed lifecycle recording
and checks numeric negative controls against the comparator.

The driver bounds each process and RAM import/profile scratch, checks the
15,000,000,000-byte HOME floor before and during runs, immediately compresses
raw trace output, and deletes only its own external snapshot/import copies.
Source hashes, commands, counts, speed maxima, route/tape paths and failures
remain under the output directory. Failed setup rounds are retained separately.

For native movies, `native-movie-routes.json` exposes every expanded tape,
map, preset, sensitivity, warmup, adapter and command arguments. Copy this
adapter into a separately imported source snapshot. Use its `--movie-ticks=768`
option for a short input-driven camera sequence, or omit it for the complete
route and control tour. The example uses Godot `--write-movie`; the caller owns
the private native display, renderer verification, AVI cap, encoding and free
space checks. The adapter does not drive Mike's desktop or open a browser.

For old-look native clips, use both `--variant=old` and `--look=old`; for an
input-driven comparison use `--variant=toggle`. Native captures must label their
actual backend from `evaluator/engine.json`, independently of this parity scope.

The completed proof under `look/evidence/r17-parity/verified` measures the pinned
7c82e0877 runtime. Parent title, required-asset and label-placement changes made
while it ran are outside that snapshot. `POSTFLIGHT.json` records this boundary.
