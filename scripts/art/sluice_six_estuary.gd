extends RefCounted
## the flood barrier curves back into the tower; its buttresses root every span below water.
const ART := preload("res://scripts/art/sluice_six_art.gd")
static func dress(level: Node3D) -> void:
	var centre := Vector3(-8,0,-92)
	var count := 18
	for i: int in count:
		var angle := deg_to_rad(float(i)*5.0)
		var radius := 58.0
		var at := centre+Vector3(-sin(angle)*radius,0,-cos(angle)*radius)
		var wall := Node3D.new()
		wall.name = "FloodBarrier_%02d" % i
		wall.position = at
		wall.rotation.y = angle
		level.add_child(wall)
		ART._box(wall,"foundation",Vector3(0,-5,0),Vector3(5.4,8,9),Color("596e70"),true)
		ART._box(wall,"pier",Vector3(-2.4,1,0),Vector3(0.7,10,6),Color("858e86"),true)
		ART._box(wall,"gate",Vector3(0,0,-1.4),Vector3(4.5,5,0.5),Color("57777b"),true)
		ART._box(wall,"crest",Vector3(0,5,0),Vector3(5.4,0.8,6),Color("c3c0ac"),true)
		ART._box(wall,"lower_apron",Vector3(0,-2.6,4),Vector3(5.4,0.5,10),Color("839c97"),true)
		ART._box(wall,"fall",Vector3(0,-0.5,1.8),Vector3(4.5,4,0.12),Color("bad5ce"))
		ART._box(wall,"foam",Vector3(0,-2.87,7),Vector3(4.5,0.02,4),Color("c7ddd3"))
		for x: float in [-2.4,2.4]:
			ART._box(wall,"rail_post_%s" % x,Vector3(x,6,2.8),Vector3(0.08,1.2,0.08),Color("3e575a"))
		ART._box(wall,"rail",Vector3(0,6.6,2.8),Vector3(5.4,0.08,0.08),Color("3e575a"))
	_outfall(level)
	# the far shore is one overlapping rocky landform rather than isolated decorative blocks.
	for i: int in 12:
		var hill := MeshInstance3D.new()
		hill.name = "EstuaryHeadland_%d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		hill.mesh = mesh
		hill.scale = Vector3(45,18+float(i%3)*9,32)
		hill.position = Vector3(-170+float(i)*27,-4,-280-float(i%3)*11)
		hill.material_override = ART._material(Color("708d8c"))
		level.add_child(hill)

	# exposed tidal flats and rising banks frame a water channel that opens into the sea.
	_tidal_flat(level,"west_tidal_flat",Vector3(-120,-3.05,-105),Vector3(75,0.5,105),Color("a3a18a"))
	_landform(level,"west_shingle_bank",Vector3(-132,-4,-120),Vector3(66,7,95),Color("777f70"))
	_landform(level,"west_marsh",Vector3(-140,-2,-130),Vector3(52,8,85),Color("879078"))
	_tidal_flat(level,"east_tidal_flat",Vector3(105,-3.05,-165),Vector3(78,0.5,135),Color("a3a18a"))
	_landform(level,"east_shore",Vector3(110,-5,-170),Vector3(78,15,130),Color("7d8978"))
	_landform(level,"river_bend_west",Vector3(-95,-5,-265),Vector3(60,22,90),Color("70877e"))
	_landform(level,"river_bend_east",Vector3(110,-5,-300),Vector3(75,30,100),Color("6e8582"))

static func _landform(level: Node3D, id: String, at: Vector3, size: Vector3, color: Color) -> void:
	var land := MeshInstance3D.new()
	land.name = id
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	land.mesh = mesh
	land.position = at
	land.scale = size
	land.material_override = ART._material(color)
	level.add_child(land)

static func _outfall(level: Node3D) -> void:
	# one spill channel passes beneath the existing bank service walk into a submerged apron.
	ART._box(level,"outfall_apron",Vector3(19,-3.2,-86),Vector3(16,0.5,14),Color("6b8384"),true)
	ART._box(level,"outfall_pool_bed",Vector3(35,-0.1,-86),Vector3(28,6,14),Color("7b8b86"),true)
	for side: int in [-1,1]:
		ART._box(level,"spill_cheek_%s" % side,Vector3(19,-0.5,-86+side*6.6),Vector3(16,7,0.8),Color("8c9b94"),true)
		ART._box(level,"pool_bank_%s" % side,Vector3(35,0.5,-86+side*6.6),Vector3(28,6,0.8),Color("8c9b94"),true)
	ART._box(level,"pool_end",Vector3(49,0.5,-86),Vector3(0.8,6,14),Color("8c9b94"),true)
	ART._box(level,"retained_water",Vector3(35,2.96,-86),Vector3(28,0.05,12),Color("688f91"))
	var sheet := SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(21,2.96,-92),Vector3(21,2.96,-80),Vector3(11,-2.8,-80),Vector3(11,-2.8,-92)]
	var uvs: Array[Vector2] = [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for i: int in [0,1,2,0,2,3]:
		sheet.set_normal(Vector3(-0.5,0.86,0))
		sheet.set_uv(uvs[i])
		sheet.add_vertex(points[i])
	var spill := MeshInstance3D.new()
	spill.name = "WorkingOutfall"
	spill.mesh = sheet.commit()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, specular_disabled;
void fragment(){
 float wave=sin(UV.y*15.0-TIME*3.0+sin(UV.x*13.0)*0.5);
 float broken=smoothstep(0.2,0.7,sin(UV.x*45.0+UV.y*6.0));
 float foam=smoothstep(0.55,0.95,wave)*broken*0.35+smoothstep(0.7,1.0,UV.y)*0.15;
 ALBEDO=mix(vec3(0.35,0.58,0.59),vec3(0.7,0.8,0.73),foam);
 ROUGHNESS=0.7; SPECULAR=0.0;
}
"""
	material.shader = shader
	spill.material_override = material
	level.add_child(spill)

static func _flat_height(u: float, v: float) -> float:
	var shore := 1.0+0.10*sin(v*11.0)+0.06*sin(v*23.0)
	var radius := u*u/(shore*shore)+v*v
	var creek := exp(-pow(sin(u*19.0+v*3.0)/0.16,2.0))*0.20
	return maxf(-0.6,1.0-radius)-creek

static func _tidal_flat(level: Node3D, id: String, at: Vector3, size: Vector3, color: Color) -> void:
	# connected intertidal contours and shallow creeks articulate a single exposed bank.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: int in 24:
		for z: int in 32:
			var corners: Array[Vector2] = [Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]
			for i: int in [0,1,2,0,2,3]:
				var uv := corners[i]/Vector2(12,16)-Vector2.ONE
				var height := _flat_height(uv.x,uv.y)
				var band := 0.5+0.5*sin(height*22.0)
				surface.set_color(color.lerp(Color("7f8d7e"),band*0.18))
				surface.add_vertex(at+Vector3(uv.x*size.x,height*size.y,uv.y*size.z))
	surface.generate_normals()
	var shore := MeshInstance3D.new()
	shore.name = id
	shore.mesh = surface.commit()
	var material := ART._material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	shore.material_override = material
	level.add_child(shore)
