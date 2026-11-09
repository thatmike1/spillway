extends Node3D
## a three-corner launch circuit: speed and alignment earn the flight, lower courts catch misses.
const GEO := preload("res://scripts/r19_course_geometry.gd")
const PLAYER := preload("res://scripts/r19_line_drive_player.gd")
const MAP_ID := "line-drive"
const MAP_ENTRY := {"name": "Line Drive", "theme": "Aligned speed earns three launch transfers", "kind": "experiment", "experimental": true,
	"script": "res://scripts/r19_line_drive_level.gd", "runner": "res://scripts/r19_line_drive_player.gd",
	"instructions": "EXPERIMENTAL · carry 300+ u/s onto a launch pad, moving along its line. Each pad fires once per attempt. R resets the circuit."}
var level_id := "r19-line-drive"
var level_name := "Line Drive"
var level_version := 2
var variant := MAP_ID
var spawn := Transform3D(Basis.IDENTITY, Vector3(0, 6.04, 12))
var finish_title := "Launch house"
var finish_position := Vector3(79, 9, 14)
var finish_radius := 5.0
var finish_bounds := AABB(Vector3(70, 8.8, 7), Vector3(18, 5, 15))
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-22, -8, -88), Vector3(130, 60, 130))
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var mechanics: Array = []
var manifest: Array[Dictionary] = []
var prisms: Array[Dictionary] = []
var jump_gaps: Array[Dictionary] = []
var launch_pads: Array[Dictionary] = []
var _built := false

func build() -> void:
	if _built:
		return
	_built = true
	GEO.deck(self, "run_in", -8, 8, -32, 18, 6, 0)
	_pad("LaunchWest", -6, 6, -44, -32, 6, 0, Vector3.FORWARD)
	GEO.deck(self, "west_landing", -8, 12, -68, -48, 7, 1)
	GEO.deck(self, "east_run", 12, 40, -68, -50, 7, 1)
	_pad("LaunchEast", 40, 56, -66, -54, 7, 1, Vector3.RIGHT)
	GEO.deck(self, "east_landing", 66, 94, -68, -50, 8, 2)
	GEO.deck(self, "home_run", 70, 90, -50, -24, 8, 2)
	_pad("LaunchHome", 72, 86, -24, -8, 8, 2, Vector3.BACK)
	GEO.deck(self, "finish", 68, 90, 2, 28, 9, 3)
	GEO.deck(self, "low_return", -14, 100, -82, 34, 0, -1, "recovery")
	var ramp: Array[Vector3] = [Vector3(-6, 6, 18), Vector3(6, 6, 18), Vector3(6, 0, 30), Vector3(-6, 0, 30)]
	GEO.prism(self, "return_ramp", ramp, -0.8, -1, "recovery")
	checkpoints = [
		{"pose": spawn, "title": "Launch west", "bounds": AABB(Vector3(-8, 5.8, 6), Vector3(16, 4, 12))},
		{"pose": Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(2, 7.04, -57)), "title": "Launch east", "bounds": AABB(Vector3(-8, 6.8, -68), Vector3(20, 6, 24))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(79, 8.04, -57)), "title": "Launch home", "bounds": AABB(Vector3(66, 7.8, -68), Vector3(28, 6, 18))},
		{"pose": Transform3D(Basis(Vector3.UP, PI), Vector3(79, 9.04, 4)), "title": "Launch house", "bounds": AABB(Vector3(68, 8.8, 2), Vector3(22, 6, 10))}]
	for point: Dictionary in checkpoints:
		segment_bounds.append(point.bounds)
	var landings := [Vector3(0, 7, -48), Vector3(66, 8, -58), Vector3(79, 9, 2)]
	for i: int in launch_pads.size():
		var pad: Dictionary = launch_pads[i]
		var edge: Vector3 = (pad.bounds as AABB).get_center()
		edge += pad.direction * (6.0 if i == 0 else 8.0)
		edge.y = [6.0, 7.0, 8.0][i]
		jump_gaps.append({"label": pad.id, "edge": edge, "land": landings[i], "recovery": "low court returns to the start"})
	_environment()
	_sign("title", Vector3(0, 10, 17), PI, "LINE DRIVE\nEXPERIMENTAL LAUNCH CIRCUIT\nBHOP TO 300 u/s / ALIGN WITH THE PAD", 0.005)
	_sign("west", Vector3(0, 10, -30), 0, "LAUNCH WEST\n300+ u/s / STRAIGHT AHEAD", 0.005)
	_sign("east", Vector3(45, 11, -58), -PI / 2, "LAUNCH EAST\n300+ u/s / TOWARD THE NEXT DECK", 0.005)
	_sign("home", Vector3(79, 12, -18), PI, "LAUNCH HOME\nEACH PAD FIRES ONCE / R RESETS", 0.005)
	_sign("return", Vector3(0, 3, 31), PI, "LOW RETURN\nWALK THE RAMP BACK TO THE START", 0.006)

func _pad(id: String, x0: float, x1: float, z0: float, z1: float, y: float, stage: int, direction: Vector3) -> void:
	GEO.deck(self, id, x0, x1, z0, z1, y, stage)
	launch_pads.append({"id": id, "bounds": AABB(Vector3(x0, y - 0.15, z0), Vector3(x1 - x0, 0.5, z1 - z0)), "direction": direction})
	# a dark straight rail is the alignment cue; orange stays on the take-off lip.
	var paint := MeshInstance3D.new()
	paint.name = "Art_paint_dark_" + id
	var box := BoxMesh.new()
	box.size = Vector3(0.10 if absf(direction.z) > 0 else 3, 0.012, 3 if absf(direction.z) > 0 else 0.10)
	paint.mesh = box
	paint.position = Vector3((x0 + x1) / 2, y + 0.012, (z0 + z1) / 2)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263d45")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.material_override = material
	add_child(paint)

func route_hint(stage: int, _feet: Vector3) -> String:
	return ["Build speed with connected hops, then land along the west pad's dark alignment rail.", "Turn east across the landing. Keep at least 300 u/s and meet the next pad straight.", "Turn toward the launch house. A pad is spent until R or checkpoint practice resets the attempt.", "Reach the launch house. The low court and start ramp recover a missed transfer."][mini(stage, 3)]

func is_finish_at(feet: Vector3) -> bool:
	return finish_bounds.has_point(feet)

## numeric coordinates preserve small collision/law changes that Variant strings round away.
static func coordinates(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is AABB:
		return [coordinates(value.position), coordinates(value.size)]
	if value is Basis:
		return [coordinates(value.x), coordinates(value.y), coordinates(value.z)]
	if value is Transform3D:
		return [coordinates(value.basis), coordinates(value.origin)]
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[str(key)] = coordinates(value[key])
		return result
	if value is Array or value is PackedVector3Array:
		var result: Array = []
		for item: Variant in value:
			result.append(coordinates(item))
		return result
	return value

func geometry_identity() -> Dictionary:
	return coordinates({"map": level_id, "version": level_version, "launch": PLAYER.LAUNCH_LAW,
		"spawn": spawn, "finish": {"position": finish_position, "radius": finish_radius, "bounds": finish_bounds},
		"kill": kill_bounds, "solids": manifest, "pads": launch_pads, "checkpoints": checkpoints,
		"segments": segment_bounds, "roles": progress_roles, "gaps": jump_gaps})

func geometry_hash() -> String:
	return JSON.stringify(geometry_identity(), "", true, true).sha256_text()

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
	add_child(sun)
	var sea := MeshInstance3D.new()
	sea.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	sea.mesh = plane
	sea.position = Vector3(40, -4, -30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("789f9c")
	sea.material_override = material
	add_child(sea)

func _sign(id: String, at: Vector3, angle: float, text: String, pixels: float) -> void:
	var label := Label3D.new()
	label.name = "Sign_" + id
	label.position = at
	label.rotation.y = angle
	label.text = text
	label.font_size = 48
	label.pixel_size = pixels
	label.modulate = Color("263d45")
	label.outline_size = 0
	add_child(label)
