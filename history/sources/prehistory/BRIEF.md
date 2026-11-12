# Foldrunner: Mirror's Edge movement in a folding city

Foldrunner is Mike's first-person parkour game in Godot 4.7.2: Mirror's Edge momentum through a city that bends and folds like Control Resonant. Two rebuilds on 3 Nov both missed the feel:

- **The Opus version** is more polished and closer to Mirror's Edge, but has too little momentum.
- **The GPT version** is faster, but its momentum feels like Clustertruck.

Since then, a reverse-engineering job read Mike's own copy of Mirror's Edge and wrote down how it moves: `/home/thatmike1/mirrors-edge-re/SPEC.md`. Your job is to build Foldrunner on that spec, from the Opus version, into a 60 to 90 second route through a folding city that Mike plays on Windows.

This is a long job, and that is intended. Build it in the milestones below, verify each one before the next, and keep going until all of them are done.

## What you have

- **`wt/`:** a sparse clone of `ccChat-general` on branch `feat/foldrunner-me-build`, made from `feat/foldrunner-rework-opus` (8881e26e). The game is `wt/projects/foldrunner`. Read its `README.md`, `AGENTS.md`, `docs/CONTRACT.md` and the code before changing anything.
  - `AGENTS.md` still says every engine run must be `--headless`. That was a rule for one past run on another machine, and it no longer applies: on this laptop, render, capture frames and look at them. Update `AGENTS.md` to match.
- **The spec, `/home/thatmike1/mirrors-edge-re/SPEC.md`.** Read the whole thing. Its first section says what to reproduce first, and its "Implementing the spec in Godot 4.7" section and acceptance checks are written for this build. Values marked U (unresolved) or P (port choice) are yours to decide, labelled as such. Do not read or use anything else under `/home/thatmike1/mirrors-edge-re/` or `/home/thatmike1/mirrors-edge/`; the spec is the only input from the game.
- **The direction:**
  - `/home/thatmike1/foldrunner-rework-2026-11-03/reference/`: the moodboard (`moodboard.html` and `images/`), `VIBE.md`, and `mike-notes/notes.md` with crops. Mike loved the moodboard. His four notes steer it:
    1. folds are coherent, recognisable city blocks, not random buildings;
    2. the bending is Control Resonant, not the first Control;
    3. the hands entering at the jump is "the Mirror's Edge satisfying feel";
    4. route reading follows Mirror's Edge's runner vision, not lit doorways and carpets.
  - The images are private reference. Never copy them into the repo or the game.
- **History:** `/home/thatmike1/foldrunner-rework-2026-11-03/BRIEF.md` (last round's brief), and `opus/REPORT.md` and `sol/REPORT.md` there.
- **Godot:** `/home/thatmike1/.local/share/foldrunner/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`. Capture frames from scripted runs with `--write-movie` (PNG sequence or AVI), and read the frames yourself.

## Milestones

Commit and push the branch at the end of each milestone. Then write `checkpoints/<n>.md` in this folder: what works, the test and trace results, the frame files to look at, and what is next. Do not start a milestone before the previous one passes its checks.

1. **Ground movement to the spec.**
   - A data resource in SI units holds every tuning value, each with a short comment naming the spec section and its confidence letter.
   - Ground acceleration follows the reconstructed speed-to-acceleration table, with the direction-change and turn costs.
   - Gravity, jump impulse and air control come from the spec.
   - A trace harness runs scripted inputs headless and writes speed, position and state over time as CSV. Tests compare the traces to the spec's predictions: time to 4.0, 6.3 and 7.0 m/s, jump apex and distance, landing speed. Tolerances are written down.
2. **The move set as distinct controllers**, each with its own momentum contract from the spec:
   - landing with fall-height selection, and the roll on a fresh crouch press in its window;
   - vault and speed vault;
   - ledge grab and pull-up;
   - horizontal wall run, wall-run jump with the repeat penalty, and vertical wall climb;
   - slide, the 180 turn, springboard, and step-ups.

   Add trace tests for each contract the spec gives. Optional helpers the spec did not find (coyote time, jump buffer) are labelled Foldrunner extensions with a settings toggle.
3. **Camera and body.**
   - An original first-person body and hands, with the hands reaching for the actual ledge, wall or vault surface, and entering the view at the jump (Mike's note 3).
   - Eye height and motion per move, the asymmetric wall-run tilt, turn lag and landing response, all from the spec's measurements. The FOV is set with the horizontal/vertical handling the spec describes.
   - Verify in captured frames: a frame strip of a jump, a vault, a wall run and a landing.
4. **Runner vision.** Route objects turn red by the rules the spec recovered. The route is read through runner vision, not through lit props.
5. **The folding city route, 60 to 90 seconds**, aimed at the moodboard:
   - Coherent city blocks that fold whole and readably while you run them, bending in the Control Resonant sense.
   - Varied beats that use the whole move set, with at least one optional route choice and checkpoints.
   - A skyline and distance layers, environmental sound, and a clear finish.
   - Keep the last round's fixes: free look from the first frame, no teleports or seams, gravity turning only on surfaces built for it, and fall respawn on the last roof.
   - Check it against the moodboard with frame captures from scripted runs. Write in the checkpoint which moodboard images the route answers and how.
6. **Playtest pass.**
   - A scripted runner finishes the whole route.
   - Look through a full-run capture for anything that reads wrong: clipping, popping, unreadable folds, the camera fighting the player.
   - Fix what you find.
   - Tune within the spec. Where you choose to depart from a spec value for fun, label it.
   - Make sure Mike's Windows launcher (`Play Foldrunner.cmd`, `tools/run.ps1`) still works for a fresh checkout.

## Rules

- **Commits:** on `feat/foldrunner-me-build`, in coherent steps, one-line lowercase messages ending with the bead id, for example `feat: ground acceleration from the spec table (ccChat-general-rowb)`. Push the branch after each milestone.
- **What you never do:**
  - push `main`;
  - deploy;
  - run `bd`;
  - write memory notes;
  - start subagents, launch Claude, or leave background processes behind.
- **What stays out of the repo:** `SPEC.md`, the moodboard images, the game files and anything decompiled. Tuning numbers in your own resource are fine.
- **Disk:** about 7.9 GB is free on this laptop. Delete movie captures once you have checked them, and keep a few frames per milestone in `checkpoints/frames/` here, never in the repo.
- **When to stop:** when all six milestones pass their checks. There is no time limit.

## The report

At the end, write `REPORT.md` in this folder for Mike, who skims. Open with how to play it on Windows from a fresh checkout (exact commands) and on Linux. Then:

- what changed in how it moves, in plain words, against the two versions he disliked;
- the route, beat by beat;
- the trace results against the spec;
- what you labelled as Foldrunner extensions or departures from the spec;
- what is not done;
- the last pushed commit.
