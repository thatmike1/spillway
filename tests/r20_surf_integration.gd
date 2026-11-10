extends SceneTree
## production registration, revision separation, inherited identities and actual look/collision checks.
const R19 := preload("res://scenes/r19.tscn")
const R20 := preload("res://scenes/r20.tscn")
const OLD_MAPS := preload("res://scripts/r19_map_catalog.gd")
const NEW_MAPS := preload("res://scripts/r20_map_catalog.gd")
const BASE_MAPS := preload("res://scripts/r15_maps.gd")
const READER := preload("res://scripts/r16_run_reader.gd")
const GEOMETRY := preload("res://tests/r20_surf_geometry.gd")
var output := ""
var checks: Array = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "check": label})
	if not ok:
		push_error(label)

func host(scene: PackedScene, map: String) -> Node3D:
	var game: Node3D = scene.instantiate()
	game.map_id = map
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = output.path_join("absent.cfg")
	game.ghosts_directory = output.path_join("ghosts")
	game.ghost_share_storage = output.path_join("selection.cfg")
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	return game

func run() -> void:
	RenderingServer.render_loop_enabled = false
	assert(output.is_absolute_path())
	DirAccess.make_dir_recursive_absolute(output)
	var old_maps := OLD_MAPS.make()
	var new_maps := NEW_MAPS.make()
	check(old_maps.order == new_maps.order and old_maps.default_chain == new_maps.default_chain, "catalog order and defaults retained")
	for id: String in old_maps.order:
		check(new_maps.catalog[id] == old_maps.catalog[id] if id != "saltglass" else new_maps.catalog[id].script == "res://scripts/r20_surf_level.gd", "catalog: " + id)
	var identities := {}
	for id: String in BASE_MAPS.ORDER + ["saltglass"]:
		var old := host(R19, id)
		var before: Dictionary = old.motion_identity()
		old.request_quit(0)
		old.free()
		var game := host(R20, id)
		var after: Dictionary = game.motion_identity()
		var matches := READER.identity_matches(before, after).is_empty()
		identities[id] = {"before": before, "after": after, "compatible": matches}
		check(matches if id != "saltglass" else not matches and before.geometry != after.geometry, "local ghost motion identity: " + id)
		check("Spillway R20" in game.window_title() and "R19" not in game.window_title(), "R20 window title: " + id)
		if id == "breakwater":
			check(game.map_revision.version == "r19-breakwater-flow-1" and before.overlay == after.overlay, "delivered R19 Breakwater gate revision retained")
		if id == "saltglass":
			check("Older Saltglass ghosts" in game.map_revision_description(), "clear older-map note")
			check(game.recording_metadata("proof").build == "spillway-2026.11.10-r20" and game.recording_metadata("proof").build_label == "Spillway R20", "R20 recording and sharing build")
			check(game.level.find_children("Art_paint_dark_crest_*", "MeshInstance3D", true, false).is_empty(), "no redundant authored crest cylinders")
			check(game.level.level_id == "r20-saltglass" and game.level.level_version == 2, "new level identity")
			var geometry := GEOMETRY.audit(game.level)
			check(geometry.ok, "new geometry matches actual collision")
			var before_solids: Dictionary = solid_points(game.level)
			var painted: bool = game.look_enabled and game.look_layer.enabled
			key(KEY_L)
			check(painted and not game.look_enabled and not game.look_layer.enabled, "inherited L turns LookC off")
			check(solid_points(game.level) == before_solids and game.motion_identity() == after, "L off preserves all collision and identity")
			key(KEY_L)
			check(game.look_enabled and game.look_layer.enabled and solid_points(game.level) == before_solids, "L restores LookC without collision changes")
			check(game.look_layer.report.sky == "res://assets/look/r17/practice-sky.png" and game.look_layer.report.ink_segments > 0 and game.look_layer.report.jump_lips > 0, "practice palette, static painted sky, ink and gap lips attached")
		game.request_quit(0)
		game.free()
	var experiment := host(R20, "tether-yard")
	check("EXPERIMENTAL" in experiment.window_title(), "inherited experimental suffix retained")
	experiment.request_quit(0)
	experiment.free()
	var result := {"ok": checks.all(func(row: Dictionary) -> bool: return row.ok), "checks": checks, "identities": identities, "limit": "headless integration and collision checks; native presentation belongs to parent"}
	var file := FileAccess.open(output.path_join("integration.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("R20 surf integration: ", result.ok, " checks=", checks.size())
	quit(0 if result.ok else 1)

func key(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func solid_points(level: Node3D) -> Dictionary:
	var result := {}
	for row: Dictionary in level.manifest:
		var body := level.get_node(NodePath(row.name)) as StaticBody3D
		var collision := body.get_child(0) as CollisionShape3D
		result[row.name] = Array((collision.shape as ConvexPolygonShape3D).points).map(func(p: Vector3) -> Vector3: return body.transform * collision.transform * p)
	return result
