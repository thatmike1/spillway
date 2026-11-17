extends Node3D
## saltglass: high entries, rising crescent, flat exits and open water below the fins.

const GEO := preload("res://scripts/r19_course_geometry.gd")
const LEVEL_ID := "r21-saltglass"
const LEVEL_NAME := "Saltglass"
const LEVEL_VERSION := 3
const MAP_ID := "saltglass"
const MAP_ENTRY := {"name": LEVEL_NAME, "theme": "Low exits, climbing salt pans and outside lines", "kind": "course", "script": "res://scripts/r21_surf_level.gd"}
var level_id := LEVEL_ID
var level_name := LEVEL_NAME
var level_version := LEVEL_VERSION
var variant := "saltglass"
var spawn := Transform3D(Basis.IDENTITY, Vector3(9.7, 15.54, 16))
var finish_title := "Salt house"
var finish_position := Vector3(310, 4, 38)
var finish_radius := 4.0
var finish_bounds := AABB(Vector3(300, 3.7, 27), Vector3(22, 4, 22))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-40, -11, -240), Vector3(430, 80, 420))
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = []
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var jump_gaps: Array[Dictionary] = []
var routes: Dictionary = {}
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	# p / entry decks at 86.1% of the 18 m crest; both first contacts must exceed 80%.
	GEO.deck(self, "headrace", 6, 16, 0, 24, 15.5, 0)
	_fin("west", Transform3D.IDENTITY, 0)
	# p / lower flat supports are beyond the fin end, never beneath its face.
	GEO.deck(self, "west_landing", -16, 20, -197, -173, 7, 1)
	# p / nine ascending pans preserve the high second entry after the low fling.
	for i: int in 9:
		var x := 4.0 + 13.0 * i
		GEO.deck(self, "crescent_%d" % i, x, x + 11.5, -224, -200, 7.9 + 0.9 * i, 1)
	GEO.deck(self, "east_headrace", 108, 142, -206, -168, 15.5, 2)
	_fin("east", Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(132, 0, -168)), 2)
	GEO.deck(self, "east_landing", 112, 148, 5, 29, 7, 3)
	# p / a working salt quay has broken pans and a tall store, with water outside.
	for i: int in 9:
		var x := 128.0 + 19.0 * i
		GEO.deck(self, "salt_step_%d" % i, x, x + 16, 32, 54, 6.5 - 0.3 * i, 3)
	# the inland quay links the pans; its narrow necks stop short of the outside edge.
	for i: int in range(1, 9):
		var x := 128.0 + 19.0 * i
		GEO.deck(self, "quay_neck_%d" % i, x - 3, x, 32, 44, 6.8 - 0.3 * i, 3)
	GEO.deck(self, "outside_lip", 220, 223, 49, 54, 5.0, 3)
	GEO.deck(self, "house_neck", 296, 300, 32, 44, 4.1, 3)
	GEO.deck(self, "salt_house", 300, 322, 27, 64, 4, 3)
	# the store's south face ends at the quay edge. outside it there is only sea.
	GEO.prism(self, "salt_store", GEO.rectangle(215, 220, 40, 54, 11.3), 5.3, 3, "obstacle", "warehouse")
	_gap("crescent_first", Vector3(12, 7, -197), Vector3(12, 7.9, -200))
	for i: int in range(1, 9):
		var x := 4.0 + 13.0 * i
		_gap("crescent_%d" % i, Vector3(x - 1.5, 7.0 + 0.9 * i, -212), Vector3(x, 7.9 + 0.9 * i, -212))
	_gap("salt_first", Vector3(138, 7, 29), Vector3(138, 6.5, 32))
	for i: int in range(1, 9):
		var x := 128.0 + 19.0 * i
		_gap("salt_%d" % i, Vector3(x - 3, 6.8 - 0.3 * i, 53), Vector3(x, 6.5 - 0.3 * i, 53))
	_gap("salt_house", Vector3(296, 4.1, 53), Vector3(310, 4, 53))
	_define_progress()
	_environment()
	_sign("title", Vector3(10, 19, 24), PI, "SALTGLASS\nHIGH FINS / RISING CRESCENT / SALT STEPS", 0.006)
	_sign("surf_entry", Vector3(15, 20, 2), 0.0, "SURF\nA / D INTO THE FACE\nLET THE FIN CARRY YOU TO THE LOW DECK", 0.005)
	_sign("crescent", Vector3(120, 20, -236), 0, "CRESCENT\nCLIMB THROUGH THE HOPS", 0.007)
	_readable_surfaces()
	_dressing()
	_sign("salt_house", Vector3(322, 8, 38), -PI * 0.5, "SALT HOUSE\nFINISH", 0.009)
	_fixture_look.call_deferred()

func _fin(id: String, pose: Transform3D, stage: int) -> void:
	# p / 168 m fin; each 21 m prism stays below 32 m in every dimension.
	# p / 2 cm downhill seam relief is geometry, never a collision-law override.
	for i: int in 8:
		var a := -21.0 * i
		var b := -21.0 * (i + 1)
		var drop := 0.02 * i
		var top: Array[Vector3] = [pose * Vector3(0, -drop, a), pose * Vector3(12, 18 - drop, a), pose * Vector3(12, 18 - drop, b), pose * Vector3(0, -drop, b)]
		GEO.prism(self, "Surf_%s_%d" % [id, i], top, -5, stage, "surf", "steel_ramp")

func _define_progress() -> void:
	checkpoints = [
		{"pose": spawn, "title": "West fin", "bounds": AABB(Vector3(6, 15.2, 12), Vector3(10, 4, 12))},
		{"pose": Transform3D(Basis.IDENTITY, Vector3(6, 7.04, -194)), "title": "Climbing salt pans", "bounds": AABB(Vector3(-16, 6.7, -197), Vector3(36, 10, 24))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(122.3, 15.54, -178)), "title": "East fin", "bounds": AABB(Vector3(108, 15.2, -206), Vector3(34, 5, 38))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(126, 7.04, 26)), "title": "Salt quay", "bounds": AABB(Vector3(112, 6.7, 5), Vector3(36, 10, 24))},
	]
	routes = {"basic": [spawn.origin, Vector3(9.7, 15.5, 0), Vector3(5.3, 7.8, -168), Vector3(6, 7, -194), Vector3(12, 7.9, -222), Vector3(108, 15.1, -222), Vector3(122.3, 15.5, -178), Vector3(126.7, 7.8, 0), Vector3(126, 7, 26), Vector3(138, 6.5, 53), Vector3(205, 5.6, 47), Vector3(234, 5.3, 47), finish_position]}
	routes["outside"] = [Vector3(205, 5.6, 61), Vector3(212, 5.6, 63), Vector3(219, 7, 67), Vector3(231, 5.3, 63)]

func route_hint(stage: int, _feet: Vector3) -> String:
	match stage:
		0:
			return "Enter high, then let the fin carry you low and long to the flat deck. Water below."
		1:
			return "Link the climbing salt pans to the high east headrace. Every rise needs a clean hop."
		2:
			return "D presses into the east fin too. Spend speed on distance to the lower flat deck."
	return "The store splits the quay: broad inland landings, or a precise outside curve over water."

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

func geometry_hash() -> String:
	var data: Array = ["centred-convex-v1"]
	for piece: Dictionary in manifest:
		var points: Array = []
		for p: Vector3 in piece.points:
			points.append([p.x, p.y, p.z])
		data.append([piece.name, piece.stage, piece.role, piece.kind, points])
	# progress and finish volumes belong to the same identity as every solid.
	for point: Dictionary in checkpoints:
		var bounds: AABB = point.bounds
		data.append([point.title, _v(point.pose.origin), _v(bounds.position), _v(bounds.size)])
	data.append([LEVEL_ID, LEVEL_VERSION, _v(spawn.origin), _v(finish_position), _v(finish_bounds.position), _v(finish_bounds.size), _v(kill_bounds.position), _v(kill_bounds.size)])
	return JSON.stringify(data, "", false, true).sha256_text()

func _gap(id: String, edge: Vector3, land: Vector3) -> void:
	jump_gaps.append({"label": id, "edge": edge, "land": land, "recovery": "fall and respawn at last checkpoint"})

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b7cacc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdd0ce")
	env.ambient_light_energy = 0.5
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -110, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	var sea := MeshInstance3D.new()
	sea.name = "SaltglassWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	sea.mesh = plane
	sea.position = Vector3(0, -7, -40)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/look/saltglass_water.gdshader")
	sea.material_override = material
	add_child(sea)

func _sign(id: String, at: Vector3, yaw: float, text: String, pixels: float) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + id
	label.position = at
	label.rotation.y = yaw
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.modulate = Color("263d45")
	label.outline_size = 0
	add_child(label)

func _line(id: String, a: Vector3, b: Vector3, color: Color, radius: float) -> void:
	var node := MeshInstance3D.new()
	node.name = "Art_paint_dark_" + id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	node.mesh = mesh
	node.position = (a + b) * 0.5
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	var forward := side.cross(axis).normalized()
	node.basis = Basis(side, axis, forward)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	add_child(node)

static func _v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

func _dressing() -> void:
	# repeated supports describe one facility; they never add walkable collision.
	for piece: Dictionary in manifest:
		if piece.role != "route":
			continue
		var centre := Vector3.ZERO
		for p: Vector3 in piece.points.slice(0, 4):
			centre += p * 0.25
		var underside := centre.y - 0.8
		var bounds := AABB(piece.points[0], Vector3.ZERO)
		for point: Vector3 in piece.points.slice(0, 4):
			bounds = bounds.expand(point)
		if minf(bounds.size.x, bounds.size.z) > 8:
			# paired bents and full bearing beams make each pan a supported process bed.
			for z_sign: float in [-1, 1]:
				var z := centre.z + z_sign * bounds.size.z * 0.28
				_art_box("pan_bearing_%s_%s" % [piece.name, z_sign], Vector3(centre.x, underside - 0.55, z), Vector3(bounds.size.x - 0.4, 1.1, 1.8), Color("657f81"))
				for x_sign: float in [-1, 1]:
					var x := centre.x + x_sign * bounds.size.x * 0.28
					var top := underside - 1.1
					_art_box("pan_pile_%s_%s_%s" % [piece.name, x_sign, z_sign], Vector3(x, (top - 9.0) * 0.5, z), Vector3(1.8, top + 9.0, 1.8), Color("657f81"))
		else:
			_art_box("pier_" + str(piece.name), Vector3(centre.x, (underside - 9.0) * 0.5, centre.z), Vector3(1.4, underside + 9.0, 2.4), Color("657f81"))
	for z: float in [-10, -52, -94, -136]:
		_art_box("west_fin_foundation_%s" % z, Vector3(6, -7, z), Vector3(3, 4, 4), Color("526b6a"))
		_art_box("east_fin_foundation_%s" % z, Vector3(126, -7, -168 - z), Vector3(3, 4, 4), Color("526b6a"))
	# pump feet sit on the inland edge of each real pan, not beyond it.
	for i: int in 9:
		var x := 5.5 + 13.0 * i
		var top := 15.5 if i == 8 else 7.9 + 0.9 * i
		_art_box("pan_pump_%d" % i, Vector3(x, top + 0.65, -201.2), Vector3(2.4, 1.3, 1.4), Color("657f81"))
		_art_box("pump_foot_%d" % i, Vector3(x, top + 0.12, -201.2), Vector3(2.8, 0.24, 1.8), Color("263d45"))
		if i < 8:
			var next_top := 15.5 if i == 7 else top + 0.9
			_line("brine_header_%d" % i, Vector3(x, top + 0.45, -201.2), Vector3(x + 13, next_top + 0.45, -201.2), Color("657f81"), 0.18)
	# an open intake frame and brine tank form one supported skyline landmark.
	for x: float in [136.8, 142.2]:
		for z: float in [-202, -196]:
			_art_box("intake_leg_%s_%s" % [x, z], Vector3(x, 13, z), Vector3(0.9, 44, 0.9), Color("657f81"))
	_art_box("intake_bearing", Vector3(139.5, 22.75, -199), Vector3(7.8, 0.5, 8), Color("657f81"))
	_art_cylinder("brine_tank", Vector3(139.5, 28, -199), 3.0, 10, Color("657f81"))
	_art_cylinder("paint_brine_collar", Vector3(139.5, 28, -199), 3.04, 0.35, Color("d9ddcf"))
	_art_box("intake_crown", Vector3(139.5, 35.4, -199), Vector3(7.8, 0.8, 8), Color("b9b3a1"))
	for i: int in 5:
		_art_box("store_louvre_%d" % i, Vector3(217.5, 7.5 + i * 0.55, 54.03), Vector3(4.9, 0.12, 0.1), Color("263d45"))
	# the loading canopy bears on four columns planted on the finish deck.
	_art_box("salt_house_roof", Vector3(314, 9, 58), Vector3(12, 0.4, 9), Color("657f81"))
	for x: float in [308.5, 319.5]:
		for z: float in [54.5, 61.5]:
			_art_box("house_column_%s_%s" % [x, z], Vector3(x, 6.4, z), Vector3(0.35, 4.8, 0.35), Color("657f81"))
	# bulk salt sits under the loading canopy, clear of the finish approach.
	for x: float in [311, 317]:
		var heap := _art_cylinder("salt_heap_%d" % int(x), Vector3(x, 5.4, 58), 2.4, 2.8, Color("eee7d6"))
		(heap.mesh as CylinderMesh).top_radius = 0.15
		(heap.mesh as CylinderMesh).radial_segments = 7
		heap.name = "SaltglassSalt_%d" % int(x)
	_sign("store_stencil", Vector3(214.97, 8.8, 49), -PI * 0.5, "SALT\n04", 0.025)
	(get_node("Sign_store_stencil") as Label3D).modulate = Color("e8dfc9")
	for foot: Vector3 in [Vector3(210, 5.3, 52.8), Vector3(248, 4.7, 52.8), Vector3(286, 4.1, 52.8), Vector3(312, 4, 52.8)]:
		_work_lamp("quay_%d" % int(foot.x), foot, 3.8)
	# this founded harbour beacon sits seaward of the blind corner, not on a fake platform.
	_work_lamp("seaward_beacon", Vector3(221.5, -9, 57.5), 18.0)
	for x: float in [306, 320]:
		_art_box("mooring_pile_%s" % x, Vector3(x, -3, 68), Vector3(0.7, 12, 0.7), Color("586b6b"))

func _art_box(id: String, at: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Art_" + id
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	node.material_override = material
	add_child(node)
	return node

func _readable_surfaces() -> void:
	# map-local names keep the shared look swap from erasing slope readability.
	for node: Node in get_children():
		if node is MeshInstance3D and str(node.name).begins_with("Mesh_"):
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/look/saltglass_surface.gdshader")
			material.set_shader_parameter("surf", "steel_ramp" in str(node.name))
			material.set_shader_parameter("crest", node.mesh.get_aabb().end.y)
			var bounds: AABB = node.mesh.get_aabb()
			material.set_shader_parameter("pan", "crescent_" in str(node.name) or "salt_step_" in str(node.name))
			material.set_shader_parameter("pan_bounds", Vector4(bounds.position.x, bounds.position.z, bounds.end.x, bounds.end.z))
			material.set_shader_parameter("wear", preload("res://assets/look/painted-wear.png"))
			node.material_override = material
			node.name = "SaltglassSurface_" + str(node.name)
	# short edge bands announce takeoff and the tiny receiver in both look modes.
	_art_box("paint_lip_outside_takeoff", Vector3(210.8, 5.312, 53.82), Vector3(7.5, 0.025, 0.3), Color("d95b30"))
	_art_box("paint_lip_outside_receiver", Vector3(221.5, 5.012, 53.82), Vector3(3, 0.025, 0.3), Color("d95b30"))
	# paint follows the actual seaward store edge around the blind corner, with no fake ledge.
	_art_box("paint_hazard_store_corner", Vector3(214.992, 5.45, 53.84), Vector3(0.016, 0.3, 0.32), Color("d95b30"))
	_art_box("paint_hazard_store_seaward", Vector3(217.5, 5.45, 54.008), Vector3(5, 0.3, 0.016), Color("d95b30"))
	_art_box("paint_lip_west_land", Vector3(2, 7.012, -173.15), Vector3(36, 0.025, 0.3), Color("d95b30"))
	_art_box("paint_lip_east_land", Vector3(130, 7.012, 5.15), Vector3(36, 0.025, 0.3), Color("d95b30"))


func _art_cylinder(id: String, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Art_" + id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	node.material_override = material
	add_child(node)
	return node

func _work_lamp(id: String, foot: Vector3, height: float) -> void:
	_art_box("lamp_pole_" + id, foot + Vector3.UP * height * 0.5, Vector3(0.18, height, 0.18), Color("526b75"))
	_art_box("lamp_arm_" + id, foot + Vector3(0, height - 0.15, -0.65), Vector3(0.18, 0.16, 1.3), Color("526b75"))
	var head := _art_box("lamp_head_" + id, foot + Vector3(0, height - 0.3, -1.15), Vector3(0.65, 0.22, 0.7), Color("fff0ce"))
	var material := head.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color("fff0ce")
	material.emission_energy_multiplier = 0.25

func _fixture_look() -> void:
	# keep ordinary hop edges quiet; orange is reserved for low exits and the outside choice.
	for lip: Node in find_children("JumpLips", "MeshInstance3D", true, false):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("c3c8b9")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		lip.material_override = material
	for look: Node in find_children("R17Look", "Node3D", true, false):
		var environment: Environment = look.get("painted_environment")
		if environment != null and environment.sky != null:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/look/saltglass_sky.gdshader")
			material.set_shader_parameter("panorama", preload("res://assets/look/r17/practice-sky.png"))
			environment.sky.sky_material = material
