extends RefCounted
## original procedural architecture; private reference imagery is never loaded by the game.
const CONCRETE := preload("res://assets/maps/foundry/concrete.gdshader")

static func dress(level: Node3D) -> void:
	var concrete := ShaderMaterial.new()
	concrete.shader = CONCRETE
	for child: Node in level.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Mesh_"):
			child.material_override = concrete
	# recovery concrete stays visually above water rather than sharing the same plane.
	level.get_node("Water").position.y = -10
	for row: Array in level.art_manifest:
		if row[0] == "Water":
			row[1] = [0,-10,-40]
	# the hall walls and foundations make the floor levels legible from the shaft.
	for x: float in [-29.0,29.0]:
		box(level,"hall_wall_%s" % x,Vector3(x,5,-28),Vector3(2,26,110),concrete)
		for z: float in [12.0,-12.0,-48.0,-76.0]:
			box(level,"buttress_%s_%s" % [x,z],Vector3(x,12,z),Vector3(4,40,3),concrete)
	for z: float in [8.0,-35.0,-70.0]:
		var top: float = 18 if z > 0 else (12 if z > -50 else 2)
		for x: float in [-8.0,8.0]:
			box(level,"deck_pier_%s_%s" % [x,z],Vector3(x,(top-8)/2,z),Vector3(2,top+8,5),concrete)
	# dark coping creates an ink-like silhouette; orange remains confined to takeoff lips.
	for row: Array in [[0,18,0,20],[0,12,-28,20],[0,12,-42,20],[0,2,-60,20]]:
		level._box("lip_%s" % row[2],Vector3(row[0],row[1]+0.02,row[2]),Vector3(row[3],0.04,0.16),Color("b5683c"))
		level._box("lip_shadow_%s" % row[2],Vector3(row[0],row[1]-0.12,row[2]),Vector3(row[3],0.12,0.08),Color("243b3c"))
	# one coherent pipe pair descends beside the tailrace instead of scattering props.
	for x: float in [11.0,13.0]:
		level._box("tailrace_pipe_%s" % x,Vector3(x,2,-57),Vector3(0.9,20,0.9),Color("466b69"))
	for child: Node in level.get_children():
		if child is WorldEnvironment:
			var env: Environment = child.environment
			var sky := Sky.new()
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/look/sky.gdshader")
			material.set_shader_parameter("panorama",preload("res://assets/look/r17/practice-sky.png"))
			sky.sky_material = material
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			env.ambient_light_energy = 0.7

static func box(level: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> void:
	level._box(id,at,size,Color("657b77"))
	level.get_child(level.get_child_count()-1).material_override = material
