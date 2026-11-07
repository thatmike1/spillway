# Delivering R13 Overflow

How the R13 game is packaged and how a package is proven, 7 November 2026. R12's
`package-spillway.py`, `check-pack.sh` and `delivery/spillway-r12` are history and stay as
they are. Nothing here claims native Windows execution, desktop GPU pacing or fun.

| File | Role |
| --- | --- |
| `tools/package-overflow.py` | `package`: freeze HEAD, export the pack, build Linux/Windows zips, run `check`, publish. `check`: verify published zips |
| `tools/check-overflow-pack.sh` | the exact-pack check (`package-overflow.py check`) |
| `tools/overflow-pack-probe.gd` | harness autoload inside the shipped runtime: identity, pack contents, loaded modules, tape play, records, pause and Quit |
| `tools/check-overflow.sh` | R13 source suites, with controls and historical R12 suites kept apart |
| `tests/test_overflow_delivery.py` | negative controls: each packaging hazard must be refused |

## Runtime: official release templates

The zips ship Godot's official 4.7.2 **release export templates**, not the editor binary, so
the player gets a normal game window and a release build (no debug runtime). Provenance:
`Godot_v4.7.2-stable_export_templates.tpz` from the
[4.7.2-stable release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), sha256
`f298490b…6248011`, matching both GitHub's asset digest and the release's `SHA512-SUMS.txt`.
Only `linux_release.x86_64`, `windows_release_x86_64.exe` and its console wrapper were
extracted, to `~/.local/share/foldrunner/godot-4.7.2-templates/` with `PROVENANCE.json` (member
hashes); the 1.3 GB archive was then deleted. The editor that exports the pack is the official
`Godot_v4.7.2-stable_linux.x86_64` (sha256 `8d106cbe…`, equal to the official zip's member).
The Godot licence and third-party notices equal `LICENSE.txt`/`COPYRIGHT.txt` at the tag. No
account, signing or paid service is involved; the Windows exe is unsigned and keeps Godot's
icon and version resource (rcedit was not used).
Their verified member digests are pinned in the committed helper as well as the extraction
record. Editing a cache's PROVENANCE.json cannot authorize different runtime bytes.

Measured behaviour of these templates, which shapes the tools:

- They refuse `--main-pack` and `--path` (built without path overrides) and **ignore `--script`**,
  running the pack's main scene instead. They load `<executable name>.pck` beside the binary.
- They read an `override.cfg` beside the executable, including an `[autoload]` with an absolute
  script path. The checker uses exactly that, in a harness copy, to host its probe; a shipped
  folder containing `override.cfg` is rejected because it can change the main scene.
- With a pack mounted, `res://` resolves loose files against the **working directory** as a
  fallback, while `DirAccess` on `res://` lists only the pack. Every check therefore runs from
  a new empty directory and tests pack membership through `DirAccess`.

## Package layout

`<build>-linux-x86_64-<commit8>.zip` holds `SpillwayR13-linux-x86_64/`: `SpillwayR13.x86_64`,
`SpillwayR13.pck`, `README.txt`, `BUILD.json`, `licenses/` (Godot licence, third-party notices,
each asset kit's licence files and `MANIFEST.json`). The Windows zip holds `SpillwayR13.exe`,
`SpillwayR13.console.exe` (log window), the same pack, a CRLF `README.txt`, `BUILD.json` and
`licenses/`. One Linux-preset pack serves both; it carries desktop S3TC/BPTC textures only.
`SHA256SUMS`, `BUILD.json` (commit, Git tree, archive hash, engine, runtime provenance, pack
hash, course key, stages, startup line, helper hashes) and `VERIFICATION.json` sit beside the
zips, outside Git. README controls are copied from the committed HUD's `CONTROLS_FULL`.

Records stay in `user://spillway_r13.cfg` under the Godot user data folder named by
`config/name` ("Spillway"); R12's `spillway_r12.cfg` is only read for first-launch settings.
The current R13 checker requires the adopted art module, its applied report and the
visible course's `momentum_overflow_surface.gdshader`, using the licensed kit textures.
Finding the old shader only in a hidden node or in the resource cache cannot satisfy it.
The scanner requires real mesh vertices, effective visibility, camera-layer intersection
and renderable run, landing, catch, recovery and wall surfaces. At least one walkable
vertex must enter the camera frustum; props need a drawable descendant. This does not
prove final pixels or artistic quality. Native frame inspection remains separate.

## Commands

From `projects/foldrunner`:

```sh
python3 tools/package-overflow.py package --output DIR --stages "Pier,Chute,Tail race,Finish" --tape TAPE [--require res://scripts/NEW.gd]...
python3 tools/package-overflow.py package --output DIR --stages "..." --startup-only     # no play proof; says so
tools/check-overflow-pack.sh DIR --evidence NEW_DIR --stages "..." [--tape EXPANDED --reference TRACE --arm-motor-steps N]
tools/check-overflow.sh [--out DIR] [--route TAPE]... [--controls] [--historical]
python3 tests/test_overflow_delivery.py --package DIR --evidence NEW_DIR [--only preflight contents runtime]
```

`DIR` must be new or empty and outside Git; nothing is overwritten. `--stages` is the intended
segment list from the course design, not read from the code under test. `--require` adds a
module or asset the running game must have loaded and the pack must contain (for example the
art pass's new module). Native runs use a private Xvfb (`--display`, default `:167`), Dummy
audio, isolated `XDG_*` directories and a fresh environment without the parent display or
Wayland socket; the tool refuses a display that is already in use.

## What `package` refuses and does

It refuses, before writing anything: an output inside Git or with files; uncommitted or
untracked files in the project; a committed default scene other than
`scenes/momentum_overflow.tscn`, a scene not running `momentum_overflow_main.gd` with
`persist = true`, a `BUILD_ID` other than `spillway-2026.11.07-r13-overflow`, a records file
other than `user://spillway_r13.cfg`, a missing R13 startup line, a missing `Overflow Pack`
preset; and any engine, template or licence file whose hash differs from the pinned official
one. It never edits project config.

Then it extracts `git archive HEAD:<project>` to a stage (and checks the extracted list equals
the committed tree), imports and exports there with isolated profiles, prints the source
startup line, and with `--tape` expands the tape and plays it in source mode with the
committed tape executor on that frozen copy (must finish clean). It assembles both folders,
zips them, writes `SHA256SUMS`, and runs `check`. Zips reach `DIR` only when every check
passes; otherwise they go to `DIR/rejected/` with `VERIFICATION.json`.
Archive entry times are fixed to the source commit's timestamp, so the recorded archive
hash can be reproduced. The executing packager must match its frozen source, and the
pack run uses a snapshot of that source's probe. Standalone rechecks record their own
tool/probe hashes separately from the original packaging helpers.

## What `check` proves

Static, both zips: checksums; each folder holds nothing but runtime, pack, readme, manifest
and licences; runtimes equal the official template members; the manifest names the actual pack
and build; both platforms carry the same pack. **Windows stops here: it is not run.**
External and embedded manifests must agree. Source tree, canonical archive, file count
and original helper hashes are resolved against the recorded Git commit. The recorded
course key is checked in the game even when the caller supplies no separate key.

Linux, the shipped binary and pack:

1. A player's launch: the binary started from an empty directory with `-- --verify-startup`
   finds its own pack and prints the R13 startup line (build, course, stage count, course key
   equal to the source startup, records off headless, candidate runner, Compatibility), with no
   engine error and nothing written.
2. Native runs on the private display through a harness copy (binary and pack byte-identical,
   plus `override.cfg` naming the probe). The probe checks: release runtime, not editor or debug;
   pack hash; the pack's main scene is the R13 scene and the engine ran it; main, level, runner
   (candidate on the CARRY base), HUD and audio scripts; build id, records path, `persist`; stage
   labels; HUD wording (no R12, surf or debug words); every committed game resource is inside the
   pack (scripts only as compiled `.gdc`, no tests/tools/docs); the R13 modules, kit shader and
   textures were actually loaded by the running game; the course is drawn with the kit shader,
   kit textures and kit props. The OS window title is read with `xprop`.
3. With a tape (`play`, fresh profile): key and relative-mouse events through `Input` at the tape
   executor's tick boundaries; like the executor, tick 0 opens a render frame once the motor has
   run at least the reference's warmup. Initialization and exact warmup can affect contact
   resolution, as the independent review below demonstrates.
   Required: clean finish, stages in order, every stage measured, zero respawns, first clean run
   becomes best/open best/splits/segments, all values saved to `spillway_r13.cfg` (the only `.cfg` written), the
   packed trace equal to the source executor's tick for tick (position exactly, yaw within 1e-12
   for JSON text), Esc pauses and shows build, course and best, a click on **Quit** ends the
   process with exit 0, no engine error, the working directory stays empty.
4. `reload`: a new process on the same profile shows `records=loaded` with the same clean
   best, open best, splits and segments (numeric serialization allowance 1e-9 s). The pause
   panel shows the actual formatted best values, the profile is not rewritten, Quit exits 0.
5. Cleanup: the private display's socket and lock are gone and no process names the evidence.
   Engine groups are released in `finally`; SIGINT/SIGTERM unwind ownership scopes, including
   interruption while the display starts. This cannot promise cleanup after SIGKILL or power loss.

Without a tape a single `startup` run covers 2 and the pause/Quit path, and `VERIFICATION.json`
has no play result. The probe never writes pose, velocity, progress or records and never calls
the finish. Frames are sparse readbacks under `--fixed-fps 30` on llvmpipe: presentation
evidence, not performance.

## Root wiring

The current source has the `Window.title` fix from `c85e96a3` and the export preset from
`35500aa5`. The diagnostic package below predates those changes. Final acceptance must
use a new package with the actual current source and accepted art.

1. The `Overflow Pack` preset in `export_presets.cfg` is:

   ```ini
   [preset.2]
   name="Overflow Pack"
   platform="Linux"
   runnable=false
   dedicated_server=false
   custom_features=""
   export_filter="all_resources"
   include_filter=""
   exclude_filter="docs/*,tests/*,tools/*,builds/*,AGENTS.md,README.md"
   export_path=""
   script_export_mode=2

   [preset.2.options]
   custom_template/debug=""
   custom_template/release=""
   binary_format/architecture="x86_64"
   ```

   `all_resources` ships every resource outside the excluded folders, so a new art module,
   shader or texture needs no list edit; R12's scripts also ship, unused (about 12 MB pack).
2. Commit the art handoff and these tools, then from a clean tree run `package` with the final
   stages, the final ordinary tape, and `--require` for each new art module or asset the game
   must load. Repeat `check` with the mastery and miss tapes if wanted (`--tape` takes an
   expanded tape; `--reference` the source executor's `evaluator/trace.jsonl`).
3. If the build id, scene or records file changes for a later round, change the constants at
   the top of `package-overflow.py` deliberately.

## Diagnostic verification (not the final package)

Evidence and the resumable log are outside Git in `checkpoints/spillway/r13/delivery-tools/`
(`STATE.md`). This is a tool proof on a scratch repository, **not a release**: its zips sit in
`rejected/` and must not be promoted.

- **Source.** `diag-bc040f5b/repo` commit A is `git archive` of `projects/foldrunner` at
  bc040f5b (root's promoted default scene); its tree id equals the real one, `9e4aa1ca`. Commit B
  adds only the `Overflow Pack` preset above and these uncommitted tools (`CONFIG-DELTA.diff`).
  Art files were untracked and are absent. The final run packaged that scratch `f35ca6d5`.
- **Package.** `package --stages "Pier,Chute,Tail race,Finish"` with the root-verified ordinary
  tape (`overflow-revision/final-275c477b/driver/course.candidate.ordinary/events.tape.json`).
  Pack `57ca082e…`, course key `c61d8696bcbffc59`, Linux zip 37 MB, Windows zip 47 MB,
  `SHA256SUMS` `6bf02a9c…` (Linux) and `c54e7802…` (Windows). Tool `d995ecd5…`, probe `a007ea1e…`.
  An earlier run of the same project with older tool bytes gave pack `14a15257…`: pack bytes
  are not reproducible across those exports (the cause, possibly the uid cache, was not
  investigated), so the commit, not the pack hash, identifies the source.
- **Result: 28 of 30 checks pass, so the tool rejected it.** Passing: every static check; the
  shipped binary's own startup from an empty directory; packed play on the release runtime,
  clean 24.892 s, stages in order (splits 6.617 / 10.558 / 13.692 / 24.892 s), zero respawns,
  saved as first best, only `spillway_r13.cfg` written; the packed trace equal to the source
  executor's for all 3,372 ticks (0.0 m); reload in a new process showing `records loaded` and
  `Best 00:24.89` without rewriting the profile; Quit exits 0 in both; no engine errors;
  display released, no process left. Frames: `package/evidence/check/runs/play/frames/`.
- **Failure kept: the OS window title is "Spillway".** `xprop` never saw `Spillway R13 ·
  Overflow` in the play or reload run. The main calls `DisplayServer.window_set_title`, and the
  root `Window`'s own title (`config/name`) replaces it. A scratch variant changing only that
  line to `get_window().title = "%s · %s" % [BUILD_LABEL, COURSE_NAME]` showed the R13 title
  (`title-test/`, `main.diff`). The main is root's; that one-line fix is root's to make.
- **Observed discrepancy, with its cause still under review.** The first packed run
  armed tick 0 after exactly 10 motor steps, which put it one physics step off the executor's
  render-frame phase. It finished identically (24.892 s, same splits) but drifted from the
  source run from tick 979, where the runner first touches both `platform_e` and `platform_w`:
  at most 0.0170 m before the finish, 0.0035 m after. Separately measured:
  - three source executor runs: identical to each other;
  - two packed release runs at that phase: identical to each other (0.0 m);
  - editor binary with the same pack, headless, and release template headless: the same
    0.0170 m, so neither the release build nor the display causes it;
  - a packed release run armed so tick 0 opens a render frame (as the executor arms): 0.0 m
    against the source over all ticks.

  The aligned pack and release runtime reproduce source motion exactly. The subsequent
  independent review reproduced both historical trajectories in source mode by changing
  world construction timing, with the same ten neutral motor steps and identical recorded
  initial script state. Controlled process-cadence and tape-phase changes preserved exact
  motion. A different neutral warmup can also change the trajectory. Render phase is not
  established as the cause, and the engine-internal mechanism remains unresolved. All
  twenty valid cases finished at 24.892 s with identical splits and zero respawns. The
  maximum observed body-position difference was 1.70 cm; this is not a general guarantee
  near other edges. No production physics change or relaxed tolerance follows. Evidence:
  outer `checkpoints/spillway/r13/phase-review-sol/REPORT.md` and root's `ROOT-CHECK.json`.
  The probe arms like the executor; tolerance stays 0.0 m.
- **Source suites.** `check-overflow.sh --controls --route <ordinary tape>` in a clone of the
  scratch repo: all active checks and both controls pass, route clean 24.892 s.
- **Negative controls.** Preflight refuses wrong default scene, wrong build id, R12 records
  file, missing preset and an uncommitted edit. The checker refuses `override.cfg` beside the
  runtime, a loose source script in the folder, a pack that differs from its manifest, and a zip
  checksum mismatch; each fails only on its intended check. At runtime, a consistent package
  whose pack lacks the R13 HUD module fails the shipped binary's startup, and one whose pack
  writes `spillway_r12.cfg` fails the probe's records-namespace check.
- **Displays.** Root allocated `:167`, but an Xvfb started at 18:50 by another Claude session
  (`8fb72c1e`, from the checkout) held it; it was left alone. Runs used `:168` before it was
  reassigned, then unallocated `:170`.

## Limits

- Windows is checked statically only: contents, official runtime hashes, pack identity,
  README. Native Windows execution, the console wrapper and Windows file associations are
  unverified. Wine was not used and would not count.
- Input is engine-injected (`Input.parse_input_event`, `Viewport.push_input` for the Quit click):
  no OS keyboard/mouse delivery, pointer capture or focus is tested.
- Rendering is Mesa llvmpipe on a private Xvfb at 1280×720 with fixed fps: shaders compile and
  draw, but no GPU pacing, latency or target-resolution claim follows.
- One recorded state-aware ordinary line proves one route on one commit, not imperfect play.
- The harness relies on `override.cfg` support in official templates; if a later Godot disables
  it, the play proof needs another host.
- The checker derives required pack contents from the package's own source commit, so `check`
  must run in a repository that has that commit.
