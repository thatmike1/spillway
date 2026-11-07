extends Node3D
## p / r13 overflow: a compact gravity-fed maintenance course on a dam, for the carry motor.
## one script builds the full course or the neutral jump/turn block (and its mirrored and
## landing-offset holdouts). every walkable or reachable solid is a convex prism or a kit
## prop proxy listed in a geometry manifest; its hash freezes the block before air profiles
## are compared. layout, numbers and criteria: docs/momentum/OVERFLOW.md.
##
## course, in order (forward is -z, then -x at the pier head, then -z again):
##   crest -> 15 degree apron -> slot hop (3.0 m, 1 m down) -> terrace -> descent ->
##   slot hop (3.5 m, 1 m down) -> pier -> pier head turn (or the diagonal over the bay) ->
##   exit ramp -> pier deck -> baffle blocks (or the basin floor) -> sill -> uphill arrival.
## every slot and the bay land on a catch surface with a visible ramp back up.

const Materials := preload("res://scripts/momentum_materials.gd")

const VARIANTS := ["course", "block", "block_mirror", "block_offset"]
## p / the landing-offset holdout moves everything after the block's gap this far sideways.
const OFFSET := 3.0
const WALL_THICK := 0.4
## p / course only: the pier deck gains a 6 m apron to the south so an overspeed runner off the
## exit ramp has room to turn into the basin; the basin and everything after it sit this far
## further south. the block's frozen pieces are unchanged.
const BASIN_DZ := -6.0
## p / training walls are taller than a hop's 1.3 m apex; parapets are ordinary guards.
const TRAINING := 2.0
const PARAPET := 1.1
const NEUTRAL := {
	&"deck": Color("c9c9c6"), &"concrete": Color("a3a5a6"), &"old_concrete": Color("6e7571"),
	&"steel": Color("56616c"), &"ochre": Color("b08a40"), &"brick": Color("8a4b3c"),
}

## set by a factory before the level enters the tree; build() reads it once.
static var next_variant: String = ""

var variant: String = "course"
## "kit" uses the licensed surface kit, "neutral" flat colours for attribution runs.
var material_mode: String = "kit"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 3.0
## p / water is scenery here: no wading regions, recovery is dry.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var routes: Dictionary = {}
## every collision piece: name, world points, stage, kind. hashed without materials.
var manifest: Array[Dictionary] = []

var _mirror := 1.0
var _shift := Vector3.ZERO
var _surfaces: Dictionary = {}
var _finish_box := AABB()
var _built := false
var _wheel: Node3D
var _gate: Node3D
var _release: MeshInstance3D
var _wheel_speed := 0.0
var _running := false
var _gate_open := 0.0
var _water_shader := Shader.new()

func build() -> void:
	if _built:
		return
	_built = true
	if not next_variant.is_empty():
		variant = next_variant
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--overflow-world="):
			variant = arg.trim_prefix("--overflow-world=")
		elif arg == "--overflow-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "overflow: unknown variant " + variant)
	_mirror = -1.0 if variant == "block_mirror" else 1.0
	_water_shader.code = WATER
	_environment()
	if variant == "course":
		_crest_and_apron()
	_pier_section()
	if variant == "course":
		_deck("pier_deck_apron", -45, -19, -62, -62 + BASIN_DZ, 3.5, &"deck", 2)
		_wall_z("pier_apron_e", -19, -62.4, -62 + BASIN_DZ, 3.5, 3.5, 1, PARAPET)
		_wall_z("pier_apron_w", -45, -62.4, -62 + BASIN_DZ, 3.5, 3.5, -1, PARAPET)
		_shift = Vector3(0, 0, BASIN_DZ)
		_baffle_basin()
		_arrival()
		_shift = Vector3.ZERO
	else:
		_block_finish()
	_scenery()
	_commit_meshes()
	_define_progress()

# --- the course ---------------------------------------------------------------------------

func _crest_and_apron() -> void:
	# beat 1: open descent. the crest walk, a 15 degree apron and the first slot hop.
	_deck("crest", -5, 5, 56, 44, 20.5, &"deck", 0)
	_ramp_z("apron", -5, 5, 44, 22, 20.5, 14.5, &"deck", 0)
	_deck("terrace_1", -5, 5, 22, 11, 14.5, &"deck", 0)
	_slot_hop("slot_1", 11.0, 8.0, 14.5, 13.5, 0.0)
	# training walls along both sides; the right side steps out around slot 1's return.
	_wall_z("crest_l", -5, 58, 44, 20.5, 20.5, -1, TRAINING)
	_wall_z("crest_r", 5, 58, 44, 20.5, 20.5, 1, TRAINING)
	_wall_z("apron_l", -5, 44, 22, 20.5, 14.5, -1, TRAINING)
	_wall_z("apron_r", 5, 44, 22, 20.5, 14.5, 1, TRAINING)
	_wall_z("terrace_1_l", -5, 22, 11, 14.5, 14.5, -1, TRAINING)
	_wall_z("terrace_1_r", 5, 22, 11, 14.5, 14.5, 1, TRAINING)
	_wall_z("terrace_2_l", -5, 8, -4, 13.5, 13.5, -1, TRAINING)

func _pier_section() -> void:
	# the neutral block is this section: terrace 2, a 16 degree descent, a 3.5 m slot hop,
	# the pier and its head turn, the diagonal over the bay, the exit ramp and the pier deck.
	_deck("terrace_2", -5, 5, 8, -4, 13.5, &"deck", 0)
	if variant == "course":
		_wall_z("terrace_2_r_tail", 5, -2.92, -4, 13.5, 13.5, 1, TRAINING)
	else:
		_wall_x("block_back", -5.4, 5.4, 8, 13.5, 1, TRAINING)
		_wall_z("terrace_2_l", -5, 8, -4, 13.5, 13.5, -1, TRAINING)
		_wall_z("terrace_2_r", 5, 8, -4, 13.5, 13.5, 1, TRAINING)
	_ramp_z("descent", -5, 5, -4, -18, 13.5, 9.5, &"deck", 0)
	_deck("runout", -5, 5, -18, -28, 9.5, &"deck", 0)
	_wall_z("descent_l", -5, -4, -18, 13.5, 9.5, -1, TRAINING)
	_wall_z("descent_r", 5, -4, -18, 13.5, 9.5, 1, TRAINING)
	_wall_z("runout_l", -5, -18, -28, 9.5, 9.5, -1, TRAINING)
	_wall_z("runout_r", 5, -18, -28, 9.5, 9.5, 1, TRAINING)
	_wall_x("wing_2_end", 5, 8.4, -4, 13.5, -1, TRAINING)
	# everything past the gap moves for the landing-offset holdout.
	_slot_hop("slot_2", -28.0, -31.5, 9.5, 8.5, _shift_x())
	_shift = Vector3(_shift_x(), 0, 0)
	_deck("pier", -5, 5, -31.5, -62, 8.5, &"deck", 1)
	# the ochre nosing marks where the long diagonal leaves the pier's open bay edge. closer to
	# the pier head the cut is shorter and saves less; there is no wall or lip on any cut.
	_trim("diagonal_nosing", Vector3(-5.0, 8.5, -38.0), Vector3(-5.0, 8.5, -45.0), 0.35)
	_rail_line("pier_rail", Vector3(4.86, 8.5, -42.6), Vector3(4.86, 8.5, -61.86))
	_wall_x("pier_head", -5, 5.4, -62, 8.5, -1, PARAPET)
	# exit ramp along -x from the pier head, then the pier deck.
	_ramp_x("exit_ramp", -62, -52, -5, -19, 8.5, 3.5, &"deck", 2)
	_wall_x_slope("exit_ramp_outer", -5, -19, -62, 8.5, 3.5, -1, PARAPET)
	_deck("pier_deck", -19, -45, -62, -47, 3.5, &"deck", 2)
	# the bay: a catch floor 7 m below the pier, its far walls, and a visible ramp at its far
	# side that climbs south onto the pier deck before the next stage.
	_deck("bay_floor", -30, -5, -47, -31.5, 1.5, &"old_concrete", -1, 0.0, "catch")
	_deck("bay_floor_south", -19, -5, -52, -47, 1.5, &"old_concrete", -1, 0.0, "catch")
	_ramp_z("bay_return", -30, -20, -37, -47, 1.5, 3.5, &"concrete", -1, "recovery")
	_wall_z("bay_west", -30, -31.1, -47, 1.5, 1.5, -1, 3.1)
	_wall_x("bay_north", -30.4, -5, -31.5, 1.5, 1, 3.1)
	_wall_x("pier_deck_north", -45.4, -30.4, -47, 3.5, 1, PARAPET)
	_wall_z("pier_deck_west", -45, -47, -62.4, 3.5, 3.5, -1, PARAPET)
	if variant == "course":
		_wall_x("pier_deck_south_e", -27.6, -18.6, -62 + BASIN_DZ, 3.5, -1, PARAPET)
		_wall_x("pier_deck_south_w", -45.4, -42.4, -62 + BASIN_DZ, 3.5, -1, PARAPET)
	else:
		_wall_x("pier_deck_south", -45.4, -19, -62, 3.5, -1, PARAPET)
	_shift = Vector3.ZERO

func _baffle_basin() -> void:
	# beat 3: baffle blocks between basin walls. the blocks are a hop rhythm; the basin floor
	# beside and between them is a slower line that climbs back to the sill ahead.
	_deck("basin_floor", -42, -28, -62, -94.4, 0.0, &"old_concrete", -1, -1.0, "catch")
	# p / blocks are long enough that an edge hop lands on the next one from about 4 to 13.5 m/s,
	# the speeds the course delivers here; the last one's top falls toward the sill.
	_block("baffle_1", Vector3(-35.0, 0, -69.0), Vector2(6, 8), 0.0, 3.2, 3.2)
	_block("baffle_2", Vector3(-33.8, 0, -79.95), Vector2(6, 7.5), -5.0, 2.9, 2.9)
	_block("baffle_3", Vector3(-35.0, 0, -90.6), Vector2(5, 7), 5.0, 2.8, 2.2)
	# p / the whole floor climbs to the sill past the last block: a miss in any lane holds W
	# and comes back up (21 degrees), no hunting for a side ramp against a sill face.
	_ramp_z("sill_ramp", -42, -28, -94.4, -99.0, 0.0, 1.8, &"concrete", -1, "recovery")
	_deck("sill", -42, -28, -99.0, -101, 1.8, &"deck", 3)
	_wall_z("basin_w", -42, -62, -101, 4.6 - TRAINING, 4.6 - TRAINING, -1, TRAINING)
	_wall_z("basin_e", -28, -62, -101, 4.6 - TRAINING, 4.6 - TRAINING, 1, TRAINING)

func _arrival() -> void:
	# the uphill arrival spends speed; the sluice-house deck leaves 20 m to brake and look.
	_ramp_z("arrival_ramp", -42, -28, -101, -119, 1.8, 5.0, &"deck", 3)
	_wall_z("arrival_w", -42, -101, -119, 1.8, 5.0, -1, PARAPET)
	_wall_z("arrival_e", -28, -101, -119, 1.8, 5.0, 1, PARAPET)
	_deck("sluice_deck", -46, -24, -119, -143, 5.0, &"deck", 3)
	_wall_x("sluice_deck_n_w", -46.4, -42.4, -119, 5.0, 1, PARAPET)
	_wall_x("sluice_deck_n_e", -27.6, -23.6, -119, 5.0, 1, PARAPET)
	_wall_z("sluice_deck_w", -46, -119, -143, 5.0, 5.0, -1, PARAPET)
	_wall_z("sluice_deck_e", -24, -119, -143, 5.0, 5.0, 1, PARAPET)
	_finish_box = _box(Vector3(-46, 4.9, -123.5), Vector3(22, 3.5, 3.0))
	finish_position = _w(Vector3(-35, 5.0, -122))
	# the sluice house: brick, a handwheel on its face and an outlet gate beside it.
	_solid("sluice_house", [Vector3(-44, 16, -143), Vector3(-26, 16, -143), Vector3(-26, 16, -153), Vector3(-44, 16, -153)], -1.0, &"brick")
	_prism_visual([Vector3(-44.6, 16, -142.4), Vector3(-25.4, 16, -142.4), Vector3(-25.4, 16, -153.6), Vector3(-44.6, 16, -153.6)], 15.4, &"concrete")
	_solid("wheel_plinth", [Vector3(-37.5, 5.9, -142.2), Vector3(-32.5, 5.9, -142.2), Vector3(-32.5, 5.9, -143), Vector3(-37.5, 5.9, -143)], 5.0, &"steel")
	_wheel = _handwheel(_w(Vector3(-35, 9.0, -142.6)), 1.7)
	_solid("outlet_pier_w", [Vector3(-23.6, 9, -144), Vector3(-22.6, 9, -144), Vector3(-22.6, 9, -152), Vector3(-23.6, 9, -152)], -1.5, &"concrete")
	_solid("outlet_pier_e", [Vector3(-15.6, 9, -144), Vector3(-14.6, 9, -144), Vector3(-14.6, 9, -152), Vector3(-15.6, 9, -152)], -1.5, &"concrete")
	_prism_visual([Vector3(-23.6, 9.8, -144), Vector3(-14.6, 9.8, -144), Vector3(-14.6, 9.8, -146), Vector3(-23.6, 9.8, -146)], 9.0, &"steel")
	_gate = Node3D.new()
	_gate.name = "SluiceGate"
	add_child(_gate)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(7.0, 4.6, 0.35)
	plate.mesh = plate_mesh
	plate.material_override = _material(&"steel")
	plate.position = Vector3(0, 1.1, 0)
	_gate.add_child(plate)
	_gate.position = _w(Vector3(-19.1, 0, -145.0))
	_release = MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(7.0, 26.0)
	_release.mesh = sheet
	_release.material_override = _water_material(Color("5f8f8a"), 2.4)
	_release.position = _w(Vector3(-19.1, -0.9, -132.0))
	_release.set_meta("gate_z", _w(Vector3(0, 0, -145.0)).z)
	_release.visible = false
	add_child(_release)

func _block_finish() -> void:
	# the block's finish is a band across the pier deck with 11 m to brake beyond it.
	var o := _shift_x()
	_finish_box = _box(Vector3(-34 + o, 3.4, -62), Vector3(3.0, 3.5, 15))
	finish_position = _w(Vector3(-32.5 + o, 3.5, -54.5))
	_wheel = _handwheel(_w(Vector3(-44.85 + o, 6.0, -54.5)), 1.2, PI * 0.5)
	var label := Label3D.new()
	label.text = "OVERFLOW BLOCK / %s\nneutral jump-turn fixture, not the course" % variant.to_upper()
	label.pixel_size = 0.012
	label.font_size = 64
	label.outline_size = 10
	label.modulate = Color("f4f1dd")
	label.position = _w(Vector3(0, 17.5, 8))
	add_child(label)

func _slot_hop(label: String, z_edge: float, z_land: float, y_from: float, y_to: float, offset: float) -> void:
	# a slot gap 2 m deeper than its landing. its catch floor runs right, out from under the
	# landing deck, into a trench with a 2 m ramp that climbs back onto the landing level.
	# offset shifts the landing side (already applied by _shift) for the offset holdout.
	var floor_y := y_to - 2.0
	var right := 8.0 + offset
	var left := -5.0
	_raw_deck(label + "_floor", left, right, z_edge, z_land, floor_y, &"old_concrete", -1, 0.0, "catch")
	var ramp_end := z_land - 2.0 / tan(deg_to_rad(14.0))
	_raw_ramp_z(label + "_return", 5.0 + offset, right, z_land, ramp_end, floor_y, y_to, &"concrete", -1, "recovery")
	var wing_end := ramp_end - 2.5
	var stage := 1 if label == "slot_2" else 0
	_raw_deck(label + "_wing", 5.0 + offset, right, ramp_end, wing_end, y_to, &"deck", stage)
	_raw_wall_z(label + "_outer", right, z_edge + WALL_THICK, wing_end - WALL_THICK, y_to, y_to, 1, TRAINING)
	_raw_wall_x(label + "_closure", 5.0 + WALL_THICK, right + WALL_THICK, z_edge, y_from, 1, TRAINING)
	_raw_wall_x(label + "_wing_end", 5.0 + offset, right + WALL_THICK, wing_end, y_to, -1, TRAINING)
	_raw_wall_z(label + "_end_l", left, z_edge, z_land, floor_y, floor_y, -1, y_from + TRAINING - floor_y)
	if offset > 0.0:
		# the landing moved right: close the slot's left end against the bay below.
		_solid(label + "_bay_guard", [Vector3(-5.0, floor_y + 1.1, z_land), Vector3(-5.0 + offset, floor_y + 1.1, z_land), Vector3(-5.0 + offset, floor_y + 1.1, z_land - WALL_THICK), Vector3(-5.0, floor_y + 1.1, z_land - WALL_THICK)], -1.5, &"concrete", -1, "wall")

# --- progress, finish and hints --------------------------------------------------------------

func _define_progress() -> void:
	var o := _shift_x()
	if variant == "course":
		spawn = _pose(Vector3(0, 20.5, 52), 0.0)
		checkpoints = [
			{"pose": spawn, "title": "Crest"},
			{"pose": _pose(Vector3(0, 8.5, -35), 0.0), "title": "Pier", "bounds": _box(Vector3(-5, 8.3, -62), Vector3(13, 4, 30.5))},
			# the deck alone (x -45..-19): a diagonal that falls short must not collect it over the bay.
			{"pose": _pose(Vector3(-35, 3.5, -58), 0.0), "title": "Pier deck", "bounds": _box(Vector3(-45, 3.3, -62 + BASIN_DZ), Vector3(26, 6, 15 - BASIN_DZ))},
			{"pose": _pose(Vector3(-35, 1.8, -100 + BASIN_DZ), 0.0), "title": "Sill", "bounds": _box(Vector3(-42, 1.6, -119 + BASIN_DZ), Vector3(14, 6, 23.9))},
		]
		segment_bounds = [_box(Vector3(-9, 0, -31.5), Vector3(18, 30, 91.5)), _box(Vector3(-46, -1, -63 + BASIN_DZ), Vector3(55, 14, 31.5 - BASIN_DZ)), _box(Vector3(-47, -2, -166), Vector3(38, 25, 103 + BASIN_DZ))]
		water_audio_sources = [_w(Vector3(14, 6, 10)), _w(Vector3(-10, -1, -81)), _w(Vector3(-19, -0.5, -146))]
		routes = {
			"ordinary": [Vector3(0, 20.5, 52), Vector3(0, 14.5, 12), Vector3(0, 13.5, 0), Vector3(0, 9.5, -27), Vector3(0, 8.5, -54), Vector3(-12, 6.0, -57), Vector3(-30, 3.5, -55), Vector3(-35, 3.5, -61), Vector3(-35, 3.2, -73), Vector3(-35, 1.8, -106), Vector3(-35, 5.0, -128)],
			"diagonal": [Vector3(-4.8, 8.5, -45.5), Vector3(-14, 5.3, -53.5)],
			"bay_recovery": [Vector3(-12, 1.5, -49), Vector3(-25, 1.5, -36), Vector3(-25, 3.5, -48)],
			"basin_recovery": [Vector3(-40, 0, -86), Vector3(-36, 0, -99), Vector3(-36, 1.8, -106)],
		}
	else:
		spawn = _pose(Vector3(0, 13.5, 5), 0.0)
		checkpoints = [
			{"pose": spawn, "title": "Block start"},
			{"pose": _pose(Vector3(o, 8.5, -35), 0.0), "title": "Pier", "bounds": _box(Vector3(-5 + o, 8.3, -62), Vector3(13, 4, 30.5))},
			{"pose": _pose(Vector3(-24 + o, 3.5, -54.5), PI * 0.5), "title": "Pier deck", "bounds": _box(Vector3(-45 + o, 3.3, -62), Vector3(40, 6, 15))},
		]
		segment_bounds = [_box(Vector3(-9, 0, -31.5), Vector3(18, 20, 40)), _box(Vector3(-46 + o, -1, -63), Vector3(55, 14, 31.5))]
		water_audio_sources = []
		routes = {
			"ordinary": [Vector3(0, 13.5, 5), Vector3(0, 9.5, -27), Vector3(o, 8.5, -54), Vector3(-12 + o, 6, -57), Vector3(-32 + o, 3.5, -54.5)],
			"diagonal": [Vector3(-4.8 + o, 8.5, -45.5), Vector3(-14 + o, 5.3, -53.5)],
			"bay_recovery": [Vector3(-12 + o, 1.5, -49), Vector3(-25 + o, 1.5, -36), Vector3(-25 + o, 3.5, -48)],
		}
		for key: String in routes:
			var mirrored: Array = []
			for p: Vector3 in routes[key]:
				mirrored.append(Vector3(p.x * _mirror, p.y, p.z))
			routes[key] = mirrored
	if variant == "course":
		for key: String in routes:
			var mapped: Array = []
			for p: Vector3 in routes[key]:
				mapped.append(_w(p))
			routes[key] = mapped

func _shift_x() -> float:
	return OFFSET if variant == "block_offset" else 0.0

func _pose(feet: Vector3, yaw: float) -> Transform3D:
	var p := _w(feet) + Vector3.UP * 0.04
	return Transform3D(Basis(Vector3.UP, yaw * _mirror), p)

func _box(corner: Vector3, size: Vector3) -> AABB:
	# design-frame box to world: mirroring swaps the x extent.
	var a := _w(corner)
	var b := _w(corner + size)
	return AABB(Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z)), Vector3(absf(b.x - a.x), size.y, absf(b.z - a.z)))

func is_finish_at(feet: Vector3) -> bool:
	return _finish_box.has_point(feet)

func segment_at(position: Vector3) -> int:
	for i: int in segment_bounds.size():
		if segment_bounds[i].has_point(position):
			return i
	return 0

func route_hint(stage: int, feet: Vector3) -> String:
	var d := Vector3(feet.x * _mirror, feet.y, feet.z) - _shift
	if variant != "course":
		d.x -= _shift_x() if d.z < -28.0 else 0.0
	if d.y < 3.0 and d.z < -31.0 and d.z > -53.0 and d.x < -4.0:
		return "Short of the pier deck: the ramp at the far side of the bay climbs back up."
	if d.y < 1.6 and d.z < -62.0 + BASIN_DZ:
		return "Off the blocks: the floor climbs to the sill ahead."
	if (absf(d.z - 9.5) < 6.0 and d.y < 12.6) or (absf(d.z + 30.0) < 8.0 and d.y < 8.4 and d.x > -5.5):
		return "Missed the hop: the ramp on the right climbs back out."
	match stage:
		0:
			return "Run down. Height turns into speed; hop the slots." if variant == "course" else "Run down and hop the slot onto the pier."
		1:
			return "Turn left at the pier head, or carry speed and hop the bay from the ochre edge."
		2:
			return "Turn right into the basin and hop the baffle blocks." if variant == "course" else "Cross the band on the pier deck."
	return "Climb to the sluice house."

func start_wheel() -> void:
	_running = true
	if is_instance_valid(_release):
		_release.visible = true

func reset_state() -> void:
	_running = false
	_wheel_speed = 0.0
	_gate_open = 0.0
	if is_instance_valid(_wheel):
		_wheel.rotation = Vector3(_wheel.rotation.x, _wheel.rotation.y, 0.0)
	if is_instance_valid(_gate):
		_gate.position.y = 0.0
	if is_instance_valid(_release):
		_release.visible = false
		_release.scale = Vector3(1, 1, 0.02)

func _process(delta: float) -> void:
	# p / the finish turns the handwheel, lifts the sluice gate and lets the outflow run.
	_wheel_speed = move_toward(_wheel_speed, 1.6 if _running else 0.0, delta * 1.2)
	if is_instance_valid(_wheel):
		_wheel.rotate_object_local(Vector3.FORWARD, _wheel_speed * delta)
	if is_instance_valid(_gate):
		_gate_open = move_toward(_gate_open, 1.0 if _running else 0.0, delta * 0.35)
		_gate.position.y = smoothstep(0.0, 1.0, _gate_open) * 3.6
	if is_instance_valid(_release) and _release.visible:
		_release.scale = Vector3(1, 1, maxf(0.02, smoothstep(0.1, 1.0, _gate_open)))
		_release.position.z = float(_release.get_meta("gate_z")) + 13.0 * _release.scale.z

## the frozen geometry: sorted pieces with rounded world points, materials excluded.
func geometry_manifest() -> Array:
	var pieces: Array = []
	for piece: Dictionary in manifest:
		var points: Array = []
		for p: Vector3 in piece.points:
			points.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
		pieces.append({"name": piece.name, "role": piece.role, "stage": piece.stage, "points": points, "shape": piece.shape})
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	return pieces

func geometry_hash() -> String:
	return JSON.stringify(geometry_manifest()).sha256_text()

# --- pieces ----------------------------------------------------------------------------------

func _w(p: Vector3) -> Vector3:
	var q := p + _shift
	return Vector3(q.x * _mirror, q.y, q.z)

func _deck(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = 0.0, role: String = "route") -> StaticBody3D:
	return _raw_deck(label, x0, x1, z0, z1, top, kind, stage, base, role)

func _raw_deck(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = 0.0, role: String = "route") -> StaticBody3D:
	return _solid(label, [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)], base, kind, stage, role)

func _ramp_z(label: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, kind: StringName, stage: int, role: String = "route") -> StaticBody3D:
	return _raw_ramp_z(label, x0, x1, z0, z1, y0, y1, kind, stage, role)

func _raw_ramp_z(label: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, kind: StringName, stage: int, role: String = "route") -> StaticBody3D:
	return _solid(label, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], minf(y0, y1) - 1.0 if role == "recovery" else 0.0, kind, stage, role)

func _ramp_x(label: String, z0: float, z1: float, x0: float, x1: float, y0: float, y1: float, kind: StringName, stage: int, role: String = "route") -> StaticBody3D:
	return _solid(label, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], minf(y0, y1) - 1.0 if role == "recovery" else 0.0, kind, stage, role)

func _block(label: String, center: Vector3, size: Vector2, yaw_deg: float, top_front: float, top_back: float) -> StaticBody3D:
	# a baffle block, yawed about its centre; a sloped top falls from its +z to its -z face.
	var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var corners := [Vector3(-hx, top_front, hz), Vector3(hx, top_front, hz), Vector3(hx, top_back, -hz), Vector3(-hx, top_back, -hz)]
	var points: Array = []
	for c: Vector3 in corners:
		var flat := basis * Vector3(c.x, 0, c.z)
		points.append(Vector3(center.x + flat.x, c.y, center.z + flat.z))
	return _solid(label, points, 0.0, &"deck", -1, "baffle")

func _wall_z(label: String, x: float, z0: float, z1: float, y0: float, y1: float, side: int, height: float) -> StaticBody3D:
	return _raw_wall_z(label, x, z0, z1, y0, y1, side, height)

func _raw_wall_z(label: String, x: float, z0: float, z1: float, y0: float, y1: float, side: int, height: float) -> StaticBody3D:
	# a wall outside a deck edge at x, running along z, its top `height` above the deck line.
	var xo := x + side * WALL_THICK
	return _solid(label, [Vector3(x, y0 + height, z0), Vector3(xo, y0 + height, z0), Vector3(xo, y1 + height, z1), Vector3(x, y1 + height, z1)], -1.5, &"concrete", -1, "wall")

func _wall_x(label: String, x0: float, x1: float, z: float, y: float, side: int, height: float) -> StaticBody3D:
	return _raw_wall_x(label, x0, x1, z, y, side, height)

func _raw_wall_x(label: String, x0: float, x1: float, z: float, y: float, side: int, height: float) -> StaticBody3D:
	var zo := z + side * WALL_THICK
	return _solid(label, [Vector3(x0, y + height, z), Vector3(x1, y + height, z), Vector3(x1, y + height, zo), Vector3(x0, y + height, zo)], -1.5, &"concrete", -1, "wall")

func _wall_x_slope(label: String, x0: float, x1: float, z: float, y0: float, y1: float, side: int, height: float) -> StaticBody3D:
	var zo := z + side * WALL_THICK
	return _solid(label, [Vector3(x0, y0 + height, z), Vector3(x1, y1 + height, z), Vector3(x1, y1 + height, zo), Vector3(x0, y0 + height, zo)], -1.5, &"concrete", -1, "wall")

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid") -> StaticBody3D:
	# a convex prism: a planar top quad extruded straight down to `base`. design coordinates.
	var points: Array[Vector3] = []
	for p: Vector3 in top:
		points.append(_w(p))
	for p: Vector3 in top:
		points.append(_w(Vector3(p.x, base, p.z)))
	var body := StaticBody3D.new()
	body.name = label
	if stage >= 0:
		body.set_meta("progress_stage", stage)
	body.set_meta("surface", role)
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array(points)
	shape.shape = hull
	body.add_child(shape)
	add_child(body)
	_add_prism(points, kind)
	manifest.append({"name": label, "role": role, "stage": stage, "points": points, "shape": "prism", "kind": kind})
	return body

func _prism_visual(top: Array, base: float, kind: StringName) -> void:
	var points: Array[Vector3] = []
	for p: Vector3 in top:
		points.append(_w(p))
	for p: Vector3 in top:
		points.append(_w(Vector3(p.x, base, p.z)))
	_add_prism(points, kind)

func _trim(label: String, a: Vector3, b: Vector3, width: float) -> void:
	# a flush painted strip on a deck edge: visual only, 4 mm proud, no collision.
	var inward := Vector3(width, 0, 0)
	var lift := Vector3.UP * 0.004
	_prism_visual([a + lift, a + inward + lift, b + inward + lift, b + lift], a.y - 0.05, &"ochre")
	set_meta(label, [_w(a), _w(b)])

func _rail_line(label: String, a: Vector3, b: Vector3) -> void:
	# kit rail sections, feet on the deck at their posts, with the kit's collision proxies.
	var wa := _w(a)
	var wb := _w(b)
	var run := wb - wa
	var count := maxi(1, int(round(run.length() / 2.0)))
	var direction := run.normalized()
	var basis := Basis(direction, Vector3.UP, direction.cross(Vector3.UP))
	for i: int in count + 1:
		var prop: Node3D = Materials.instance_prop(&"rail_section" if i < count else &"rail_post")
		prop.name = "%s_%02d" % [label, i]
		prop.transform = Transform3D(basis, wa + run * (float(i) / count))
		# sections are 2 m; scale only along the run so the posts meet the next section.
		if i < count:
			prop.transform.basis.x *= run.length() / count / 2.0
		add_child(prop)
		for proxy: Node in prop.find_children("*", "StaticBody3D", true, false):
			proxy.set_meta("surface", "rail")
		var spec: Dictionary = Materials.PROPS[&"rail_section" if i < count else &"rail_post"]
		var centre: Vector3 = prop.transform * spec.proxy_center
		var half: Vector3 = spec.proxy_size * 0.5
		var corners: Array[Vector3] = []
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					corners.append(prop.transform * (spec.proxy_center + Vector3(sx * half.x, sy * half.y, sz * half.z)))
		manifest.append({"name": prop.name, "role": "rail", "stage": -1, "points": corners, "shape": "rail_proxy", "kind": &"ochre", "foot": prop.transform.origin, "centre": centre})

func _handwheel(centre: Vector3, radius: float, yaw: float = 0.0) -> Node3D:
	# a spoked ochre handwheel; it spins about its own axis at the finish. scenery, no body.
	var wheel := Node3D.new()
	wheel.name = "Handwheel"
	wheel.position = centre
	wheel.rotation.y = yaw * _mirror
	add_child(wheel)
	var material := _material(&"ochre")
	for i: int in 16:
		var a := TAU * i / 16.0
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(radius * TAU / 16.0 + 0.05, 0.16, 0.16)
		seg.mesh = box
		seg.material_override = material
		seg.position = Vector3(cos(a), sin(a), 0) * radius
		seg.rotation.z = a + PI * 0.5
		wheel.add_child(seg)
	for i: int in 4:
		var spoke := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(radius * 2.0, 0.1, 0.1)
		spoke.mesh = box
		spoke.material_override = material
		spoke.rotation.z = PI * 0.25 * i
		wheel.add_child(spoke)
	var hub := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.25
	cyl.height = 0.5
	hub.mesh = cyl
	hub.rotation.x = PI * 0.5
	hub.material_override = _material(&"steel")
	wheel.add_child(hub)
	return wheel

# --- meshes and materials ------------------------------------------------------------------

func _add_prism(points: Array[Vector3], kind: StringName) -> void:
	# top 0-3, bottom 4-7. faces get flat normals; winding is fixed per triangle so a
	# mirrored build renders the same faces.
	if not _surfaces.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[kind] = st
	var st: SurfaceTool = _surfaces[kind]
	var centre := Vector3.ZERO
	for p: Vector3 in points:
		centre += p / 8.0
	var faces: Array = [[0, 1, 2, 3], [7, 6, 5, 4]]
	for i: int in 4:
		var j := (i + 1) % 4
		faces.append([i, j, j + 4, i + 4])
	for face: Array in faces:
		var quad: Array[Vector3] = [points[face[0]], points[face[1]], points[face[2]], points[face[3]]]
		var normal := (quad[2] - quad[0]).cross(quad[3] - quad[1]).normalized()
		var mid := (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
		if normal.dot(mid - centre) < 0.0:
			normal = -normal
		if normal.length_squared() < 0.5:
			continue
		for tri: Array in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = quad[tri[0]]
			var b: Vector3 = quad[tri[1]]
			var c: Vector3 = quad[tri[2]]
			if (b - a).cross(c - a).length_squared() < 1e-10:
				continue
			# godot treats clockwise as front: the right-hand normal must point inward.
			if (b - a).cross(c - a).dot(normal) > 0.0:
				var swap := b
				b = c
				c = swap
			for v: Vector3 in [a, b, c]:
				st.set_normal(normal)
				st.add_vertex(v)

func _commit_meshes() -> void:
	for kind: StringName in _surfaces:
		var instance := MeshInstance3D.new()
		instance.name = "Mesh_" + String(kind)
		instance.mesh = (_surfaces[kind] as SurfaceTool).commit()
		instance.material_override = _material(kind)
		add_child(instance)
	_surfaces.clear()

func _material(kind: StringName) -> Material:
	if material_mode == "kit":
		return Materials.get_material(kind)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = NEUTRAL[kind]
	flat.roughness = 0.85
	flat.metallic = 0.4 if kind == &"steel" else 0.0
	return flat

const WATER := "shader_type spatial;\nrender_mode cull_disabled;\nuniform vec3 tint : source_color = vec3(0.3, 0.45, 0.45);\nuniform float flow = 0.0;\nvarying vec3 wpos;\nvoid vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tvec2 p = wpos.xz * 0.35 + vec2(0.0, TIME * flow);\n\tfloat r = sin(p.x * 3.1 + TIME * 0.7) * sin(p.y * 2.3 - TIME * 0.5) + sin((p.x + p.y) * 5.7 + TIME * 1.3) * 0.4;\n\tALBEDO = tint * (0.9 + r * 0.06);\n\tROUGHNESS = 0.12 + r * 0.03;\n\tMETALLIC = 0.0;\n\tSPECULAR = 0.6;\n\tNORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(cos(p.x * 3.1) * 0.05, 0.0, cos(p.y * 2.3) * 0.05, 0.0)).xyz);\n}\n"

func _water_material(color: Color, flow: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _water_shader
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("flow", flow)
	return material

func _water(center: Vector3, size: Vector2, color: Color, flow: float = 0.0) -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	plane.mesh = mesh
	plane.material_override = _water_material(color, flow)
	plane.position = center
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)

# --- environment and scenery ---------------------------------------------------------------

func _environment() -> void:
	# p / late-morning sun from behind the start: faces toward the runner are lit, landing
	# tops read lightest, and long shadows fall forward down the course.
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("5d8fbf")
	atmosphere.sky_horizon_color = Color("bccbd0")
	atmosphere.ground_horizon_color = Color("a9b2ac")
	atmosphere.ground_bottom_color = Color("56605a")
	atmosphere.sun_angle_max = 20.0
	sky.sky_material = atmosphere
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("b7c4c8")
	environment.fog_density = 0.0016
	environment.fog_aerial_perspective = 0.35
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-28.0) * _mirror, 0.0)
	sun.light_energy = 1.3
	sun.light_color = Color("fff2df")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

func _scenery() -> void:
	# tailwater around the piers and basin, deep enough that leaving the course over a guard
	# drops out of bounds rather than into a hidden pocket.
	_water(_w(Vector3(-20, -1.2, -60)), Vector2(320, 300), Color("3f6466"))
	if variant != "course":
		return
	# the dam: crest wall, reservoir behind it, and its downstream faces either side of the
	# stepped spillway. none of it is reachable over the training walls.
	_water(_w(Vector3(0, 19.6, 140)), Vector2(400, 160), Color("4b7377"))
	for side: float in [-1.0, 1.0]:
		var inner := side * 5.4
		var outer := side * 95.0
		_solid("dam_crest_%s" % ("l" if side < 0 else "r"), [Vector3(minf(inner, outer), 23.0, 60), Vector3(maxf(inner, outer), 23.0, 60), Vector3(maxf(inner, outer), 23.0, 46), Vector3(minf(inner, outer), 23.0, 46)], -1.5, &"concrete", -1, "scenery")
		_prism_visual([Vector3(minf(inner, outer), 23.0, 46), Vector3(maxf(inner, outer), 23.0, 46), Vector3(maxf(inner, outer), -1.5, -2), Vector3(minf(inner, outer), -1.5, -2)], -1.5, &"old_concrete")
	# the gatehouse behind the spawn, with an overflow weir and spill sheet to the right.
	_solid("gatehouse", [Vector3(-7, 28.5, 61), Vector3(7, 28.5, 61), Vector3(7, 28.5, 56), Vector3(-7, 28.5, 56)], 20.5, &"brick", -1, "scenery")
	_prism_visual([Vector3(-7.6, 29.2, 61.6), Vector3(7.6, 29.2, 61.6), Vector3(7.6, 29.2, 55.4), Vector3(-7.6, 29.2, 55.4)], 28.5, &"concrete")
	_water(_w(Vector3(16, 10.5, 22)), Vector2(8, 52), Color("8fb3ae"), -3.0)
	var spill := get_child(get_child_count() - 1) as Node3D
	spill.rotation.x = atan2(24.0, 50.0)
	# a steel gantry over the terraces gives scale and a passing reference at speed.
	for z: float in [26.0, 2.0]:
		for x: float in [-5.6, 5.6]:
			_prism_visual([Vector3(x - 0.25, 25, z + 0.25), Vector3(x + 0.25, 25, z + 0.25), Vector3(x + 0.25, 25, z - 0.25), Vector3(x - 0.25, 25, z - 0.25)], 13.5, &"steel")
		_prism_visual([Vector3(-6.2, 25.6, z + 0.35), Vector3(6.2, 25.6, z + 0.35), Vector3(6.2, 25.6, z - 0.35), Vector3(-6.2, 25.6, z - 0.35)], 24.6, &"ochre")
	_prism_visual([Vector3(-5.9, 25.4, 26), Vector3(-5.3, 25.4, 26), Vector3(-5.3, 25.4, 2), Vector3(-5.9, 25.4, 2)], 24.8, &"steel")
	_prism_visual([Vector3(5.3, 25.4, 26), Vector3(5.9, 25.4, 26), Vector3(5.9, 25.4, 2), Vector3(5.3, 25.4, 2)], 24.8, &"steel")
	# a brick pump house on its own footing off the pier head: the turn's landmark.
	_solid("pump_house", [Vector3(7.5, 16.0, -54), Vector3(17.5, 16.0, -54), Vector3(17.5, 16.0, -68), Vector3(7.5, 16.0, -68)], -2.0, &"brick", -1, "scenery")
	_prism_visual([Vector3(7.0, 16.6, -53.5), Vector3(18.0, 16.6, -53.5), Vector3(18.0, 16.6, -68.5), Vector3(7.0, 16.6, -68.5)], 16.0, &"concrete")
	# valley sides and the far bank, so the horizon is land rather than a uniform sky.
	_prism_visual([Vector3(-150, 34, 40), Vector3(-75, 6, 40), Vector3(-75, 6, -230), Vector3(-150, 34, -230)], -2.0, &"old_concrete")
	_prism_visual([Vector3(60, 6, 40), Vector3(150, 38, 40), Vector3(150, 38, -230), Vector3(60, 6, -230)], -2.0, &"old_concrete")
	_prism_visual([Vector3(-150, 22, -205), Vector3(150, 22, -205), Vector3(150, 4, -170), Vector3(-150, 4, -170)], -2.0, &"old_concrete")
