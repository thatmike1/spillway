extends RefCounted
## original procedural concrete with the project's licensed painted sky; visual only, no physics or acquisition writes.
static func apply(level: Node3D) -> void:
	preload("res://scripts/art/viaduct_dam.gd").build(level)
	var concrete := _surface(Color("cfc9b9"),Color("657a7c"),0.85)
	var incline := _surface(Color("c3c2b5"),Color("617777"),0.85)
	var basin := _surface(Color("728781"),Color("4d6667"),0.35)
	var steel := _steel()
	for node: Node in level.get_children():
		if node is MeshInstance3D and (node.name.begins_with("Mesh_") or node.name.begins_with("viaduct_pier") or node.name.begins_with("viaduct_crossbeam") or node.name.begins_with("viaduct_foot")):
			if str(node.name).contains("maintenance_court"):
				node.material_override = basin
			elif str(node.name).begins_with("Mesh_recovery"):
				node.material_override = incline
			else:
				node.material_override = concrete
			if node.name.begins_with("viaduct_pier") or node.name.begins_with("viaduct_crossbeam"):
				node.material_override = steel
	for node: Node in level.get_children():
		if node is MeshInstance3D and node.name == "viaduct_house_panel":
			var cladding := _surface(Color("718b90"),Color("587a82"),0.0)
			cladding.set_shader_parameter("metal",0.65)
			node.material_override = cladding
	# broad distant banks ground the basin without crowding the playable silhouette.
	for side: float in [-1.0,1.0]:
		box(level,Vector3(side*67,-7.5,-35),Vector3(48,12,180),Color("6f8175"))
		box(level,Vector3(side*42,-6,-35),Vector3(1,12,180),Color("566563"))
	# reuse the project's original redistributable painted sky, not the private moodboard.
	for node: Node in level.get_children():
		if node is MeshInstance3D and node.name == "Water":
			node.material_override = preload("res://scripts/art/viaduct_dam.gd").basin_water()
		if node is WorldEnvironment:
			var sky := Sky.new()
			var painted := ShaderMaterial.new()
			painted.shader = preload("res://shaders/look/sky.gdshader")
			painted.set_shader_parameter("panorama",preload("res://assets/look/r17/overflow-sky.png"))
			sky.sky_material = painted
			node.environment.sky = sky
			node.environment.background_mode = Environment.BG_SKY
			node.environment.sky_rotation.y = deg_to_rad(28.0)
			node.environment.ambient_light_energy = 0.30
			node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			node.environment.tonemap_exposure = 0.92
		if node is DirectionalLight3D:
			node.light_energy = 0.35
			node.shadow_enabled = true
			node.directional_shadow_max_distance = 160.0
	_sky_light(level, "viaduct")
	# inverted hulls outline major solid members; thin rails and water remain quiet.
	var ink := ShaderMaterial.new()
	var ink_shader := Shader.new()
	ink_shader.code = "shader_type spatial; render_mode cull_front,unshaded; void vertex(){VERTEX+=NORMAL*0.035;} void fragment(){ALBEDO=vec3(0.055,0.095,0.105);}"
	ink.shader = ink_shader
	for node: Node in level.find_children("*","MeshInstance3D",true,false):
		if node is MeshInstance3D and node.mesh is BoxMesh and node.material_override != null and node.mesh.get_aabb().size.length() > 2.5 and node.name != "Water" and not str(node.name).begins_with("Art_paint") and not str(node.name).begins_with("RampBearing") and not node.has_meta("viaduct_no_ink"):
			node.material_override = node.material_override.duplicate()
			node.material_override.next_pass = ink
	level.add_child(preload("res://scripts/r17_contours.gd").new().build(level,true))
	level.add_child(preload("res://scripts/art/viaduct_cable.gd").new())
	_deck_wear(level)
	_takeoff_bands(level)

static func _deck_wear(level: Node3D) -> void:
	# the pier tops were one blank cream sheet; an overlay adds the crane dock's wear family (sparse crisp
	# stains, faint mottling) without touching the pinned deck material underneath.
	var overlay := wear_overlay()
	for node: Node in level.get_children():
		var id := str(node.name)
		if node is MeshInstance3D and id.begins_with("Mesh_deck") and not id.contains("maintenance_court"):
			(node as MeshInstance3D).material_overlay = overlay

## a multiply overlay for pale deck tops; foundry reuses it so the courses share one wear family.
static func wear_overlay() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mul,unshaded,depth_draw_never,shadows_disabled;
uniform sampler2D wear : repeat_enable,filter_linear_mipmap;
varying vec3 wp;
varying vec3 wn;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float top=smoothstep(0.65,0.92,wn.y);
 float fade=1.0-smoothstep(25.0,95.0,distance(wp,CAMERA_POSITION_WORLD));
 float spot=smoothstep(0.70,0.73,texture(wear,wp.xz/vec2(2.7,3.4)).r);
 float field=smoothstep(0.44,0.58,texture(wear,wp.xz/vec2(9.1,6.7)+vec2(0.37,0.61)).g);
 float mottle=smoothstep(0.30,0.80,texture(wear,wp.xz/13.0).r);
 float dark=top*fade*(0.075*spot*field+0.045*mottle);
 ALBEDO=vec3(1.0-dark,1.0-dark*0.97,1.0-dark*0.88);
}
"""
	var overlay := ShaderMaterial.new()
	overlay.shader = shader
	overlay.set_shader_parameter("wear", preload("res://assets/look/painted-wear.png"))
	return overlay

static func _takeoff_bands(level: Node3D) -> void:
	# the takeoff lip was a hairline at spawn distance; a receiver-deep band behind it reads as the edge.
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("cf7746")
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node: Node in level.get_children():
		var id := str(node.name)
		if not (node is MeshInstance3D and (id.begins_with("Art_paint_orange_lip_") or id == "Art_paint_upper_lip")):
			continue
		var lip := node as MeshInstance3D
		lip.material_override = paint
		var band := MeshInstance3D.new()
		band.name = "Look_takeoff_band_" + id.trim_prefix("Art_paint_")
		var mesh := BoxMesh.new()
		mesh.size = Vector3((lip.mesh as BoxMesh).size.x, 0.014, 0.6)
		band.mesh = mesh
		band.position = Vector3(lip.position.x, lip.position.y - 0.012, lip.position.z - 0.11 + 0.3)
		band.material_override = paint
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(band)

static func _sky_light(level: Node3D, id: String) -> void:
	# lane 02 owns these sky and light values; this file only hands over its environment and sun.
	var sky_light := load("res://scripts/look/sky_light.gd")
	if sky_light == null or not sky_light.has_map(id):
		return
	var env: Environment
	var sun: DirectionalLight3D
	for node: Node in level.get_children():
		if node is WorldEnvironment and env == null:
			env = (node as WorldEnvironment).environment
		if node is DirectionalLight3D and sun == null:
			sun = node
	if env != null:
		sky_light.apply(env, sun, id)

static func _steel() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_toon,specular_disabled;
uniform sampler2D wear : repeat_enable,filter_linear_mipmap;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=texture(wear,wp.xy*0.16).r;
 float edge=1.0-smoothstep(0.015,0.075,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
 float chip=smoothstep(0.48,0.72,n)*edge;
 ALBEDO=mix(vec3(0.32,0.46,0.51)*(0.94+n*0.10),vec3(0.48,0.37,0.26),chip*0.65);
 ROUGHNESS=0.88; SPECULAR=0.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
	return material

static func box(level: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = preload("res://scripts/movement/grapple_player.gd")._flat(color)
	level.add_child(node)

static func _surface(top: Color, side: Color, joints: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/look/surface.gdshader")
	material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("top_color",top)
	material.set_shader_parameter("side_color",side)
	material.set_shader_parameter("wear_amount",0.16)
	material.set_shader_parameter("deck",joints)
	return material
