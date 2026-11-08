# R14 verifier closure review

Two P2 verifier gaps remain: source routes scan the supervisor's stdout rather than
Godot's error log, and the HUD visibility assertion accepts labels that draw no text.
Neither reduction demonstrates a defect in the actual candidate gameplay or a complete
tampered package passing. The candidate's recorded 204/204 result, hashes, ten complete
trace pairs and authoritative integer records checked out independently.

Reviewed on 8 November 2026 against prepared base
`1e325245d5f4dc6f092ccb8e24ae4540d00f9756` and candidate
`5484f10d1c1ef009fd22de76651431db7e1e065e`. The four requested verifier/test files
are byte-identical between the prepared checkout and candidate commit.

Evidence root:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-closure-review/`.
Authoritative observations are `authoritative/SUMMARY.json`,
`authoritative.stdout` and `authoritative/godot/engine.log`.

## Reproduced defects

### P2: an evaluator engine error still passes source-route acceptance

`tools/package-r14.py:413-436` captures `momentum-tape.py run` stdout as `text` and
checks `ERRORS.search(text)`. The tape supervisor redirects Godot stdout/stderr to
`source-run/evaluator/godot.log` (`tools/momentum-tape.py:382-383`). Its stdout is
the JSON returned by `summary(report)`, with no engine-log text or engine-error verdict
(`:1057-1073`, `:1106-1109`). Its evaluator does not scan that log either.

The reduction executes the actual `source_route` with only its subprocess boundary
controlled. The boundary produces three valid ordered finite rows, a completed clean
finish, all delivery/order/rate/cleanup verdicts true, neutral input and no integrity
flags. It writes `SCRIPT ERROR: controlled evaluator error` into the actual evaluator-log
path and returns ordinary JSON on supervisor stdout, matching the real supervisor's
output arrangement. `source_route` accepts it. It also accepts the same fixture with no
evaluator log. The valid fixture accepts; independent false rate, non-neutral input and
failed-end controls reject.

This is a reproduced helper-level false acceptance with a controlled supervisor, not
an engine fault induced in the game. Unlike the original hardening test's stdout error,
it challenges the file where the real child writes errors. Because source, package and
route recheck all use this helper, all three inherit this missing rejection. The packed
runtime has its own error scan and is not shown to share the bypass.

Close this by requiring and scanning the actual evaluator log, preferably also carrying
an explicit engine-error verdict through the supervisor report. Add a negative that
writes the error only in that file. The inspected candidate has no such error: an
independent scan of 67 candidate engine/supervisor logs found zero matching error markers.

### P2: visible-HUD checks accept labels with no visible characters

`tools/r14-pack-probe.gd:419-430` checks label existence, tree visibility, text,
modulation alpha, positive bounds and viewport containment. It does not check the
effective font alpha or `visible_characters`.

The actual `_check_hud_words` group was executed headless in a 1280 x 720 viewport,
with real Labels in the scene tree and all seven required fields supplied. A tiny
subclass overrides only the probe's automatic `_ready` startup; every tested verifier
method is inherited unchanged.

| Fixture | Entire HUD assertion group accepts |
| --- | --- |
| Visible labels, nonempty text | yes |
| Hidden labels | no |
| Modulation alpha zero | no |
| Off-screen labels | no |
| Font color alpha zero on every label | **yes** |
| `visible_characters = 0` on every label | **yes** |

The last case deterministically draws no glyphs even though `Label.text` contains the
correct identity. This is a reproduced production assertion gap, not evidence that the
candidate's HUD is hidden. No native frame or full packed-controls acceptance is claimed
for these fixtures. Require nonzero visible characters and effective text alpha, then
keep the final rendered readability review separate from node-property assertions.

## Original findings checked for closure

The existing hardening suite was run in focused groups, not as a full game rerun.
`hardening/SUMMARY.json` has 37/37 passing data, source and actual-GDScript controls.
`cancel/SUMMARY.json` has 6/6 passing wrapper cancellation checks.

| Original finding | Closure assessment and evidence |
| --- | --- |
| Missing/duplicate/disjoint/reversed ticks, truncated vectors, nonfinite values, empty traces | Original reductions reject in both Python comparators; GDScript valid control accepts and duplicate/truncated/nonfinite controls reject. Python checks exact integer ticks and typed game fields. Source mode binds coverage to expanded-tape duration. GDScript permits integral JSON numbers in references because its JSON reader represents them as floats; the Python check adds strict type enforcement. |
| Source delivery/order/rate verdicts | Delivery/order/cleanup/integrity negatives reject in the hardening suite. Separate rate, neutral and failed-end negatives reject here. Script errors on supervisor stdout reject, but the evaluator-log defect above prevents full closure. |
| Requested external reference ignored by package/recheck | The finite 1 m external mismatch raises `Rejected` inside `source_route`. Source mode, package and `recheck_routes` each call that helper before accepting routes, so its rejection reaches all three paths. This was checked at the helper plus caller-source level; no export or complete tampered-package challenge was run here. |
| Wrapper-only cancellation leaves engine alive | Both actual full-wrapper runs reached their disposable engine, received wrapper-only SIGINT/SIGTERM, exited 130 and left no engine child. The ownership runner has deadlines, process groups and cleanup. No new nested-supervisor race or display cancellation was independently exercised here. |
| Hidden identity/absent jump labels | The original hidden/absent reductions reject. Actual packed reports contain visibility and speed/jump/sync checks on captured frames. The two no-glyph states above still pass. |
| Exact integer records | Actual GDScript `_same_ticks` accepts integer scalar/array controls and rejects equivalent floats, strings, bool, null, wrong integers/arrays and dictionary shapes. All ten saved candidate profiles contain exact integer best/split/segment payloads matching their play reports, with successful fresh-process reload checks. Rounded seconds remain display summaries. |

## Actual candidate inspected

Candidate root:
`/home/thatmike1/foldrunner-build-2026-11-05/delivery/work/r14-candidate-5484f10d/`.

- `VERIFICATION.json` contains 204 true checks and is byte-identical to
  `evidence/check/summary.json`. The controls probe contains 291 checks.
- Both ZIPs pass complete member CRC reads. Their hashes match `SHA256SUMS`, their
  embedded manifests agree with the outer build, their runtime hashes match the pinned
  release-template hashes, and they carry the same pack.
- `verify_source_manifest` independently resolves the 486-file source tree, archive,
  manifest and helper hashes against Git. The archive SHA-256 is
  `447ab44d96127079d4edcca587e1d20548e2e3606fe875589b98c29937b597ea`.
- All ten source/packed trace pairs total **52,916 ticks**. Each covers precisely
  `0..duration-1`, has full finite position vectors and finite yaw, and agrees exactly on
  post position, yaw, checkpoint, elapsed, finished, finish kind and respawns. Every
  source report has successful delivery, order, rate and cleanup. All play/reload
  probe assertions are true, including 6,790 required-label visibility assertions.
- The final source evidence at outer `checkpoints/spillway/r14/source-final-5484f10d/`
  has five Overflow routes. I re-read their retained compressed traces and independently
  recomputed all five requested external-reference comparisons: each matches exactly,
  with no permitted game-difference ticks. The candidate's ten packaging routes do not
  themselves request external references; these are distinct evidence sets.

`authoritative/input-hashes.json` pins the verifier inputs and every consumed route
trace, evaluator report/log, play/reload report, saved profile and final external trace.
`authoritative/candidate-hashes.json` pins the top-level candidate files.
`candidate-log-scan.json` records the separate 67-log scan and its input hashes.

```text
b849ce5ebb177b95a7b1c1a7683869d87e515142048542b41b2579d85593c7b4  spillway-2026.11.08-r14-linux-x86_64-5484f10d.zip
7a39d10362966254e502c7a7254325e221f77234957f4cbfbf7b3b8c28b8f108  spillway-2026.11.08-r14-windows-x86_64-5484f10d.zip
39bd8deab191d46f7a128ba003108764a35acbecce4c61a825d5ea510f6f8c1c  BUILD.json
ee6844a7eecd409609f3910d5929d7a8c0f51fae98ab98f8a45ddbd4170dd447  VERIFICATION.json
4e6446043e8f17c07673cead946e06e4c1f9e3473e73604bdef81cc5cf0654a8  common pack
9fd11335a682699c0d07b7b39af4f20aea45f88bd3c332e841eda0ece546e6f1  tools/package-r14.py
0a29cb5561267d84604f2487bbbab9febe5553aefe4a652fe5c1cc3202cde924  tools/r14-pack-probe.gd
c60ea50e584c3ac26316e1e287273d8d088efb983cc5f83695b77825458fb980  tools/check-r14.sh
f4437af42eddabf6f7287f042ccad61c447c70602478c01cd441fba83d8b0da8  tests/test_r14_verifier_hardening.py
17792b004a6d87d81a8abcdcf6dc90abde7cf03d2ea823252ea4cde91ba494dd  tests/test_r14_verifier_closure_review.py
```

## Source-level concerns and coverage limits

No additional whole-package bypass was reproduced. The original review's coordinated
pack-plus-identity concern remains a source-level limitation: the checker authenticates
the source archive/helper hashes and a subset of identity, but does not independently
recompute the complete frozen runtime identity during a route-free recheck. It is not
a newly demonstrated release defect here.

HUD text is compared with live display-speed and observer values; this proves agreement
with those producers, not a second independent reconstruction of every speed/sync/gain
measurement. Trace equality covers the named fields above, not every velocity, pitch or
contact value. No OCR, occlusion/contrast proof, movement-feel verdict, CS binary match,
Windows execution or final whole-contract/report approval follows from this review.

No native display, export, desktop interaction or full native rerun occurred. Headless
Godot ran only the small verifier fixtures. Root's concurrent `/tmp/r14-negative-final-5484f10d`
and permanent takeover log were neither altered nor signalled, and their claims are not
counted as this review's evidence. Only this new document and the new dedicated Python
review file were written in Git; no production edits, commits or children were made.

## Reproduction and fixture limitations

From `projects/foldrunner`, the exact authoritative commands were:

```sh
python3 -B tests/test_r14_verifier_hardening.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-closure-review/hardening --only data source godot
python3 -B tests/test_r14_verifier_hardening.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-closure-review/cancel --only cancel
python3 -B tests/test_r14_verifier_closure_review.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-closure-review/authoritative --candidate /home/thatmike1/foldrunner-build-2026-11-05/delivery/work/r14-candidate-5484f10d --source-final /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-final-5484f10d
```

Their stdout/stderr were redirected to the corresponding `hardening.stdout`,
`cancel.stdout` and `authoritative.stdout` at the evidence root. Reproduction needs
fresh output directories. The new script is observational: exit 0 means its 41
observations completed, including false acceptances, not that the verifier is sound.

Early fixture attempts are retained separately. The first let the probe's normal
startup quit without a spec and used stale pre-retention `/tmp` paths. The next had a
zero-size headless viewport, so even the visible baseline rejected. The authoritative
run disables only automatic probe startup, explicitly sizes the viewport and resolves
the retained source evidence paths. Its visible baseline accepts, its intended hidden
controls reject, and its engine log has no script errors. These fixture mistakes are
not production findings. All generated traces are compressed; the entire new evidence
is below 5 MiB and contains no PNG or movie dumps.

## Root follow-through after review

Both reproduced gaps are repaired without changing gameplay. `source_route` now requires
and scans `evaluator/godot.log`, retaining its hash and error verdict. The HUD predicate
also checks nonzero visible characters, effective font-color alpha and positive font size.
The original observational script is retained unchanged; its exit0 means observations
completed, not acceptance. `test_r14_verifier_closure_gate.py` turns its12 source/HUD
observations into assertions. Root's existing expanded hardening suite passes45/45, and
the independent fixtures now give12/12 expected accept/reject outcomes. A fresh export
with these exact helpers is required before promotion. Evidence: outer
`checkpoints/spillway/r14/verifier-closure-fix/` and
`verifier-closure-fix-observations/ROOT-ASSERTIONS.json`.
