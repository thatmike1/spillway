# R16 native acceptance

The acceptance harness runs the actual `scripts/r16_main.gd` with the approved course runner and its production style panel, session, recording reader and ghost. It freezes committed source outside the checkout, then overlays only the new acceptance tests. Nothing here changes production physics, maps, HUD, ghost or scoring.

The full motion/recording target is `a26d94c0`, including style identity `r16-style-2`; the final HUD text is separately captured from `34fb79a4`. `c071480d` outputs are labelled baseline evidence and do not validate the repaired scoring. Final packed acceptance belongs to root.

Evidence is outside Git at `/home/thatmike1/foldrunner-build-2026-11-05/checkpoints/spillway/r16/native-acceptance/`. Each run has `run.json` with commands, source commit, engine digest, source/import budget, HOME free space, device and GPU observations; `SOURCE-HASHES.json` records every frozen source and test. Native display records include desktop `:0` checks before and after and owned process cleanup.

## Proof surfaces

- `r16_native_acceptance.gd`: unchanged accepted R15 Breakwater F2 tape through the actual R16 main, normal spawn. The real finish seals the recording, saves the time/style bests and offers the fastest clean ghost. R starts a slower crouch-walk, G hides and shows its ghost, and a matching-input prefix repeats actual landings with the near fade. Esc shows the actual map picker, recording path and G switch.
- `r16_native_acceptance_opportunities.gd`: reuses the established input-earned passage controller against the actual R16 host and its one production scoring session. Breakwater uses labelled authored stage 3 practice; Whiteout starts normally. Selected approaching, passing and exit images use the runner's actual camera. No authored fixed camera substitutes for them.
- `r16_native_acceptance_lab.gd`: actual R16 host and real lab, no fixture surfaces. The normal-spawn strafe/bhop chain presses Shift on descent with Space held, lands in a slide and makes a fresh hop. Authored chamber practice holds A/D through two kicks, refuses a third and refills on landing. A clearly labelled read-only test overlay exposes the live budget and held inputs; it is additional test UI, not a production HUD feature.
- `r16_native_acceptance_os.gd`: read-only observer. All tour control comes from OS XTest events via `xdotool`, including Esc, map selection, Shift, Space, A/D, G and the actual menu Quit. This short tour proves event delivery and controls only; it is not a clean route or a physical keyboard/mouse latency measurement.
- `r16_native_acceptance_ui.gd`: short final-HUD views from `34fb79a4`, using the actual authored Slide lane and Wall chamber practice APIs, player camera and Esc menu. It checks and captures the final hints and recording line without replaying full routes.
- `r16_native_acceptance_compare.py`: per-tick native/headless motion, view, progress, held-input and score comparison, accepted R15 reference comparison, and recorded tick/input/style-seal verification through the existing recording checker.

## Resource and renderer boundaries

Every native launch rechecks at least 15 GiB available on `/home`, then uses the unmodified `tools/r14_native_display.py` with explicit private displays 196–199, real AMD rendering, `GpuWatch` and the engine's device line. No software fallback, desktop config change or desktop socket manipulation is allowed. HOME and all XDG directories are private; audio is Dummy.

Owned source/import scratch is in `/dev/shm`, capped at 300 MiB; the temporary AVI is capped at 1 GiB. It is removed after MP4 dimensions, decoded frame count, duration and full decoding are verified. Only compact recordings, compressed traces, selected JPEGs, bounded MP4s and small logs/manifests are retained. The complete evidence tree is capped at 55 MiB. Scratch and owned engines/compositors are cleaned on success and failure.

## Baseline findings and harness repairs

The `c071480d` baseline headless tape exactly matched all 5,777 accepted R15 Breakwater motion/view ticks, completed cleanly in 44.6015625 s and saved a 937-point style best through real finish/session APIs. Native baseline images were inspected: the gap callout, running score, time/style finish, translucent leading ghost, hidden-G state and Esc menu were readable.

The first baseline native comparison was **not exact**: a process-frame arm after 34 settled ticks versus 33 headless shifted only feet height by at most 0.0000575185 m; velocity, horizontal position, view, clock and score matched. This was a harness cadence difference, not accepted as equality. The new driver arms after exactly 33 settled physics ticks regardless of draw cadence. The baseline comparison and traces remain, including its false result.

Two baseline OS tour attempts were terminated after they checked map selection before the new map finished loading. Both failures, input logs, screenshots and reasons remain in `baseline-native-os*`; neither is counted as a successful tour. The corrected observer waits for the actual map state and the later baseline tour selected Movement Lab, toggled G, delivered the named movement keys and quit with exit 0. No production edit was made to repair those harness failures.

## Final results

The complete moving routes and passage rows below use frozen `a26d94c0`, the pinned Godot 4.7.2 binary (`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`), AMD/X11 on private `:196`, isolated HOME/XDG/profile/recordings and Dummy audio. `FINAL-COURSE-COMPARE.json`, `FINAL-LAB-COMPARE.json` and `FINAL-WHITEOUT-COMPARE.json` all report `ok: true`.

| native run | executed result | independent tick/input/seal check |
|---|---|---|
| `final-native-course` | normal-spawn accepted R15 Breakwater tape unchanged; clean 44.6015625 s, time best and style best 937, automatically offered sealed ghost | all 5,777 motion/view/progress ticks exactly equal to both final headless and accepted R15 reference; score/combo equal headless; all 149 key edges and 4,820 mouse rows on their own recorded tick; five style events sum to 937 with none after finish |
| `final-native-whiteout-tape` | reused the parallel route worker's final `a26d94c0` normal-spawn Whiteout apron passage and full clean finish; 63.3671875 s, style best 1,790 including the 900-point airborne apron crouch save | all 8,138 motion/view/progress ticks exactly equal its final headless executor reference; all 125 key edges and 2,226 mouse rows aligned; six style events sum to 1,790 |
| `final-native-lab-tape` | reused that worker's final normal-spawn lab flow tape through the actual main; clean 14.4609375 s, style best 1,631; descent arm, held-Space landing slide, fresh hop, A/D kicks, refill and existing grapple sequence | all 1,878 motion/view/progress ticks exactly equal its final headless executor reference; all 49 key edges and 319 mouse rows aligned; three style events sum to 1,631 |
| `final-breakwater-crouch` | actual session awards 900 for the input-earned passage, `r16-style-2` | authored stage 3 practice explicitly labelled; approach, airborne crossing and exit retained; best ineligible |
| `final-breakwater-thread` | actual session awards 134 for the input-earned 430 u/s thread, `r16-style-2` | authored stage 3 practice explicitly labelled; approach, crossing and exit retained; best ineligible |
| `final-native-lab-practice` | actual-host normal-spawn 392.5 u/s slide chain plus authored chamber practice; six checks pass | 41 grounded/ducked slide ticks, fresh hop at 362.3 u/s; two held-A/D kicks, third-face budget refusal and landing refill in the real chamber |
| `final-native-os` | synthetic OS XTest Esc, keyboard menu selection of Lab, W/Space/Shift/A/D, G off/on, Esc and actual menu Quit; exit 0 | read-only observer logs all physical keycodes, map/pause/ghost state and the real recording lifecycle; this deliberately short controls tour is not a claim that OS inputs performed a clean route |

There are 15,793 exact native/reference moving tape ticks across the three complete routes. Breakwater's additional 830-tick same-input ghost replay also matches its first run exactly, with fade 0 throughout. The saved ghost is loaded from the first run's real completed/sealed recording; no best/profile file is fabricated. Subsequent slower crouch-walking shows the translucent ghost ahead; G actually hides and restores it. The overlap landing images show the deck unobstructed by the near ghost. The production fade remains 1.5–6 m.

The retained Breakwater movie is 1280×720, 32 FPS, 1,792 decoded frames, 56.0 s and 21,337,269 bytes. AVI and MP4 dimensions/frame counts agree and the MP4 decodes fully; the 199,356,314-byte temporary AVI was deleted. Baseline movie bytes were removed after verification to reserve evidence space; its movie digest/probe, selected images and compressed traces remain.

The two reused route references live under outer `r16/player-routes/final-a26d94c0-{whiteout,lab}/executor/`. Their actual tape/reference digests, source commit and native commands are retained in each run manifest and comparison file. They are fixed engine-injected input tapes, not physical keyboard runs or authored camera flythroughs.

### Final HUD text patch

`final-hud-34fb79a4/` freezes the later HUD-only patch and passes all three live text checks. Its three JPEGs were opened and inspected: the Slide lane hint teaches descent Shift then a fresh Space press; the Wall chamber hint names A/D held and two kicks per landing, each wall once; the Esc menu shows the actual isolated recording directory followed by “Recordings stay on this machine. Copy the r16_runs folder back for analysis.” All three captures verify that the active camera is the actual runner camera.

The final HUD SHA-256 is `d2882b594c79e87e6f16b48bfc0d1a4d1d25483f520ad0f93a8db1e6298de539`. Comparing the complete frozen `scripts/` manifests between the full-course run and this UI run finds exactly one changed runtime file, `scripts/r16_hud.gd`. Main `6937de67…`, session `8705d1e1…`, style `3d7e233f…`, ghost `f9d48346…` and reader `76f2f2b7…` remain identical. The full routes were not rerendered for this text patch.

### Shutdown observations and cleanup

The thread-passage run logged four ObjectDB instances leaked at exit; the first focused native lab practice run logged six. Their engine logs and all execution results remain. A later native verbose lab recheck (`lab-cleanup-debug`) passed the same six checks and did not reproduce its warning. The causes are not established, and no production change is claimed to fix them. These warnings do not invalidate the recorded input/motion comparisons, but they prevent a claim that every native shutdown was warning-free.

The final versions of all five new GDScript drivers also pass isolated Godot `--check-only`; `FINAL-PARSER.json` records their executed hashes and commands. Both Python drivers pass AST parsing.

`FINAL-AUDIT.json` checks every owned native display session: AMD device/GPU evidence, HOME floor at launch, source/import budget, absent scratch paths, desktop `:0` before/after, clean helper shutdown and zero remaining owned compositor/game processes. No temporary AVI or owned source/profile directory remains. The final evidence tree is about 51.4 MiB, below 55 MiB; final HOME free space was about 15.49 GiB. Large headless summaries and episode JSON were losslessly gzipped (`COMPACTED-JSON.json`), and unselected duplicate verbose-recheck images were removed with a retention manifest. The final MP4 and selected images remain. This describes observed cleanup, not a general memory-leak or performance guarantee.

### Images inspected

The implementer opened the selected JPEGs with the image viewer, including these final-source images:

- Breakwater `first-combo.jpg` shows `Gap 2.5 m +124`, running total 195 and ×1.25. `finish-time-style-bests.jpg` shows 00:44.60, style 937, new time/style bests and the new ghost message. The ghost-ahead, G-hidden/shown, overlap landing and Esc menu images were also checked. The actual menu shows the map cards, recording directory and loaded 00:44.60 G switch.
- Both Breakwater passage approach/crossing/exit sets were inspected. CROUCH and STYLE mark the authored openings; the player passes through the real geometry and the exit views show `Crouch save 3 cm +900` or `Thread 10 cm +134`. No fixed camera replaces these views.
- Whiteout's approach/crossing/exit and full finish were inspected. The apron crouch save appears in the actual player view, and the real finish shows 01:03.37 and style 1,790.
- Lab `lab-slide_armed.jpg`, `lab-slide_landing.jpg`, `lab-fresh-hop.jpg`, both `lab-wall_jump-budget*.jpg` and `lab-wall_refill.jpg` were inspected. The actual HUD shows ARMED, LANDING SLIDE, and 1/2, 0/2 then 2/2 wall kicks left. The separate labelled test observer adds held keys and internal state. Captures happen at the next draw, so a screenshot may be several physics ticks after the requested event; the per-tick trace/recording is the input/event authority.
- The final OS tour's Esc menu, lab map selection and lab menu were inspected. The menu states the Shift landing-slide and two-per-landing wall rules, while the observer logs the actual OS events and Quit.

These selected views revealed no issue requiring a production edit for this task. The lab's initial instruction text is dense, and the additional test observer covers some of the right-hand lab text; it is clearly labelled test UI and never enters production. This is a sampled inspection, not a blanket visual-quality or release verdict.

## Reproduction

From `projects/foldrunner`, with sufficient HOME space:

```sh
python3 -I tests/r16_native_acceptance.py --commit a26d94c0 --mode course --fps 128 --out /absolute/new-headless-directory
python3 -I tests/r16_native_acceptance.py --commit a26d94c0 --mode course --native --movie --fps 32 --out /absolute/new-native-directory
python3 -I tests/r16_native_acceptance_compare.py --headless /absolute/new-headless-directory --native /absolute/new-native-directory --out /absolute/comparison.json
python3 -I tests/r16_native_acceptance.py --commit a26d94c0 --mode opportunities --case breakwater-crouch --native --fps 128 --out /absolute/new-passage-directory
python3 -I tests/r16_native_acceptance.py --commit a26d94c0 --mode lab --native --fps 128 --out /absolute/new-lab-directory
python3 -I tests/r16_native_acceptance.py --commit a26d94c0 --mode os --native --fps 128 --out /absolute/new-os-directory
python3 -I tests/r16_native_acceptance.py --commit 34fb79a4 --mode ui --native --fps 32 --out /absolute/new-final-hud-directory
```

Other passage cases are `breakwater-thread` and `whiteout-crouch`. `--route-tape PATH --map ID` reuses an expanded accepted player-route tape on the same actual host and stops after its real finish. Existing directories are refused so attempts cannot silently overwrite each other.

No human feel, display/input latency, general performance, Windows, packaged release or release approval claim follows from this evidence.
