extends RefCounted
## movement lab, look c only: a calm test hall rather than a grey box. walls are cast concrete
## panels with a dark weathered base band, high clerestory windows let painted daylight in along
## both long walls, steel roof trusses span the hall, the floor goes shell-white, machine
## housings go weathered blue steel, and the yellow-black wall-jump panels become pale panels
## framed in lip orange. nothing here collides: windows sit flush on the walls above every
## housing, trusses stay under the roof and skip the bay where the grapple ropes run.

const SURFACE := preload("res://shaders/look/surface.gdshader")
const PALETTE := {"top": "f7f2e6", "side": "5b6f73"}
## the hall floor is lit mostly by ambient light (the roof shades the sun), so it starts brighter.
const SURFACES := {"floor": {"top_color": "fffbf1"}}
const HALF := 12.0
const ROOF := 12.0
const HUB_Z := 10.0
const END_Z := -100.0
## the grapple bay: no truss between these z values, so no rope line crosses one.
const ROPE_BAY := [-96.0, -70.0]
const WALL := """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 upper : source_color = vec4(0.79,0.78,0.73,1.0);
uniform vec4 base_band : source_color = vec4(0.36,0.45,0.46,1.0);
uniform float band_top = 2.4;
uniform sampler2D wear : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
 vec2 uv=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float w=texture(wear,uv/vec2(3.0,3.0)).r;
 vec2 cell=abs(fract(uv/vec2(3.0,2.4)+0.5)-0.5)*vec2(3.0,2.4);
 vec2 aa=max(fwidth(uv),vec2(0.003));
 float joint=1.0-min(smoothstep(0.01-aa.x,0.01+aa.x,cell.x),smoothstep(0.01-aa.y,0.01+aa.y,cell.y));
 float band=step(wp.y,band_top);
 vec3 c=mix(upper.rgb,base_band.rgb,band);
 c=mix(c,c*0.9,smoothstep(0.62,0.74,w)*0.25);
 c*=1.0-joint*0.18;
 float lip=1.0-smoothstep(0.0,0.05,abs(wp.y-band_top));
 c=mix(c,vec3(0.15,0.22,0.24),lip*0.7);
 if(wn.y>0.65){ c=upper.rgb*0.92; }
 ALBEDO=c; ROUGHNESS=0.95; SPECULAR=0.0;
}
"""
const PANEL := """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec2 size = vec2(5.8,6.0);
uniform vec4 face : source_color = vec4(0.91,0.88,0.80,1.0);
uniform vec4 frame : source_color = vec4(0.85,0.36,0.19,1.0);
varying vec3 lp;
void vertex(){ lp=VERTEX; }
void fragment(){
 vec2 q=vec2(lp.y,lp.z);
 vec2 d=size*0.5-abs(q);
 float border=step(min(d.x,d.y),0.14);
 ALBEDO=mix(face.rgb,frame.rgb,border); ROUGHNESS=0.9; SPECULAR=0.0;
}
"""

var _wall: ShaderMaterial
var _housing: ShaderMaterial
var _board: Label3D
var _board_state := {}
var _signs: Array[Label3D] = []

func material(key: String, node: GeometryInstance3D, proposed: Material) -> Material:
	# imported props (pipes, stacks, machine parts) keep their shapes but leave the violet-blue
	# kit palette for the same weathered steel as the housings.
	if node.material_override == null and proposed is BaseMaterial3D:
		return _housing_material()
	if key == "Mesh_wall_panel":
		return _wall_material()
	if key in ["Mesh_housing", "Mesh_rack_low"]:
		return _housing_material()
	if key.begins_with("Panel_") and node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
		var box := (node as MeshInstance3D).mesh as BoxMesh
		var shader := Shader.new()
		shader.code = PANEL
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("size", Vector2(box.size.y, box.size.z))
		return m
	return proposed

func dress(level: Node3D) -> Node3D:
	var root := Node3D.new()
	# clerestory windows: flush on both long walls, 6 m bays with 2 m piers between.
	var sky := StandardMaterial3D.new()
	sky.albedo_color = Color("d9e8e6")
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mullion := _flat(Color("33474b"))
	var z := HUB_Z - 3.0
	var i := 0
	while z - 6.0 > END_Z + 1.0:
		for side: float in [-1.0, 1.0]:
			var x := side * (HALF - 0.015)
			_box(root, "Clerestory_%d_%d" % [i, int(side)], Vector3(x, 10.3, z - 3.0), Vector3(0.02, 2.2, 6.0), sky)
			_box(root, "ClerestoryMullion_%d_%d" % [i, int(side)], Vector3(x - side * 0.01, 10.3, z - 3.0), Vector3(0.02, 2.2, 0.1), mullion)
			_box(root, "ClerestorySill_%d_%d" % [i, int(side)], Vector3(x - side * 0.06, 9.15, z - 3.0), Vector3(0.12, 0.1, 6.2), mullion)
		z -= 8.0
		i += 1
	# roof trusses: a bottom chord and two posts under the roof, every 10 m, outside the rope bay.
	var steel := _flat(Color("2f4246"))
	var tz := HUB_Z - 5.0
	while tz > END_Z + 2.0:
		if tz < ROPE_BAY[0] or tz > ROPE_BAY[1]:
			_box(root, "TrussChord_%d" % int(tz), Vector3(0, ROOF - 0.95, tz), Vector3(2.0 * HALF, 0.22, 0.3), steel)
			for x: float in [-8.0, -2.5, 2.5, 8.0]:
				_box(root, "TrussPost_%d_%s" % [int(tz), x], Vector3(x, ROOF - 0.45, tz), Vector3(0.14, 0.8, 0.2), steel)
		tz -= 10.0
	# each roof tube gets a dark fitting above it, so it hangs from the roof instead of floating.
	for child: Node in level.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("LampTube_"):
			var at: Vector3 = (child as MeshInstance3D).position
			_box(root, "LampFitting_" + str(child.name).trim_prefix("LampTube_"), Vector3(at.x, (at.y + 0.05 + ROOF) * 0.5, at.z), Vector3(0.42, ROOF - at.y - 0.05, 5.3), steel)
	# the hub board becomes a painted place name; key names and unit figures leave the world
	# (the hud carries them), and l off brings every sign back as it was.
	_board = level.get_node_or_null("Sign_hub_board") as Label3D
	if _board != null:
		_board_state = {"modulate": _board.modulate, "outline": _board.outline_size, "text": _board.text}
	for child: Node in level.get_children():
		if child is Label3D and str(child.name).begins_with("Sign_") and child != _board:
			_signs.append(child)
	return root

func set_enabled(value: bool) -> void:
	for label: Label3D in _signs:
		if is_instance_valid(label):
			label.visible = not value
	if not is_instance_valid(_board):
		return
	_board.modulate = Color("f1ead8") if value else _board_state.modulate
	_board.outline_size = 0 if value else int(_board_state.outline)
	_board.text = "MOVEMENT LAB" if value else str(_board_state.text)

func _wall_material() -> ShaderMaterial:
	if _wall == null:
		var shader := Shader.new()
		shader.code = WALL
		_wall = ShaderMaterial.new()
		_wall.shader = shader
		_wall.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	return _wall

func _housing_material() -> ShaderMaterial:
	if _housing == null:
		_housing = ShaderMaterial.new()
		_housing.shader = SURFACE
		_housing.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
		_housing.set_shader_parameter("top_color", Color("9fb0b2"))
		_housing.set_shader_parameter("side_color", Color("587078"))
		_housing.set_shader_parameter("wear_amount", 0.06)
		_housing.set_shader_parameter("metal", 0.0)
	return _housing

func _box(root: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)

func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m
