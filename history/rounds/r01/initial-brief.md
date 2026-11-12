# Foldrunner: first playable slice

## Fantasy

Run through a recognizable city that folds into impossible architecture. Preserve momentum while streets, facades and ceilings exchange roles. Reference: Control Resonant gravity anomalies and Doctor Strange's folding city; parkour rhythm inspired by Mirror's Edge. Original code and geometry, no extracted game assets.

## Sequence

1. Ordinary roof: learn sprint, jump and camera controls; amber accents identify the path.
2. Folding facade: crossing a roof trigger opens a rigid bridge into the next roof.
3. Checkpoint: immediate recovery on falling, retaining current architecture state.
4. Gravity ribbon: travel from horizontal roof through wall to underside; panoramic skyline supplies the spectacle.
5. Impossible window: cross a masked seam to a remote upright district with transformed momentum.
6. Final roof: reach beacon, see time, restart instantly.

The target is a short replayable traversal slice. Timing and human reachability are unverified until a graphical playtest. Initial bridge is one unfolding rigid facade; continuous multi-building folding during traversal is a follow-up.

## Visual direction

Dark blue/charcoal architecture, warm amber traversal accents, sparse cool cyan highlights. Monumental repeated buildings and impossible tilted clusters around a simple readable foreground route. Silhouettes and contrast do the work before detailed textures. Default head bob off; camera roll adjustable. No jump-scare or combat requirements.

## First-pass commitments

- [x] Original rooftop scene with route, checkpoint and finish.
- [x] Sprint/jump/crouch, collision-driven vault/wall-run, configurable comfort.
- [x] Folding collision geometry, local gravity and swept seam crossing.
- [x] Headless system tests and integrated reset/pause/progression tests.
- [x] Browser export feasibility checked with Compatibility renderer.
- [x] Run instructions and recorded limitations.
- [ ] Visual/feel QA after Mike is done gaming.

## Reference notes

- Remedy description of changing gravity and orientation: https://www.remedygames.com/article/remedy-entertainment-unveils-new-gameplay-details-for-control-resonant
- Character motion primitives: https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html
- Physics-synchronized moving structures: https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html
- Portal reference implementation (studied; not copied into the prototype): https://github.com/io12/godot-portal-demo

Mike's direct account of playing Resonant is the primary creative brief. No screenshots, clips or game assets were captured. A later reference pass can collect specific licensed/user-provided footage if useful; it is not a blocker for this original prototype.
