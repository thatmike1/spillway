extends SubViewportContainer
## render-only ghosts in the existing map world. no bodies, input replay or progress.
const LOOK := preload("res://scripts/r18_ui_theme.gd")
const READER := preload("res://scripts/recordings/reader.gd")
const REVIEW_LAYER := 1 << 19
var viewport: SubViewport
var camera: Camera3D
var actors: Array[MeshInstance3D] = []
var tracks: Array = []
var world_identity := {}
var scenery: Node3D
var follow_target := 0

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(260, 210)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.own_world_3d = true
	scenery = Node3D.new()
	viewport.add_child(scenery)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = LOOK.SEA
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = LOOK.CREAM
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	viewport.add_child(sun)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.handle_input_locally = false
	add_child(viewport)
	camera = Camera3D.new()
	camera.cull_mask = REVIEW_LAYER | ((1 << 19) - 1)
	camera.far = 1500
	viewport.add_child(camera)
	camera.current = true
	for tint: Color in [LOOK.TEAL, LOOK.CORAL_DEEP]:
		var actor := MeshInstance3D.new()
		var mesh_ := CapsuleMesh.new()
		mesh_.height = 1.75
		mesh_.radius = 0.28
		actor.mesh = mesh_
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = tint
		actor.material_override = material
		actor.layers = REVIEW_LAYER
		actor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewport.add_child(actor)
		actors.append(actor)

func attach_map(source: Node3D, identity: Dictionary) -> void:
	for child: Node in scenery.get_children():
		child.free()
	world_identity = identity.duplicate(true)
	_copy_visuals(source)

func _copy_visuals(source: Node) -> void:
	var copy: GeometryInstance3D
	if source is MeshInstance3D and source.mesh != null and source.is_visible_in_tree():
		var mesh := MeshInstance3D.new()
		mesh.mesh = source.mesh
		for i: int in source.mesh.get_surface_count():
			mesh.set_surface_override_material(i, source.get_active_material(i))
		copy = mesh
	elif source is MultiMeshInstance3D and source.multimesh != null and source.is_visible_in_tree():
		var mesh := MultiMeshInstance3D.new()
		mesh.multimesh = source.multimesh
		copy = mesh
	if copy != null:
		copy.material_override = source.material_override
		copy.material_overlay = source.material_overlay
		scenery.add_child(copy)
		copy.transform = source.global_transform
	for child: Node in source.get_children():
		_copy_visuals(child)

func load_pair(pair: Dictionary) -> String:
	clear()
	if not pair.get("ok", false):
		return "Choose a comparable recording pair first."
	if world_identity.is_empty() or not READER.identity_matches(pair.attempt.identity, world_identity).is_empty():
		return "Load this attempt's map, preset and geometry to see its 3D review."
	for run: Dictionary in [pair.attempt, pair.best]:
		var columns: Dictionary = run.run.columns
		var times := PackedFloat64Array()
		var poses := PackedVector3Array()
		var yaw := PackedFloat64Array()
		var ducked := PackedByteArray()
		for i: int in columns.tick.size():
			if columns.flags[i] & 1 != 0:
				if times.is_empty() and i > 0:
					times.append(0.0)
					poses.append(columns.p[i - 1])
					yaw.append(columns.yaw[i - 1])
					ducked.append(1 if columns.flags[i - 1] & 16 != 0 else 0)
				times.append(columns.elapsed[i])
				poses.append(columns.p[i])
				yaw.append(columns.yaw[i])
				ducked.append(1 if columns.flags[i] & 16 != 0 else 0)
				if columns.flags[i] & 2 != 0: break
		tracks.append({"times": times, "poses": poses, "yaw": yaw, "ducked": ducked})
	scrub_to(0)
	return ""

func clear() -> void:
	tracks.clear()
	for actor: MeshInstance3D in actors:
		actor.visible = false

func pose_at(track: Dictionary, time: float) -> Vector3:
	return _sample(track, time).feet

func _sample(track: Dictionary, time: float) -> Dictionary:
	var hi := clampi(track.times.bsearch(time), 0, track.times.size() - 1)
	var lo := maxi(hi - 1, 0)
	var span: float = track.times[hi] - track.times[lo]
	var weight := clampf((time - track.times[lo]) / span, 0, 1) if span > 0 else 0.0
	return {"feet": (track.poses[lo] as Vector3).lerp(track.poses[hi], weight),
		"yaw": lerp_angle(track.yaw[lo], track.yaw[hi], weight),
		"ducked": track.ducked[hi if weight >= 0.5 else lo] != 0}

func scrub_to(time: float) -> void:
	if tracks.size() != 2:
		return
	for i: int in 2:
		var pose := _sample(tracks[i], time)
		var height := 1.30 if pose.ducked else 1.75
		(actors[i].mesh as CapsuleMesh).height = height
		actors[i].visible = true
		actors[i].position = pose.feet + Vector3.UP * height * 0.5
		actors[i].rotation.y = pose.yaw
	var target := clampi(follow_target, 0, 1)
	var at := actors[target].position
	var facing := Basis(Vector3.UP, float(_sample(tracks[target], time).yaw))
	camera.position = at + facing * Vector3(0, 3.5, 7)
	camera.look_at(at + Vector3.UP * 0.2)
