extends "r16-pack-probe.gd"
## exact normal r17 scene; reuse the delivered r16 input, recording and ghost observer.

func captured(name: String, wanted: Dictionary) -> Dictionary:
	var state: Dictionary = await super.captured(name,wanted)
	var label := game.look_label as Control
	for field: String in ["lab_tag", "lab_panel", "practice_tag"]:
		var control := game.hud.get(field) as Control
		check(name+": R17 label clears inherited "+field,not control.is_visible_in_tree() or not label.get_global_rect().intersects(control.get_global_rect()),
			{"look":str(label.get_global_rect()),"inherited":str(control.get_global_rect())})
	check(name+": R17 label stays in view",get_viewport().get_visible_rect().encloses(label.get_global_rect()),str(label.get_global_rect()))
	return state

func _check_identity() -> void:
	super._check_identity()
	check("R17 inherits the delivered R16 main", _script_chain(game).slice(0, 2) == ["res://scripts/r17_main.gd", "res://scripts/r16_main.gd"], _script_chain(game))
	check("R17 presentation identity", str(ProjectSettings.get_setting("application/config/version")) == "2026.11.09-r17" and str(game.look_label.text).begins_with("R17") and game.window_title().begins_with("Spillway R17"))
	check("inherited R16 session and services active", _script_path(game.session) == "res://scripts/r16_run_session.gd" and _script_path(game.session.style) == "res://scripts/r16_style.gd" and _script_path(game.session.recorder) == "res://scripts/r16_run_recorder.gd" and _script_path(game.session.ghost) == "res://scripts/r16_ghost.gd")
	for map: String in game.PRESENTATION.PALETTES.MAPS:
		var sky: String = game.PRESENTATION.PALETTES.MAPS[map].sky
		check(map + ": exported sky dependency loads", ResourceLoader.exists(sky) and load(sky) is Texture2D, sky)

func _geometry() -> String:
	var rows: Array = [game.level.manifest, game.level.spawn, game.level.checkpoints, game.level.segment_bounds, game.course_geometry, game.overlay_id, game.course_key, game.motion_identity()]
	for node: Node in game.level.find_children("*", "CollisionShape3D", true, false):
		rows.append([str(game.level.get_path_to(node.get_parent())), node.global_transform, node.disabled, node.shape.get_debug_mesh().get_faces()])
	return var_to_str(rows).sha256_text()

func _behavior() -> String:
	return var_to_str([game.player.global_transform, game.player.velocity, game.elapsed, game.checkpoint_index, game.attempts, game.finished, game.clean_eligible, game.session.style.snapshot(), game.session.ghost_state, game.record_identity(), game.motion_identity()])

func _controls() -> void:
	await super._controls()
	var maps: Array = expect.identity.registry.maps
	var home: String = game.map_id
	var results: Array = []
	for map: String in maps:
		if game.map_id != map:
			await _pause_menu_click("Map_" + map, "R17 map " + map)
			await _physics(5)
		await _tap(KEY_ESCAPE)
		check(map + ": paused for atomic L comparison", game.paused)
		var geometry := _geometry()
		var state := _behavior()
		var original: bool = game.look_enabled
		await captured("r17-" + map + "-paint", {"map": map, "paused": true})
		await _tap(KEY_L)
		check(map + ": L selects original R16 presentation", game.look_enabled != original and not game.look_layer.enabled and game.look_label.text.contains("original R16"))
		check(map + ": L preserves collision, progress and identities", geometry == _geometry() and state == _behavior())
		var restored := true
		for swap: Dictionary in game.look_layer.swaps:
			var material: Material = swap.node.get_surface_override_material(swap.surface) if swap.has("surface") else swap.node.material_override
			restored = restored and material == swap.old
		if game.look_layer.world != null:
			restored = restored and game.look_layer.world.environment == game.look_layer.old_environment
		for light: Dictionary in game.look_layer.light_states:
			restored = restored and light.node.rotation == light.rotation and light.node.light_color == light.color and light.node.light_energy == light.energy
		check(map + ": original material, environment and light references restored", restored)
		await captured("r17-" + map + "-original", {"map": map, "paused": true})
		await _tap(KEY_L)
		check(map + ": second L restores painted presentation without gameplay writes", game.look_enabled == original and game.look_layer.enabled and geometry == _geometry() and state == _behavior())
		await captured("r17-" + map + "-restored", {"map": map, "paused": true})
		results.append({"map": map, "geometry_sha256": geometry, "look": game.look_layer.report})
		await _tap(KEY_ESCAPE)
	if game.map_id != home:
		await _pause_menu_click("Map_" + home, "restore R17 start map")
		await _physics(5)
	report["r17_maps"] = results
