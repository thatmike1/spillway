extends RefCounted
## original procedural architecture; private reference imagery is never loaded by the game.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const CONCRETE := preload("res://assets/maps/foundry/concrete.gdshader")

static func dress(level: Node3D) -> void:
	var concrete := ShaderMaterial.new()
	concrete.shader = CONCRETE
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://assets/maps/foundry/outline.gdshader")
	concrete.next_pass = ink
	for child: Node in level.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Mesh_") and not str(child.name).begins_with("Mesh_structure_crane_"):
			child.material_override = concrete
	# recovery concrete stays visually above water rather than sharing the same plane.
	level.get_node("Water").position.y = -10
	for row: Array in level.art_manifest:
		if row[0] == "Water":
			row[1] = [0,-10,-40]
	# the hall walls and foundations make the floor levels legible from the shaft.
	for x: float in [-29.0,29.0]:
		box(level,"hall_wall_%s" % x,Vector3(x,5,-28),Vector3(2,26,110),concrete)
		for z: float in [12.0,-16.0,-48.0,-76.0]:
			box(level,"buttress_%s_%s" % [x,z],Vector3(x,12,z),Vector3(4,40,3),concrete)
	for row: Array in [[-16,18,4],[6,18,4],[-8,12,-32],[8,12,-24],[-8,2,-70],[8,2,-70]]:
		box(level,"deck_pier_%s_%s" % [row[0],row[2]],Vector3(row[0],(row[1]-0.8-8)/2.0,row[2]),Vector3(2,row[1]-0.8+8,5),concrete)
	# dark coping creates an ink-like silhouette; orange remains confined to takeoff lips.
	for row: Array in [[-6,18,0,32],[0,12,-20,20],[-10.5,12,-36,23],[0,2,-50,20],[-6,18,8,6],[-6,18,3,6],[5.5,12,-28,9]]:
		level._box("lip_%s_%s" % [row[0],row[2]],Vector3(row[0],row[1]+0.02,row[2]),Vector3(row[3],0.04,0.16),Color("b5683c"))
		level._box("lip_shadow_%s_%s" % [row[0],row[2]],Vector3(row[0],row[1]-0.12,row[2]),Vector3(row[3],0.12,0.08),Color("243b3c"))
	# paint follows the intake cut and the gallery's actual inner boundary.
	for x: float in [-9.0,-3.0]:
		level._box("intake_edge_%s" % x,Vector3(x,18.025,5.5),Vector3(0.16,0.05,5),Color("b5683c"))
	line(level,"gallery_lip",Vector3(-10,18.025,0),Vector3(-10,12.025,-24),0.13,Color("b5683c"))
	for y: float in [-6.0,0.0,6.0]:
		level._box("intake_tidemark_%s" % y,Vector3(-9.97,y,-12),Vector3(0.06,0.32,24),Color("203c3d"))
	level._box("tailrace_preview_edge",Vector3(1,12.025,-32),Vector3(0.16,0.05,8),Color("b5683c"))
	# one coherent pipe pair descends beside the tailrace instead of scattering props.
	for x: float in [11.0,13.0]:
		level._box("tailrace_pipe_%s" % x,Vector3(x,2,-57),Vector3(0.9,20,0.9),Color("466b69"))
	for x: float in [11.0,13.0]:
		level._box("tailrace_pipe_header_%s" % x,Vector3(x,12,-47),Vector3(0.9,0.9,22),Color("466b69"))
	# level bands on the existing drops compare the high handoff with the low catch.
	for y: float in [2.0,7.0,12.0]:
		for x: float in [11.0,13.0]:
			level._box("tailrace_pipe_band_%s_%s" % [x,y],Vector3(x,y,-56.54),Vector3(0.92,0.24,0.02),Color("d5cead"))
	for child: Node in level.get_children():
		if child is DirectionalLight3D:
			child.shadow_enabled = true
			child.light_energy = 0.6
			child.directional_shadow_max_distance = 110
		if child is WorldEnvironment:
			var env: Environment = child.environment
			var sky := Sky.new()
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/look/sky.gdshader")
			material.set_shader_parameter("panorama",preload("res://assets/look/r17/practice-sky.png"))
			sky.sky_material = material
			env.sky = sky
			env.background_mode = Environment.BG_SKY
			env.ambient_light_energy = 0.32
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 0.95

static func box(level: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> void:
	var half := size*0.5
	GEO.prism(level,id,GEO.rectangle(at.x-half.x,at.x+half.x,at.z-half.z,at.z+half.z,at.y+half.y),at.y-half.y,-1,"prop","structure")
	level.get_child(level.get_child_count()-1).material_override = material

static func line(level: Node3D, id: String, start: Vector3, end: Vector3, width: float, color: Color) -> void:
	level._box(id,(start+end)*0.5,Vector3(width,width,start.distance_to(end)),color)
	var mesh: MeshInstance3D = level.get_child(level.get_child_count()-1)
	mesh.look_at(end,Vector3.UP)
	level.art_manifest.append(["rotation",id,[mesh.rotation.x,mesh.rotation.y,mesh.rotation.z]])
