# R16 portable negative controls

`tests/test_r16_portable_negatives.py` adapts the actual-package controls in `test_r15_delivery.py` to the R16 schema and recording contract. It complements the component assertions in `test_r16_delivery.py`. It does not run source acceptance, promote a release, establish enjoyment, or execute Windows.

Run from this project with a new evidence directory:

```sh
python3 -I tests/test_r16_portable_negatives.py \
  --candidate /tmp/r16-candidate-a26d94c0 \
  --source-commit a26d94c0ccaa7fd764bbff6ed751892682b9fa05 \
  --evidence /home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/portable-negatives/run1 \
  --scratch /tmp
```

Use the directory actually holding both ZIPs, BUILD.json and SHA256SUMS. If root retains the package under `rejected/`, pass that exact directory with `--rejected-baseline`. Its negative-control results say nothing about release approval or the positive checker's findings. Optional `--base-manifest FILE` verifies an existing receipt; otherwise the harness writes `NEGATIVE-BASE.json` into evidence before consuming the package. Exit 0 means selected controls passed, 1 means a failure, and 2 means offline controls finished but package-dependent execution is pending. No candidate is polled or awaited.

The default source pin is `a26d94c0ccaa7fd764bbff6ed751892682b9fa05`. BUILD's full source commit, project tree, archive, manifest, file count and helper hashes resolve against Git. Current checker helpers must equal those committed helpers. A later test/document commit does not invalidate a build, and concurrent game edits are not inputs to a checker executing candidate ZIPs. `FROZEN-SOURCE.json` records the committed game/helper hashes and labels any current workspace differences as informational.

The candidate is read-only and rehashed at the end. All copies, disposable sparse-clone commits, imports, profiles and variant packs stay in a unique RAM directory outside Git. The harness reserves capacity before bulky steps, limits owned scratch to 1 GiB and requires another 1.2 GiB free. Evidence is limited to 8 MiB and retains hashes, summaries and compressed logs rather than frames, profiles or ZIPs. Every import, export and native run checks HOME's 15 GiB floor. It neither edits Weston nor touches the desktop. Actual native work uses the existing checked AMD owner and its checked display range 190–199; held displays are refused. Signals go only to the suite itself at acquisition boundaries or to processes/groups it created. The cancellation test sends SIGTERM to its own checker PID alone.

## Controls

- `ownership`: SIGINT/SIGTERM during engine and stub-display acquisition, handler restoration, busy-display refusal before spawning, an engine deadline including its descendant, and a forced storage-floor refusal. The acquisition children are Python sleepers, not Godot or a real display.
- `preflight`: a shared-object sparse clone at the candidate source pin. Its clean preflight must pass. Actual `package --startup-only --diagnostic` calls then reject dirty tracked and untracked files, wrong scene/profile/build/records/startup identities, absent persistence or recording, the wrong scene script, absent/misconfigured export preset and a committed override. Four CLI argument controls cover output inside Git, startup-only release, missing course proofs and diagnostic output in the delivery directory. No failing case may write package files.
- `provenance`: the real candidate manifest followed by individual identity, tree/archive/manifest/count/helper, runtime and startup lies. The helper's expected rejection text is retained.
- `baseline`: the unchanged candidate through actual `check_package`, with only its native stage stubbed. All 19 static checks must pass before package-content or runtime negatives are interpretable.
- `contents`: actual `package-r16.py check` subprocesses on rewritten ZIPs/manifests/checksums. Each must exit 1, skip native work and fail exactly its declared static set. Coverage includes extra loose files, a substituted editor, a manifest lying about that editor, executable mode, preserved R15 licences/manifests, preset labels, default map/records, source tree/helper/runtime provenance, embedded-only provenance, altered packs, checksums, truncation and an extra ZIP.
- `runtime`: import a Git archive matching the candidate's source archive hash, then export one variant at a time. Both ZIPs receive that pack plus consistent hashes, so static checks pass first. Each actual AMD checker run must fail exactly its declared top-level and probe sets and cleanly release its private display. Re-export byte equality is informational because the previous R15 pipeline demonstrated non-reproducible pack bytes.
- `cancel`: run the actual checker against the unchanged candidate. Once its native controls engine and probe are live, SIGTERM only that checker. Require exit 130, the cancellation message, all observed descendants gone, clean display/runtime release, absent X socket/lock and removed checker scratch. Only descendants of the owned checker are inspected.

## Runtime expectations declared before execution

These exact sets are hypotheses derived from the current helper and probe until exercised. Execution retains both expected and actual results, including failed development expectations.

| Variant | Exact failed top-level checks | Exact failed probe checks / audit reason |
|---|---|---|
| Hide the style score Label while retaining its actual text and layout | `controls: probe ran and found no failures` | `startup: full style score glyphs are drawn` |
| Change R16 SAVE_PATH to `user://spillway_r16_negative.cfg` | `controls: probe ran and found no failures` | `records namespace`; `registry save_path equals the frozen source` |
| Disable the player scene's `record_runs` flag | `controls: only explicitly observed sealed attempts, earlier profiles unchanged` | no probe failures; audit reports `probe observed no recorded attempts` |
| Add 0.25 m only to the recorder's stored position column | `controls: only explicitly observed sealed attempts, earlier profiles unchanged` | no probe failures; audit reports `p differs from actual motor observation at tick 0` |
| Change only the manifest's frozen Breakwater/F2 record key | `controls: probe ran and found no failures` | `record key equals the frozen source key`; `normal course hides experimental state and restores its record key` |

The script declares exact static refusal names directly beside every content variant. Runtime `*-EXPECTED.json` files are written before each run. Hashes of every executed variant ZIP/BUILD/SUMS, variant pack hashes, helper/suite hashes, the unchanged base receipt and cleanup results are retained. A refusal caused by an unrelated positive-baseline defect remains a failed negative control.

## Execution status

Offline execution passed on 9 November 2026. The initial full invocation, `run1/summary.json`, passed 31 controls and returned exit 2 because no complete candidate existed at its single availability check. Its explicit pending groups are `provenance`, `baseline`, `contents`, `runtime` and `cancel`. The candidate was never polled or awaited, and no candidate bytes were pinned or consumed. There is no package-unchanged, static-baseline, native-renderer or exported-cancellation verdict yet.

The final harness was then exercised with `--only ownership preflight` in `run2-offline/summary.json`: **32 passed, 0 failed, exit 0**. That run deliberately does not check candidate availability. It includes nine ownership controls, twenty clean/negative preflight controls and three cleanup/hash checks. The owned scratch tree was removed, no process named it afterward, and the executing helper hashes stayed unchanged. Neither offline run started an actual display, import, export or native game. The preflight baseline executes only the pinned editor's `--version`.

Final executed suite SHA-256: `1337df1c591e8058720e73c132a66f5247afb4c87579419b83070ec90a81efb3`. The helper hashes and full expected/observed preflight refusals are in `run2-offline/summary.json`; per-command logs sit beside it. The package tool's executed hash is `ea90d32ed9d9abf3fdd090fb63095a1c28be3e81c57771119e078df20b5cb00d`. The two retained run directories together occupied 37,601 bytes after execution, below the shared 8 MiB evidence cap. No executed development expectation failed.

Root should run the complete command above against the completed immutable output, or its explicit `rejected/` directory with the required label. Runtime refusal sets in this document remain source-derived hypotheses until that happens. Root owns source suites and final release acceptance.

The first native candidate was subsequently rejected by root before course play. Those old helper bytes are superseded. The repaired candidate is pinned to67e608a0; pass `--source-commit 67e608a0` explicitly when executing this harness against it. Root separately rechecked42 verifier assertions with28 delivery and79 recording-integrity controls on that commit. Package-dependent negative expectations remain unexecuted until the actual final-byte run.
