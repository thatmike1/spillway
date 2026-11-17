extends SceneTree
## the wave-1 collision/anchor contract survives visual construction and animation.
const PLAYER := preload("res://scripts/movement/grapple_player.gd")
const LEVEL := preload("res://scripts/maps/foundry.gd")
const WAVE1_GEOMETRY := "544896293f49e30f6cecb277b4cfba5298a820ad662a044ab4418db4a17228f5"
var output := "/tmp/r22-02-swing-height/scenery"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func v3(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func pose(value: Transform3D) -> Array:
	return [v3(value.basis.x),v3(value.basis.y),v3(value.basis.z),v3(value.origin)]

func physical(node: Node) -> Array:
	var rows: Array = []
	if node is CollisionObject3D:
		rows.append([str(node.get_path()),pose(node.global_transform),node.collision_layer,node.collision_mask])
	if node is CollisionShape3D:
		var points: Array = []
		if node.shape is ConvexPolygonShape3D:
			for point: Vector3 in node.shape.points:
				points.append(v3(point))
		rows.append([str(node.get_path()),pose(node.global_transform),node.disabled,node.shape.get_class(),node.shape.margin,points])
	for child: Node in node.get_children():
		rows.append_array(physical(child))
	return rows

func reject_manifest(reason: String, diagnostics: bool) -> bool:
	if diagnostics:
		print("manifest mismatch: "+reason)
	return false

func manifest_matches(level: Node3D, diagnostics: bool = false) -> bool:
	if physical(level).size()!=level.manifest.size()*2:
		return reject_manifest("physical count",diagnostics)
	for piece: Dictionary in level.manifest:
		var body := level.get_node_or_null(str(piece.name).validate_node_name()) as StaticBody3D
		if body == null or body.get_child_count()!=1:
			return reject_manifest(str(piece.name)+" body/shape pair",diagnostics)
		var origin := Vector3.ZERO
		for point: Vector3 in piece.points:
			origin += point/piece.points.size()
		if body.transform!=Transform3D(Basis.IDENTITY,origin) or body.collision_layer!=1 or body.collision_mask!=1:
			return reject_manifest(str(piece.name)+" transform/layers "+str(body.transform)+" expected origin "+str(origin),diagnostics)
		if body.get_meta("progress_stage")!=piece.stage or body.get_meta("surface")!=piece.role:
			return reject_manifest(str(piece.name)+" metadata",diagnostics)
		if body.physics_material_override!=null or body.constant_linear_velocity!=Vector3.ZERO or body.constant_angular_velocity!=Vector3.ZERO:
			return reject_manifest(str(piece.name)+" material/constant velocity",diagnostics)
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or collision.disabled or collision.transform!=Transform3D.IDENTITY or not collision.shape is ConvexPolygonShape3D:
			return reject_manifest(str(piece.name)+" shape transform/type",diagnostics)
		var shape := collision.shape as ConvexPolygonShape3D
		if shape.points.size()!=piece.points.size() or shape.margin!=ConvexPolygonShape3D.new().margin:
			return reject_manifest(str(piece.name)+" point count/margin "+str(shape.margin),diagnostics)
		for i: int in piece.points.size():
			if shape.points[i]!=piece.points[i]-origin:
				return reject_manifest(str(piece.name)+" point "+str(i)+" "+str(shape.points[i])+" expected "+str(piece.points[i]-origin),diagnostics)
	return true

func run() -> void:
	var level := LEVEL.new()
	root.add_child(level)
	level.build()
	var gate: Node3D = level.get_node_or_null("SeaGate")
	if gate == null:
		level.free()
		quit(1)
		return
	gate.set_process(false)
	var before := JSON.stringify(physical(level),"",false,true)
	var start: Vector3 = gate.trolley.position
	gate._process(10.0)
	var moved: float = gate.trolley.position.distance_to(start)
	var stable := before == JSON.stringify(physical(level),"",false,true)
	var geometry := level.geometry_hash()
	var collision_inventory := manifest_matches(level,true)
	# challenge actual shape contents and transforms without changing the manifest.
	var body: StaticBody3D = level.get_node(str(level.manifest[0].name).validate_node_name())
	var shape: ConvexPolygonShape3D = body.get_child(0).shape
	var points := shape.points
	var changed := points.duplicate()
	changed[0] += Vector3(0.125,0,0)
	shape.points = changed
	var shape_mutation_rejected := not manifest_matches(level)
	shape.points = points
	var at := body.position
	body.position += Vector3(0.125,0,0)
	var transform_mutation_rejected := not manifest_matches(level)
	body.position = at
	body.collision_layer = 2
	var mask_mutation_rejected := not manifest_matches(level)
	body.collision_layer = 1
	var margin := shape.margin
	shape.margin += 0.01
	var margin_mutation_rejected := not manifest_matches(level)
	shape.margin = margin
	var controls_ok := shape_mutation_rejected and transform_mutation_rejected and mask_mutation_rejected and margin_mutation_rejected and manifest_matches(level)
	var anchors := get_nodes_in_group(PLAYER.ANCHOR_GROUP)
	var anchors_ok := anchors.size()==3
	for i: int in 3:
		var found := false
		for anchor: Node3D in anchors:
			if str(anchor.get_meta("r21_anchor_id","")) == "foundry-%d" % i:
				found = anchor.global_position == LEVEL.FOUNDRY_ANCHORS[i]
		anchors_ok = anchors_ok and found
	var ok := controls_ok and anchors_ok and collision_inventory and stable and geometry == WAVE1_GEOMETRY and physical(gate).is_empty() and moved > 1.0
	var result := {"ok":ok,"actual_anchors_unchanged":anchors_ok,"actual_collision_matches_manifest":collision_inventory,"shape_mutation_rejected":shape_mutation_rejected,"transform_mutation_rejected":transform_mutation_rejected,"mask_mutation_rejected":mask_mutation_rejected,"margin_mutation_rejected":margin_mutation_rejected,"original_collision_and_anchor_manifest":geometry==WAVE1_GEOMETRY,"geometry_hash":geometry,"animation_collision_unchanged":stable,"scenery_collision_objects":physical(gate).size(),"trolley_displacement":moved}
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	level.free()
	await process_frame
	quit(0 if ok else 1)
