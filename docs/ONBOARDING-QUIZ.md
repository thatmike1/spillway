# START-HERE reader check

Give a fresh reader only START-HERE.md and ask these five questions. The lead owns the fresh-agent run; the implementation job starts no child agents.

1. Which configured scene starts the game, where is the current implementation, and which inherited module owns map selection and the shared physics loop?
2. Where are the F2 collision/velocity implementation and Source acceleration laws, and why does the old runner resource path stay?
3. Where would you inspect Tether Yard geometry versus rope force/acquisition behavior? Are Fall Line and Line Drive in the current menu?
4. Which service samples the completed motor step, where are scoring/recording/ghost implementations, and where do user settings and attempts go?
5. What are the ordinary and full verification commands? What exact original-map result is required, and where do release builds go?

Expected answers:

1. `scenes/r21.tscn`; stable `scripts/r21_main.gd` forwards to `scripts/game.gd`; `scripts/r16_main.gd` owns shared selection/lifecycle/physics.
2. `scripts/movement/course_player.gd` and `source_motion.gd`; `scripts/r15_source_player.gd` remains a compatibility identity used by recordings and type checks.
3. `scripts/maps/tether_yard.gd` versus `scripts/movement/grapple_player.gd`; Fall Line and Line Drive are retained dependencies but shelved from the menu.
4. `scripts/recordings/session.gd`; `scripts/scoring/style.gd` and `scripts/recordings/{recorder,reader,ghost}.gd`; `user://spillway_r16.cfg` and `user://r16_runs/`.
5. `python3 tools/test.py` and `python3 tools/test.py --slow`; 48 plays, 16 routes, 288 exact comparisons with zero differences; GitHub releases on the private repository.
