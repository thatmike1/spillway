extends SceneTree
## live-host visual scope: resources restore on exit and never enter motion identity or law.
const HOST := preload("res://scripts/game.gd")
const CABLE := preload("res://scripts/art/viaduct_cable.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game := HOST.new()
	game.map_id = "viaduct"
	game.motor = "server128"
	game.persist = false
	game.record_runs = false
	game.seed_from_r15 = false
	game.set_window_title = false
	game.profile_path = "/tmp/r22-01-swing-flow/presentation-absent.cfg"
	game.ghosts_directory = "/tmp/r22-01-swing-flow/presentation-ghosts"
	game.ghost_share_storage = "/tmp/r22-01-swing-flow/presentation-selection.cfg"
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	var tether := game.player.get_node("GrappleTether") as MeshInstance3D
	var original_mesh := tether.mesh
	var original_material := tether.material_override
	var identity: Dictionary = game.motion_identity()
	var dam := game.level.get_node("ViaductDam")
	assert(dam.find_children("*","CollisionObject3D",true,false).is_empty())
	assert(dam.find_children("*","CollisionShape3D",true,false).is_empty())
	assert(identity.course_key == "be901b697eb867b0")
	var law: String = game.player.r21_law_sha256()
	await process_frame
	await process_frame
	var checks := [is_equal_approx(float(tether.mesh.get("top_radius")),0.0015),tether.mesh != original_mesh,tether.material_override != original_material,game.motion_identity() == identity,game.player.r21_law_sha256() == law]
	checks.append(not game.level.is_finish_at(game.level.UPPER_LANDING.get_center()))
	game.player.reset_to(Transform3D(Basis.IDENTITY,Vector3(-15,10,-68)))
	for _tick: int in 4:
		await physics_frame
		game.player._physics_process(1.0/128)
	var inside_upper: bool = game.level.UPPER_LANDING.has_point(game.player.global_position)
	var airborne: bool = not game.player.is_grounded()
	var upper_rejected: bool = not game.level.is_finish_at(game.player.global_position)
	checks.append(inside_upper)
	checks.append(airborne)
	checks.append(upper_rejected)
	print("VIADUCT AIRBORNE UPPER inside=",inside_upper," airborne=",airborne," rejected=",upper_rejected)
	for _tick: int in 200:
		if game.player.is_grounded():
			break
		await physics_frame
		game.player._physics_process(1.0/128)
	checks.append(game.level.UPPER_LANDING.has_point(game.player.global_position) and game.player.is_grounded())
	checks.append(not game.level.is_finish_at(game.player.global_position))
	print("VIADUCT UPPER LANDING feet=",game.player.global_position," grounded=",game.player.is_grounded()," finish=",game.level.is_finish_at(game.player.global_position))
	game.player.reset_to(game.level.spawn)
	var deck := game.level.get_node("Mesh_deck_viaduct_terrace_0_0_0") as MeshInstance3D
	checks.append(deck.material_override is ShaderMaterial and deck.material_override.shader.resource_path == "res://shaders/look/surface.gdshader")
	checks.append(deck.material_override.get_shader_parameter("top_color") == Color("cfc9b9"))
	var original_layers: int = tether.layers
	game.change_setting("tether_rope_visual",true)
	checks.append(tether.layers == 0 and game.tether_feedback.enabled("tether_rope_visual"))
	game.change_setting("tether_rope_visual",false)
	checks.append(tether.layers == original_layers and not game.tether_feedback.enabled("tether_rope_visual"))
	var observer: Node
	for child: Node in game.level.get_children():
		if child.get_script() == CABLE:
			observer = child
	if observer == null:
		game.free()
		quit(1)
		return
	game.level.remove_child(observer)
	checks.append(tether.mesh == original_mesh and tether.material_override == original_material)
	checks.append(game.motion_identity() == identity and game.player.r21_law_sha256() == law)
	observer.free()
	game.select_map("tether-yard")
	game.player.set_physics_process(false)
	await process_frame
	var next_tether := game.player.get_node("GrappleTether") as MeshInstance3D
	checks.append(is_equal_approx(float(next_tether.mesh.get("top_radius")),0.018))
	var ok := checks.all(func(value: bool) -> bool: return value)
	print("VIADUCT PRESENTATION ",ok," checks=",checks)
	game.request_quit(0)
	game.free()
	quit(0 if ok else 1)
