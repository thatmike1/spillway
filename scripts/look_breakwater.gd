extends Node3D
## p / reversible rendering only. originals are held by reference and restored exactly.
const SURFACE := preload("res://shaders/look/surface.gdshader")
const INK := preload("res://shaders/look/ink.gdshader")
const WATER := preload("res://shaders/look/water.gdshader")
const SKY := preload("res://shaders/look/sky.gdshader")
var enabled := false
var swaps: Array[Dictionary] = []
var world: WorldEnvironment
var old_environment: Environment
var painted_environment: Environment
var light_states: Array[Dictionary] = []
var ink_mesh: MeshInstance3D
var _lines := SurfaceTool.new()
var _caps := SurfaceTool.new()
var _edge_seen := {}
var line_count := 0
## original nodes hidden while look c is on (figures painted in the world), shown again with l off.
var _hidden: Array[Node3D] = []

func attach(level: Node3D) -> void:
	name = "LookC"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child: Node in level.get_children():
		if child == self:
			continue
		if child is WorldEnvironment:
			world = child
			old_environment = world.environment
		elif child is DirectionalLight3D:
			light_states.append({"node": child, "rotation": child.rotation, "color": child.light_color, "energy": child.light_energy})
		elif child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var key := String(mesh.name)
			var replacement: Material
			if key == "Harbour":
				var water := ShaderMaterial.new()
				water.shader = WATER
				replacement = water
			elif key.begins_with("Mesh_") or key.begins_with("Containers_") or key == "ContainerFrames" or key.begins_with("PropSupports_"):
				replacement = _material(key)
			if replacement != null:
				swaps.append({"node": mesh, "old": mesh.material_override, "new": replacement})
	painted_environment = old_environment.duplicate()
	var sky := Sky.new()
	var panorama := ShaderMaterial.new()
	panorama.shader = SKY
	panorama.set_shader_parameter("panorama",load("res://assets/look/cloud-sky.png"))
	sky.sky_material = panorama
	painted_environment.sky = sky
	painted_environment.sky_rotation = Vector3(0, PI, 0)
	painted_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	painted_environment.ambient_light_color = Color("a6bfc3")
	painted_environment.ambient_light_energy = 0.32
	painted_environment.ambient_light_sky_contribution = 0.0
	painted_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	painted_environment.tonemap_exposure = 0.92
	painted_environment.fog_light_color = Color("a5c2bd")
	painted_environment.fog_density = 0.0007
	painted_environment.fog_sky_affect = 0.0
	_structure_ink(level)
	_dressing(level)
	ink_mesh = MeshInstance3D.new()
	ink_mesh.name = "StructuralInk"
	ink_mesh.mesh = _lines.commit()
	var ink := ShaderMaterial.new()
	ink.shader = INK
	ink_mesh.material_override = ink
	ink_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ink_mesh)
	ink_mesh.hide()
	var caps := MeshInstance3D.new()
	caps.name = "BoundaryCaps"
	caps.mesh = _caps.commit()
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color("d95b30")
	cap_material.roughness = 1.0
	cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cap_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	caps.material_override = cap_material
	caps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(caps)
	set_meta("line_count", line_count)

func _material(key: String) -> Material:
	if key.begins_with("Mesh_paint") and key.ends_with("white"):
		# white paint is the deck's own surface a step lighter, worn like the deck, so the start line
		# reads as paint in light and shade instead of a flat bar across the view.
		var paint := ShaderMaterial.new()
		paint.shader = SURFACE
		paint.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
		paint.set_shader_parameter("top_color", Color("efe9e2"))
		paint.set_shader_parameter("side_color", Color("efe9e2"))
		paint.set_shader_parameter("wear_amount", 0.45)
		paint.set_shader_parameter("deck", 0.0)
		return paint
	if key.begins_with("Mesh_paint"):
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color("d95b30") if key.ends_with("yellow") else (Color("e0daca") if key.ends_with("white") else Color("213e45"))
		flat.roughness = 1.0
		# lips stay unshaded orange.
		if key.ends_with("yellow"):
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return flat
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	var side := Color("6b8a8e")
	# lane 01's shell white e0dad2, nudged off the green the harbour fill puts on it.
	var top := Color("e4d9d1")
	var is_deck := key in ["Mesh_pavers", "Mesh_asphalt", "Mesh_steel_ramp"]
	if key.begins_with("Containers_"):
		side = [Color("527b87"), Color("63868b"), Color("759395"), Color("7c9494"), Color("59898b"), Color("8ba09e")][int(key.trim_prefix("Containers_")) % 6]
		mat.set_shader_parameter("metal", 1.0)
	elif key in ["ContainerFrames", "Mesh_frame", "Mesh_crane_dark"] or key.begins_with("PropSupports_"):
		side = Color("28434b")
		top = Color("597376")
	elif key in ["Mesh_cladding", "Mesh_cladding_warm", "Mesh_crane", "Mesh_hull"]:
		side = Color("365762")
		top = Color("829a97")
		mat.set_shader_parameter("metal", 1.0)
	elif key in ["Mesh_plaster", "Mesh_hull_white"]:
		side = Color("e4e0d2")
	elif key == "Mesh_plaster_red":
		# the lighthouse bands are the finish landmark: a clear brick vermilion, deeper than the
		# route orange so lips stay the brightest accent.
		side = Color("b4503a")
		top = side
	elif key == "Mesh_land":
		top = Color("829491")
	mat.set_shader_parameter("top_color", top)
	mat.set_shader_parameter("side_color", side)
	mat.set_shader_parameter("deck", 1.0 if is_deck else 0.0)
	mat.set_shader_parameter("wear_amount", 0.55 if key == "Mesh_concrete" else (0.10 if key in ["Mesh_plaster","Mesh_plaster_red"] else 0.18))
	return mat

func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	for swap: Dictionary in swaps:
		(swap.node as MeshInstance3D).material_override = swap.new if value else swap.old
	world.environment = painted_environment if value else old_environment
	for state: Dictionary in light_states:
		var lamp: DirectionalLight3D = state.node
		if value:
			lamp.rotation_degrees = Vector3(-24, -135, 0) if lamp.name == "Sun" else Vector3(-55, 45, 0)
			lamp.light_color = Color("fff0d3") if lamp.name == "Sun" else Color("9bb9c4")
			lamp.light_energy = 0.48 if lamp.name == "Sun" else 0.12
		else:
			lamp.rotation = state.rotation
			lamp.light_color = state.color
			lamp.light_energy = state.energy
	ink_mesh.visible = value
	for node: Node3D in _hidden:
		if is_instance_valid(node):
			node.visible = not value

func _structure_ink(level: Node3D) -> void:
	# p / authored major edges only, no triangle diagonals, grain, door bars or ribs.
	var joins := {}
	for prism: Dictionary in level.get("prisms"):
		if str(prism.kind) not in ["pavers", "asphalt", "steel_ramp"]:
			continue
		var polygon: Array = prism.top
		for i: int in polygon.size():
			var key := _edge_key(polygon[i],polygon[(i+1)%polygon.size()])
			joins[key] = int(joins.get(key,0))+1
	for prism: Dictionary in level.get("prisms"):
		if str(prism.kind).begins_with("paint_"):
			continue
		var top: Array = prism.top
		if str(prism.kind) == "concrete" and (top[0] as Vector3).y > 0.5:
			for i: int in range(1,top.size()-1):
				var tri: Array[Vector3] = [top[0]+Vector3.UP*0.006,top[i]+Vector3.UP*0.006,top[i+1]+Vector3.UP*0.006]
				if (tri[1]-tri[0]).cross(tri[2]-tri[0]).y > 0:
					tri.reverse()
				for v: Vector3 in tri:
					_caps.set_normal(Vector3.UP)
					_caps.add_vertex(v)
			var centre := Vector3.ZERO
			for v: Vector3 in top:
				centre += v/top.size()
			for i: int in top.size():
				var a: Vector3 = top[i]
				var b: Vector3 = top[(i+1)%top.size()]
				var out := (b-a).cross(Vector3.UP).normalized()
				if out.dot((a+b)*0.5-centre) < 0:
					out = -out
				a += out*0.008+Vector3.UP*0.006
				b += out*0.008+Vector3.UP*0.006
				var down := Vector3.DOWN*0.10
				for v: Vector3 in [a,b,b+down,a,b+down,a+down]:
					_caps.set_normal(out)
					_caps.add_vertex(v)
		for i: int in top.size():
			var a: Vector3 = top[i]
			var b: Vector3 = top[(i + 1) % top.size()]
			if int(joins.get(_edge_key(a,b),0)) < 2 or str(prism.kind) not in ["pavers", "asphalt", "steel_ramp"]:
				_line(a + Vector3.UP * 0.009, b + Vector3.UP * 0.009, 0.005 if str(prism.kind) in ["pavers", "asphalt", "steel_ramp"] else 0.012)
			if str(prism.kind) == "concrete" and a.y > 0.5:
				_line(a, Vector3(a.x, -2.7, a.z), 0.012)
	for box: Dictionary in level.get("containers"):
		var c: Vector3 = box.centre
		var along := Vector3.RIGHT if box.along_x else Vector3.BACK
		var across := Vector3.BACK if box.along_x else Vector3.RIGHT
		var corners: Array[Vector3] = []
		for uv: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			corners.append(c + along * uv.x * float(box.length) * 0.5 + across * uv.y * float(box.width) * 0.5 + Vector3.UP * 2.599)
		for i: int in 4:
			_line(corners[i],corners[(i+1)%4],0.013)
	var k: Dictionary = (level.get_script() as Script).get_script_constant_map()
	var head: Vector3 = k.HEAD
	for height: float in [9.0,12.0,18.0,21.0,25.0]:
		var radius := lerpf(3.6,2.6,(height-2.0)/23.0)+0.014
		for i: int in 16:
			var a := TAU*i/16.0
			var b := TAU*(i+1)/16.0
			_line(Vector3(head.x+cos(a)*radius,height,head.z+sin(a)*radius),Vector3(head.x+cos(b)*radius,height,head.z+sin(b)*radius),0.012)

## look-only structure: no collision, nothing on or over a traversal path below 5 m.
func _dressing(level: Node3D) -> void:
	var k: Dictionary = (level.get_script() as Script).get_script_constant_map()
	var half: float = k.HALF
	var cw: float = k.CW
	var wall_top: float = float(k.GROUND) + 2.0 * float(k.CH)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the gate canopy was drawn without an underside and hung 14 m out from the gatehouse with
	# nothing under its front: give it a frame (edge beams and open slats, so the sky and the
	# cranes still read through it at spawn) and let its edges bear on posts that stand on the
	# yard-wall container roofs, out of jump reach.
	var post_x := half + cw * 0.35
	var ex := post_x + 0.3
	for sx: float in [-1.0, 1.0]:
		_slab(st, Vector3(minf(sx * ex, sx * (ex - 0.45)), 4.98, -6.3), Vector3(maxf(sx * ex, sx * (ex - 0.45)), 5.36, 8.4))
	for z: float in [-6.3, 8.0]:
		_slab(st, Vector3(-ex, 4.98, z), Vector3(ex, 5.36, z + 0.4))
	var slat := -5.9 + 1.2
	while slat < 7.9:
		_slab(st, Vector3(-ex + 0.45, 5.08, slat - 0.11), Vector3(ex - 0.45, 5.36, slat + 0.11))
		slat += 1.2
	for sx: float in [-1.0, 1.0]:
		for z: float in [-5.9, 1.2]:
			var lo := Vector3(sx * post_x - 0.17, wall_top, z - 0.17)
			var hi := Vector3(sx * post_x + 0.17, 4.98, z + 0.17)
			_slab(st, lo, hi)
			for corner: Vector2 in [Vector2(lo.x, lo.z), Vector2(hi.x, hi.z)]:
				_line(Vector3(corner.x, lo.y, corner.y), Vector3(corner.x, hi.y, corner.y), 0.012)
	for x: float in [-post_x - 0.3, post_x + 0.3]:
		_line(Vector3(x, 4.98, -6.3), Vector3(x, 4.98, 8.4), 0.012)
	_line(Vector3(-post_x - 0.3, 4.98, -6.3), Vector3(post_x + 0.3, 4.98, -6.3), 0.012)
	var steel := MeshInstance3D.new()
	steel.name = "CanopyFrame"
	steel.mesh = st.commit()
	var soffit := ShaderMaterial.new()
	soffit.shader = SURFACE
	soffit.set_shader_parameter("wear", load("res://assets/look/painted-wear.png"))
	soffit.set_shader_parameter("top_color", Color("c3cecb"))
	soffit.set_shader_parameter("side_color", Color("8ea3a3"))
	soffit.set_shader_parameter("wear_amount", 0.06)
	steel.material_override = soffit
	add_child(steel)
	# the breach hazard band read as a dashed route marking: under look c it is covered by deck,
	# drawn with the runway's own world-space material, a few millimetres over the paint.
	var mole_w: float = k.MOLE_W
	var mole_end: float = k.MOLE_END
	var patch := SurfaceTool.new()
	patch.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := float(k.TRACK_Y) + 0.010
	var x0 := mole_w + 0.5
	var x1 := mole_w + 13.3
	var z0 := mole_end + 1.72
	var z1 := mole_end + 3.08
	# both windings, so the patch faces up whichever order godot treats as front.
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var c := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	for v: Vector3 in [a, b, c, a, c, d, a, c, b, a, d, c]:
		patch.set_normal(Vector3.UP)
		patch.add_vertex(v)
	var deck := MeshInstance3D.new()
	deck.name = "BreachDeck"
	deck.mesh = patch.commit()
	deck.material_override = _material("Mesh_pavers")
	add_child(deck)
	# distance and gap figures painted on walls and decks are teaching text, not the place.
	var marks := level.get_node_or_null("Markings")
	if marks != null:
		for label: Node in marks.get_children():
			if label is Label3D and str(label.name) != "TerminalSign":
				_hidden.append(label as Node3D)
	# the lantern beam reads as a cold glare in the painted daylight; keep it a warm hint.
	var beam := level.get_node_or_null("Beam")
	if beam != null and beam.get_child_count() > 0 and beam.get_child(0) is MeshInstance3D:
		var fan := beam.get_child(0) as MeshInstance3D
		var old := fan.material_override as StandardMaterial3D
		if old != null:
			var soft := old.duplicate() as StandardMaterial3D
			soft.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			soft.albedo_color = Color(1.0, 0.88, 0.70, 0.30)
			swaps.append({"node": fan, "old": old, "new": soft})

func _slab(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	# a closed box, underside included, with outward flat normals.
	var faces := [
		[Vector3.UP, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]],
		[Vector3.DOWN, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)]],
		[Vector3.LEFT, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
		[Vector3.RIGHT, [Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z)]],
		[Vector3.FORWARD, [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3.BACK, [Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)]],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var q: Array = face[1]
		for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			# godot fronts are clockwise seen from outside.
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			if (b - a).cross(c - a).dot(n) > 0.0:
				var t := b
				b = c
				c = t
			for v: Vector3 in [a, b, c]:
				st.set_normal(n)
				st.add_vertex(v)

func _line(a: Vector3, b: Vector3, radius: float) -> void:
	if a.distance_squared_to(b) < 0.05:
		return
	var key := "%s/%s" % [a.snapped(Vector3.ONE*0.001),b.snapped(Vector3.ONE*0.001)]
	var reverse := "%s/%s" % [b.snapped(Vector3.ONE*0.001),a.snapped(Vector3.ONE*0.001)]
	if _edge_seen.has(key) or _edge_seen.has(reverse):
		return
	_edge_seen[key] = true
	line_count += 1
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()*radius
	var up := side.cross(axis).normalized()*radius
	var corners := [side+up,-side+up,-side-up,side-up]
	for i: int in 4:
		for point: Vector3 in [a+corners[i],b+corners[i],b+corners[(i+1)%4],a+corners[i],b+corners[(i+1)%4],a+corners[(i+1)%4]]:
			_lines.add_vertex(point)

func _edge_key(a: Vector3, b: Vector3) -> String:
	var aa := str(a.snapped(Vector3.ONE*0.001))
	var bb := str(b.snapped(Vector3.ONE*0.001))
	return aa+"/"+bb if aa < bb else bb+"/"+aa
