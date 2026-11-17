extends SceneTree
## compare the delivered r21 identity and real solids, including both look states.
const LEVEL := preload("res://scripts/maps/saltglass.gd")
const LOOK := preload("res://scripts/r17_look.gd")
const AUDIT := preload("res://verification/frozen/r21_surf_geometry.gd")
const HASH := "082ccbc2b6fcadce607bb6c22f4376ca812f14bd928d4b1955f4f8414a59b0dd"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	assert(level.geometry_hash() == HASH, "art must retain delivered r21 identity")
	assert(AUDIT.audit(level).ok, "manifest must match actual collision")
	for node: Node in level.get_children():
		if not str(node.name).begins_with("Art_paint_lip_"):
			continue
		var supported := false
		for piece: Dictionary in level.manifest:
			var polygon := PackedVector2Array()
			for point: Vector3 in piece.points.slice(0, 4):
				polygon.append(Vector2(point.x, point.z))
			if Geometry2D.is_point_in_polygon(Vector2(node.position.x, node.position.z), polygon):
				supported = supported or absf(node.position.y - piece.points[0].y) < 0.03
		assert(supported, "paint lip must sit on a real deck: " + str(node.name))
	var before := solids(level)
	var look := LOOK.new()
	root.add_child(look)
	look.attach(level, "practice")
	assert(look.swaps.size() > 0 and look.world != null)
	for enabled: bool in [true, false, true]:
		look.set_enabled(enabled)
		assert(solids(level) == before and level.geometry_hash() == HASH)
		for node: Node in level.get_children():
			if str(node.name).begins_with("SaltglassSurface_"):
				assert(node.material_override is ShaderMaterial)
		assert(level.get_node("Art_paint_lip_outside_receiver").visible)
	print("PASS saltglass art: r21 hash, real solids and slope shader retained through both look states")
	look.free()
	level.free()
	quit()

func solids(level: Node3D) -> Dictionary:
	var result := {}
	for body: Node in level.find_children("*", "StaticBody3D", true, false):
		for shape: Node in body.get_children():
			if shape is CollisionShape3D:
				result[str(body.name)] = [body.transform, shape.transform, shape.shape.points]
	return result
