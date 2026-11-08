# R14 record and display review

Root follow-through, 8 November: both P3 findings below are fixed after this frozen review.
Runtime allocation now records ownership under deferred signals, as process launch does.
Record version/rate types are checked before comparison; oversized exact ticks are also
rejected consistently with the ranking helper. The unchanged independent reproductions
pass after the fix: seven Python methods and 46 record assertions, with no script errors.
The expanded root precision suite passes 66/66, and the existing native offline set
passes 11/11. Evidence is under `record-display-review/root-*-after*`; the original red
evidence and findings below remain intact. Neither fix changes movement or record keys.

Reviewed prepared base `2a564e04b8709b5de6706dd66d1b7b665ae74a76`, 8 November 2026.
No normal-play record regression or P0–P2 finding reproduced. The process ownership fix
survives cancellation at both launches. Two P3 findings remain: an empty runtime directory
can escape cancellation cleanup, and a malformed record marker emits a script error.
Neither finding changes movement or the elapsed clock. This is not final release acceptance.

Evidence root: `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r14/record-display-review/`.
`REVIEW.json` records counts, hashes and the unchanged tracked-file check. New review files
are intentionally uncommitted. Production, existing tests and R12/R13 files are unchanged.

## P3: cancellation can leave an empty runtime directory while reporting clean

Location: `tools/r14_native_display.py:585`, with cleanup at lines 683–688 and 704–705.

`tempfile.mkdtemp()` creates its directory before returning. SIGTERM after that allocation,
before assignment to `self._runtime`, raises `Cancelled`. Cleanup sees `_runtime is None`,
reports `clean: true`, and cannot remove or record the directory it just created.

The new Python test calls production `_start_weston()` through a subclass that bypasses
GPU/storage startup. A wrapper around the real `mkdtemp` sends SIGTERM immediately after
allocation. It changes no production function or process behavior. No compositor or X server
is started; the test fails before either launch. The final run left `/tmp/r14nd-azfyozmh`
while `native-display.json` reported clean with no cleanup problems. The test's `finally`
removed it. The earlier trial reproduced the same result with another unique directory.

Reproduction from `projects/foldrunner`, using a fresh evidence directory:

```sh
python3 -I tests/r14_record_display_review_native.py --evidence /tmp/r14-review-native-evidence
```

Observed exit **1**, seven test methods, six pass and one expected regression failure.
Evidence: `native-final.log`, `native-final/runtime-allocation-observation.json` and
`native-final/runtime-allocation-cancel/native-display.json`.

Impact is bounded to an empty private directory and an inaccurate cleanup result. This is
not a child-process, X socket or GPU leak. It is a deterministic cancellation-window
reproduction, not a measured frequency during ordinary use. Apply the same deferred-signal
ownership treatment used by `_spawn` to runtime allocation if closing this gap.

## P3: a malformed record version raises a script error instead of a quiet rejection

Location: `scripts/r14_main.gd:882`.

Start with a legitimate saved section and change only `time_ticks_version` to the string
`"bad"`. `_load_tick_records` compares that String directly with an int, and Godot reports
`Invalid operands 'String' and 'int' in operator '!='.` It occurs at all three tested rates.
The loader leaves records empty and does not fall back to the float summaries. The process
continues and exits 0. There is no normal-play way to produce this marker with `_save`.

Reproduce with the new GDScript review below. `records.log` contains three script errors;
`records/summary.json` contains 46 successful state assertions. The assertion count alone
therefore must not be described as an error-free run. Validate the marker and rate types
before comparing them if graceful malformed-file refusal is required.

Additional corrupted-file observation, not a movement blocker: a clean/open payload of
`9007199254740992` ticks, with matching final split, loads as positive seconds even though
`_record_ticks` returns -1 for that same value. `records/oversized-observation.json` records
`loaded_seconds=70368744177664.0`, `rank_ticks=-1`, and a subsequent valid candidate ranking
as faster. This exceeds the helper's supported exact range and cannot arise in practical
play. Rejecting it on load would make validation consistent; it is optional hardening.

## Record behavior checked

The new `tests/r14_record_display_review.gd` uses the real main and fixture level. It seeds
tick-derived elapsed/split values and calls production `_finish`, `_save` and `_load_records`.
Those are serialization/ranking fixtures, not played routes. At 64, 120 and 128 Hz it checks:

- a first clean finish, complete splits and independent best segments survive reload;
- an equal finish changes neither the profile hash nor the new-best message;
- one tick faster replaces the clean/open best and final split;
- a slower full run can improve one segment without replacing the best run's splits;
- a faster open finish preserves the clean run and its segments;
- all three presets share one profile while retaining distinct keys and their own values;
- exact fields override deliberately conflicting float summaries;
- wrong types, short arrays, reversed splits and bad versions never load float summaries;
- marker-free legacy summaries recover to the expected ticks;
- the profile remains format 1 and serializes integer tick fields.

Separately reran the existing precision suite: **60/60, exit 0, no script errors**. That
includes six fresh processes playing W-only fixture runs, exact reloads and no false new
best at each rate. Reran the existing loop's `persist` group: **21/21, exit 0, no script
errors**, including byte/hash protection for isolated R12/R13 profile sentinels. Their
reports and process logs are under `existing-precision/` and `existing-persistence/`.

## Display ownership and refusal checked

The new Python suite starts only disposable non-rendering Python children using production
`_spawn` and cleanup. Four launch subcases pass: SIGINT/SIGTERM after Popen returns a real
child, at both the first and second launch. The caller never assigns the cancelled return
value; `_spawn` has already registered its owner/pid, and every child is dead after cleanup.
Also pass: repeated signals during cleanup, original body-exception propagation, a dead
leader with a surviving child in another process group of the same owned session, foreign
lock/socket preservation, and a below-floor refusal that launches nothing. Fake X files
live in an isolated temporary directory, never the real X socket directory.

The existing native offline suite also passes: **11 tests executed, 12 live/game tests
explicitly skipped, exit 0**. It checks real busy abstract sockets within 190–199, flock
separation, software device-log refusal and environment cleanup, package/binary/manifest tampering,
nonempty evidence refusal and the original launch cancellation case. The pinned `.MTREE`
check passed; changed manifests were refused. Evidence: `existing-native-offline.log`.

No new native Weston/Xwayland session was attempted. Desktop `:0` answered `xdpyinfo`
before and after both new Python runs. The recorded free space after the final run was
16,283,660,288 bytes, above 15 GiB. No desktop settings, X0 path, X0_ socket or repaired
symlink were changed. All test-owned children, sockets, runtime directories and profiles
were cleaned, including the deliberately reproduced directory leak. Source/import/profile
scratch stayed below 40 MiB on `/tmp` and was removed. Final cleanup details are in
`cleanup.json`.

## Reproduction and identities

Use an isolated source copy so imports and profiles stay outside the checkout. The existing
`tests/test_r14_native_display.py prepare` command creates/imports an archived source at the
named commit. Copy the new review `.gd` and `.gd.uid` into that copy's `tests/`, then run:

```sh
~/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --audio-driver Dummy --fixed-fps 128 --path /tmp/r14-review-source \
  --script res://tests/r14_record_display_review.gd -- --out=/tmp/r14-review-record-evidence
```

For the existing suites, use the same engine flags and isolated source with respectively
`res://tests/test_r14_record_precision.gd` and
`res://tests/test_r14_loop.gd -- --only=persist --out=FRESH_OUTPUT_DIRECTORY`.
The native offline command is `python3 -I tests/test_r14_native_display.py`, without live
opt-in environment variables. These commands and the Python reproduction above were run
with the equivalent outer evidence paths and `/tmp/r14-record-display-review-source`.

SHA-256 identities:

| file | sha256 |
|---|---|
| `scripts/r14_main.gd` | `bc57db370d5614f2c1c9c824cb876e8de4cb5f629160f71c0618713bb7a4342e` |
| `tools/r14_native_display.py` | `494872c0c6c52b870340e1c87946198e87cce9bc49afce95535e0e08f1c44b87` |
| Godot 4.7.2 official `ed1daf0bf` | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |
| `tests/r14_record_display_review.gd` | `fe0906ec00fbae51d2b676feff9ebc16354a411176a44c2f1e15b32bf43698cd` |
| `tests/r14_record_display_review_native.py` | `17a25774732dbc16da23154e0a3f9185c33021a1f9ad0b6a722c47ff7a1fbd6d` |

Initial trial logs are retained and superseded by the named final runs. Trial 1 incorrectly
expected `ConfigFile.set_value(..., null)` to retain a marker; that API deletes the key,
legitimately taking the legacy path. Its Python foreign-socket test also exceeded Unix
socket path length. Both test setup errors were corrected. A later UID-import command
accidentally retained `--script` without `--out`, exited 2 and logged shutdown leaks; the
correct editor-only import subsequently exited 0. None is a production regression.

## Exclusions

No full native tape, new GL client, movie, desktop gameplay, final packed checker or release
archive was run here. Earlier AMD/tape and quit-investigation outcomes are prior workers'
evidence, not fresh reviewer measurements. No native Windows execution, CS binary fidelity,
physical latency, performance, enjoyment or R14 completion claim. Final release/checker
review remains separate.
