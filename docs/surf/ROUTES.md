# R12 route evidence

The full-course fast line uses `scripts/spillway_surf_driver.gd`, selected by `--bot --route=fast`. The ordinary waypoint driver handles safe, brake, wet, recovery and safe_corner. Both send action and mouse events; neither writes velocity or position after normal spawn/reset. The fast controller reads authored geometry and exact physics. Its executable line is not a human performance claim.

Final runtime f84e175d / PCK206baad9: native HUD finishes fast13.700 s, recovery30.433 s, safe43.433 s. The uninterrupted videos, raw inputs and strict clean ordered zero-respawn capture checks are in outer `checkpoints/spillway/r12/native-final-2/`. Source tracing may include a few post-finish simulation ticks; HUD time is authoritative for records. The fast recording's optional post-finish head turn is logged mouse input after braking, not a game camera animation.

`--seed` applies a fixed run-wide aim bias (default range0.012 rad for nonzero seeds). `--aim-deg` sets the range explicitly. `--jump-delay` shifts the initial Crest takeoff by speed×delay; it does not perturb automatic landing hops. Ordinary timing perturbations schedule each waypoint jump. Trace headers identify the policy.

The strict no-walk analysis counts turns and stops: final safe3.65 s, recovery3.45 s, brake/safe_corner/wet3.70 s. Water recovery uses the actual walkable exit, not a reset. A missed bridge can reach the Yard via the new basin ramp; approach its toe from open water. Traversability is proven separately from fresh-player discovery.

R11 fast waypoints and fast_direct_finish, fast_housing_turn and rail_hop_recovery aliases are retired because the stepping supports and apron/run-up junction no longer exist. Tests name their replacement geometry checks. Historical R11 matrices remain unchanged. The former bot stop at the Yard landing marker was repaired by dropping the redundant marker, retaining the real joint hop. A broad lookahead was rejected after breaking two routes; those trials remain in outer ordinary-turn-root/.

See RESULTS.md for denominators, failures, saved records, renderer and platform limits.
