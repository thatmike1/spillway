# Milestone 7: the council's fixes

Your six milestones are pushed and the numbers are good. The trace results land on the spec. Before Mike plays it, two reviewers from different model families scored the finished build from your own frames and the code, against the moodboard, his four notes and the spec:

| | Hands/body | Camera vs spec | Clear view | ME feel | Coherent folds | Resonant | Runner vision | Beats | Atmosphere | Overall |
|---|---|---|---|---|---|---|---|---|---|---|
| Opus | 3 | 5 | 5 | 3 | 5 | 3 | 4 | 6 | 4 | 4.5 |
| Sol | 4 | 5 | 3 | 3 | 6 | 4 | 5 | 6 | 3 | 4 |

The movement is credible. What the frames show is a greybox obstacle course with stiff hands, and three of Mike's four notes are not met yet. Work through the fixes below as milestone 7, in the same way as before: commit in steps, push, verify each fix in rendered frames, then write `checkpoints/7.md` with before and after frame pairs, and update `REPORT.md`. Keep every recovered movement number, and label anything new as P or a Foldrunner extension. The rules in `BRIEF.md` still hold.

## 1. Camera faults (each one checked in code by the reviewers)

- **The wall-run lean is inverted.** `player.gd` applies the spec's UE3 roll (+17.814° left wall, −23° right wall) directly about `Vector3.BACK`. UE3 is left-handed and Godot is right-handed, so the sign flips in the port. The head currently leans into the wall. Make it lean the way moodboard image 21 does, and add a camera test asserting the ear-height sign on a left and a right wall run.
- **The roll puts the eye underground.** The crouched eye offset minus the 1.39665 m roll excursion is about 0.3 m below the roof. That excursion is a local measurement, not a world displacement (the spec says so). Author the roll's eye path around the crouched body, keep the measured duration and the 3.1352 m travel, and resolve the final eye position against geometry. Check: a dense roll strip, with eye-to-floor clearance logged.
- **The turn lag is nearly invisible.** It multiplies a single tick's yaw input instead of a yaw rate, which gives under 0.05°. Use the angular rate through the spec's lazy spring (0.20 s, −0.15, the velocity scaling) so a fast flick shows a small but visible roll.
- **Ordinary landings make no visible impact.** The 0.2 floor in `player.gd` around line 673 cuts an ordinary drop to about 2.4 cm, and the `_dip` spring is never triggered. The spec says landing weight comes from the eye animation, not a universal shake. Give ordinary landings an eye response scaled by impact (a few cm, recovering in about 0.3 s), labelled P. Check: the landing row of the move strip shows the horizon move and recover.

## 2. Hands and body (Mike's note 3, the thing he cares most about)

- **Jump hands.** Re-pose them to moodboard image 15. Hands near the outer edges of the frame and low, with forearms coming in from the lower corners. Fingers splay forward, not raised palms. The backs of the hands face the eye, and the lower centre stays clear for the landing. Today they read as "hands up". Use the dark glove material that exists in `arms.gd` but only the feet use, give the palm some shape, and slim the sleeves. Stagger the two hands through takeoff, flight and recovery rather than mirroring them.
- **Real contact.** Use a two-bone solve with fixed arm lengths so the elbows bend, and close the cuff-to-sleeve gap.
  - On the wall run, the palm lies flat on the wall.
  - On the vault, a hand is planted on the rail for the push-off. `3-vault.png` currently shows no hand and no rail: the eye compression drops the view below the hands, and `arms.gd` discards `hand_world`.
  - The vertical climb uses separate left and right targets.
- **Legs.** Bring the legs and shoes into the look-down view and the vault, as in images 16 and 20. Today they are a box with two lumps.
- **The arm layer's own light** makes the arms glow in the dark slide. Light them with the scene's light.
- **Check:** dense strips of the jump, vault, grab and wall run next to images 15, 20 and 21, plus the look-down.

## 3. Runner vision, not signage (note 4)

- Remove the painted chevron arrows, the ladder rungs and the periodic floor stripes from `level.gd`. Remove the 200 m cyan finish pillar too, or show it only from the last roof. These are the lit-doorway approach Mike rejected.
- Mark usable hardware instead of whole slabs: the rail's top bar, the step nosing, roof lips, a pipe, the springboard plank, the wall-run trim. The high rail and the terrace are currently full red boxes covering about half the frame. Make the neutral state match the surrounding material.
- `_cue()` registers vision with the default 15 m omnidirectional options. Pass each cue an authored distance and direction, longer on the fold bridges, so the far landing reads red before takeoff and passed cues fade.
- Make the water-tank 180° turn and the eastward continuation readable from the geometry.
- **Check:** with the HUD hidden, every decision point shows the next action and the destination after it. Red stays a small share of any frame.

## 4. The folding city: coherent and Resonant (notes 1 and 2)

- The far set pieces in `_spectacle()` (the hanging chunk and the high block) read as floating debris, which is exactly note 1's complaint. Replace them with a continuous mirrored city overhead in the Resonant sense, as in images 08 and 39: copies of your street chunks upside down far above, faded by fog, with a slit of sky between. Rebuild the hard-hinged bent tower as one continuously curving building (image 06).
- `FallingFront` is a 1.2 m slab. Make it a full-depth building front: side facades, cornice, roof equipment.
- `RisingDistrict` is the best fold you have, but it happens off to the side, where it barely registers in the running view. Turn and stage it so its street faces the route, and it stays visible before, during and after its motion. Bring it onto the route if it fits within 60 to 90 seconds.
- Retime the fold triggers so a full-speed runner never stands waiting on a fold. The bot currently stops twice.
- **Check:** the full-route contact sheets show the same block before, during and after its fold, and no isolated floating shapes in any sky.

## 5. The crest

From 31 to 35 s the view is mostly empty sky or flat wall. Put a landmark on tower B's roof, on the route line just past the crest, so it is visible during the whole run up the wall. **Check:** no frame in that window is more than about 60% sky or flat wall.

## 6. Atmosphere toward image 38

The scene washes out to mid-grey: dark pixels are under 4% of the frame, against roughly 30 to 55% in images 38, 32 and 08.
- Darken the dusk and drop the ambient light.
- Move the sun so it rims the forms instead of sitting behind the runner.
- Add gentle glow so the warm windows read against dark silhouettes.
- Vary the facades, and separate concrete, glass and metal.
- Fix the concentric shadow-acne rings on the roofs.
- Late roofs need foreground detail.

**Check:** the same start, fold, wall-run and finish views before and after.

## Declined

- **A camera that leads the gravity turn:** it would fight the player's free look. The crest landmark solves the same problem.
- **Exact replacement coordinates and colour values from the reviews:** the numbers above are the targets, and the layout is your call.

You will be scored again on the same nine categories once `checkpoints/7.md` lands.
