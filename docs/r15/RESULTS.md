# R15 delivered: five courses, crouch and a separate Movement Lab

Accepted on 9 November 2026. The portable ZIPs are in outer `delivery/spillway-r15/`; outer `REPORT.md` is the player guide. Source commit **8a254d16455d69cee6df8ca37f82c53d04e6ab4c** produced the package. Later commits add tests, reports and the decision trail, without changing its game or helper bytes.

## Delivered behavior

- F2 AA100/128 Hz remains the default; F5 AA1000 remains primary. F1 vanilla64 is retired from R15. F3/F4 are labelled advanced comparisons.
- Five new original maps have multiple checkpoints, different geometry and licensed external assets: Breakwater, Whiteout Relay, Sunken Court, Rainline and Night Shift. Penstock Yard and Overflow remain selectable.
- Ctrl/C changes the real collision box on the ground and in flight. Jump-then-crouch ledges, low passages, crouched landings and deferred standing are proven. The centred 9 u air lift is an explicit game choice.
- The optional Movement Lab has slide, wall jump and bounded grapple, individual toggles, a separate runner and loadout records. Leaving it restores the course runner.
- Esc selects maps or checkpoint practice; F retries the last checkpoint and R starts clean. Practice, respawned and mixed-preset attempts cannot save a clean best. Exact tick and split records use only `spillway_r15.cfg`.

## Exact portable-package acceptance

`delivery/spillway-r15/VERIFICATION.json` has **304/304** top-level checks passing. The actual official Linux release runtime ran outside the source checkout on private AMD/X11, with Dummy audio and isolated profiles. GPU use was checked through both the device log and kernel amdgpu activity. Its interactive controls passed **746/746** assertions.

All 15 plays below finished clean, visited checkpoints in order and had zero respawns. **90,410 packed ticks** match fresh source traces exactly in position, velocity, yaw and compared game fields. Every input edge, mouse delivery, motor ordering, rate and crouch hull-origin transition passed the packed observer. Each play saved its complete integer record, then a separate process restored it without rewriting the profile and exited through Quit.

| Packed input line | Preset | Finish |
| --- | --- | ---: |
| Breakwater ordinary | F2 | 44.6015625 s |
| Whiteout ordinary | F2 | 62.296875 s |
| Sunken Court ordinary | F2 | 47.53125 s |
| Rainline ordinary | F2 | 38.21875 s |
| Night Shift ordinary | F2 | 57.546875 s |
| Penstock advanced | F2 | 28.609375 s |
| Overflow | F2 | 45.9609375 s |
| Overflow | F5 | 45.9609375 s |
| Whiteout crouch gantry | F2 | 61.984375 s |
| Sunken crouch hop | F2 | 47.0390625 s |
| Rainline duct | F2 | 43.1796875 s |
| Night Shift crouch shutter | F2 | 57.203125 s |
| Movement Lab combined | F2 | 15.03125 s |
| Night Shift earned | F5 | 42.6796875 s |
| Breakwater physical alley return | F2 | 55.4765625 s |

Safe deferred standing is independently proven in the labelled source collision fixtures; the packed duct route proves passage while crouched. The last line physically misses and returns, without respawning. Automatic checkpoint respawns were checked separately in the course source/native evidence. The packed probe exercises checkpoint selection, F practice, restart purity, ground/air hull changes, map/preset switching, lab isolation and exact records; it does not admit reset discontinuities into clean route comparisons.

## Independent challenges and other evidence

- Approved uncrouched F2/F5 routes remain exact across **16,356 ticks**. See outer `checkpoints/spillway/r15/crouch-harness/approved-routes/RESULTS.json`.
- The final current-helper source wrapper passes every active gate and unchanged R13 controls. Its complete evaluation files are under `final-source-2b7b01ac/`. The final package separately regenerated all 15 source references.
- Contact, live-crouch settings, checkpoint/record and lab reviews are retained in CROUCH-REVIEW.md, MAPS-REVIEW.md, COURSES-REVIEW.md and EXPERIMENT-REVIEW.md. The conditional live-settings faults were repaired before the final motor freeze.
- Verifier findings were repaired and then executed on this fresh package. The boundary suite passes **255/255**, including all 60 allowed-title positive/negative cases. RELEASE-REVIEW.md and VERIFIER-RECHECK.md preserve the original counterexamples.
- All **78/78** negative delivery controls pass against the exact 8a254d16 package/helper bytes. They include real broken exported runtimes and cancellation during native checking. See DELIVERY-NEGATIVES.md and `delivery-negatives/run3-8a254d16/summary.json`.
- Root inspected final packed views from all five new maps, the lab finish/reloaded best and the menu. A separate normal shipped Linux launch used synthetic OS keyboard/pointer input without a probe or override: crouch, airborne crouch at 250 u/s, F5, all eight map cards and Quit worked. See `final-os-8a254d16/RESULTS.json` and its selected JPEGs.
- Breakwater's bounded player-view discovery remained unfinished after 60 decisions and four misses. F and automatic water recovery worked; later sections used explicit checkpoint practice. DISCOVERY.md preserves this result.
- A later unchanged-game F5 breach controller finishes in 33.9765625 s and replays once exactly at the driver's recorded precision. It is source headless evidence, separate from the 15 packed lines. See F5-BREACH.md.

## Identity and storage

| Artifact | SHA-256 |
| --- | --- |
| Linux ZIP | `e7da4896bbe29888382fdf4b29886a811a5c29a4fd99a707c2b3d95d9c943418` |
| Windows ZIP | `b41646efd844728adbfa6df934f73b2573c3de6853bea8c1072f00b32336a450` |
| Shared pack | `4bd3b6cf9350adeebd1e7f3838da5984385884cccfc43ecaac0be7105b496373` |
| VERIFICATION.json | `b6927faf398ec0a3017b54b515783b45ca41bd9ed367615fb05743dec503c473` |

BUILD.json, SHA256SUMS and VERIFICATION.json remain byte-identical to the checker output. ACCEPTANCE.json records root's promotion separately. Exported pack bytes are not reproducible across exports of the same commit; each delivered pack is identified by its own manifest and hash.

The complete evaluation data, selected exact PNGs and sparse proof MP4s are under outer `checkpoints/spillway/r15/final-package-8a254d16/`. CURATION.json.gz maps every original file to its retained bytes or an explicitly omitted intermediate frame hash. Large text/JSON/source copies and traces are losslessly compressed. Sparse proof movies are not frame-pacing measurements. Full course source-mode movies remain indexed by their course documents.

The final copy was guarded by projected disk use and left more than 15 GiB free on HOME. Storage receipts record retired backed-up history, removed task caches and byte-identical asset sharing in completed worktrees. The pinned Weston dependency and final R12/R13/R14 deliveries remain.

## Practical limits

No human has approved R15's maps or experimental moves. Scripted completions establish executable lines, not discovery, robustness or enjoyment. Rainline and Breakwater are below the agent's 45 s design target; Rainline's duct is slower, and duct-then-street-jump failed. Sunken/Night crouch alternatives save little, and Night's earned landing is fragile. Dark sections, flat surrounding terrain and modest lab art remain.

Windows is checked statically, not run natively. Audio listening, physical gamepad input, physical-device latency and ordinary desktop frame pacing remain unverified. Forced private Wayland can hang in Godot teardown; the final X11 runs exited cleanly. Finish records are saved before Quit. Neither cvar reconstruction, Godot collision repair nor the chosen air-crouch anchor is a claim of CS:GO binary fidelity.
