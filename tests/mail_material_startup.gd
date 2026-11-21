extends SceneTree
## keep owned surfaces while retaining the shared painted sky and ink, including across l toggles.
const HOST := preload("res://scripts/game.gd")
const ROOF_MATERIAL := preload("res://scripts/art/mail_roof_material.gd")
var checks: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks.append({"ok": ok, "check": description})
	if not ok:
		push_error("MAIL MATERIAL: " + description)

func _run() -> void:
	for map: String in ["mail-run", "mail-roofs"]:
		var game := HOST.new()
		game.map_id = map
		game.persist = false
		game.record_runs = false
		game.seed_from_r15 = false
		game.set_window_title = false
		game.profile_path = "/tmp/r22-mail-run/material-absent-%d.cfg" % OS.get_process_id()
		_check(not FileAccess.file_exists(game.profile_path), map + " starts without a profile")
		root.add_child(game)
		game.set_paused(true)
		_check(game.look_enabled and is_instance_valid(game.look_layer) and game.look_layer.enabled, map + " retains default painted layer")
		var identity: String = game.course_key
		var pattern := "Mail_roof_Mesh_deck_*" if map == "mail-roofs" else "Mail_quay_Mesh_deck_*"
		var meshes: Array[Node] = game.level.find_children(pattern, "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), map + " owns roof/quay mesh names")
		var roof_code: String = ROOF_MATERIAL.concrete(Color("53666a"), true).shader.code
		for enabled: bool in [true, false, true]:
			game.set_look(enabled)
			_check(game.course_key == identity, map + " look toggle preserves record identity")
			for mesh: MeshInstance3D in meshes:
				var material := mesh.material_override as ShaderMaterial
				var valid := material != null and material.shader != null
				if valid and map == "mail-roofs":
					valid = material.shader.code == roof_code and material.get_shader_parameter("roof") == true
				elif valid:
					valid = float(material.get_shader_parameter("deck")) == 1.0 and (not enabled or material.get_shader_parameter("top_color") != null) and (enabled or material.get_shader_parameter("top_color") == Color("d6d0bd"))
				_check(valid, "%s L=%s owned surface: %s" % [map, enabled, mesh.name])
		game.request_quit(0)
		game.free()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	print("MAIL MATERIAL STARTUP ", JSON.stringify({"ok": ok, "checks": checks}))
	quit(0 if ok else 1)
