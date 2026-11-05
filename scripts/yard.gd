extends "res://scripts/level.gd"
## original open-air test yard. dimensions are metres; every station has a bypass.
var stations: Dictionary = {}
var _grid: SurfaceTool

func build() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 731
	_make_materials()
	_environment()
	for child: Node in get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_energy = .48
			child.environment.fog_density = .001
	_grid = SurfaceTool.new()
	_grid.begin(Mesh.PRIMITIVE_LINES)
	_platform(Vector3(2, 0, -35), Vector2(28, 94), "MainApron")
	spawn = Transform3D(Basis.IDENTITY, Vector3(0, .9, 3))
	stations["straight"] = {"length": 75.0, "start": Vector3(0, 0, 3), "end": Vector3(0, 0, -72)}
	_sign("75 m  /  sprint lane", Vector3(-2, 1, 0))
	for z: float in [3.0, -72.0]:
		_mesh(self, Vector3(0, .015, z), Vector3(3, .02, .08), _materials.lane)
	# an actual clear 2.1 m door opening, rather than a scaled painted silhouette.
	_solid(self, Vector3(5.35, 1.05, 3), Vector3(.2, 2.1, .3), _materials.metal, "DoorLeft")
	_solid(self, Vector3(6.65, 1.05, 3), Vector3(.2, 2.1, .3), _materials.metal, "DoorRight")
	_solid(self, Vector3(6, 2.2, 3), Vector3(1.5, .2, .3), _materials.metal, "DoorLintel")
	stations["door"] = {"height": 2.1, "point": Vector3(6, 0, 3)}
	_sign("2.1 m doorway  /  1 m grid", Vector3(6, 2.7, 3))
	var heights: Array[float] = [.35, .65, 1, 1.4, 1.8]
	for i: int in heights.size():
		var h: float = heights[i]
		var z: float = -12 - i * 12
		var body := _solid(self, Vector3(8, h / 2, z), Vector3(3, h, .55), _materials.concrete_dark, "Obstacle%d" % i)
		_mark_object(body)
		stations["obstacle%d" % i] = {"height": h, "body": body, "bypass": Vector3(12, 0, z)}
		_sign("%.2f m   /   bypass right" % h, Vector3(10.8, .9, z + 1))
	# grab/climb station, with stairs at its right for a walking bypass.
	_platform(Vector3(21, 0, -3), Vector2(10, 24), "ClimbApproach")
	_platform(Vector3(21, 2.8, -22), Vector2(7, 14), "GrabLedge")
	stations["grab"] = {"height": 2.8, "front": Vector3(21, 2.8, -15)}
	_sign("2.8 m  /  jump, climb, grab", Vector3(21, 3.5, -15))
	for i: int in 10:
		_solid(self, Vector3(26, .14 * (i + 1), -13 - i * .5), Vector3(2, .28 * (i + 1), .5), _materials.concrete)
	_platform(Vector3(25.5, 2.8, -22), Vector2(2, 8), "LedgeBypass")
	for i: int in 5:
		var x: float = 34 + i * 8
		var gap: float = 2 + i
		_platform(Vector3(x, 0, -11), Vector2(5, 38), "GapApproach%d" % i)
		_platform(Vector3(x, 0, -46 - gap / 2), Vector2(5, 32 - gap), "GapLanding%d" % i)
		# side bridge is deliberately lower than the landing lip, distinct from the gap.
		_platform(Vector3(x + 3.3, -.1, -35), Vector2(1.4, 54), "GapBypass%d" % i)
		stations["gap%d" % int(gap)] = {"width": gap, "front": Vector3(x, 0, -30), "landing": Vector3(x, 0, -30 - gap), "bypass": Vector3(x + 3.3, -.1, -32)}
		_sign("%d m gap" % int(gap), Vector3(x, .8, -23))
	# crosswalk at the north end joins the lanes without crossing their test gaps.
	_platform(Vector3(43, 0, 7), Vector2(57, 4), "GapAccess")
	for i: int in 3:
		var h: float = [1.0, 3.0, 6.0][i]
		var x: float = -20 - i * 10
		_platform(Vector3(x, h, -8), Vector2(6, 24), "DropStart%d" % int(h))
		_platform(Vector3(x, 0, -35), Vector2(6, 30), "DropLanding%d" % int(h))
		# a sloping side ramp allows access and bypass in either direction.
		var ramp := _solid(self, Vector3(x + 4.2, h / 2, -8), Vector3(2, .3, sqrt(24 * 24 + h * h)), _materials.concrete_dark, "DropBypass%d" % int(h))
		ramp.rotation.x = atan2(h, 24)
		stations["drop%d" % int(h)] = {"height": h, "start": Vector3(x, h + .9, -6), "front": Vector3(x, h, -20), "bypass": ramp}
		_sign("%d m drop" % int(h), Vector3(x, h + 1, -17))
	_platform(Vector3(-26, 0, 8), Vector2(35, 8), "DropAccess")
	# loop: clear apron out, low vault, springboard, wall run, then return on the apron.
	var rail := _solid(self, Vector3(-7, .45, -18), Vector3(3, .9, .35), _materials.metal, "ChainRail")
	_mark_object(rail)
	_solid(self, Vector3(-7, .32, -39), Vector3(2, .64, .45), _materials.concrete_dark, "SpringFirst")
	_solid(self, Vector3(-7, .60, -40.12), Vector3(2, 1.2, .45), _materials.concrete_dark, "SpringSecond")
	stations["springboard"] = {"first": Vector3(-7, .64, -39), "second": Vector3(-7, 1.2, -40.12)}
	_solid(self, Vector3(-10.7, 2.5, -65), Vector3(.4, 5, 18), _materials.concrete_dark, "WallRunWall")
	_mesh(self, Vector3(-10.47, 2.0, -65), Vector3(.04, .12, 18), _materials.metal)
	stations["wallrun"] = {"point": Vector3(-10.3, 1, -58), "length": 18.0}
	stations["climb"] = stations.grab
	stations["loop"] = {"rail": rail, "bypass": Vector3(-3, 0, -18)}
	_sign("Chain loop  /  vault, springboard, wall run", Vector3(-6, 1.1, -7))
	_sign("Drop stations  /  return via side ramps", Vector3(-17, .9, 5))
	# distant perimeter gives a horizon without introducing a city traversal puzzle.
	for x: float in [-49, 77]:
		_solid(self, Vector3(x, 3, -30), Vector3(.5, 6, 105), _materials.dark)
	for z: float in [19, -88]:
		_solid(self, Vector3(14, 3, z), Vector3(126, 6, .5), _materials.dark)
	var grid_mesh := MeshInstance3D.new()
	grid_mesh.mesh = _grid.commit()
	grid_mesh.material_override = _standard(Color("#818b93"), 1)
	grid_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid_mesh)
	finish_point = Vector3(0, 0, -78)
	finish_trigger = _trigger("YardLap", Vector3(0, 1, -79), Vector3(3, 3, 1))
	checkpoints.append({"area": null, "pose": spawn, "folds_down": 0})

func _platform(top: Vector3, size: Vector2, node_name: String) -> void:
	_solid(self, top - Vector3.UP * .25, Vector3(size.x, .5, size.y), _materials.concrete, node_name)
	for x: int in range(ceili(top.x - size.x / 2), floori(top.x + size.x / 2) + 1):
		_grid.add_vertex(Vector3(x, top.y + .012, top.z - size.y / 2))
		_grid.add_vertex(Vector3(x, top.y + .012, top.z + size.y / 2))
	for z: int in range(ceili(top.z - size.y / 2), floori(top.z + size.y / 2) + 1):
		_grid.add_vertex(Vector3(top.x - size.x / 2, top.y + .012, z))
		_grid.add_vertex(Vector3(top.x + size.x / 2, top.y + .012, z))

func _sign(text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = 40
	label.pixel_size = .008
	label.modulate = Color("#f3d4a2")
	label.no_depth_test = false
	add_child(label)
