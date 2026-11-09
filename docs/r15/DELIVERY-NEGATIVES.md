# R15 delivery negatives

`tests/test_r15_delivery.py` challenges the R15 package tool with deliberate broken checkouts, ZIPs and game packs. Every case must reach its own named refusal. An unrelated failure, a timeout or an invalid baseline does not count. These are tool challenges on one candidate. They are not release acceptance, a feel claim or Windows execution.

```
python3 -I tests/test_r15_delivery.py --candidate DIR --base-manifest NEGATIVE-BASE.json \
    --evidence NEW_DIR --scratch RAM_DIR [--only ownership provenance preflight baseline contents runtime cancel]
```

The candidate directory is read only. Before anything runs, its bytes are checked against the root's `NEGATIVE-BASE.json` and its own SHA256SUMS. Its source commit must equal this checkout's HEAD, and the executing helpers must equal the candidate's `helpers_sha256`. Bulky copies live in a private directory under `--scratch`, which is held below 1 GiB with at least 1.2 GiB left free on that disk, and removed at the end. Unchanged ZIPs are hard links to the candidate. `--evidence` keeps summaries, gzipped logs and a hash list of every checker file. Frames, profiles, packs and ZIPs are hashed and dropped.

## Groups

- **ownership** (in process, no engine): cancellation at the engine and Xvfb acquisition boundary for SIGINT and SIGTERM, restored signal handlers, refusal of a held display, a deadline that kills the owned group including a grandchild, and the storage floor. Ported from the R14 suite.
- **provenance** (git only): the candidate's real BUILD.json resolves through `verify_source_manifest`. Eighteen single-field lies are refused with the expected message: tree, archive, manifest, file count, helper hash, helpers flag, records file, default map/preset, main scene, profile folder, export preset, build, short commit, editor runtime member, startup-line key and build, and frozen start map.
- **preflight**: a sparse clone using `--shared` alternates, so no object store is copied. The unmutated clone passes the clone's own `preflight()` (editor version only, no export). Each case then breaks one thing and runs the clone's `package --startup-only --diagnostic`, which must exit 1 with the expected message and write nothing. Cases: a dirty tracked edit, an untracked file, the default scene, the profile name, a custom user dir, BUILD_ID, SAVE_PATH, `persist`, the scene's main script, the startup line, a renamed `R15 Pack`, a preset that ships tests, and a committed override.cfg. Four argument refusals in `package()` run on the clean clone: output inside the checkout, a startup-only release, a release missing F2 courses, and a diagnostic written to `delivery/spillway-r15`.
- **baseline**: the unmodified candidate through the actual `check_package`. Only `check_runs` is stubbed, because native positive runs are the root's job. All 19 static checks must pass, and their names become the reference list.
- **contents**: each case builds a package with one break and runs the real `tools/package-r15.py check` on it. Checksums and the embedded and external manifests are rewritten wherever the break has to reach a later check. The failed top-level checks must equal the declared set exactly, and native runs must be skipped.
- **runtime**: `git archive` of the candidate's commit must equal its `source_archive_sha256`. The suite imports it once with the pinned editor and exports variant packs. Each variant replaces the pack in both ZIPs with consistent manifests and checksums, so all static checks pass. The real checker then runs it on the private AMD/X11 backend. The named refusal must appear, every other probe failure must be a declared direct consequence, and the display must be released.
- **cancel**: the real checker on the unmodified candidate with `--native-backend amd`. When the controls engine runs on its private display and the probe has printed, SIGTERM goes to the checker process only. It must exit 130. Every descendant seen during the run must be gone, including the engine, weston and Xwayland. The X socket and lock and the weston runtime directory must be gone, NativeDisplay must record a clean release, and the checker's scratch tree must be removed.

## Declared outcomes

| case | refused at |
|---|---|
| override.cfg, loose committed `scripts/r15_hud.gd`, committed `tests/test_r15_crouch.gd` beside the runtime | linux: nothing but runtime, pack, readme, manifest and licences |
| editor binary as `SpillwayR15.x86_64` | linux: runtime is the official release template |
| editor plus a manifest claiming its hash | linux runtime + linux embedded/external provenance |
| runtime mode 0644 | linux: executable bit |
| nested `assets/r15/library` kit licence edited in both ZIPs | linux + windows licences |
| `assets/r15/breakwater/MANIFEST.json` removed (linux) | linux file set + linux licences |
| README without the active F5 label `Bhop server AA 1000` | linux + windows readme |
| both manifests claim `default_map=practice`, or the R14 records file | source manifest, plus both platforms' file set and licences (an unresolved manifest yields no committed file list) |
| embedded linux manifest alone claims F5 as default | linux embedded/external provenance |
| both packs or only the linux pack one bit off | each changed platform's pack check; the latter also "both platforms carry the same pack" |
| SHA256SUMS digit changed | zip checksums |
| linux ZIP truncated, checksum updated | linux zip opens |
| an extra `-deadbeef` ZIP | exactly two packages, SHA256SUMS lists exactly, zip checksums |
| pack exported without `scripts/r15_hud.gd` | shipped startup and startup errors, with `Preload file "res://scripts/r15_hud.gd" does not exist` in the shipped headless log |
| pack exported with `SAVE_PATH = user://spillway_r15_negative.cfg` | probe "records namespace"; consequence: "registry save_path equals the frozen source" |
| manifests alter only `identity.keys.breakwater.server128.course_key` | probe "record key equals the frozen source key"; consequence: the lab-exit check that restores that key |

## Result on source 406640de

The final run on 9 November passed **78/78** controls in 512 s: setup 2, ownership 9, provenance 19, preflight 19, baseline 1 (19 static checks), contents 17, runtime 5 and cancel 6. Every native run reported the AMD Radeon (radeonsi, renoir) device with kernel GPU activity and released its display. Cancellation used private display :191 and left no process, socket, lock or runtime directory behind. Evidence (1.2 MiB): outer `checkpoints/spillway/r15/delivery-negatives/run1/`, with `run1.log.gz` and `SUITE.sha256`.

Development runs corrected five expectations in this suite and nothing in production. The two untrusted-manifest cases also fail both platforms' file-set and licence checks. The records-namespace and record-key packs each fail one more probe check that reads the same changed value. The no-HUD pack's headless startup reaches its 120 s deadline because the unparsable main never quits. The named refusal there is the missing startup line together with the logged parse error, not the timeout.

Observation, not a negative: two exports of the unmodified committed source with the pinned editor gave pack hashes `5c6ac777…` and `0ae8d898…`, and neither equals the candidate's `cf6c95ac…`. Pack bytes do not reproduce, so a pack can be verified only against the hash its own manifest records, not rebuilt from source.

Not run here: positive packed routes and controls on the candidate, which are the root's job in `/tmp/r15-candidate-406640de`; Windows execution; a pack that ships `res://tests/` (the probe's stray-file check; only the loose folder copy is covered); and recovery-route admission. The older offline23, observer44 and lab37 results, and the three lab runtime mutations, remain component evidence. None of them stands in for these package-level controls.

## Fresh rerun on source03d970be

Root reran the unchanged suite against an immutable copy of the fresh03d970be ZIPs, from an exact03d970be scratch clone so the candidate commit and helper hashes both matched. All **78/78** named expectations passed again, with zero failures. This includes the repaired helper bytes, three broken runtime variants and wrapper-only SIGTERM cleanup. The complete suite took 518s. All four candidate file hashes still equal the pre-run manifest afterward. The scratch clone was removed and its size recorded.

Evidence: outer `checkpoints/spillway/r15/delivery-negatives/run2-03d970be/summary.json`, `run2-03d970be.log.gz` and `RERUN-03d970be.json`. The immutable baseline receipt is `release-plan/NEGATIVE-BASE-03d970be.json`. The positive15-route package run is separate; these negative controls alone do not promote it. Re-exported pack bytes differed again, an informational reproducibility limitation rather than a false acceptance or a gameplay failure.

## Final-helper rerun on source8a254d16

After the independent boundary and lab-title repairs, root reran the unchanged78-control suite on the new8a254d16 candidate, using the same committed HEAD and helpers. **78/78 passed, zero failures**, in529seconds. The three real broken runtimes and wrapper-only cancellation passed their named expectations. All4candidate file hashes were rechecked unchanged afterward, and executed helpers equal the candidate manifest.

Evidence: outer `checkpoints/spillway/r15/delivery-negatives/run3-8a254d16/summary.json`, `run3-8a254d16.log.gz`, `RERUN-8a254d16.json` and `release-plan/NEGATIVE-BASE-8a254d16.json`. The positive15-route run remains a separate verdict.
