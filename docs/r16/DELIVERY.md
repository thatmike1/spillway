# R16 delivery tools

R16 delivery is separate from the frozen R15 downloads. The tools retain the independent official Godot editor, release-template and licence digests, committed-source manifest checks, isolated profiles, input/order/visibility checks and owned-process cleanup. An inherited R15 result is never R16 acceptance.

## Source checks

From this project, `tools/check-r16.sh` freezes committed HEAD into an external RAM directory, imports it and executes the R16 source checks. `--source worktree` includes tracked and non-ignored untracked files and labels the result a development diagnostic. The wrapper records every frozen source hash and the executing helper hashes in `SOURCE.json`; it removes its source, imports and isolated engine profiles on success, error or cancellation. Evidence stays outside Git.

```sh
bash tools/check-r16.sh --source worktree --allow-r15-default --components-only --out /dev/shm/r16-source-development
```

`--allow-r15-default` explicitly launches `scenes/r16.tscn` without changing the frozen default or relaxing the R15 content comparison. It is for development only. `--components-only` omits the complete course route requirement. Neither option produces release acceptance.

A full check omits both flags and supplies `--route` for F2 on every course plus an F5 comparison. Route syntax is exposed by `python3 -I tools/package-r16.py source --help`. The accepted R15 course inputs and references remain in outer `checkpoints/spillway/r15/release-plan/ROUTES.json`; choose preserved course lines from there. R16's changed lab moves need their own line evidence, rather than a claim of equality to the old combined lab tape.

The source gates comprise:

- The pinned `8a254d16455d69cee6df8ca37f82c53d04e6ab4c` scripts, shaders, scenes, assets, protected project settings and existing export presets. `check-r16-preservation.py --git-project REPO` obtains this baseline read-only from the source repository while checking the external snapshot. The default pin cannot be overridden.
- All eight maps, every supported map/preset identity, default Breakwater/F2 and the actual R16 host's recorder, glyph layout and post-step ordering.
- Live R16 lab input: an earned circle strafe over 330 u/s, Shift during descent with Space held, grounded landing slide, fresh hop out, and the real wall chamber with A then D held. Two kicks reach the mezzanine, a third wall is refused by the budget, and a real landing refills it.
- Geometry style fixtures and their negative controls, the actual R16 product loop, recording schema/malformed/mixed-folder and real write-failure checks, and focused delivery/profile/process/visibility negatives.
- The lab adapter in `tests/r16_delivery_lab.gd` reuses the established movement challenges with the actual R16 host and automatic lab runner selection. R15/source comparisons retain their frozen labelled host. Its added fixture walls explicitly carry surface metadata; production map geometry is unchanged.

Some component fixtures deliberately use R15 as their host. Their scope is stated in their own summaries; the separate feature probe and product-loop tests exercise R16 integration. Headless glyph layout is not native visual acceptance.

`package-r16.py source` can also check an already imported external snapshot. It requires the current helper bytes, performs the preservation comparison and actual-host feature probe, and optionally executes supplied routes. The caller owns that input snapshot; the wrapper owns and deletes snapshots it creates.

## Portable exact-pack checking

`tools/package-r16.py` supplies `package`, `check`, `source` and the owned-child `engine` commands. `tools/check-r16-pack.sh` wraps `check`.

A non-diagnostic package requires clean committed source, default `scenes/r16.tscn`, `spillway-2026.11.09-r16`, `user://spillway_r16.cfg`, export preset `R16 Pack`, and both `persist = true` and `record_runs = true` in the player scene. It regenerates its source identities, feature proof and route references from that commit. It never repairs configuration or falls back to loose source.

The Linux release runtime executes from an external empty working directory and a harness hard-linked to the extracted runtime/pack bytes. Its override contains only the probe autoload. The shipped directories never contain the override. Windows checks remain static unless someone actually runs that build on Windows.

AMD/X11 is the default native backend, using the existing private-display owner and explicit 190–199 range. HOME must have at least 15 GiB before export or native work. No desktop config or socket is changed. Per-run native deadlines default to 600 seconds. Route captures are bounded selections; the traces retain every tick.

Both package and recheck reconcile source/archive/resource/helper manifests. Current checker helpers must equal the package's committed helpers, including `r16_run_reader.gd` and `analyze-r16-runs.py`. Reader hardening or a probe change therefore requires a new committed export and fresh checking. A stale helper result cannot promote a later candidate.

## Attempt files and profile scope

Startup includes `records=STATE; recordings=PATH|off;` before the runner. Headless startup writes neither configs nor attempts unless an isolated directory is explicitly enabled. Native player scenes record by default. `--no-records` controls config persistence; `--no-run-recordings` controls attempt files.

The probe observes the actual body, view, clock, rate, checkpoint, respawns and held actions at priority 1000. The session must sample after stats and before that observer/next-tick input. Each observed attempt tick is matched with the recorded tick, including pre-arm idle. Position/velocity float32 values and view/clock/rate values are checked against independent observations. Recorded column and input bytes must equal the current engine reader's decoded bytes. The independent Python reader validates the same complete streams. Tape input edges and mouse deltas must appear on the corresponding recording tick, in order.

Profile auditing admits only the exact sealed attempt paths named by the probe plus the R16 config when that mode permits it. An arbitrary new recording, another config, an older-profile overwrite or a deleted profile fails. Reload and Quit may legitimately seal new attempts; reloading must leave the config bytes unchanged. The separate reader process includes the Quit-sealed file, and runs with config and attempt writes disabled. No arbitrary extension or directory wildcard admits player files.

The finish file includes its final tick and stops there, even when the tape continues beyond the finish. Style event totals must equal the sealed total; practice cannot claim clean style eligibility. The packed probe checks clean style persistence, separate-process ghost restoration, interpolation, toggling, nonphysical children and wrong-identity/corrupt/incomplete rejection. Source loop tests additionally check ghost motion neutrality and lifecycle persistence.

The reader preserves explicit diagnostic/partial states. A complete recording does not imply clean-best eligibility. The recorder, reader, analyzer and ghost retain their component contracts in `RECORDINGS.md`.

## Evidence and release boundary

Executed receipts and retained failures live outside Git in outer `checkpoints/spillway/r16/delivery-tools/`. Each source run keeps its source/helper hashes, command, logs and assertion summaries. Large traces and diagnostics are compressed; source/import scratch is disposable. The implementation handoff lists the executed hashes and explicitly distinguishes those bytes from later reader/host/overlay changes.

Packed execution, native player-view/fade inspection, the current committed export, Linux candidate promotion and the final player report belong to root's final run. Native Windows, physical input latency and human feel are not established by these tools or any assertion count.

## Independent attribution hardening

The R16 delivery observation protocol is version2 (the player recording format remains version1). The probe independently receives raw motion key and mouse events through `_input`, before serialization. Both screen-relative and viewport-relative mouse columns must match, including their legitimate difference under a scaled headless viewport. Lifecycle-reset tails are checked against the boundary event; preset/loadout-carried inputs must reach the next attempt. Unknown attempts, invalid ticks, unconsumed observations and missing packed tape coverage fail closed.

Each observed physics sample also freezes the newly emitted live style events and cumulative score. The auditor validates event order/ticks, known reward types, bounded integer points and multiplier, then reconciles each recorded event and the sealed total/by-kind summary with that live stream. This checks serialization and attribution; geometry correctness remains the separate real-collision scoring suite and full passage routes. The generic recording readers do not authenticate forged files.

Both exact trace paths include pitch alongside position, velocity and yaw. The full-glyph structural predicate supports plain HUD labels and rejects unsupported canvas materials/parent-material inheritance; actual native views still provide pixel evidence. The lab picker control can remain at the selected chamber for its movement check, rather than exercising R and then inadvertently starting the chamber script at the hub.
