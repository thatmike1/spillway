extends RefCounted
## a post-finish dispatch court catches ordinary coasting without moving the timed destination.
const GEO := preload("res://scripts/r19_course_geometry.gd")

static func build(level: Node3D, far: float, near: float, stage: int, sign_at := 0.0) -> void:
	GEO.prism(level, "dispatch_runout", GEO.rectangle(-15.5, 15.5, far, near, 4), -5, stage, "structure")
	var concrete: Material = level.get_node("Mesh_deck_apron_0_pad_-1").material_override
	var paving := concrete.duplicate() as ShaderMaterial
	paving.set_shader_parameter("deck", 1.0)
	level.get_node("Mesh_deck_dispatch_runout").material_override = paving
	GEO.prism(level, "dispatch_endstop", GEO.rectangle(-15.5, 15.5, far, far + 0.6, 6.4), 4, -1, "wall")
	# keep the same solid safety barrier, represented by a glazed balustrade rather than a wall.
	level.get_node("Mesh_deck_dispatch_endstop").visible = false
	level.prisms.pop_back()
	level._box("Art_dispatch_sill", Vector3(0, 4.35, far + 0.3), Vector3(31, 0.7, 0.6), Color("677371"))
	for i: int in 7:
		var x := -15.4 + i * (30.8 / 6)
		level._box("Art_dispatch_rail_post_%d" % i, Vector3(x, 5.55, far + 0.3), Vector3(0.08, 1.7, 0.12), Color("4e727e"))
	level._box("Art_dispatch_glass", Vector3(0, 5.55, far + 0.3), Vector3(30.8, 1.7, 0.025), Color(0.55, 0.73, 0.77, 0.12))
	var pane := level.get_node("Art_dispatch_glass") as MeshInstance3D
	var glass := pane.material_override as StandardMaterial3D
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: float in [-15.5, 15.5]:
		level._box("Art_dispatch_curb_%s" % x, Vector3(x, 4.18, (far + near) * 0.5), Vector3(0.3, 0.35, near - far), Color("5e6765"))
	level._box("Art_dispatch_cap", Vector3(0, 6.42, far + 0.3), Vector3(31, 0.08, 0.75), Color("a87a54"))
	sign_panel(level, near if is_zero_approx(sign_at) else sign_at, stage)

static func sign_panel(level: Node3D, near: float, stage: int) -> void:
	# the sign is a physical panel carried by a beam on the two side quays.
	var sign_z := near + 0.1
	for x: float in [-13, 13]:
		level._box("Art_dispatch_post_%d_%s" % [stage, x], Vector3(x, 7.2, sign_z), Vector3(0.35, 6.6, 0.45), Color("344b53"))
	level._box("Art_dispatch_header_%d" % stage, Vector3(0, 10.4, sign_z), Vector3(26.4, 0.35, 0.45), Color("344b53"))
	level._box("Art_dispatch_sign_%d" % stage, Vector3(0, 9.4, sign_z), Vector3(3.8, 0.8, 0.12), Color("d2c1a1"))
	var board := level.get_node("Art_dispatch_sign_%d" % stage) as MeshInstance3D
	var paint := board.material_override as StandardMaterial3D
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x: float in [-1.8, 1.8]:
		level._box("Art_dispatch_sign_hanger_%d_%s" % [stage, x], Vector3(x, 10.0, sign_z), Vector3(0.045, 1.2, 0.045), Color("344b53"))
	var label := level.get_node("Sign_dispatch" if stage == 2 else "Sign_outer_dispatch") as Label3D
	# offset the transfer board above the left quay, leaving the receiving lane unobscured.
	var sign_x := -10.0 if level.variant == "gantry-chain" and stage == 2 else 0.0
	level.get_node("Art_dispatch_sign_%d" % stage).position.x = sign_x
	for x: float in [-1.8, 1.8]:
		var hanger := level.get_child(level.get_child_count() - (1 if x > 0 else 2)) as MeshInstance3D
		hanger.position.x += sign_x
	label.position = Vector3(sign_x, 9.4, sign_z + 0.09)
	label.pixel_size = 0.007
	label.modulate = Color("263d45")
	level.art_manifest.append(["dispatch_sign_offset", stage, sign_x])
