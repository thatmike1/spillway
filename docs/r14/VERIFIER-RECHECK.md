# R14 verifier recheck

Both specific P2 findings are closed at the code and fixture level against
`65d205be85c884dc13295725a3eb26c3f46d9ca7`. The independent asserting wrapper passes
12/12, and additional focused sibling checks pass 99/99. No blocking regression was
observed within this scope. Fresh-pack acceptance remains root's work.

Reviewed 8 November 2026. Read `VERIFIER-CLOSURE-REVIEW.md`, including its root
follow-through, and inspected the repair commit and shared callers. Evidence is outside
Git at:
`/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-recheck/`.
The evidence contains 288 files totaling 1,008,234 bytes, below the 2 MiB limit.

## Evaluator-log rejection

`tools/momentum-tape.py:382` redirects both engine streams to
`evaluator/godot.log`. `tools/package-r14.py:433-444` requires that exact path to
be a file, hashes its bytes, decodes it with replacement for invalid UTF-8, and scans
it with the existing engine-error matcher. Missing logs and matching errors reject
even when supervisor stdout is ordinary JSON, exit status is zero, and trace/report
completion checks otherwise pass. Successful results retain `engine_log_present`,
`engine_log_sha256` and `engine_log_error`.

The original independent source fixtures accept their valid empty-log control and
reject evaluator-only script errors, a missing log, false rate, non-neutral input and
failed completion. The sibling reduction adds ten cases through each of the actual
`source_route`, `source_mode` and `recheck_routes` functions:

- A nonempty clean log containing an invalid UTF-8 byte accepts. The helper's retained
  hash matches the exact original bytes, and its presence/error verdicts are correct.
- Evaluator-only `SCRIPT ERROR:`, `ERROR:`, `Parse Error:` and `Failed to load` reject.
- An absent log, a directory at the log path, and a log placed one directory above the
  evaluator all reject.
- Supervisor-only errors and a nonzero supervisor exit still reject with a clean
  evaluator log.

These exercise the real acceptance code with a controlled tape-supervisor boundary.
For source mode, failures produce a false overall result and route errors in its summary;
route recheck propagates `Rejected`. The archive/import/identity boundaries in the
recheck fixture are controlled, so this is not a real import or replay.

Caller inspection and AST assertions confirm one shared `source_route` call in each of
`package` at line 798, `source_mode` at line 1238 and `recheck_routes` at line 1334.
The package call is inspected, not executed here. No export was needed to establish
that these callers share the repaired rejection.

## Actual Label checks

The independent fixture executes the production `_check_hud_words` and `_label_drawn`
methods in headless Godot with actual in-tree Labels and a 1280 x 720 viewport. Its shim
overrides only automatic `_ready` startup. Visible Labels accept; hidden, zero-modulate,
off-screen, font-alpha-zero and zero-visible-character fixtures reject.

`tools/r14-pack-probe.gd:419-431` checks nonempty trimmed text, tree visibility,
`visible_characters != 0`, accumulated ancestor modulation, label self-modulation,
resolved theme font-color alpha, positive font size and on-screen positive bounds.

The sibling fixture checks all seven required fields individually. For each field,
font alpha zero and zero visible characters reject the entire HUD assertion group
while the other six Labels remain valid. Self-modulation zero, ancestor modulation
zero, inherited theme font alpha zero and whitespace text also reject. Fully visible
Labels, positive visible-character counts and half-alpha text accept. All 63 HUD
observations have their expected outcomes; the Godot process exits zero without any
matching engine errors. Both fixtures use the actual pinned editor binary.

Positive visible-character count is a property check, not proof that the complete
identity is readable: the one-character control accepts. These checks also do not
establish rendered contrast, clipping, occlusion or OCR correctness.

## Evidence and reproduction

Run from the prepared checkout's `projects/foldrunner` directory. The first command
invokes the unchanged observational script through its asserting wrapper. Both commands
completed with exit 0; reproduction requires fresh output directories.

```sh
python3 -B tests/test_r14_verifier_closure_gate.py --out /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-recheck/closure-gate --candidate /home/thatmike1/foldrunner-build-2026-11-05/delivery/work/r14-candidate-5484f10d --source-final /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/source-final-5484f10d
python3 -B /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/verifier-recheck/focused.py
```

Combined stdout/stderr are `closure-gate.log` and `focused.log`. Assertions are in
`closure-gate/CLOSURE-GATES.json` and `FOCUSED-GATES.json`. The latter's 99 checks
comprise 30 source outcomes, one log-hash/verdict check, three shared-caller assertions,
one error-free Godot execution, one complete-HUD-observation count and 63 HUD outcomes.
`PROVENANCE.json` records input hashes and results; `EVIDENCE-SHA256.json` hashes the
other evidence files. The original observational script's exit 0 alone establishes
neither expected rejection nor verifier soundness.

One initial sibling fixture stopped because its synthetic source archive omitted the
probe copied by successful `recheck_routes`. `fixture-attempt.log` retains that setup
failure. The corrected fixture supplies the actual probe bytes in its synthetic archive
and completes all 99 assertions. This was a fixture error, not a production regression.

```text
cb83afd072f7543697905a3452f55fd7bac49f0729f4c0c07707c37f8c36c53b  tools/package-r14.py
5800af65efb5df5b91d84e8e4b7eaea2f2ee1f7a15795e13792815d6adfea6f1  tools/r14-pack-probe.gd
17792b004a6d87d81a8abcdcf6dc90abde7cf03d2ea823252ea4cde91ba494dd  tests/test_r14_verifier_closure_review.py
79cd8f73b7c9aebbffcb62b9ce451cddfd9700e605e2e796dfcc0f3cc73df416  tests/test_r14_verifier_closure_gate.py
eb009b7b66d9f77aa6777ad21b3bcf1c298f439b6e79aa80696eacfe561509ec  focused.py
8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e  Godot editor
```

## Fresh-pack acceptance is still separate

Root's retained `verifier-closure-fix/SUMMARY.json` contains 45/45 passing hardening
checks. That suite was read, not rerun here. This recheck independently reran the
12 asserting fixtures and added the focused checks above.

The wrapper also reads the old `r14-candidate-5484f10d` package and retained
`source-final-5484f10d` evidence. Its recorded 204/204 result and static package/route
observations concern that older build. They do not establish execution of the repaired
helpers in a new export. The repair leaves `scripts`, `scenes`, `modules` and
`project.godot` unchanged relative to that candidate, as checked with
`git diff --name-only 5484f10d..65d205be -- scripts scenes modules project.godot`.

Root must finish the fresh helper-pinned ten-route candidate at
`/tmp/r14-candidate-65d205be` and source wrapper at `/tmp/r14-source-65d205be`, then
assess their permanent `delivery-takeover/candidate-65d205be.log` and
`delivery-takeover/source-65d205be.log` evidence. This review neither polled those jobs
nor read, altered or signalled their active evidence or processes.

Only this new document was written in Git. No production edits, commits, children,
exports or native display runs were made. This is not a whole-game feel verdict,
Windows execution proof, broad verifier audit or final promotion approval.
