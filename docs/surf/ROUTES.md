# R12 route evidence

P / the full-course fast line uses scripts/spillway_surf_driver.gd, selected by --bot --route=fast. The ordinary waypoint driver still handles safe, brake, wet, recovery and safe_corner. Both use engine action and mouse events only. The surf driver reads exact physics state and authored geometry; its13.658s line is executable input, not a human performance claim.

The surf driver's traces include raw mouse/action events, per-tick state, ordered stages and an explicit result. --bot-quit exits after the result. --seed supplies a fixed run-wide aim bias, default range0.012rad for nonzero seeds. --aim-deg sets its range explicitly. --jump-delay shifts the initial Crest takeoff by speed×delay; it does not pretend to perturb automatic landing-tick hops. Safe-route timing perturbation still schedules each waypoint jump. The trace records which policy ran.

The full-course R11 fast waypoints and its fast_direct_finish, fast_housing_turn and rail_hop_recovery aliases are retired. The stepping supports and the apron/run-up junction they targeted no longer exist. The actual-level access suite explicitly replaces the old apron-hop expectations with a notch-hop check. This retires obsolete geometry acceptance, not a failed physical requirement. Historical R11 matrices and logs remain unchanged.

The active no-walk measure counts turns and brief stops. Source-stage safe/safe_corner/brake each report at most3.65s ordinary running. Wet7.5s and recovery18.55s remain open course weaknesses. The final frozen R12 matrix must list its cases and denominators separately from R11's41 attempts. Exact-pack traces and native final routes remain delivery gates.
