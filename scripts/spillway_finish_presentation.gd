extends Node3D
## p / the finish bay as working machinery: a bucketed wheel fed by a wall penstock and flume,
## a grated tailrace pit and a loading door give the lower hall a purpose.
## visual only: nothing here collides, every added solid-looking part sits flush on existing
## solids or above reach, and the gate and water answer level._wheel_running and reset with it.

const WATER_SHADER: Shader = preload("res://shaders/spillway_finish_water.gdshader")
const CENTRE := Vector3(23.8, -0.5, -69.15)
const RADIUS := 2.45
const WALL_Z := -69.5
# p / head race: the wall outlet, its flume along the hall face and the lip over the wheel.
const OUTLET_X := 19.6
const FLUME_X := Vector2(19.0, 24.45)
const FLUME_Y := 2.25
const FLUME_FRONT := -68.88
const GATE_LIFT := 0.5

var _level: Node3D
var _materials: Dictionary
var _flow: float = 0.0
var _gate: Node3D
var _handwheel: Node3D
var _sheets: Array[MeshInstance3D] = []
var _sheet_material: ShaderMaterial
var _pit_material: ShaderMaterial


func build(level: Node3D, materials: Dictionary) -> void:
	_level = level
	_materials = materials
	name = "ArtFinishPresentation"
	# the batching pass keeps everything under this node live so the gate can move.
	set_meta("moving_geometry", true)
	_pit_material = ShaderMaterial.new()
	_pit_material.shader = WATER_SHADER
	_materials["art_finish_pit"] = _pit_material
	_sheet_material = ShaderMaterial.new()
	_sheet_material.shader = WATER_SHADER
	_sheet_material.set_shader_parameter("sheet", true)
	_hall_face()
	_wheel_buckets()
	_bearing()
	_head_race()
	_gate_and_spindle()
	_sheets_of_water()
	_tailrace()


func _process(delta: float) -> void:
	if _level == null:
		return
	if bool(_level.get("_wheel_running")):
		_flow = move_toward(_flow, 1.0, delta * 0.7)
	else:
		_flow = 0.0
	var lift := smoothstep(0.0, 0.4, _flow)
	_gate.position.y = lift * GATE_LIFT
	_handwheel.rotation.y = lift * TAU * 3.0
	var reveal := smoothstep(0.25, 0.95, _flow)
	_sheet_material.set_shader_parameter("reveal", reveal * 1.08)
	_pit_material.set_shader_parameter("flow", smoothstep(0.5, 1.0, _flow))
	for sheet: MeshInstance3D in _sheets:
		sheet.visible = reveal > 0.0


func _hall_face() -> void:
	# p / the blank lower-hall front becomes a loading front: a steel roller door onto the apron,
	# a three-light clerestory above it and a plinth band; all flush on the existing wall.
	var z := WALL_Z
	_box(Vector3(16.6, -1.25, z + 0.03), Vector3(3.4, 3.5, 0.06), "steel")
	for i: int in 9:
		_box(Vector3(16.6, -2.85 + float(i) * 0.4, z + 0.065), Vector3(3.34, 0.035, 0.02), "shadow")
	_box(Vector3(16.6, 0.72, z + 0.14), Vector3(3.9, 0.46, 0.28), "steel")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(16.6 + side * 1.82, -1.25, z + 0.05), Vector3(0.18, 3.5, 0.1), "concrete")
		_box(Vector3(16.6 + side * 1.82, -2.4, z + 0.075), Vector3(0.2, 1.2, 0.14), "ochre")
	_box(Vector3(16.6, 1.12, z + 0.06), Vector3(4.2, 0.3, 0.12), "concrete")
	for x: float in [15.35, 16.6, 17.85]:
		_box(Vector3(x, 2.85, z + 0.02), Vector3(1.05, 2.6, 0.04), "art_glass")
		_box(Vector3(x, 2.85, z + 0.05), Vector3(0.06, 2.6, 0.06), "steel")
		for row: int in 3:
			_box(Vector3(x, 1.95 + float(row) * 0.9, z + 0.05), Vector3(1.05, 0.06, 0.06), "steel")
	_box(Vector3(16.6, 1.5, z + 0.08), Vector3(4.0, 0.12, 0.16), "concrete")
	_box(Vector3(16.6, 4.2, z + 0.05), Vector3(4.0, 0.14, 0.1), "concrete")
	# a darker splash plinth ties the hall to the apron instead of a hard pale seam.
	_box(Vector3(19.0, -2.82, z + 0.025), Vector3(11.0, 0.36, 0.05), "old_concrete")


func _wheel_buckets() -> void:
	# p / a second rim, a sole ring and inclined steel buckets give the wheel depth and purpose.
	var pivot := _level.get("_hero_wheel") as Node3D
	if pivot == null:
		return
	var ochre: Array = []
	var steel: Array = []
	var back := -0.24
	var rim := BoxMesh.new()
	rim.size = Vector3(0.15, 2.0 * PI * RADIUS / 32.0 + 0.02, 0.15)
	for i: int in 32:
		var angle := TAU * (float(i) + 0.5) / 32.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		ochre.append([rim, Transform3D(Basis(Vector3.BACK, angle), radial * RADIUS * 0.996 + Vector3.BACK * back)])
	var sole := BoxMesh.new()
	sole.size = Vector3(0.03, 2.0 * PI * 2.1 / 24.0 + 0.01, 0.3)
	var bucket := BoxMesh.new()
	bucket.size = Vector3(0.03, 0.44, 0.24)
	for i: int in 24:
		var angle := TAU * float(i) / 24.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		steel.append([sole, Transform3D(Basis(Vector3.BACK, angle), radial * 2.1 + Vector3.BACK * -0.12)])
		# each bucket board leans back from the radius so the wheel reads as made to carry water.
		var lean := angle - PI * 0.5 + 0.55
		var at := radial * 2.3 + Vector3.BACK * -0.12
		steel.append([bucket, Transform3D(Basis(Vector3.BACK, lean), at)])
	for i: int in 8:
		var angle := TAU * float(i) / 8.0 + PI / 8.0
		var arm := BoxMesh.new()
		arm.size = Vector3(0.08, 2.0, 0.08)
		steel.append([arm, Transform3D(Basis(Vector3.BACK, angle - PI * 0.5), Vector3(cos(angle), sin(angle), 0.0) * 1.1 + Vector3.BACK * -0.2)])
	var flange := CylinderMesh.new()
	flange.top_radius = 0.62
	flange.bottom_radius = 0.62
	flange.height = 0.1
	flange.radial_segments = 20
	steel.append([flange, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.BACK * 0.11)])
	var boss := CylinderMesh.new()
	boss.top_radius = 0.07
	boss.bottom_radius = 0.07
	boss.height = 0.08
	boss.radial_segments = 8
	for i: int in 8:
		var angle := TAU * float(i) / 8.0
		ochre.append([boss, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(cos(angle), sin(angle), 0.0) * 0.47 + Vector3.BACK * 0.18)])
	pivot.add_child(_merge("WheelBucketsOchre", ochre, _materials["ochre"]))
	pivot.add_child(_merge("WheelBucketsSteel", steel, _materials["steel"]))


func _bearing() -> void:
	# p / the axle enters the hall through a bolted bearing plate, flush on the wall.
	_box(Vector3(CENTRE.x, CENTRE.y, WALL_Z + 0.03), Vector3(1.5, 1.5, 0.06), "steel")
	_box(Vector3(CENTRE.x, CENTRE.y - 0.98, WALL_Z + 0.03), Vector3(1.9, 0.36, 0.06), "steel")
	for i: int in 8:
		var angle := TAU * (float(i) + 0.5) / 8.0
		_box(Vector3(CENTRE.x + cos(angle) * 0.62, CENTRE.y + sin(angle) * 0.62, WALL_Z + 0.075), Vector3(0.09, 0.09, 0.05), "ochre")


func _head_race() -> void:
	# p / an open riveted flume carried on wall brackets drops water on the wheel's east crown.
	var length := FLUME_X.y - FLUME_X.x
	var mid := (FLUME_X.x + FLUME_X.y) * 0.5
	var depth := FLUME_FRONT - WALL_Z
	_box(Vector3(mid, FLUME_Y + 0.03, WALL_Z + depth * 0.5), Vector3(length, 0.06, depth), "steel")
	_box(Vector3(mid, FLUME_Y + 0.22, FLUME_FRONT - 0.025), Vector3(length, 0.44, 0.05), "steel")
	_box(Vector3(FLUME_X.x + 0.025, FLUME_Y + 0.22, WALL_Z + depth * 0.5), Vector3(0.05, 0.44, depth), "steel")
	_box(Vector3(mid, FLUME_Y + 0.45, FLUME_FRONT - 0.02), Vector3(length + 0.04, 0.06, 0.1), "steel")
	var ribs: int = 7
	for i: int in ribs:
		var x := lerpf(FLUME_X.x + 0.3, FLUME_X.y - 0.15, float(i) / float(ribs - 1))
		_box(Vector3(x, FLUME_Y + 0.2, FLUME_FRONT + 0.01), Vector3(0.07, 0.46, 0.04), "steel")
	# a short down-turned lip over the wheel.
	_box(Vector3(FLUME_X.y + 0.06, FLUME_Y - 0.02, WALL_Z + depth * 0.5), Vector3(0.14, 0.05, depth), "steel")
	# knee brackets stay west of the wheel; a hanger carries the free end from above.
	for x: float in [19.7, 20.95]:
		_beam(Vector3(x, FLUME_Y - 0.75, WALL_Z), Vector3(x, FLUME_Y, FLUME_FRONT), 0.07)
		_box(Vector3(x, FLUME_Y - 0.01, WALL_Z + depth * 0.5), Vector3(0.08, 0.06, depth), "steel")
		_box(Vector3(x, FLUME_Y - 0.75, WALL_Z + 0.02), Vector3(0.24, 0.3, 0.04), "steel")
	var hang_x := FLUME_X.y - 0.3
	_beam(Vector3(hang_x, FLUME_Y + 0.45, FLUME_FRONT - 0.02), Vector3(hang_x, 3.75, FLUME_FRONT - 0.02), 0.04)
	_box(Vector3(hang_x, 3.78, (WALL_Z + FLUME_FRONT) * 0.5), Vector3(0.1, 0.1, depth + 0.04), "steel")
	_box(Vector3(hang_x, 3.78, WALL_Z + 0.02), Vector3(0.26, 0.3, 0.04), "steel")


func _gate_and_spindle() -> void:
	# p / a wall penstock: dark outlet, guide channels and a rising-spindle headstock.
	var x := OUTLET_X
	var z := WALL_Z
	var sill := FLUME_Y + 0.45
	_box(Vector3(x, sill + 0.4, z + 0.01), Vector3(0.84, 0.8, 0.02), "shadow")
	_box(Vector3(x, sill - 0.04, z + 0.06), Vector3(1.3, 0.08, 0.12), "steel")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(x + side * 0.56, sill + 0.75, z + 0.07), Vector3(0.12, 1.5, 0.14), "steel")
	# the headstock stands proud of the hall cornice so the spindle can rise in front of it.
	_box(Vector3(x, sill + 1.6, z + 0.17), Vector3(1.4, 0.16, 0.34), "steel")
	_box(Vector3(x, sill + 1.71, z + 0.26), Vector3(0.3, 0.06, 0.16), "ochre")
	# the moving gate and handwheel are two merged meshes each and too small to need shadows.
	_gate = Node3D.new()
	_gate.name = "PenstockGate"
	add_child(_gate)
	var plate := BoxMesh.new()
	plate.size = Vector3(1.0, 0.92, 0.05)
	var stiffener := BoxMesh.new()
	stiffener.size = Vector3(0.96, 0.06, 0.04)
	var yoke := BoxMesh.new()
	yoke.size = Vector3(0.22, 0.1, 0.24)
	var spindle := CylinderMesh.new()
	spindle.top_radius = 0.035
	spindle.bottom_radius = 0.035
	spindle.height = 1.1
	spindle.radial_segments = 8
	_gate.add_child(_merge("GateSteel", [
		[plate, Transform3D(Basis.IDENTITY, Vector3(x, sill + 0.44, z + 0.075))],
		[yoke, Transform3D(Basis.IDENTITY, Vector3(x, sill + 0.92, z + 0.18))],
		[spindle, Transform3D(Basis.IDENTITY, Vector3(x, sill + 1.45, z + 0.26))],
	], _materials["steel"], false))
	_gate.add_child(_merge("GatePaint", [[stiffener, Transform3D(Basis.IDENTITY, Vector3(x, sill + 0.62, z + 0.115))]], _materials["ochre"], false))
	# the handwheel sits on the headstock and turns while the gate rises.
	_handwheel = Node3D.new()
	_handwheel.position = Vector3(x, sill + 1.82, z + 0.26)
	add_child(_handwheel)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.3
	torus.rings = 20
	torus.ring_segments = 6
	var spoke := BoxMesh.new()
	spoke.size = Vector3(0.52, 0.03, 0.03)
	_handwheel.add_child(_merge("HandwheelRim", [[torus, Transform3D.IDENTITY]], _materials["ochre"], false))
	_handwheel.add_child(_merge("HandwheelSpokes", [[spoke, Transform3D.IDENTITY],
		[spoke, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)]], _materials["steel"], false))


func _sheets_of_water() -> void:
	# p / outlet pour into the flume, then the lip spill riding down the wheel's east buckets.
	var sill := FLUME_Y + 0.45
	var outlet: Array[Vector3] = [Vector3(OUTLET_X, sill + 0.1, WALL_Z + 0.03), Vector3(OUTLET_X, sill + 0.07, WALL_Z + 0.2),
		Vector3(OUTLET_X, sill - 0.08, WALL_Z + 0.33), Vector3(OUTLET_X, FLUME_Y + 0.1, WALL_Z + 0.4)]
	_sheets.append(_ribbon("OutletPour", outlet, Vector3.RIGHT, 0.78))
	var z := -69.22
	var path: Array[Vector3] = [Vector3(FLUME_X.y + 0.1, FLUME_Y - 0.03, z)]
	var radius := RADIUS + 0.13
	var start := acos((FLUME_X.y + 0.12 - CENTRE.x) / radius)
	var finish := -1.24
	for i: int in 19:
		var angle := lerpf(start, finish, float(i) / 18.0)
		path.append(Vector3(CENTRE.x + cos(angle) * radius, CENTRE.y + sin(angle) * radius, z))
	path.append(Vector3(path[-1].x - 0.05, -2.99, z))
	_sheets.append(_ribbon("WheelSpill", path, Vector3.BACK, 0.42))
	# seen from the apron the spill would be edge-on, so the lip pour and the water held in the
	# descending buckets also face the arrival view between the two rims.
	var lip: Array[Vector3] = [Vector3(FLUME_X.y + 0.12, FLUME_Y - 0.02, -68.96), path[1] + Vector3(0.0, 0.0, 0.26)]
	_sheets.append(_ribbon("LipPour", lip, Vector3.RIGHT, 0.34))
	var held: Array[Vector3] = []
	for i: int in 15:
		var angle := lerpf(start - 0.12, -1.42, float(i) / 14.0)
		held.append(Vector3(CENTRE.x + cos(angle) * 2.27, CENTRE.y + sin(angle) * 2.27, -69.08))
	_sheets.append(_ribbon("BucketWater", held, Vector3.ZERO, 0.0, 0.3))


func _ribbon(label: String, path: Array[Vector3], across: Vector3, width: float, radial: float = 0.0) -> MeshInstance3D:
	# a strip of water along path, width metres across; uv.y runs from the lip to the end.
	# radial > 0 instead spans that width outward from the wheel centre, in the wheel's plane.
	var total: float = 0.0
	var lengths: Array[float] = [0.0]
	for i: int in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
		lengths.append(total)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in path.size() - 1:
		var quad: Array[Vector3] = []
		var uv: Array[Vector2] = []
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var p := path[i + corner.y]
			var v := lengths[i + corner.y] / total
			if radial > 0.0:
				var out := Vector3(p.x - CENTRE.x, p.y - CENTRE.y, 0.0).normalized()
				quad.append(p + out * radial * (float(corner.x) - 0.5))
			else:
				quad.append(p + across * width * (float(corner.x) - 0.5))
			uv.append(Vector2(corner.x, v))
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.set_uv(uv[index])
			tool.add_vertex(quad[index])
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = tool.commit()
	instance.material_override = _sheet_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = false
	add_child(instance)
	return instance


func _tailrace() -> void:
	# p / the wheel turns over a grated tailrace that runs east and south into the tower culvert.
	# the overlays are 1.5 cm skins on the existing floor; their ochre curbs are paint, not steps.
	var top := -3.0
	var skin := 0.015
	_box(Vector3(23.9, top + skin * 0.5, -68.55), Vector3(5.8, skin, 1.9), "art_finish_pit")
	_box(Vector3(25.85, top + skin * 0.5, -71.75), Vector3(2.3, skin, 4.5), "art_finish_pit")
	_box(Vector3(23.9, top + 0.006, -67.58), Vector3(5.8, 0.012, 0.06), "ochre")
	_box(Vector3(21.03, top + 0.006, -68.55), Vector3(0.06, 0.012, 1.9), "ochre")
	_box(Vector3(26.77, top + 0.006, -70.95), Vector3(0.06, 0.012, 6.1), "ochre")
	_box(Vector3(24.73, top + 0.006, -71.75), Vector3(0.06, 0.012, 4.5), "ochre")
	# the culvert mouth in the tower front: a dark opening, a cast surround and screen bars.
	var face := -74.0
	_box(Vector3(25.85, -2.3, face + 0.02), Vector3(1.5, 1.4, 0.04), "shadow")
	_box(Vector3(25.85, -1.45, face + 0.05), Vector3(2.1, 0.3, 0.1), "concrete")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(25.85 + side * 0.9, -2.3, face + 0.05), Vector3(0.3, 1.4, 0.1), "concrete")
	for i: int in 6:
		_box(Vector3(25.25 + float(i) * 0.24, -2.3, face + 0.045), Vector3(0.04, 1.4, 0.04), "steel")
	# a lean-to hood over the tailrace, carried by the hall and the tower, well above reach.
	_box(Vector3(26.15, 2.62, -71.75), Vector3(3.3, 0.18, 4.5), "concrete")
	_box(Vector3(26.15, 2.42, WALL_Z - 0.1), Vector3(3.3, 0.6, 0.2), "concrete")
	_box(Vector3(26.15, 2.1, WALL_Z - 0.12), Vector3(3.3, 0.05, 0.24), "shadow")


func _merge(label: String, parts: Array, material: Material, shadows: bool = true) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	for part: Array in parts:
		tool.append_from(part[0], 0, part[1])
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = tool.commit()
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _box(center: Vector3, size: Vector3, material: String) -> void:
	_level.call("_box", center, size, material)


func _beam(a: Vector3, b: Vector3, thickness: float) -> void:
	_level.call("_beam", a, b, thickness, "steel")
