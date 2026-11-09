extends "res://tests/r19_tether_route.gd"
## input restart and pause while attached, then actual map transitions through the R19 host.
var phase := "first attachment"
var phase_tick := 0
var checks: Array = []
var pause_state: Dictionary = {}
var lifecycle_done := false
var first_body: WeakRef
var frozen_ticks := 0

func _control_source(tick: int) -> void:
	match phase:
		"first attachment":
			if not player.grapple.is_empty() and player.grapple_ticks > 30:
				_want({}, tick)
				_key("r", true, tick)
				_key("r", false, tick)
				check(player.grapple.is_empty() and player.grapple_count == 0, "R clears attached rope and counts")
				check(player.position.distance_to(level.spawn.origin) < 0.01 and game.checkpoint_index == 0, "R uses normal authored spawn and clears progress")
				check(game.clean_eligible and game.respawn_count == 0, "R begins a new clean attempt")
				node_index = 0
				node_from = Vector2(player.position.x, player.position.z)
				phase = "second attachment"
				return
			follow(tick)
		"second attachment":
			if not player.grapple.is_empty() and player.grapple_ticks > 30:
				_key("esc", true, tick)
				_key("esc", false, tick)
				check(game.paused and not player.input_enabled, "Esc pauses actual host while rope is attached")
				pause_state = {"p": player.position, "v": player.velocity, "rope_ticks": player.grapple_ticks, "length": player.grapple_length_u, "elapsed": game.elapsed}
				phase = "paused"
				phase_tick = tick
				return
			follow(tick)
		"paused":
			frozen_ticks += 1
			check(player.position == pause_state.p and player.velocity == pause_state.v and player.grapple_ticks == pause_state.rope_ticks and player.grapple_length_u == pause_state.length and game.elapsed == pause_state.elapsed, "paused simulation and rope remain exact")
			if tick - phase_tick >= 20:
				_key("esc", true, tick)
				_key("esc", false, tick)
				check(not game.paused and player.input_enabled, "Esc resumes actual host")
				phase = "resumed"
				phase_tick = tick
		"resumed":
			if tick - phase_tick < 5:
				return
			check(player.grapple_ticks > int(pause_state.rope_ticks), "attached rope resumes ticking")
			for key: String in ["one", "two", "three", "shift"]:
				_key(key, true, tick)
				_key(key, false, tick)
			player.set_mechanic("slide", true)
			player.set_mechanic("wall_jump", true)
			player.set_mechanic("grapple", false)
			check(not player.mechanic_enabled("slide") and not player.mechanic_enabled("wall_jump") and player.mechanic_enabled("grapple") and game.lab_moves().is_empty(), "number keys, Shift and setters cannot change fixed loadout")
			check(player._wall_step(Vector3(20, 0, 0), false) == Vector3.ZERO and not player.slide_active and player.wall_jump_count == 0, "other lab move hooks remain physically inactive")
			check(not player._ring_material.emission_enabled and not player._tether_material.emission_enabled, "grapple materials have no emission")
			first_body = weakref(player)
			_want({}, tick)
			game.select_map("breakwater")
			player = game.player
			level = game.level
			check(first_body.get_ref() == null, "leaving map frees grapple body")
			check(game.runner_path() == "res://scripts/r15_source_player.gd" and not player.has_method("mechanic_enabled"), "main map restores exact R15 course runner")
			check(root.get_tree().get_nodes_in_group("r15_grapple_anchor").is_empty(), "leaving tether removes all tether anchors")
			phase = "main map"
			phase_tick = tick
		"main map":
			if tick - phase_tick < 5:
				return
			game.select_map("experiment")
			player = game.player
			level = game.level
			check(game.runner_path() == "res://scripts/r16_experiment_player.gd" and player.mechanic_enabled("slide") and player.mechanic_enabled("wall_jump") and player.mechanic_enabled("grapple"), "original Movement Lab retains all original moves")
			game.select_map("tether-yard")
			player = game.player
			level = game.level
			check(game.runner_path() == str(TETHER_LEVEL.MAP_ENTRY.runner) and player.grapple.is_empty() and player.grapple_count == 0 and game.checkpoint_index == 0, "returning to tether starts a fresh fixed runner at normal spawn")
			check(root.get_tree().get_nodes_in_group("r15_grapple_anchor").size() == 3, "returning creates exactly three anchors")
			check(game.window_title().contains("EXPERIMENTAL"), "experimental title is present")
			lifecycle_done = true

func follow(tick: int) -> void:
	super._control_source(tick)

func _route_finished(_tick: int) -> bool:
	return lifecycle_done

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func _observe(_tick: int) -> void:
	# this probe changes maps through host APIs, so its observations have explicit boundaries.
	pass

func _accept(summary: Dictionary) -> bool:
	summary["checks"] = checks
	summary["frozen_ticks"] = frozen_ticks
	summary["lifecycle_done"] = lifecycle_done
	return lifecycle_done and frozen_ticks >= 20 and checks.all(func(c: Dictionary) -> bool: return bool(c.ok)) and not summary.recordings.is_empty() and summary.recordings.all(func(r: Dictionary) -> bool: return bool(r.ok))
