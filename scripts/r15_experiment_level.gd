extends Node3D
## p / r15 Movement Lab: the separate, clearly experimental playground for the optional slide,
## wall jump and grapple (r15_experiment_player.gd). it is not one of the five courses and keeps
## its own record identity (kind "lab", the moves' on/off and tuning). it publishes the r14 level
## interface r15_main.gd hosts: spawn, checkpoints, finish, kill bounds, hints, manifest, hash,
## level identity, plus `mechanics` and the grapple anchors (nodes in "r15_grapple_anchor").
## layout, numbers and evidence: docs/r15/EXPERIMENT.md.
##
## the place: a service and test workshop, one long hall (24 m wide, 110 m, forward is -z) under
## a lit roof. a hub with the station boards, then the three stations in a line that is also the
## combined route:
##   slide lane: a run-up, then a 5 m lane under a 60 u (1.52 m) pipe rack that only a ducked
##     hull fits, then a 1 m run-out and a 2.6 m trench. a slide carries enough speed to jump it;
##     a crouch walk does not. the trench is a catch: its ramp walks back up to the run-up.
##   wall chamber: a 3.2 m slot between two 8.5 m machine housings with striped faces, ending at
##     a 3.2 m mezzanine wall. a standing or crouch jump cannot reach it; two wall jumps do.
##     a miss lands on the chamber floor.
##   grapple gap: 14 m from the mezzanine to the dispatch bay across a machine pit, under two
##     marked anchors on gantry beams. the right of the pit is a catch floor with a ramp back to the
##     mezzanine; the left is the scrap chute (respawn at the checkpoint). a column hides anchor A2
##     from the middle of the mezzanine, so a blocked target and a blocked line have a real cause.
## collision: every solid is a named convex prism (top polygon extruded down), as Breakwater's
## are; walkable pieces stay within 32 m and reach 5 m under their tops (docs/r14/CONTACT-GUARD.md).

const Art := preload("res://scripts/r15_experiment_art.gd")
const ASSETS := preload("res://scripts/r15_assets.gd")

## bump LEVEL_VERSION with any change to geometry, progress, anchors or timing semantics.
const LEVEL_ID := "r15-movement-lab"
const LEVEL_NAME := "Movement Lab"
const LEVEL_VERSION := 1
const U := 0.0254
const MECHANICS := ["slide", "wall_jump", "grapple"]

## the hall interior, metres.
const HALF := 12.0
const WALL_T := 0.6
const ROOF := 12.0
const BASE := -5.0
const HUB_Z := 10.0
const RUNUP_Z := -8.0
const LANE_Z0 := -22.0
## the rack covers 5 m; the lane floor runs 1 m past it, open above, so a jump fits before the edge.
const RACK_Z1 := -27.0
const LANE_Z1 := -28.0
const LANE_HALF := 1.5
## p / the lane ceiling: 60 u. the 54 u duck hull fits, the 72 u standing hull does not.
const LANE_CEILING_U := 60.0
const SLOT_X0 := 7.0
const SLOT_X1 := 11.0
const SLOT_TOP_Z := -16.0
const TRENCH_Y := -2.2
const TRENCH_Z1 := -30.6
const CHAMBER_Z0 := -44.0
const CHAMBER_Z1 := -56.0
const CHAMBER_HALF := 1.6
const HOUSING_TOP := 8.5
const MEZZ_Y := 3.2
const GAP_Z0 := -70.0
const GAP_Z1 := -84.0
const PIT_Y := -4.0
const CHUTE_X := -4.0
const PIT_RAMP_X := 8.0
const END_Z := -100.0
## p / a fall below this leaves the kill envelope: only the scrap chute reaches it.
const KILL_Y := -7.0
## anchors: name, position (m). each hangs 0.7 m under its gantry beam.
const ANCHORS := [["A1", Vector3(0.0, 10.5, -80.0)], ["A2", Vector3(-7.0, 9.5, -88.0)]]
const COLUMN := [-4.8, -4.0, -78.4, -77.6]

## set by a factory before the level enters the tree (r14 convention); unused here.
static var next_variant: String = ""

var variant: String = "workshop"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var mechanics: Array = MECHANICS.duplicate()
var finish_title: String = "Dispatch bay"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 4.0
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var progress_roles: Array = ["route"]
var routes: Dictionary = {}
var kill_bounds := AABB(Vector3(-HALF - 2.0, KILL_Y, END_Z - 2.0), Vector3(2.0 * HALF + 4.0, ROOF + 2.0 - KILL_Y, HUB_Z - END_Z + 4.0))
## every collision piece: name, world points, stage, role, kind. hashed without materials.
var manifest: Array[Dictionary] = []
## prism tops and bases the art pass draws, by kind.
var prisms: Array[Dictionary] = []
## painted marks and signs: visual only, not hashed.
var markings: Array[Dictionary] = []
## anchor records: name, position, beam. the nodes are in ANCHOR_GROUP.
var anchors: Array[Dictionary] = []
## the stations: id, title, the move, a practice stage, controls text.
var stations: Array[Dictionary] = []
## sourced props standing where a runner can reach them: label, model, feet, scale, yaw. each has
## a collision prism over its measured, scaled footprint (in `manifest` as role "prop").
var props: Array[Dictionary] = []

var _finish_box := AABB()
var _built := false
var _art: RefCounted

func build() -> void:
	if _built:
		return
	_built = true
	_shell()
	_hub()
	_slide_lane()
	_wall_chamber()
	_grapple_gap()
	_dispatch()
	_define_progress()
	_art = Art.new()
	_art.call("dress", self)

# --- the hall ----------------------------------------------------------------------------------

func _shell() -> void:
	# side walls in 28 m pieces, the two end walls and the roof slabs: unreachable but solid, so
	# nothing the camera can see is passable.
	var cuts := [HUB_Z + WALL_T, -18.0, -46.0, -74.0, END_Z - WALL_T]
	for i: int in cuts.size() - 1:
		_box("hall_wall_w_%d" % (i + 1), -HALF - WALL_T, -HALF, cuts[i], cuts[i + 1], ROOF, BASE, &"wall_panel", -1, "wall")
		_box("hall_wall_e_%d" % (i + 1), HALF, HALF + WALL_T, cuts[i], cuts[i + 1], ROOF, BASE, &"wall_panel", -1, "wall")
		_box("hall_roof_%d" % (i + 1), -HALF - WALL_T, HALF + WALL_T, cuts[i], cuts[i + 1], ROOF + 0.5, ROOF, &"roof", -1, "ceiling")
	_box("hall_end_s", -HALF, HALF, HUB_Z + WALL_T, HUB_Z, ROOF, BASE, &"wall_panel", -1, "wall")
	_box("hall_end_n", -HALF, HALF, END_Z, END_Z - WALL_T, ROOF, BASE, &"wall_panel", -1, "wall")

func _hub() -> void:
	# stage 0: the hub, 24 × 18 m of clear floor with the station boards on the walls ahead.
	_box("s0_hub", -HALF, HALF, HUB_Z, RUNUP_Z, 0.0, BASE, &"floor", 0, "route")
	_box("s0_bench_w", -11.5, -9.2, 6.0, 1.5, 0.9, 0.0, &"steel", -1, "prop")
	_box("s0_bench_e", 9.2, 11.5, 6.0, 1.5, 0.9, 0.0, &"steel", -1, "prop")
	_box("s0_rack_w", -HALF, -10.8, -0.5, -6.5, 2.4, 0.0, &"rack", -1, "prop")
	_box("s0_rack_e", 10.8, HALF, -0.5, -6.5, 2.4, 0.0, &"rack", -1, "prop")
	_prop("s0_machine_w", "kenney-factory/models/machine.glb", Vector3(-10.4, 0.0, -2.0), 1.6, 0.5)
	_prop("s0_machine_e", "kenney-factory/models/machine-window.glb", Vector3(10.4, 0.0, -2.0), 1.6, -0.5)
	_prop("s0_robot_arm", "kenney-factory/models/robot-arm-a.glb", Vector3(-10.0, 0.9, 3.8), 1.0, 0.25)
	_prop("s0_crates", "kenney-factory/models/box-large.glb", Vector3(10.3, 0.9, 3.8), 1.4, 0.0)
	_paint_x("s0_start", -2.0, 2.0, 2.0, -0.25, &"paint_white")
	_paint_x("s0_threshold", -HALF, HALF, RUNUP_Z, 0.3, &"paint_yellow")

func _slide_lane() -> void:
	# stage 1: the run-up (19 m of clear floor, the ramp slot on the right), the lane under the
	# pipe rack, and the trench beyond it. the housings fill the hall either side of the lane.
	var ceiling := LANE_CEILING_U * U
	_box("s1_runup_w", -HALF, SLOT_X0, RUNUP_Z, LANE_Z0, 0.0, BASE, &"floor", 1, "route")
	_box("s1_runup_e", SLOT_X0, HALF, RUNUP_Z, SLOT_TOP_Z, 0.0, BASE, &"floor", 1, "route")
	_box("s1_lane", -LANE_HALF, LANE_HALF, LANE_Z0, LANE_Z1, 0.0, BASE, &"lane_floor", 1, "route")
	_box("s1_pipe_rack", -LANE_HALF, LANE_HALF, LANE_Z0, RACK_Z1, HOUSING_TOP, ceiling, &"rack_low", -1, "ceiling")
	_box("s1_housing_w", -HALF, -LANE_HALF, LANE_Z0, LANE_Z1, HOUSING_TOP, BASE, &"housing", -1, "wall")
	_box("s1_housing_e", LANE_HALF, SLOT_X0, LANE_Z0, LANE_Z1, HOUSING_TOP, BASE, &"housing", -1, "wall")
	_box("s1_slot_wall", SLOT_X1, HALF, SLOT_TOP_Z, LANE_Z1, HOUSING_TOP, BASE, &"housing", -1, "wall")
	_solid("s1_return_ramp", [Vector3(SLOT_X0, 0.0, SLOT_TOP_Z), Vector3(SLOT_X1, 0.0, SLOT_TOP_Z), Vector3(SLOT_X1, TRENCH_Y, LANE_Z1), Vector3(SLOT_X0, TRENCH_Y, LANE_Z1)],
		BASE, &"grating", -1, "recovery")
	_box("s1_trench", -HALF, HALF, LANE_Z1, TRENCH_Z1, TRENCH_Y, BASE - 1.0, &"pit_floor", -1, "catch")
	_prop("s1_scanner_w", "kenney-factory/models/scanner-high.glb", Vector3(-7.0, 0.0, -20.6), 1.4, 0.5)
	_prop("s1_hopper_e", "kenney-factory/models/hopper-high-square.glb", Vector3(4.8, 0.0, -20.6), 1.5, 0.0)
	# the lane mouth and exit are painted; the lane ceiling height is written on the rack.
	_paint_x("s1_mouth", -LANE_HALF, LANE_HALF, LANE_Z0, -0.3, &"paint_hazard")
	_paint_x("s1_exit", -LANE_HALF, LANE_HALF, LANE_Z1, 0.3, &"paint_hazard")
	_paint_x("s1_rack_end", -LANE_HALF, LANE_HALF, RACK_Z1, -0.2, &"paint_white")
	# p / the slide mark: pressing Shift from here to the rack carries a 250 u/s run over the trench.
	_paint_x("s1_slide_mark", -LANE_HALF, LANE_HALF, LANE_Z0 + 1.2, -0.25, &"paint_white")
	markings.append({"name": "s1_rack_label", "kind": "wall", "at": Vector3(0.0, ceiling + 0.55, LANE_Z0 + 0.02), "yaw": 0.0, "text": "60 u  ·  1.52 m\nSLIDE  ·  Shift"})

func _wall_chamber() -> void:
	# stage 2: the landing deck past the trench, and the chamber slot between the housings. the
	# mezzanine's 3.2 m face closes it.
	_box("s2_deck", -HALF, HALF, TRENCH_Z1, CHAMBER_Z0, 0.0, BASE, &"floor", 2, "route")
	_box("s2_chamber", -CHAMBER_HALF, CHAMBER_HALF, CHAMBER_Z0, CHAMBER_Z1, 0.0, BASE, &"lane_floor", 2, "route")
	_box("s2_housing_w", -HALF, -CHAMBER_HALF, CHAMBER_Z0, CHAMBER_Z1, HOUSING_TOP, BASE, &"housing", -1, "wall")
	_box("s2_housing_e", CHAMBER_HALF, HALF, CHAMBER_Z0, CHAMBER_Z1, HOUSING_TOP, BASE, &"housing", -1, "wall")
	# striped panels on both inner faces mark the wall-jump faces (visual only, flush).
	for side: float in [-1.0, 1.0]:
		var x := side * (CHAMBER_HALF - 0.004)
		markings.append({"name": "s2_panel_%s" % ("w" if side < 0.0 else "e"), "kind": "panel", "x": x, "z0": CHAMBER_Z0 - 1.0, "z1": CHAMBER_Z1 + 0.5, "y0": 0.6, "y1": 6.4, "side": side})
	_paint_x("s2_mouth", -CHAMBER_HALF, CHAMBER_HALF, CHAMBER_Z0, -0.3, &"paint_hazard")
	_prop("s2_tank_w", "kenney-industrial/models/detail-tank-large.glb", Vector3(-9.0, 0.0, -38.0), 1.8, 0.0)
	_prop("s2_crates_e", "kenney-factory/models/box-long.glb", Vector3(9.5, 0.0, -36.0), 1.6, 0.5)
	markings.append({"name": "s2_height_label", "kind": "wall", "at": Vector3(0.0, MEZZ_Y - 0.6, CHAMBER_Z1 + 0.02), "yaw": 0.0, "text": "3.2 m\nWALL JUMP  ·  Space at a wall"})

func _grapple_gap() -> void:
	# stage 3: the mezzanine, the pit (catch floor and ramp on the right, chute on the left), the
	# column and the gantry beams with their anchors.
	_box("s3_mezz_w", -HALF, 0.0, CHAMBER_Z1, GAP_Z0, MEZZ_Y, BASE, &"deck_steel", 3, "route")
	_box("s3_mezz_e", 0.0, HALF, CHAMBER_Z1, GAP_Z0, MEZZ_Y, BASE, &"deck_steel", 3, "route")
	_box("s3_pit_catch", CHUTE_X, PIT_RAMP_X, GAP_Z0, GAP_Z1, PIT_Y, PIT_Y - 5.0, &"pit_floor", -1, "catch")
	_solid("s3_pit_ramp", [Vector3(PIT_RAMP_X, PIT_Y, GAP_Z1), Vector3(HALF, PIT_Y, GAP_Z1), Vector3(HALF, MEZZ_Y, GAP_Z0), Vector3(PIT_RAMP_X, MEZZ_Y, GAP_Z0)],
		PIT_Y - 5.0, &"grating", -1, "recovery")
	_box("s3_chute_floor", -HALF, CHUTE_X, GAP_Z0, GAP_Z1, -20.0, -22.0, &"chute", -1, "hazard")
	_box("s3_column", COLUMN[0], COLUMN[1], COLUMN[2], COLUMN[3], ROOF, -20.0, &"column", -1, "wall")
	_paint_x("s3_edge", -HALF, PIT_RAMP_X, GAP_Z0, 0.35, &"paint_hazard", MEZZ_Y)
	_prop("s3_machine_w", "kenney-factory/models/machine-connection-pipe.glb", Vector3(-9.5, MEZZ_Y, -61.0), 1.5, 0.5)
	for record: Array in ANCHORS:
		var at: Vector3 = record[1]
		var beam := "s3_gantry_%s" % str(record[0]).to_lower()
		_box(beam, -HALF, HALF, at.z + 0.3, at.z - 0.3, at.y + 1.3, at.y + 0.7, &"gantry", -1, "ceiling")
		var node := Node3D.new()
		node.name = "Anchor_" + str(record[0])
		node.position = at
		node.set_meta("anchor_name", str(record[0]))
		node.add_to_group("r15_grapple_anchor")
		add_child(node)
		anchors.append({"name": str(record[0]), "position": at, "beam": beam})
	markings.append({"name": "s3_gap_label", "kind": "wall", "at": Vector3(-HALF + 0.02, MEZZ_Y + 2.4, -63.0), "yaw": PI * 0.5, "text": "GRAPPLE  ·  hold E at a ring\nrelease to coast"})

func _dispatch() -> void:
	# the far side: the dispatch bay at the mezzanine's height, with the finish band at its end.
	_box("s4_bay_w", -HALF, 0.0, GAP_Z1, END_Z, MEZZ_Y, BASE, &"deck_steel", 4, "route")
	_box("s4_bay_e", 0.0, HALF, GAP_Z1, END_Z, MEZZ_Y, BASE, &"deck_steel", 4, "route")
	_paint_x("s4_edge", -HALF, HALF, GAP_Z1, -0.35, &"paint_hazard", MEZZ_Y)
	_paint_x("s4_finish", -HALF, HALF, -94.0, -0.5, &"paint_white", MEZZ_Y)
	_prop("s4_scanner_e", "kenney-factory/models/scanner-low.glb", Vector3(9.0, MEZZ_Y, -90.0), 1.5, 0.5)
	_prop("s4_crates_w", "kenney-factory/models/box-large.glb", Vector3(-9.5, MEZZ_Y, -91.0), 1.6, 0.0)
	_finish_box = AABB(Vector3(-HALF, MEZZ_Y - 0.2, END_Z), Vector3(2.0 * HALF, 3.0, 6.0))
	finish_position = Vector3(0.0, MEZZ_Y, -97.0)

# --- progress, finish and hints -------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their decks (radius 0), so a flight over a gap never
	# collects the deck beyond it.
	spawn = _pose(Vector3(0.0, 0.0, 4.0), 0.0)
	checkpoints = [
		{"pose": spawn, "title": "Hub"},
		{"pose": _pose(Vector3(0.0, 0.0, -10.0), 0.0), "title": "Slide lane", "radius": 0.0},
		{"pose": _pose(Vector3(0.0, 0.0, -33.0), 0.0), "title": "Wall chamber", "radius": 0.0},
		{"pose": _pose(Vector3(0.0, MEZZ_Y, -62.0), 0.0), "title": "Grapple gap", "radius": 0.0},
	]
	segment_bounds = [
		AABB(Vector3(-HALF, -3, RUNUP_Z), Vector3(2 * HALF, 15, HUB_Z - RUNUP_Z)),
		AABB(Vector3(-HALF, -3, TRENCH_Z1), Vector3(2 * HALF, 15, RUNUP_Z - TRENCH_Z1)),
		AABB(Vector3(-HALF, -3, CHAMBER_Z1), Vector3(2 * HALF, 15, TRENCH_Z1 - CHAMBER_Z1)),
		AABB(Vector3(-HALF, KILL_Y, END_Z), Vector3(2 * HALF, 20, CHAMBER_Z1 - END_Z)),
	]
	stations = [
		{"id": "slide", "title": "Slide lane", "stage": 1, "move": "slide", "controls": "run, let go of Space, press and hold Shift before the rack; Space at the exit"},
		{"id": "wall_jump", "title": "Wall chamber", "stage": 2, "move": "wall_jump", "controls": "jump at a striped wall, press Space again as you touch it; twice to reach the mezzanine"},
		{"id": "grapple", "title": "Grapple gap", "stage": 3, "move": "grapple", "controls": "run off the edge, hold E with a ring in view, let go to coast onto the bay"},
	]
	routes = {
		"combined": [Vector3(0, 0, 4), Vector3(0, 0, -20), Vector3(0, 0, LANE_Z1), Vector3(0, 0, -34), Vector3(0, 0, CHAMBER_Z0), Vector3(0, MEZZ_Y, -60),
			Vector3(0, MEZZ_Y, GAP_Z0), ANCHORS[0][1], Vector3(0, MEZZ_Y, -90), finish_position],
		"trench_recovery": [Vector3(4, TRENCH_Y, -29.3), Vector3(9, TRENCH_Y, -29.3), Vector3(9, 0, SLOT_TOP_Z), Vector3(0, 0, -12)],
		"pit_recovery": [Vector3(2, PIT_Y, -78), Vector3(10, PIT_Y, -83), Vector3(10, MEZZ_Y, GAP_Z0), Vector3(4, MEZZ_Y, -64)],
	}

func _pose(feet: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), feet + Vector3.UP * 0.04)

func is_finish_at(feet: Vector3) -> bool:
	return _finish_box.has_point(feet)

func segment_at(position: Vector3) -> int:
	for i: int in segment_bounds.size():
		if segment_bounds[i].has_point(position):
			return i
	return 0

func route_hint(stage: int, feet: Vector3) -> String:
	if feet.y < -0.6 and feet.y > TRENCH_Y - 0.6 and feet.z < LANE_Z1 + 0.5 and feet.z > TRENCH_Z1 - 0.5:
		return "In the trench: walk right to the ramp, it climbs back to the run-up."
	if feet.y < PIT_Y + 0.6 and feet.z < GAP_Z0 and feet.z > GAP_Z1:
		return "In the pit: the ramp at the back right climbs to the mezzanine."
	match stage:
		0:
			return "Movement Lab: experimental moves, not a course. Slide, wall jump and grapple stations lie ahead; Esc toggles each move."
		1:
			return "Run at the pipe rack, let go of Space, then press and hold Shift to slide under it. Jump at the exit."
		2:
			return "Jump at a striped wall and press Space again on contact. Off one wall, then the other, up to the mezzanine."
		3:
			return "Run off the edge and hold E with a ring in view. Let go to coast onto the dispatch bay."
	return "Cross the white band in the dispatch bay."

func reset_state() -> void:
	if _art != null:
		_art.call("finished", self, false)

func start_wheel() -> void:
	if _art != null:
		_art.call("finished", self, true)

func _process(delta: float) -> void:
	if _art != null:
		_art.call("tick", self, delta)

## the full lab record: stages, stations, anchors, pieces, units.
func course_manifest() -> Dictionary:
	var stages: Array = []
	for point: Dictionary in checkpoints:
		stages.append({"title": point.title, "pose": _v((point.pose as Transform3D).origin)})
	var anchor_list: Array = []
	for anchor: Dictionary in anchors:
		anchor_list.append({"name": anchor.name, "position": _v(anchor.position), "beam": anchor.beam})
	return {
		"level_id": LEVEL_ID, "level_name": LEVEL_NAME, "level_version": LEVEL_VERSION, "variant": variant, "kind": "lab",
		"units": {"u_m": U}, "mechanics": MECHANICS, "stages": stages, "stations": stations, "anchors": anchor_list,
		"finish": {"title": finish_title, "box": [_v(_finish_box.position), _v(_finish_box.size)]},
		"lane_ceiling_u": LANE_CEILING_U, "chamber_width_m": 2.0 * CHAMBER_HALF, "mezzanine_m": MEZZ_Y, "grapple_gap_m": GAP_Z0 - GAP_Z1,
		"recovery": "the trench ramp returns to the run-up; the pit catch ramp returns to the mezzanine; the scrap chute respawns at the checkpoint",
		"geometry_hash": geometry_hash(), "pieces": manifest.size(),
	}

## the frozen geometry: sorted pieces with rounded world points, materials excluded, plus the
## anchors (a moved anchor changes what a run means).
func geometry_manifest() -> Array:
	var pieces: Array = []
	for piece: Dictionary in manifest:
		var points: Array = []
		for p: Vector3 in piece.points:
			points.append([snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
		pieces.append({"name": piece.name, "role": piece.role, "stage": piece.stage, "points": points, "shape": piece.shape})
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	for anchor: Dictionary in anchors:
		pieces.append({"name": "anchor_" + str(anchor.name), "role": "anchor", "stage": -1, "points": [_v(anchor.position)], "shape": "point"})
	return pieces

func geometry_hash() -> String:
	return JSON.stringify(geometry_manifest()).sha256_text()

# --- pieces ----------------------------------------------------------------------------------

func _rect(x0: float, x1: float, z0: float, z1: float, y: float) -> Array:
	return [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]

func _box(label: String, x0: float, x1: float, z0: float, z1: float, top: float, base: float, kind: StringName, stage: int, role: String) -> StaticBody3D:
	return _solid(label, _rect(x0, x1, z0, z1, top), base, kind, stage, role)

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int, role: String) -> StaticBody3D:
	# a convex prism: a planar convex top polygon extruded straight down to `base`.
	assert(not has_node(NodePath(label)), "movement lab: duplicate piece " + label)
	var points: Array[Vector3] = []
	for p: Vector3 in top:
		points.append(p)
	for p: Vector3 in top:
		points.append(Vector3(p.x, base, p.z))
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
	prisms.append({"name": label, "top": top.duplicate(), "base": base, "kind": kind})
	manifest.append({"name": label, "role": role, "stage": stage, "points": points, "shape": "prism", "kind": kind})
	return body

## yaw is a multiple of a quarter turn (in turns), so the measured footprint stays axis aligned.
func _prop(label: String, model: String, feet: Vector3, scale: float, turns: float) -> void:
	assert(absf(turns * 4.0 - roundf(turns * 4.0)) < 1e-6, "movement lab: props turn in quarter turns")
	var size := ASSETS.bounds(model).size * scale
	if absi(roundi(turns * 4.0)) % 2 == 1:
		size = Vector3(size.z, size.y, size.x)
	var half := Vector2(size.x, size.z) * 0.5
	_box(label, feet.x - half.x, feet.x + half.x, feet.z + half.y, feet.z - half.y, feet.y + size.y, feet.y, &"prop_proxy", -1, "prop")
	props.append({"name": label, "model": model, "feet": feet, "scale": scale, "yaw": turns * TAU})

func _paint_x(label: String, x0: float, x1: float, z: float, width: float, kind: StringName, y: float = 0.0) -> void:
	# a flush painted band across the hall at `z`, `width` toward +z (negative: toward -z).
	var lift := 0.004
	markings.append({"name": label, "kind": "strip", "top": [Vector3(x0, y + lift, z), Vector3(x1, y + lift, z), Vector3(x1, y + lift, z + width), Vector3(x0, y + lift, z + width)],
		"base": y - 0.02, "paint": kind})

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
