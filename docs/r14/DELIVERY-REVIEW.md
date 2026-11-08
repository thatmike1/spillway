# Independent review of the R14 delivery verifier

Prepared base: `da0a43894ad7a6badc3307f256f49f73e0b04085`, 8 November 2026.

The reductions reproduce malformed-trace acceptance, source-route failures that do not fail source mode, and a source-wrapper cancellation leak. They also identify narrower gaps in HUD verification and external-reference enforcement. These are verifier findings. No full tampered package was exported or accepted in this review, and no final release approval follows.

Evidence root:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/delivery-current-review/`

Authoritative run: `final/review-summary.json`, `final.stdout` and `final/godot/engine.log`. The new `tests/test_r14_delivery_review.py` reproduces the reductions with a new `--evidence` directory. Its exit 0 means the observational run completed; the `accepted` results below describe verifier behavior, including false acceptance. It is not a green delivery regression suite.

## Ranked findings

### 1. P2: the exact trace comparators accept missing ticks and malformed numbers

Sources: `tools/package-r14.py:409` (`shipped_trace_match`), `:430` (`compare_traces`), `tools/r14-pack-probe.gd:1043` (`_compare_reference`).

Against a valid three-row reference at ticks 0, 1, 2:

| Deliberately bad candidate | Executor Python comparison | Shipped Python comparison | Actual GDScript comparison |
| --- | --- | --- | --- |
| Three copies of tick 0, omitting ticks 1 and 2 | accepts | accepts | both assertions pass |
| Three rows with disjoint ticks 100, 101, 102 | accepts | rejects | not run |
| Reverse chronological order | accepts | accepts | not run |
| Position arrays with only the matching x coordinate | accepts | accepts | not run |
| NaN in all position components and yaw | accepts | accepts | not run |

Both Python comparisons reject an ordinary finite 1 m position error, so the successful negatives are not a disconnected or always-passing fixture. `compare_traces([], [])` also accepts.

The Python implementations compare lengths and values without validating ordered, unique, contiguous integer tick identities. `compare_traces` silently skips unmatched ticks. Both use `zip` without a three-component shape check. Python's JSON reader accepts NaN; `max(0.0, nan)` leaves the accumulated worst error at zero. GDScript's comparator similarly counts repeated lookups, not distinct compared ticks. Its standalone headless execution actually returned two passing assertions for the repeated-tick reduction.

**Proven:** false acceptance at the production comparison functions, including the real GDScript function. **Limit:** the current tape recorder generates increasing ticks, and `_judge_run` separately checks clean finish, stages and motor steps. Feeding a repeated initial row to the whole judge would fail those checks. This review does not show an entire release accepting a broken movement run. It shows that the claimed independent exact-trace check does not establish trace completeness or numeric validity.

Require the exact tick sequence on both sides, nonempty expected duration, exact vector lengths, finite numeric fields, required game fields and strict types before comparing. Reject JSON nonfinite constants. Add these controls to the delivery negatives rather than relying on the producer to keep the verifier's preconditions true.

### 2. P2: source mode accepts failed input delivery and script errors

Sources: `tools/package-r14.py:388`, `:400`, `:402`, `:1178`; upstream child exit policy in `tools/momentum-tape.py:1068`.

`source_route` records `report.delivery.ok` but omits it from the rejection predicate. It also does not search the returned child log with `ERRORS`. The tape wrapper's exit policy is not a guarantee against these conditions: its `execution_exit` returns 0 for ordinary completed evaluation even when delivery validation fails.

Two bounded controls supplied a child exit of 0 and otherwise valid clean, ordered, correct-rate rows, then independently changed:

- `report.delivery.ok` to false;
- child output to `SCRIPT ERROR: controlled challenge`.

In each case the actual `source_route` returned normally. The actual `source_mode` also printed `PASS route ...` and returned true. Only its identity read and subprocess boundary were controlled; the route parsing, trace/report reading and acceptance logic executed unchanged.

**Proven:** source-mode false acceptance of the controlled evaluator result. **Limit:** no real tape input failure or game script error was induced in the current game. The child boundary is a test double, not source-run evidence. Packed playback has its own error scan and therefore need not accept the same error.

Require delivery success, error-free child output and complete expected trace coverage. Consider requiring the evaluator's cleanup/integrity results too. Do not use child exit 0 as a substitute for its report verdicts.

### 3. P2: the source shell runner leaves its engine child after wrapper-only SIGTERM

Sources: `tools/check-r14.sh:66`, especially child launch at `:70`; the full wrapper installs no ownership/cancellation trap.

The reduction extracts the actual `run_clean` function unchanged, runs it in an owned new session and substitutes one disposable sleeper for Godot. SIGTERM sent only to the wrapper terminates Bash with -15 while the child is still alive. The test then kills its own session and verifies the sleeper is gone. Final-run sleeper PID was 1305890; a later `/proc` check found it absent.

**Proven:** a real child leak for this wrapper-only cancellation path. **Limit:** this is the source wrapper, not the Python `run_engine` acquisition path or AMD display helper. Cancellation that explicitly signals the whole process group can avoid this leak; the wrapper itself provides no such guarantee. No root or existing test process was signalled.

Give source-suite children explicit ownership, a deadline and INT/TERM/EXIT cleanup, including supervisor descendants. Reuse the tested Python ownership runner if practical.

### 4. P2: packed HUD assertions accept a hidden identity and absent jump/sync labels

Sources: `tools/r14-pack-probe.gd:235`, `:397`, `:409`, `:650`; source-side semantic HUD coverage in `tests/test_r14_loop.gd:430`.

A standalone headless reduction loads the actual HUD script and its actual `identity_text` method, supplies a minimal game fixture, hides the identity Label and leaves all jump/sync labels absent. The actual `_check_hud_words` produces four passing assertions. It reads strings without requiring label visibility or geometry. `_state.identity_text` uses the same unchecked string accessor. The packed probe never asserts jump/sync text or their agreement with live hop statistics. The separate source loop suite does check stats and several HUD strings, so those semantics are not wholly untested.

**Proven:** the packed HUD assertion group accepts this reduced bad UI state. **Limit:** no actual source HUD defect, rendered screenshot failure or complete packed-controls false acceptance is claimed. The fixture does not run the game scene or the rest of controls.

Check required labels' visibility, alpha, nonempty on-screen bounds and contents at hop/landing samples. Compare displayed speed, jump gain and sync/counts with independently observed motion/stat values. Human review of final selected frames still matters; string presence and global image luminance spread do not prove readable HUD pixels.

### 5. P2: package/recheck routes do not enforce a supplied external-reference verdict

Sources: `tools/package-r14.py:404`, `:747`, `:1135`, `:1183`, `:1269`.

A controlled clean source run compared against an external reference with a finite 1 m error returns normally with `external_reference.ok=false`. This is intentional at the helper level only if every caller enforces the returned verdict. `source_mode` does enforce it. `package` and `recheck_routes` collect the returned routes without doing so; packed checks then compare the packed run against the fresh source golden, rather than the requested external reference. `check_package` does not add an external-reference check to its acceptance list.

**Proven:** the helper returns the failing comparison, and source inspection shows the package/recheck callers do not consume it. **Limit:** no complete package false acceptance was run. The existing `--root-routes` source-mode results are not invalidated by this finding, because that caller checks the verdict.

Reject a requested external mismatch before packaging or rechecking proceeds, and retain its verdict as an explicit check in the final verification summary. Otherwise a newly generated golden can agree perfectly with a changed source while the requested independent reference disagrees.

## Checks that held, and limits of the challenge

The strict `_same_ticks` helper was executed in the actual Godot probe. It accepted exact integers and integer arrays, and rejected equivalent floats, numeric strings, null, mismatched integers, float arrays and a dictionary. No malformed authoritative integer-payload acceptance was reproduced. This is narrower than testing every ConfigFile load path or record ranking transition.

The packed rate checks inspect early/late delta, engine rate, mismatch count and one motor-step increment per tick. Controls also check settled deltas after preset switches. I found no demonstrated rate bypass in these reductions. The AMD helper's render-node/GPU checks were read as context, not executed or independently certified.

The frozen source identity is a transport-equivalence reference. The independent Source-law gates supply the separate physics evidence. A recheck without routes does not recompute the full `BUILD.identity` from Git; `verify_source_manifest` validates the Git archive/helper hashes and a small identity subset, while runtime comparisons use the supplied identity. Coordinated pack-plus-identity tampering remains a source-level concern, not a demonstrated whole-package acceptance in this review. Do not describe its partial manifest validation as an independent replay of every frozen identity value.

The supplied 43 ownership/gate/integrity/preflight results were not rerun or treated as substitutes for these controls. No historical full routes were replayed. No new exports, native displays, GPU sessions, frame dumps, Windows execution, CS binary comparison or movement-feel evaluation occurred.

Root's `/tmp/spillway-r14-current-diagnostic` was inspected once for an already completed top-level `VERIFICATION.json`; none existed at that check. It was excluded. No subsequent status checks, waiting, signals or changes touched root's run, and it is not release evidence here.

## Evidence failures and cleanup

The first HUD fixture omitted the game's `rate_ok` property, causing a fixture script error and a failed HUD assertion. That is not a production defect. The corrected authoritative run has an error-free headless probe log. Its earlier failure log is retained as `harness-first-hud-error.log`.

All test traces are gzipped. Test profiles live solely under the evidence root. No native/export run occurred, so no native storage-floor exception was needed; `/home` was observed above 15 GiB. No frames or large source/runtime copies were produced. All owned sleeper sessions were explicitly killed and the last child was later confirmed absent. No desktop display was opened or reconfigured.

Only two new repository files belong to this review: this document and `tests/test_r14_delivery_review.py`. They are deliberately uncommitted for root. Production files and existing tests match the prepared base.

## Source hashes

SHA-256, verified against both disk and `git show HEAD:./PATH` for the four reviewed files:

```text
846f956ec3c60753b497ad059c7d2ada1484b7d20451589b97a7209eefb5d788  tools/package-r14.py
116ad89442876c1e0f307d393b38428cf3853ecb4275e9fbe8296c588fb20ceb  tools/r14-pack-probe.gd
ca23bff20879b290da7bc2a3fe826e8e812c3f715126d359e96f75be111b21f8  tools/check-r14.sh
6c9d02a75ddef83dd62a17c8749878f059e93a7450847872a90e0abb8ee83ba8  docs/r14/DELIVERY.md
706af55143b1b779d442c6128980d1c82309b1d6908b53371cf8b006780ff82f  tests/test_r14_delivery_review.py
```

Reproduction from `projects/foldrunner`, with a new directory outside Git:

```sh
python3 tests/test_r14_delivery_review.py --evidence NEW_DIR
```

## Root follow-through

Root preserved this review and its observational script unchanged, then added
`tests/test_r14_verifier_hardening.py` as an asserting regression suite. Trace comparisons
now require complete ordered ticks, finite full coordinates/view and required typed game
fields. Source routes require delivery/order/rate/cleanup/neutral success, no integrity
flags and no engine errors. Any requested external mismatch rejects at `source_route`,
so package and recheck callers cannot ignore it. The source wrapper launches bounded
Python process owners and forwards wrapper-only INT/TERM to them. Tests exercise the
actual full wrapper with disposable sleeper engines. Packed HUD checks now require
visible on-screen labels and compare the rendered frame's speed/jump/sync text with live
measured-speed and observer values. Final packed checks still have to run after these
repairs; the reductions alone do not certify a release.

The first added HUD reduction had a placeholder-substitution parse error in its test
script. It is retained in `root-hardening-complete/godot/engine.log`; the corrected
`root-hardening-godot-fixed` set runs without script errors. The independent original
review findings are not rewritten as if the old verifier had passed.
