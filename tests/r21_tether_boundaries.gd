extends "res://tests/r20_tether_component.gd"
## actual configured R21 production host/UI, including every inherited R20 component gate.
const R21_RUNNER := preload("res://scripts/r21_tether_player.gd")
var r21_routes := ""

func check(ok: bool, label: String) -> void:
	# only the two inherited resource-path expectations change for the production R21 wrapper.
	if label == "production registry selects mouse runner":
		super.check(game.runner_path()=="res://scripts/r21_tether_player.gd","production registry selects actual R21 mouse runner")
	elif label == "actual configured scene uses R20 pause UI":
		super.check(game.hud.get_script().resource_path=="res://scripts/r21_hud.gd","actual configured scene uses R21 pause UI")
	else:
		super.check(ok,label)

func new_case(label: String, stress: String = "", profile: String = "") -> void:
	if game != null:
		close_case()
	case_name = label
	observations = []
	inputs = []
	counter = 0
	game = load("res://scenes/r21.tscn").instantiate()
	game.name = "R21Production"
	game.map_id = "tether-yard"
	game.motor = "server128"
	game.seed_from_r15 = false
	game.source_sensitivity_override = 2.5
	game.set_window_title = false
	game.persist = true
	game.profile_path = output.path_join(label + ".cfg") if profile.is_empty() else profile
	game.record_runs = true
	game.recordings_dir = output.path_join(label + "-recordings")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("share.cfg")
	if old:
		game.source_runner = load(baseline)
	root.add_child(game)
	if stress == "range":
		# labelled extreme tangential entry fixture: initial velocity only, never an after-setup write.
		game.level.spawn = Transform3D(Basis.IDENTITY, Vector3(29.975, 10.4, -8.0))
		game.level.kill_bounds = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
		game._kill_bounds = game.level.kill_bounds
		game.course_geometry = "r20-fixture-range-collisionless-tangent240-v1"
		game._refresh_records()
		game.restart_run("fixture_range")
		game.player.velocity = Vector3(0, 240.0, -240.0)
		for solid: Node in game.level.find_children("*", "StaticBody3D", true, false):
			solid.collision_layer = 0
	elif stress == "obstructed":
		# the eye ray clears this short physical block; the required centre ray does not.
		var block := StaticBody3D.new()
		block.name = "FixtureCentreRayBlock"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2, 0.22, 0.20)
		shape.shape = box
		block.add_child(shape)
		block.position = Vector3(0, 8.4577, 2.0)
		game.level.add_child(block)
		game.course_geometry = "r20-fixture-centre-obstruction-v1"
		game._refresh_records()
		game.restart_run("fixture_obstructed")
	game.hud.dismiss_title()
	# all subsequent player travel is input, except explicit public lifecycle boundaries under test.

func lifecycle_cases() -> void:
	await super.lifecycle_cases()
	await r21_cases()

func r21_cases() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--routes="):
			r21_routes = arg.trim_prefix("--routes=")
	new_case("r21_models")
	await ticks(33)
	check(game.get_script().resource_path == "res://scripts/r21_main.gd" and game.hud.get_script().resource_path == "res://scripts/r21_hud.gd", "actual configured R21 host and HUD instantiated")
	check(game.hud.tether_models.keys() == R21_RUNNER.R21_MODELS, "actual six-model production UI order")
	check(bool(game.settings.tether_anchor_assist), "separate assist preference defaults true")
	var identities := {}
	for model_id: String in R21_RUNNER.R21_MODELS:
		game.set_paused(true)
		activate(game.hud.tether_models[model_id])
		check(game.player.model == model_id, "real keyboard pause button selects " + model_id)
		var ignored: bool = model_id in ["classic","pendulum"]
		check(game.hud.anchor_assist_switch.disabled == ignored and game.player.r21_assist_active() == not ignored, "assist applies only to Elastic family " + model_id)
		var prior_key: String = game.course_key
		if not ignored:
			activate(game.hud.anchor_assist_switch)
			check(not game.settings.tether_anchor_assist and not game.player.r21_assist_active() and game.course_key != prior_key, "actual independently persisted off selection changes identity " + model_id)
			var cfg := ConfigFile.new()
			check(cfg.load(game.profile_path) == OK and cfg.get_value("settings","tether_anchor_assist",true) == false, "assist off saved to actual profile " + model_id)
			identities[model_id+":off"] = game.course_key
			activate(game.hud.anchor_assist_switch)
		identities[model_id+":on"] = game.course_key
		game.set_paused(false)
		rope(false)
		await ticks(1)
		aim(LEVEL.ANCHORS[0])
		await ticks(1)
		var preview: Dictionary = game.player.r21_acquisition_snapshot()
		game.hud._refresh_anchor_readout()
		game.player._process(0.0)
		check(preview.ready and game.hud.displayed_anchor.id==preview.id and "Next" in game.hud.anchor_readout.text and game.player._target_ring.visible and game.player._target_ring.global_position==preview.position,"actual passive Next readout and world ring match authoritative preview " + model_id)
		button(1,true)
		await ticks(1)
		var attached: Dictionary = game.player.r21_acquisition_snapshot()
		check(attached.attached and (ignored or preview.id == attached.id), "actual host prior-preview and attachment agree " + model_id)
		# exercise the parent passive readout; it may observe state, never select a target.
		game.hud._refresh_anchor_readout()
		check(game.hud.displayed_anchor.attached and game.hud.displayed_anchor.name == attached.name and "Attached" in game.hud.anchor_readout.text, "actual passive Attached readout matches runner " + model_id)
		button(1,false)
		await ticks(1)
		game.hud._refresh_anchor_readout()
		check(game.player.grapple.is_empty() and not game.hud.displayed_anchor.attached, "actual release coasts and readout leaves Attached " + model_id)
		# stationary, unreelled full-host hold: exact lifetime for every registered law.
		aim(LEVEL.ANCHORS[0])
		await ticks(1)
		button(1,true)
		await ticks(1)
		var expected_ticks: int = 384 if model_id == "classic" else 640
		var held_rest: float = game.player.grapple_length_u
		await ticks(expected_ticks-1)
		check(not game.player.grapple.is_empty() and game.player.grapple_ticks==expected_ticks and game.player.grapple_length_u==held_rest,"original hold/reel separation and exact attachment lifetime " + model_id)
		await ticks(1)
		check(game.player.grapple.is_empty() and game.player.grapple_release_reason=="time","actual lifetime expires on following physics tick " + model_id)
		var count: int = game.player.grapple_count
		await ticks(5)
		check(game.player.grapple_count==count and not game.player.r21_acquisition_snapshot().ready,"automatic break requires a fresh press " + model_id)
		button(1,false)
		game.set_paused(true)
	check(identities.values().size() == 10 and _unique(identities.values()).size() == 10, "all six laws and Elastic assist states have distinct production record identities")
	new_case("r21_assist_pointer")
	game.change_setting("tether_model","elastic")
	game.set_paused(true)
	var control: CheckButton = game.hud.anchor_assist_switch
	await process_frame
	await process_frame
	control.grab_focus()
	game.hud._pause_scroll.ensure_control_visible(control)
	await process_frame
	await process_frame
	var point := control.get_global_rect().get_center()
	print("assist pointer fixture: rect=",control.get_global_rect()," scroll=",game.hud._pause_scroll.scroll_vertical," viewport=",root.size," visible=",control.is_visible_in_tree()," mode=",Input.mouse_mode)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	send(motion)
	for down: bool in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = down
		send(click)
	await process_frame
	check(not game.settings.tether_anchor_assist and not game.player.r21_assist_active(),"actual pointer on assist pause control changes independent preference")
	game.set_paused(false)
	await ticks(3)
	check(game.player.grapple.is_empty(),"assist menu pointer does not leak into rope acquisition")
	# every real boundary is checked with an earned attachment and held LMB.
	for reason: String in ["practice","respawn","preset","model","automatic_reel","anchor_assist","map"]:
		new_case("r21_boundary_" + reason)
		game.change_setting("tether_model","elastic")
		await ticks(33)
		aim(LEVEL.ANCHORS[0])
		await ticks(1)
		button(1,true)
		await ticks(4)
		check(not game.player.grapple.is_empty(), "earned attachment before real boundary " + reason)
		match reason:
			"practice": game.practise_stage(0)
			"respawn": game.respawn()
			"preset": game.select_preset("server128_aa1000")
			"model": game.change_setting("tether_model","elastic-soft")
			"automatic_reel": game.change_setting("tether_auto_reel",true)
			"anchor_assist": game.change_setting("tether_anchor_assist",false)
			"map": game.select_map("breakwater"); game.select_map("tether-yard")
		await ticks(8)
		check(game.player.grapple.is_empty(), "real boundary clears rope and rejects held input " + reason)
	# matching and wrong model/reel/assist plus the real old-geometry recording.
	if not r21_routes.is_empty():
		var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(r21_routes))
		for model_id: String in R21_RUNNER.R21_MODELS:
			new_case("r21_ghost_" + model_id)
			game.change_setting("tether_model",model_id)
			await ticks(2)
			var summary: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(routes[model_id]).path_join("summary.json")))
			var rec: Dictionary = summary.recordings.filter(func(r: Dictionary) -> bool: return bool(r.clean_finish.get("ok",false)))[0]
			var result: Dictionary = game.session.ghost.load_run(rec.path,game.motion_identity())
			check(result.ok,"actual matching production recording ghost loads " + model_id)
			game.change_setting("tether_auto_reel",true)
			check(not game.session.ghost.load_run(rec.path,game.motion_identity()).ok,"actual wrong-reel recording ghost refuses " + model_id)
			game.change_setting("tether_auto_reel",false)
			if model_id not in ["classic","pendulum"]:
				game.change_setting("tether_anchor_assist",false)
				check(not game.session.ghost.load_run(rec.path,game.motion_identity()).ok,"actual wrong-assist recording ghost refuses " + model_id)
	else:
		check(false,"production route manifest required for ghost identity acceptance")
	new_case("r21_old_geometry")
	var original := "/home/thatmike1/foldrunner-build-2026-11-05/playtest-r20/userdata-spillway/r16_runs/tether-yard_server128_20261111-104715_204_33ac95ce.r16run"
	var read := READER.read(original)
	game.change_setting("tether_model","elastic")
	game.change_setting("tether_auto_reel",true)
	check(read.ok and not game.session.ghost.load_run(original,game.motion_identity()).ok,"actual R20 human recording refused by revised geometry identity")
	game.set_paused(true)
	activate(game.hud.anchor_assist_switch)
	game._save()
	var cfg := ConfigFile.new()
	check(cfg.load(game.profile_path)==OK and cfg.get_value("settings","tether_anchor_assist",true)==false,"final separate-process reload profile saved assist off")
	var file := FileAccess.open(output.path_join("reload-path.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"path":game.profile_path,"model":game.player.model,"automatic":game.player.auto_reel,"assist":game.settings.tether_anchor_assist}))
	file.close()

static func _unique(values: Array) -> Array:
	var out: Array = []
	for value: Variant in values:
		if value not in out:
			out.append(value)
	return out
