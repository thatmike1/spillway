extends RefCounted
## downstream scenery stays outside the course and contains no collision or anchor nodes.
const NOISE := """float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
"""
static func build(level: Node3D) -> void:
	var dam := Node3D.new()
	dam.name = "ViaductDam"
	level.add_child(dam)
	var wall := _concrete()
	var crest := _material(Color("cfc9b9"))
	var wet := _material(Color("557683"))
	var foam := _flood()
	for i: int in 12:
		var x0 := -168.0+i*28.0
		var x1 := x0+28.0
		var z0 := -156.0-0.0018*x0*x0
		var z1 := -156.0-0.0018*x1*x1
		quad(dam,"Face%d" % i,Vector3(x0,-12,z0+14),Vector3(x1,-12,z1+14),Vector3(x1,53,z1),Vector3(x0,53,z0),wall)
		quad(dam,"Crest%d" % i,Vector3(x0,53,z0),Vector3(x1,53,z1),Vector3(x1,53,z1-8),Vector3(x0,53,z0-8),crest)
		var x := (x0+x1)*0.5
		var z := -156.0-0.0018*x*x
		box(dam,"Pier%d" % i,Vector3(x,17,z+9),Vector3(3.5,58,15),wall)
		box(dam,"Coping%d" % i,Vector3(x,54,z-2),Vector3(28.5,2,2),crest)
		box(dam,"Drain%d" % i,Vector3(x,1,z+17),Vector3(7,18,3),wet)
		box(dam,"ToeCap%d" % i,Vector3(x,10.2,z+17),Vector3(7.8,0.4,3.6),crest)
	for x: float in [-56.0,0.0,56.0]:
		var z := -156.0-0.0018*x*x
		box(dam,"Outlet%s" % x,Vector3(x,43,z+1),Vector3(19,14,5),wet)
		quad(dam,"Weir%s" % x,Vector3(x-7.5,46,z+2),Vector3(x+7.5,46,z+2),Vector3(x+7.5,46,z+5),Vector3(x-7.5,46,z+5),foam)
		quad(dam,"Flood%s" % x,Vector3(x-7.5,-8,z+19),Vector3(x+7.5,-8,z+19),Vector3(x+7.5,46,z+5),Vector3(x-7.5,46,z+5),foam)
		var spray := ShaderMaterial.new()
		var spray_shader := Shader.new()
		spray_shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec2 impact;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
"""+NOISE+"""void fragment(){
 vec2 p=(wp.xz-impact)/vec2(14.0,12.0);
 float n=noise(wp.xz*0.32+vec2(TIME*0.2,-TIME*0.6));
 if(length(p)>0.70+n*0.25) discard;
 ALBEDO=mix(vec3(0.50,0.72,0.69),vec3(0.85,0.91,0.84),smoothstep(0.25,0.65,n));
}"""
		spray.shader = spray_shader
		spray.set_shader_parameter("impact",Vector2(x,z+23))
		quad(dam,"Apron%s" % x,Vector3(x-15,-7.9,z+10),Vector3(x+15,-7.9,z+10),Vector3(x+15,-7.9,z+37),Vector3(x-15,-7.9,z+37),spray)
	box(dam,"Gatehouse",Vector3(0,58,-161),Vector3(21,10,12),crest)
	box(dam,"GatehouseWindows",Vector3(0,59,-154.9),Vector3(16,2,0.1),wet)
	# stepped retaining abutments connect the dam ends to the maintenance basin.
	for side: float in [-1.0,1.0]:
		box(dam,"RetainingLow%s" % side,Vector3(side*65,0,-70),Vector3(20,24,100),wall)
		box(dam,"RetainingMid%s" % side,Vector3(side*95,8,-135),Vector3(45,40,80),wall)
		box(dam,"RetainingHigh%s" % side,Vector3(side*150,19,-200),Vector3(80,62,80),wall)
	# visible winch carriages explain the rings; the service carrier terminates at the control house.
	for at: Vector3 in level.V_ANCHORS:
		box(dam,"Hoist%s" % at.z,at+Vector3(0,2.6,0),Vector3(3.2,0.8,2.6),wet)
		box(dam,"HoistEnd%s" % at.z,at+Vector3(0,2.65,1.35),Vector3(2.4,0.45,0.16),crest)
	var carrier := MeshInstance3D.new()
	carrier.name = "ServiceCarrier"
	var beam := BoxMesh.new()
	var start := Vector3(-23,14.5,-68)
	var end := Vector3(-25,14.5,-99)
	beam.size = Vector3(1.6,0.8,start.distance_to(end)+1)
	carrier.mesh = beam
	carrier.position = (start+end)*0.5
	carrier.rotation.y = atan2(end.x-start.x,end.z-start.z)
	carrier.material_override = wet
	dam.add_child(carrier)
	box(dam,"RoofCarrierSeat",Vector3(-25,13.8,-99),Vector3(2.2,1.6,2.2),crest)
	var path := [Vector3(-15,15,-8),Vector3(-11,15,-38),Vector3(-23,15,-68),Vector3(-25,15,-99)]
	for i: int in 3:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i+1]
		var side := Vector3((b-a).z,0,-(b-a).x).normalized()
		_member(dam,"ServiceDeck%d" % i,a,b,Vector2(1.7,0.22),crest)
		for sign_: float in [-1.0,1.0]:
			_member(dam,"Handrail%d_%s" % [i,sign_],a+side*sign_*0.8+Vector3.UP*1.1,b+side*sign_*0.8+Vector3.UP*1.1,Vector2(0.065,0.065),wet)
			for j: int in 8:
				box(dam,"RailPost%d_%s_%d" % [i,sign_,j],a.lerp(b,float(j)/8)+side*sign_*0.8+Vector3.UP*0.55,Vector3(0.065,1.1,0.065),wet)
	# a deeper intake header establishes a main lifting bay, with open sky above the carrier.
	box(dam,"IntakeHeader",Vector3(4,15.4,-8),Vector3(43.4,1.4,2.0),wet)
	for x: float in [-15.0,4.0,23.0]:
		box(dam,"HeaderStiffener%s" % x,Vector3(x,14.4,-8),Vector3(0.5,1.1,1.9),crest)
	# exposed ramp edges have a real depth and bearings, rather than a painted outline.
	for i: int in 4:
		var d: Array = level.V_DECKS[i]
		var h: float = level.V_HEIGHTS[i]
		var x: float = d[1]+3
		var z: float = d[3]-4
		box(dam,"RampBearing%d" % i,Vector3(x,h+0.006,z),Vector3(6.4,0.012,0.3),wet)
		for side: float in [-1.0,1.0]:
			var edge := MeshInstance3D.new()
			var girder := BoxMesh.new()
			girder.size = Vector3(0.2,0.35,Vector2(28,h+5).length())
			edge.mesh = girder
			edge.position = Vector3(x+side*3,(h-5)*0.5-0.28,z+14)
			edge.rotation.x = atan2(h+5,28)
			edge.material_override = crest
			edge.set_meta("viaduct_no_ink",true)
			dam.add_child(edge)
	# distant buttresses retain normal shading without casting sawtooth shadow shards over the face.
	for node: Node in dam.get_children():
		if node is MeshInstance3D and (str(node.name).begins_with("Pier") or str(node.name).begins_with("Retaining")):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _member(parent: Node3D, id: String, a: Vector3, b: Vector3, section: Vector2, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(section.x,section.y,a.distance_to(b))
	node.name = id
	node.mesh = mesh
	node.position = (a+b)*0.5
	node.rotation.y = atan2(b.x-a.x,b.z-a.z)
	node.material_override = material
	parent.add_child(node)

static func basin_water() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
"""+NOISE+"""void fragment(){
 float n=noise(wp.xz*0.10+vec2(TIME*0.035,-TIME*0.06));
 float fine=noise(wp.xz*0.32+vec2(0,TIME*0.07));
 vec3 col=mix(vec3(0.24,0.45,0.47),vec3(0.36,0.58,0.58),n*0.75+fine*0.25);
 float horizon=pow(1.0-max(dot(normalize(CAMERA_POSITION_WORLD-wp),vec3(0,1,0)),0.0),6.0);
 ALBEDO=mix(col,vec3(0.52,0.66,0.65),horizon*0.5);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func _concrete() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;
uniform sampler2D wear : repeat_enable,filter_linear_mipmap;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
 float seam=1.0-smoothstep(0.015,0.055,abs(fract(wp.y/6.0)-0.5));
 float runoff=(sin(wp.x*0.21+sin(wp.x*0.87))*0.5+0.5);
 float waterline=1.0-smoothstep(0.5,4.0,abs(wp.y+6.0));
 vec2 face=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float grain=texture(wear,face/vec2(11.0,9.0)).r;
 float mottling=(grain-0.5)*0.12;
 vec3 col=mix(vec3(0.70,0.67,0.58)+vec3(mottling),vec3(0.34,0.40,0.36),seam*0.3+runoff*waterline*0.5);
 ALBEDO=col; ROUGHNESS=1.0; SPECULAR=0.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wear",preload("res://assets/look/painted-wear.png"))
	return material

static func _flood() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
"""+NOISE+"""void fragment() {
 float y = world_position.y;
 float x = world_position.x;
 float strand = noise(vec2(x*1.2,y*0.055+TIME*0.7));
 float pulse = noise(vec2(x*3.5,y*0.16+TIME*1.3));
 float aeration = 1.0-smoothstep(-6.0,32.0,y);
 vec3 blue = vec3(0.31,0.59,0.61);
 vec3 white = vec3(0.85,0.92,0.87);
 ALBEDO = mix(blue,white,clamp(0.58+strand*0.25+pulse*0.12+aeration*0.16,0.0,1.0));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func box(parent: Node3D, id: String, at: Vector3, size: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

static func quad(parent: Node3D, id: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal((b-a).cross(c-a).normalized())
	for vertex: Vector3 in [a,c,b,a,d,c]:
		st.add_vertex(vertex)
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = st.commit()
	node.material_override = material
	parent.add_child(node)

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
