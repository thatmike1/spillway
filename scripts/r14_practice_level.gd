extends Node3D
## p / r14 practice: Penstock Yard, an original bhop and air-strafe training course on the
## bench beside the dam. it publishes the overflow level interface (spawn, checkpoints,
## segment and kill bounds, finish, routes, jump gaps, manifest, geometry hash, route hints)
## so the r13 consumers and the r14 main can host it unchanged, plus course_manifest() with
## every gap in metres and source units. layout, numbers and limits: docs/r14/PRACTICE.md.
##
## course, in order (forward is -z, then -x after the valve bend, then -z after the pump bend):
##   gatehouse pad -> penstock straight (128 m flat, marked every 8 m) -> stop-log blocks
##   (five straight, gaps 2.0 to 4.0 m, then three zig blocks) -> valve bend (left ring, two
##   radial gaps: short inside, long outside) -> weir gauges (two gaps whose width runs across
##   the track, 3 to 8 m and 3 to 12 m, wide ends on opposite sides) -> pump bend (right ring,
##   walkable inside, an outer notch that needs speed) -> tail race gauge (3.5 to 14 m, 1.5 m
##   down) -> finish band on the tailwater platform.
## every pit is walkable and climbs back to the take-off deck of the jump it caught: a retry,
## never a way forward, because source movement keeps horizontal speed through a landing and
## a hopping runner climbs a ramp for free, so a forward catch would bypass its own gap.

const Materials := preload("res://scripts/momentum_materials.gd")

## the identity the r14 main can key records and labels on. bump LEVEL_VERSION with any
## change to geometry, progress or timing semantics.
const LEVEL_ID := "r14-practice-penstock-yard"
const LEVEL_NAME := "Penstock Yard"
const LEVEL_VERSION := 1
const VARIANTS := ["practice"]
## p / source units: 1 u = 0.0254 m (the hammer/source convention of 1 u = 1 inch).
const U := 0.0254
## p / provisional vanilla cs:go figures for the manifest's dimension checks, pending the
## researcher's SOURCE-REFERENCE.md: 250 u/s knife run, 301.993 u/s jump, 800 u/s^2 gravity.
const VANILLA := {"run_ups": 250.0, "jump_ups": 301.993, "gravity_ups": 800.0, "provisional": true}
## p / judging margins: a landing must clear the far edge by this much (feet centre, no hull
## credit), and "comfortable" means the jump can also be pressed this early.
const LANDING := 0.5
const EARLY := 0.1
## p / speed tiers by the slowest speed that clears a gap with the landing margin, pressed at
## the edge (clear_ups): vanilla_run is comfortable at a 250 u/s run, vanilla_run_tight clears
## at 250 only near the edge, then up to 330 (vanilla strafing), 520 (server) and beyond.
const TIERS := [["vanilla_strafe", 330.0], ["server", 520.0], ["fast", INF]]

const WALL := 0.4
## p / training walls stand 2 m above the deck, over a jump's 1.45 m apex.
const TRAINING := 2.0
const TRACK_Y := 0.0
## p / pits are 2.5 m deep: more than the 1.45 m jump apex and a crouch-jump's ~1.6 m, so a
## fallen runner cannot hop back onto a deck and must walk the return ramp.
const PIT := 2.5
const BASE := -6.0
const WIDTH := 16.0
## the valve bend's centre and radii (left turn, from heading -z to heading -x).
const BEND_L := Vector3(-14, 0, -177.5)
const BEND_L_IN := 6.0
const BEND_L_OUT := 22.0
## p / the islands stop 2 m short of the outer wall: that moat joins every bend pit to the
## blocks' pit, whose lane climbs back to the runway.
const BEND_L_ISLAND_OUT := 20.0
## the pump bend's centre and radii (right turn, from heading -x to heading -z).
const BEND_R := Vector3(-74, 0, -203.5)
const BEND_R_IN := 4.0
const BEND_R_MID := 12.0
const BEND_R_OUT := 20.0
const TAIL_Y := -1.5
## p / stop-log blocks: [z of the near edge, depth, x from, x to]. the runway ends at -128.
## blocks stop 1 m short of the return lane (x 4 to 8), so the lane is never a step onto one.
const BLOCKS := [
	[-130.0, 3.0, -8.0, 3.0], [-135.5, 3.0, -8.0, 3.0], [-141.5, 3.0, -8.0, 3.0], [-148.0, 3.0, -8.0, 3.0], [-155.0, 3.0, -8.0, 3.0],
	[-160.5, 3.0, -1.0, 3.0], [-166.0, 3.0, -8.0, -3.0], [-171.5, 3.0, -1.0, 3.0],
]
const RUNWAY_END := -128.0
const BEND_START := -177.5
## valve bend islands in degrees from the +x radius toward -z; the spaces between are gaps.
const BEND_L_ISLANDS := [[0.0, 25.0], [43.0, 57.0], [75.0, 90.0]]
## p / weir gauges along -x: landing edge x, take-off x on the north (z -183.5) and south
## (z -199.5) sides. g1 runs 3 m north to 8 m south, g2 12 m north to 3 m south.
const G1 := {"land": -34.0, "north": -31.0, "south": -26.0}
const G2 := {"land": -58.0, "north": -46.0, "south": -55.0}
const WEIR_N := -183.5
const WEIR_S := -199.5
const WEIR_END := -74.0
## p / tail race gauge along -z: landing edge z, take-off z on the west (x -94) and east
## (x -78) sides: 14 m west, 3.5 m east, landing 1.5 m down.
const G3 := {"land": -231.5, "west": -217.5, "east": -228.0}
const TAIL_W := -94.0
const TAIL_E := -78.0
const TAIL_END := -251.5
## the pump bend's outer notch, degrees from the entry radius.
const NOTCH := [30.0, 60.0]

const LOOK := {
	&"track": [&"deck", {"top_tint": Vector3(1.06, 1.05, 1.01), "bay_tone": 0.08, "joint_dark": 0.55}],
	&"landing": [&"deck", {"top_tint": Vector3(1.24, 1.21, 1.13), "bay_tone": 0.04, "joint_dark": 0.45}],
	&"catch": [&"old_concrete", {"top_tint": Vector3(0.6, 0.63, 0.6), "stain": 0.8, "bay_size": Vector2(3.0, 3.0), "bay_tone": 0.1}],
	&"return": [&"old_concrete", {"top_tint": Vector3(0.78, 0.8, 0.74), "stain": 0.5}],
	&"hill": [&"old_concrete", {"desaturate": 0.15, "top_tint": Vector3(0.5, 0.58, 0.4), "side_tint": Vector3(0.44, 0.5, 0.36), "stain": 0.9, "bay_size": Vector2(0.0, 0.0), "macro_strength": 0.2, "macro_scale": 23.0}],
}
const NEUTRAL := {
	&"track": Color("c9c9c6"), &"landing": Color("d8d6cf"), &"catch": Color("6e7571"), &"return": Color("8c918a"),
	&"concrete": Color("a3a5a6"), &"steel": Color("56616c"), &"ochre": Color("b08a40"), &"brick": Color("8a4b3c"),
	&"hill": Color("5f6b52"), &"old_concrete": Color("6e7571"),
}

## set by a factory before the level enters the tree; build() reads it once.
static var next_variant: String = ""

var variant: String = "practice"
## "kit" uses the licensed surface kit, "neutral" flat colours for attribution runs.
var material_mode: String = "kit"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var finish_title: String = "Tailwater"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 3.0
## p / water is scenery: no wading regions, every pit is dry.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
## "ordinary" (= "basic") is the vanilla line, "advanced" the earned one; world points.
var routes: Dictionary = {}
## declared jumps in the overflow format (edge, land, design speed m/s, drained m/s, climb,
## kind), with metres, units and tiers added; course_manifest() carries the full record.
var jump_gaps: Array[Dictionary] = []
## the respawn envelope: only reachable by leaving the course over a wall.
var kill_bounds := AABB(Vector3(-140, -6.5, -290), Vector3(200, 120, 310))
## every collision piece: name, world points, stage, role, kind. hashed without materials.
var manifest: Array[Dictionary] = []
## painted measurement marks: name, world position, text. visual only, not hashed.
var markings: Array[Dictionary] = []

var _surfaces: Dictionary = {}
var _finish_box := AABB()
var _built := false
var _looks: Dictionary = {}
var _marks: Node3D
var _water_shader := Shader.new()
var _beacon: MeshInstance3D
var _finish_glow := 0.0
var _running := false

func build() -> void:
	if _built:
		return
	_built = true
	if not next_variant.is_empty():
		variant = next_variant
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--practice-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "practice: unknown variant " + variant)
	_water_shader.code = WATER
	_marks = Node3D.new()
	_marks.name = "Markings"
	add_child(_marks)
	_environment()
	_gatehouse_and_runway()
	_stop_logs()
	_valve_bend()
	_weir_gauges()
	_pump_bend()
	_tail_race()
	_scenery()
	_commit_meshes()
	_define_progress()

# --- the course ---------------------------------------------------------------------------

func _gatehouse_and_runway() -> void:
	# stage 0: a pad behind the start line and 128 m of flat runway, 16 m wide. nothing on it
	# gives or takes speed, so what the runner arrives with at its end is strafing alone.
	_deck("s0_pad", -8, 8, 8, 0, TRACK_Y, &"landing", 0)
	_deck("s0_runway", -8, 8, 0, RUNWAY_END, TRACK_Y, &"track", 0)
	_wall_x("s0_back", -8.4, 8.4, 8, TRACK_Y, 1, TRAINING)
	_wall_z("s0_left", -8, 8, RUNWAY_END, -1)
	_wall_z("s0_right", 8, 8, RUNWAY_END, 1)
	_strip_x("s0_start_line", -8, 8, 0.0, 0.3)
	# p / a thin line every 8 m and a label every 16 m on both walls, in metres and units.
	for i: int in range(1, 16):
		var z := -8.0 * i
		_strip_x("s0_mark_%02d" % i, -8, 8, z, 0.3 if i % 2 == 0 else 0.12)
		if i % 2 == 0:
			var text := "%d m\n%d u" % [8 * i, roundi(8.0 * i / U)]
			_wall_label("s0_label_l_%02d" % i, Vector3(-7.95, 1.3, z), PI * 0.5, text)
			_wall_label("s0_label_r_%02d" % i, Vector3(7.95, 1.3, z), -PI * 0.5, text)
	_strip_x("s0_runway_edge", -8, 8, RUNWAY_END, -0.35)

func _stop_logs() -> void:
	# stage 1: eight stop-log blocks over a 2.5 m pit. five straight, each gap 0.5 m wider than
	# the last, then three zig blocks two metres apart sideways. the pit's right lane walks
	# back to a ramp onto the runway's end, so a miss retries the blocks.
	var pit_y := TRACK_Y - PIT
	_deck("s1_pit", -8, 8, RUNWAY_END, BEND_START, pit_y, &"catch", -1, BASE, "catch")
	_ramp_z("s1_return", 4, 8, -140, RUNWAY_END, pit_y, TRACK_Y, &"return", -1, "recovery")
	var previous := RUNWAY_END
	for i: int in BLOCKS.size():
		var b: Array = BLOCKS[i]
		var near: float = b[0]
		var far: float = near - float(b[1])
		_deck("s1_block_%d" % (i + 1), b[2], b[3], near, far, TRACK_Y, &"landing", 1)
		_strip_x("s1_nose_%d" % (i + 1), b[2], b[3], far, -0.25)
		_floor_label("s1_gap_%d" % (i + 1), Vector3(clampf(-2.0, b[2] + 1.5, b[3] - 1.5), TRACK_Y, previous - 0.6), 0.0, _gap_text(previous - near))
		previous = far
	_floor_label("s1_gap_bend", Vector3(1.5, TRACK_Y, previous - 0.6), 0.0, _gap_text(previous - BEND_START))
	_wall_z("s1_left", -8, RUNWAY_END, BEND_START, -1, pit_y)
	_wall_z("s1_right", 8, RUNWAY_END, BEND_START, 1, pit_y)

func _valve_bend() -> void:
	# stage 2: a quarter ring turning left, 14 m of islands inside a 16 m ring. each gap spans
	# 18 degrees: 2.5 m on a tight inside line, 5.9 m round the outside, so the line that keeps
	# speed is the one that needs it. the pit under the ring joins the blocks' pit.
	var pit_y := TRACK_Y - PIT
	for a: float in range(0, 90, 10):
		var b := a + 10.0
		_ring_piece("s2_pit_%02d" % int(a), BEND_L, Vector3.RIGHT, 1.0, BEND_L_IN, BEND_L_OUT, a, b, pit_y, pit_y, &"catch", -1, BASE, "catch")
		_ring_wall("s2_inner_%02d" % int(a), BEND_L, Vector3.RIGHT, 1.0, BEND_L_IN - WALL, BEND_L_IN, a, b, pit_y)
		_ring_wall("s2_outer_%02d" % int(a), BEND_L, Vector3.RIGHT, 1.0, BEND_L_OUT, BEND_L_OUT + WALL, a, b, pit_y)
	for i: int in BEND_L_ISLANDS.size():
		var span: Array = BEND_L_ISLANDS[i]
		var a: float = span[0]
		while a < float(span[1]) - 0.01:
			var b := minf(a + 10.0, float(span[1]))
			_ring_piece("s2_island_%d_%02d" % [i + 1, int(a)], BEND_L, Vector3.RIGHT, 1.0, BEND_L_IN, BEND_L_ISLAND_OUT, a, b, TRACK_Y, TRACK_Y, &"landing", 2)
			a = b
	for i: int in BEND_L_ISLANDS.size() - 1:
		var from: float = BEND_L_ISLANDS[i][1]
		var to: float = BEND_L_ISLANDS[i + 1][0]
		for r: float in [8.0, 13.5, 19.0]:
			var p := _ring_point(BEND_L, Vector3.RIGHT, 1.0, r, from - 1.5)
			_floor_label("s2_gap_%d_r%02d" % [i + 1, int(r)], p, deg_to_rad(from), _gap_text(2.0 * r * sin(deg_to_rad(to - from) * 0.5)), 0.009)

func _weir_gauges() -> void:
	# stage 3: two gauge gaps across a 16 m track heading -x. each take-off edge runs at a
	# slant, so the gap's width changes across the track: pick a width, the paint says what
	# it needs. g1 is narrow on the north side, g2 on the south, so the wide line zig-zags.
	var pit_y := TRACK_Y - PIT
	_solid("s3_runin", [Vector3(-14, 0, WEIR_N), Vector3(G1.north, 0, WEIR_N), Vector3(G1.south, 0, WEIR_S), Vector3(-14, 0, WEIR_S)], BASE, &"track", 3, "route")
	_solid("s3_g1_pit", [Vector3(G1.north, pit_y, WEIR_N), Vector3(G1.land, pit_y, WEIR_N), Vector3(G1.land, pit_y, WEIR_S), Vector3(G1.south, pit_y, WEIR_S)], BASE, &"catch", -1, "catch")
	_solid("s3_middle", [Vector3(G1.land, 0, WEIR_N), Vector3(G2.north, 0, WEIR_N), Vector3(G2.south, 0, WEIR_S), Vector3(G1.land, 0, WEIR_S)], BASE, &"landing", 3, "route")
	_solid("s3_g2_pit", [Vector3(G2.north, pit_y, WEIR_N), Vector3(G2.land, pit_y, WEIR_N), Vector3(G2.land, pit_y, WEIR_S), Vector3(G2.south, pit_y, WEIR_S)], BASE, &"catch", -1, "catch")
	_deck_x("s3_runout", G2.land, WEIR_END, WEIR_N, WEIR_S, 0.0, &"landing", 4)
	# the south lane, 2.5 m down: each pit opens onto it and its ramp climbs east, back to the
	# deck the missed jump left from. a wall at x -34 keeps the two returns apart.
	var lane := WEIR_S - 4.0
	_deck_x("s3_lane_top_e", -14, -16, WEIR_S, lane, 0.0, &"return", -1, BASE, "recovery")
	_ramp_x("s3_lane_ramp_e", WEIR_S, lane, -16, -26, 0.0, pit_y, &"return", "recovery")
	_deck_x("s3_lane_g1", -26, G1.land, WEIR_S, lane, pit_y, &"catch", -1, BASE, "catch")
	_deck_x("s3_lane_top_w", G1.land, -44, WEIR_S, lane, 0.0, &"return", -1, BASE, "recovery")
	_ramp_x("s3_lane_ramp_w", WEIR_S, lane, -44, -54, 0.0, pit_y, &"return", "recovery")
	_deck_x("s3_lane_g2", -54, G2.land, WEIR_S, lane, pit_y, &"catch", -1, BASE, "catch")
	_wall_line("s3_north", Vector3(-14, 0, WEIR_N), Vector3(WEIR_END, 0, WEIR_N), Vector2(0, 1), TRAINING)
	_wall_line("s3_lane_outer", Vector3(-14, 0, lane), Vector3(G2.land, 0, lane), Vector2(0, -1), TRAINING)
	_wall_line("s3_lane_east", Vector3(-14, 0, WEIR_S - WALL), Vector3(-14, 0, lane - WALL), Vector2(1, 0), TRAINING)
	_wall_line("s3_lane_west", Vector3(G2.land, 0, WEIR_S), Vector3(G2.land, 0, lane - WALL), Vector2(-1, 0), TRAINING)
	_wall_line("s3_runout_south", Vector3(G2.land, 0, WEIR_S), Vector3(WEIR_END, 0, WEIR_S), Vector2(0, -1), TRAINING)
	for gauge: Dictionary in [G1, G2]:
		var tag := "g1" if gauge == G1 else "g2"
		_strip_line("s3_%s_nose" % tag, Vector3(gauge.north, 0, WEIR_N), Vector3(gauge.south, 0, WEIR_S), Vector3(0.3, 0, 0))
		_strip_line("s3_%s_land" % tag, Vector3(gauge.land, 0, WEIR_N), Vector3(gauge.land, 0, WEIR_S), Vector3(-0.3, 0, 0))
		_gauge_ticks("s3_%s" % tag, gauge.land, gauge.north, gauge.south, WEIR_N, WEIR_S, 0.0, true)

func _pump_bend() -> void:
	# stage 4: a quarter ring turning right. the inside band (r 4 to 12) is walkable all the
	# way round. the outside band has a 30 degree notch, 8.3 m across on the middle line; a
	# short jump drops onto a slope that climbs back to the inside band.
	var notch_y := TRACK_Y - PIT
	for a: float in range(0, 90, 10):
		var b := a + 10.0
		_ring_piece("s4_inside_%02d" % int(a), BEND_R, Vector3.BACK, -1.0, BEND_R_IN, BEND_R_MID, a, b, TRACK_Y, TRACK_Y, &"track", 4)
		if a >= NOTCH[0] and b <= NOTCH[1]:
			_ring_piece("s4_notch_%02d" % int(a), BEND_R, Vector3.BACK, -1.0, BEND_R_MID, BEND_R_OUT, a, b, TRACK_Y, notch_y, &"catch", -1, BASE, "catch")
		else:
			_ring_piece("s4_outside_%02d" % int(a), BEND_R, Vector3.BACK, -1.0, BEND_R_MID, BEND_R_OUT, a, b, TRACK_Y, TRACK_Y, &"landing", 4)
		_ring_wall("s4_inner_%02d" % int(a), BEND_R, Vector3.BACK, -1.0, BEND_R_IN - WALL, BEND_R_IN, a, b, notch_y)
		_ring_wall("s4_outer_%02d" % int(a), BEND_R, Vector3.BACK, -1.0, BEND_R_OUT, BEND_R_OUT + WALL, a, b, notch_y)
	for edge: float in NOTCH:
		var inner := _ring_point(BEND_R, Vector3.BACK, -1.0, BEND_R_MID, edge)
		var outer := _ring_point(BEND_R, Vector3.BACK, -1.0, BEND_R_OUT, edge)
		_strip_line("s4_notch_nose_%02d" % int(edge), inner, outer, (_ring_point(BEND_R, Vector3.BACK, -1.0, 16.0, edge + (-0.6 if edge == NOTCH[0] else 0.6)) - _ring_point(BEND_R, Vector3.BACK, -1.0, 16.0, edge)).normalized() * 0.3)
	for r: float in [14.0, 16.0, 19.0]:
		var p := _ring_point(BEND_R, Vector3.BACK, -1.0, r, NOTCH[0] - 1.5)
		_floor_label("s4_notch_r%02d" % int(r), p, -deg_to_rad(NOTCH[0]) + PI * 0.5, _gap_text(2.0 * r * sin(deg_to_rad(NOTCH[1] - NOTCH[0]) * 0.5)), 0.009)

func _tail_race() -> void:
	# stage 5: the last gauge, 1.5 m down onto the tailwater platform: 3.5 m on the east
	# (inside) edge, 14 m on the west (outside) edge, where a fast runner leaves the bend.
	var pit_y := TAIL_Y - PIT
	_solid("s5_runin", [Vector3(TAIL_W, 0, -203.5), Vector3(TAIL_E, 0, -203.5), Vector3(TAIL_E, 0, G3.east), Vector3(TAIL_W, 0, G3.west)], BASE, &"track", 5, "route")
	_solid("s5_pit", [Vector3(TAIL_W, pit_y, G3.west), Vector3(TAIL_E, pit_y, G3.east), Vector3(TAIL_E, pit_y, G3.land), Vector3(TAIL_W, pit_y, G3.land)], BASE, &"catch", -1, "catch")
	_deck("s5_platform", TAIL_W, TAIL_E, G3.land, TAIL_END, TAIL_Y, &"landing", -1)
	# the east lane, 4 m down at the pit: its ramp climbs north back to the run-in.
	var lane := TAIL_E + 4.0
	_deck("s5_lane_pit", TAIL_E, lane, G3.east, G3.land, pit_y, &"catch", -1, BASE, "catch")
	_ramp_z("s5_lane_ramp", TAIL_E, lane, G3.east, -212.0, pit_y, TRACK_Y, &"return", -1, "recovery")
	_deck("s5_lane_top", TAIL_E, lane, -212.0, -207.5, TRACK_Y, &"return", -1, BASE, "recovery")
	_wall_line("s5_west", Vector3(TAIL_W, 0, -203.5), Vector3(TAIL_W, 0, TAIL_END), Vector2(-1, 0), TRAINING)
	_wall_line("s5_east_head", Vector3(TAIL_E, 0, -203.5), Vector3(TAIL_E, 0, -207.5), Vector2(1, 0), TRAINING)
	_wall_line("s5_lane_north", Vector3(TAIL_E, 0, -207.5), Vector3(lane + WALL, 0, -207.5), Vector2(0, 1), TRAINING)
	_wall_line("s5_lane_east", Vector3(lane, 0, -207.5), Vector3(lane, 0, G3.land - WALL), Vector2(1, 0), TRAINING)
	_wall_line("s5_lane_south", Vector3(TAIL_E, TAIL_Y, G3.land), Vector3(lane, TAIL_Y, G3.land), Vector2(0, -1), TRAINING + 1.5)
	_wall_line("s5_east", Vector3(TAIL_E, TAIL_Y, G3.land), Vector3(TAIL_E, TAIL_Y, TAIL_END), Vector2(1, 0), TRAINING)
	_wall_line("s5_end", Vector3(TAIL_W - WALL, TAIL_Y, TAIL_END), Vector3(TAIL_E + WALL, TAIL_Y, TAIL_END), Vector2(0, -1), TRAINING)
	_strip_line("s5_nose", Vector3(TAIL_W, 0, G3.west), Vector3(TAIL_E, 0, G3.east), Vector3(0, 0, 0.3))
	_strip_line("s5_land", Vector3(TAIL_W, TAIL_Y, G3.land), Vector3(TAIL_E, TAIL_Y, G3.land), Vector3(0, 0, -0.3))
	_gauge_ticks("s5_g3", G3.land, G3.west, G3.east, TAIL_W, TAIL_E, -TAIL_Y, false)
	# the finish band across the platform, with 11.5 m to stop beyond it.
	_finish_box = AABB(Vector3(TAIL_W, TAIL_Y - 0.1, -240.0), Vector3(TAIL_E - TAIL_W, 4.0, 4.0))
	finish_position = Vector3(-86, TAIL_Y, -246)
	_strip_x("s5_finish_a", TAIL_W, TAIL_E, -236.0, -0.4, TAIL_Y)
	_strip_x("s5_finish_b", TAIL_W, TAIL_E, -240.0, 0.4, TAIL_Y)
	_beacon = MeshInstance3D.new()
	_beacon.name = "FinishBeacon"
	var bar := BoxMesh.new()
	bar.size = Vector3(TAIL_E - TAIL_W + 1.2, 0.5, 0.5)
	_beacon.mesh = bar
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("d9a441")
	glow.emission_enabled = true
	glow.emission = Color("d9a441")
	glow.emission_energy_multiplier = 0.4
	_beacon.material_override = glow
	_beacon.position = Vector3(-86, TAIL_Y + 6.0, -238)
	add_child(_beacon)
	for x: float in [TAIL_W - 0.6, TAIL_E + 0.6]:
		_prism_visual([Vector3(x - 0.25, TAIL_Y + 6.25, -237.75), Vector3(x + 0.25, TAIL_Y + 6.25, -237.75), Vector3(x + 0.25, TAIL_Y + 6.25, -238.25), Vector3(x - 0.25, TAIL_Y + 6.25, -238.25)], TAIL_Y - 2.0, &"steel")

# --- progress, finish and hints --------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their decks (radius 0 turns off the distance rule),
	# so a flight over a gap never collects the deck beyond it. a pose is where that stage's
	# practice starts and where a fall out of the envelope puts the runner back.
	spawn = _pose(Vector3(0, TRACK_Y, 4), 0.0)
	checkpoints = [
		{"pose": spawn, "title": "Gatehouse"},
		{"pose": _pose(Vector3(-1, TRACK_Y, -112), 0.0), "title": "Stop logs", "radius": 0.0},
		{"pose": _pose(_ring_point(BEND_L, Vector3.RIGHT, 1.0, 14.0, 6.0), deg_to_rad(6.0)), "title": "Valve bend", "radius": 0.0},
		{"pose": _pose(Vector3(-17, TRACK_Y, -191.5), PI * 0.5), "title": "Weir gauges", "radius": 0.0},
		{"pose": _pose(Vector3(-63, TRACK_Y, -191.5), PI * 0.5), "title": "Pump bend", "radius": 0.0},
		{"pose": _pose(Vector3(-86, TRACK_Y, -206.5), 0.0), "title": "Tail race", "radius": 0.0},
	]
	segment_bounds = [
		AABB(Vector3(-9, -4, RUNWAY_END), Vector3(18, 30, 8 - RUNWAY_END)),
		AABB(Vector3(-9, -4, BEND_START), Vector3(18, 30, RUNWAY_END - BEND_START)),
		AABB(Vector3(-37, -4, -200), Vector3(46, 30, 200 + BEND_START)),
		AABB(Vector3(G2.land, -4, -204), Vector3(-14 - G2.land, 30, 21)),
		AABB(Vector3(-95, -4, -204), Vector3(37, 30, 21)),
		AABB(Vector3(-95, -6, TAIL_END), Vector3(22, 30, -203.5 - TAIL_END)),
	]
	water_audio_sources = [Vector3(-30, -6, -120), Vector3(-110, -6, -230)]
	var bl := func(r: float, a: float) -> Vector3: return _ring_point(BEND_L, Vector3.RIGHT, 1.0, r, a)
	var br := func(r: float, a: float) -> Vector3: return _ring_point(BEND_R, Vector3.BACK, -1.0, r, a)
	var front: Array = [Vector3(0, 0, 4), Vector3(-1, 0, RUNWAY_END)]
	for b: Array in BLOCKS:
		front.append(Vector3((float(b[2]) + float(b[3])) * 0.5, 0, float(b[0]) - float(b[1]) * 0.5))
	routes = {
		"basic": front + [bl.call(10.0, 10.0), bl.call(9.0, 34.0), bl.call(9.0, 66.0), bl.call(10.0, 86.0),
			Vector3(-24, 0, -185.5), Vector3(-34, 0, -185.0), Vector3(-50, 0, -197.0), Vector3(-58, 0, -197.5), Vector3(-70, 0, -196),
			br.call(8.0, 20.0), br.call(8.0, 45.0), br.call(8.0, 70.0), Vector3(-81, 0, -212), Vector3(-80, 0, G3.east), Vector3(-80, TAIL_Y, -238), Vector3(-82, TAIL_Y, -244)],
		"advanced": front + [bl.call(17.5, 12.0), bl.call(18.5, 34.0), bl.call(18.5, 66.0), bl.call(17.5, 86.0),
			Vector3(-22, 0, -198.0), Vector3(-34, 0, -198.0), Vector3(-44, 0, -185.0), Vector3(-58, 0, -185.0), Vector3(-70, 0, -186),
			br.call(16.0, 20.0), br.call(16.0, 45.0), br.call(16.0, 70.0), Vector3(-91, 0, -210), Vector3(-92, 0, G3.west), Vector3(-92, TAIL_Y, -238), Vector3(-88, TAIL_Y, -244)],
	}
	routes["ordinary"] = routes["basic"]
	routes["block_recovery"] = [Vector3(-2, TRACK_Y - PIT, -146), Vector3(6, TRACK_Y - PIT, -146), Vector3(6, TRACK_Y - PIT, -140), Vector3(6, TRACK_Y, RUNWAY_END), Vector3(0, 0, -124)]
	routes["bend_recovery"] = [bl.call(14.0, 34.0) + Vector3.DOWN * PIT, bl.call(21.0, 34.0) + Vector3.DOWN * PIT, bl.call(21.0, 2.0) + Vector3.DOWN * PIT, Vector3(6, TRACK_Y - PIT, -150), Vector3(6, TRACK_Y - PIT, -140), Vector3(6, TRACK_Y, RUNWAY_END)]
	routes["g1_recovery"] = [Vector3(-30, -PIT, -192), Vector3(-30, -PIT, -201.5), Vector3(-15, 0, -201.5), Vector3(-15, 0, -197)]
	routes["g2_recovery"] = [Vector3(-55, -PIT, -190), Vector3(-56, -PIT, -201.5), Vector3(-40, 0, -201.5), Vector3(-40, 0, -197)]
	routes["notch_recovery"] = [br.call(17.0, 45.0) + Vector3.DOWN * 1.6, br.call(9.0, 45.0)]
	routes["g3_recovery"] = [Vector3(-86, TAIL_Y - PIT, -229), Vector3(-76, TAIL_Y - PIT, -229), Vector3(-76, 0, -210), Vector3(-80, 0, -209)]
	_declare_gaps()

func _declare_gaps() -> void:
	# p / intended entry speeds are design choices for the advanced lines, not measurements.
	var bl := func(r: float, a: float) -> Vector3: return _ring_point(BEND_L, Vector3.RIGHT, 1.0, r, a)
	var br := func(r: float, a: float) -> Vector3: return _ring_point(BEND_R, Vector3.BACK, -1.0, r, a)
	var previous := RUNWAY_END
	var prev_x := Vector2(-8.0, 8.0)
	for i: int in BLOCKS.size():
		var b: Array = BLOCKS[i]
		var lo := maxf(prev_x.x, float(b[2]))
		var hi := minf(prev_x.y, float(b[3]))
		var start := Vector3((lo + hi) * 0.5, 0, previous)
		var land := Vector3((lo + hi) * 0.5, 0, float(b[0]))
		if lo > hi:
			# a zig gap: the blocks do not overlap sideways, so its line is corner to corner.
			start = Vector3(prev_x.x if float(b[3]) < prev_x.x else prev_x.y, 0, previous)
			land = Vector3(float(b[3]) if float(b[3]) < prev_x.x else float(b[2]), 0, float(b[0]))
		_gap("block_%d" % (i + 1), "stop_logs", "basic", start, land, 0.0, "block_recovery", 0.0)
		previous = float(b[0]) - float(b[1])
		prev_x = Vector2(float(b[2]), float(b[3]))
	_gap("block_to_bend", "stop_logs", "basic", Vector3(1.5, 0, previous), Vector3(1.5, 0, BEND_START), 0.0, "block_recovery", 0.0)
	for i: int in BEND_L_ISLANDS.size() - 1:
		var from: float = BEND_L_ISLANDS[i][1]
		var to: float = BEND_L_ISLANDS[i + 1][0]
		_gap("bend_%d_inside" % (i + 1), "valve_bend", "basic", bl.call(8.0, from), bl.call(8.0, to), 0.0, "bend_recovery", 0.0)
		_gap("bend_%d_outside" % (i + 1), "valve_bend", "advanced", bl.call(19.0, from), bl.call(19.0, to), 0.0, "bend_recovery", 420.0)
	# gauges are judged 1 m in from the side a line uses, where a 0.4 m body can run.
	for z: float in [WEIR_N - 1.0, WEIR_S + 1.0]:
		var k := (z - WEIR_N) / (WEIR_S - WEIR_N)
		var north := z > -191.5
		_gap("g1_north" if north else "g1_south", "weir_gauges", "basic" if north else "advanced", Vector3(lerpf(G1.north, G1.south, k), 0, z), Vector3(G1.land, 0, z), 0.0, "g1_recovery", 0.0 if north else 540.0)
		_gap("g2_north" if north else "g2_south", "weir_gauges", "advanced" if north else "basic", Vector3(lerpf(G2.north, G2.south, k), 0, z), Vector3(G2.land, 0, z), 0.0, "g2_recovery", 720.0 if north else 0.0)
	_gap("notch_middle", "pump_bend", "advanced", br.call(16.0, NOTCH[0]), br.call(16.0, NOTCH[1]), 0.0, "notch_recovery", 580.0)
	_gap("notch_outer", "pump_bend", "advanced", br.call(19.5, NOTCH[0]), br.call(19.5, NOTCH[1]), 0.0, "notch_recovery", 680.0)
	for x: float in [TAIL_E - 1.0, TAIL_W + 1.0]:
		var edge := lerpf(G3.west, G3.east, (x - TAIL_W) / (TAIL_E - TAIL_W))
		var east := x > -86.0
		_gap("g3_east" if east else "g3_west", "tail_race", "basic" if east else "advanced", Vector3(x, 0, edge), Vector3(x, TAIL_Y, G3.land), 0.0, "g3_recovery", 0.0 if east else 700.0)

func _gap(label: String, section: String, line: String, edge: Vector3, land: Vector3, climb: float, recovery: String, intended_ups: float) -> void:
	# a declared jump, judged with the provisional vanilla figures, feet centre to feet centre.
	var distance := Vector2(land.x - edge.x, land.z - edge.z).length()
	var drop := edge.y - land.y
	var t := flight_time(drop)
	var min_mps := distance / t
	var clear_mps := (distance + LANDING) / t
	var comfortable_mps := (distance + LANDING) / (t - EARLY)
	var run_mps := float(VANILLA.run_ups) * U
	var slack := (run_mps * t - distance - LANDING) / run_mps
	var tier := "vanilla_run" if comfortable_mps <= run_mps else "vanilla_run_tight"
	if clear_mps > run_mps:
		for entry: Array in TIERS:
			if clear_mps / U <= float(entry[1]):
				tier = entry[0]
				break
	var intended := intended_ups if intended_ups > 0.0 else VANILLA.run_ups
	var intended_mps := intended * U
	jump_gaps.append({
		"label": label, "section": section, "line": line, "edge": edge, "land": land, "climb": climb,
		"kind": "ordinary" if line == "basic" else "earned",
		"speed": snappedf(intended_mps, 0.01), "drained": snappedf(float(VANILLA.run_ups) * U, 0.01),
		"width_m": snappedf(distance, 0.01), "width_u": roundi(distance / U), "drop_m": snappedf(drop, 0.01), "drop_u": roundi(drop / U),
		"flight_s": snappedf(t, 0.001), "min_ups": roundi(min_mps / U), "clear_ups": roundi(clear_mps / U), "comfortable_ups": roundi(comfortable_mps / U),
		"run_box_hull_short_m": snappedf(distance - 32.0 * U - run_mps * t, 0.01),
		"intended_ups": roundi(intended), "intended_spare_m": snappedf(intended_mps * t - distance - LANDING, 0.01),
		"vanilla_run_slack_s": snappedf(slack, 0.001), "tier": tier, "recovery": recovery,
	})

## flight time of a vanilla jump that lands `drop` metres below its take-off.
static func flight_time(drop: float) -> float:
	var v0 := float(VANILLA.jump_ups) * U
	var g := float(VANILLA.gravity_ups) * U
	return (v0 + sqrt(v0 * v0 + 2.0 * g * drop)) / g

## the full course record for the manifest file: sections, gaps, gauges, recoveries, units.
func course_manifest() -> Dictionary:
	var gaps: Array = []
	for gap: Dictionary in jump_gaps:
		var copy := gap.duplicate()
		copy.edge = _v(gap.edge)
		copy.land = _v(gap.land)
		gaps.append(copy)
	var gauges: Array = []
	for g: Array in [["g1", G1.land, G1.north, G1.south, 0.0], ["g2", G2.land, G2.north, G2.south, 0.0], ["g3", G3.land, G3.west, G3.east, TAIL_Y]]:
		var widths := [absf(float(g[2]) - float(g[1])), absf(float(g[3]) - float(g[1]))]
		var t := flight_time(-float(g[4]))
		gauges.append({"label": g[0], "width_m": widths, "width_u": [roundi(widths[0] / U), roundi(widths[1] / U)], "drop_m": -float(g[4]),
			"min_ups_per_metre": snappedf(1.0 / t / U, 0.01), "min_ups": [roundi(widths[0] / t / U), roundi(widths[1] / t / U)], "track_width_m": WIDTH})
	var stages: Array = []
	for point: Dictionary in checkpoints:
		stages.append({"title": point.title, "pose": _v((point.pose as Transform3D).origin)})
	return {
		"level_id": LEVEL_ID, "level_name": LEVEL_NAME, "level_version": LEVEL_VERSION, "variant": variant,
		"units": {"u_m": U, "note": "1 u = 0.0254 m (P, pending the source researcher)"},
		"vanilla_model": VANILLA, "judging": {"landing_margin_m": LANDING, "early_press_s": EARLY, "hull_credit": "none: feet centre to feet centre, conservative for a 32 u box"},
		"track": {"width_m": WIDTH, "width_u": roundi(WIDTH / U), "runway_m": -RUNWAY_END, "runway_u": roundi(-RUNWAY_END / U), "pit_depth_m": PIT, "training_wall_m": TRAINING},
		"stages": stages, "finish": {"title": finish_title, "box": [_v(_finish_box.position), _v(_finish_box.size)]},
		"gaps": gaps, "gauges": gauges, "recovery": "every pit walks back to the take-off deck of the jump it caught; nothing in a pit leads forward",
		"geometry_hash": geometry_hash(), "pieces": manifest.size(),
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
	if feet.y < TRACK_Y - 0.6 and feet.z < RUNWAY_END and feet.z > BEND_START - 23.0 and feet.x > -14.0:
		return "In the pit: walk to the right-hand lane and up the ramp to the runway's end."
	if feet.y < TRACK_Y - 0.6 and feet.z < WEIR_N and feet.z > WEIR_S - 5.0 and feet.x < -14.0 and feet.x > WEIR_END:
		return "In the gauge pit: walk to the south lane and up the ramp behind you."
	if feet.y < TRACK_Y - 0.4 and feet.z < BEND_R.z + BEND_R_OUT and feet.x < -74.0 and feet.z > -203.5:
		return "On the notch slope: walk in toward the pump house to rejoin the inside band."
	if feet.y < TAIL_Y - 0.6 and feet.z < -212.0 and feet.z > G3.land - 0.1:
		return "In the tail pit: walk east and up the lane ramp to the run-in."
	match stage:
		0:
			return "Build speed down the straight: hop, A/D with the mouse. The wall marks are 16 m apart."
		1:
			return "Hop the stop logs. Each gap is half a metre wider; the last three zig left and right."
		2:
			return "Strafe left round the bend. Inside gaps are short; the outside keeps speed and needs it."
		3:
			return "Pick a width at each gauge: the paint says what it needs. The wide ends alternate sides."
		4:
			return "Round to the right. Walk the inside band, or carry speed over the outer notch."
		5:
			return "Last gauge, 1.5 m down: 3.5 m on the right, 14 m on the left. Finish on the platform."
	return "Cross the line on the platform."

func start_wheel() -> void:
	_running = true

func reset_state() -> void:
	_running = false
	_finish_glow = 0.0

func _process(delta: float) -> void:
	# p / the finish beacon brightens after a finish: presentation only.
	_finish_glow = move_toward(_finish_glow, 1.0 if _running else 0.0, delta * 1.5)
	if is_instance_valid(_beacon):
		(_beacon.material_override as StandardMaterial3D).emission_energy_multiplier = 0.4 + _finish_glow * 2.6

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

func _deck(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	return _solid(label, [Vector3(x0, top, z0), Vector3(x1, top, z0), Vector3(x1, top, z1), Vector3(x0, top, z1)], base, kind, stage, role)

func _deck_x(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	return _deck(label, x0, x1, z0, z1, top, kind, stage, base, role)

func _ramp_z(label: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, kind: StringName, stage: int, role: String = "route") -> StaticBody3D:
	return _solid(label, [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], BASE, kind, stage, role)

func _ramp_x(label: String, z0: float, z1: float, x0: float, x1: float, y0: float, y1: float, kind: StringName, role: String) -> StaticBody3D:
	return _solid(label, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], BASE, kind, -1, role)

func _wall_z(label: String, x: float, z0: float, z1: float, side: int, floor_y: float = TRACK_Y) -> StaticBody3D:
	# a training wall outside a deck edge at x along z, 2 m over the track, down past the pits.
	var xo := x + side * WALL
	var top := TRACK_Y + TRAINING
	return _solid(label, [Vector3(x, top, z0), Vector3(xo, top, z0), Vector3(xo, top, z1), Vector3(x, top, z1)], minf(floor_y, TRACK_Y) - 1.0, &"concrete", -1, "wall")

func _wall_x(label: String, x0: float, x1: float, z: float, y: float, side: int, height: float) -> StaticBody3D:
	var zo := z + side * WALL
	return _solid(label, [Vector3(x0, y + height, z), Vector3(x1, y + height, z), Vector3(x1, y + height, zo), Vector3(x0, y + height, zo)], BASE, &"concrete", -1, "wall")

func _wall_line(label: String, a: Vector3, b: Vector3, out: Vector2, height: float) -> StaticBody3D:
	# a wall outside the edge a-b on the `out` side, its top `height` above the edge.
	var along := Vector2(b.x - a.x, b.z - a.z).normalized()
	var normal := Vector2(-along.y, along.x)
	if normal.dot(out) < 0.0:
		normal = -normal
	var o := Vector3(normal.x, 0.0, normal.y) * WALL
	var up := Vector3.UP * height
	return _solid(label, [a + up, b + up, b + o + up, a + o + up], BASE, &"concrete", -1, "wall")

func _ring_point(centre: Vector3, start: Vector3, turn: float, r: float, degrees: float, y: float = TRACK_Y) -> Vector3:
	# a point on a bend: `start` is the entry radius direction, turn +1 left (the radius swings
	# from +x toward -z), -1 right. y is the deck height.
	var d := start.rotated(Vector3.UP, deg_to_rad(degrees) * turn)
	return Vector3(centre.x + d.x * r, y, centre.z + d.z * r)

func _ring_piece(label: String, centre: Vector3, start: Vector3, turn: float, r0: float, r1: float, a: float, b: float, y_in: float, y_out: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	# one chord-bounded sector of a ring band. its inner and outer chords are parallel, so a
	# radial slope (y_in at r0, y_out at r1) is still a planar top.
	return _solid(label, [_ring_point(centre, start, turn, r0, a, y_in), _ring_point(centre, start, turn, r1, a, y_out), _ring_point(centre, start, turn, r1, b, y_out), _ring_point(centre, start, turn, r0, b, y_in)], base, kind, stage, role)

func _ring_wall(label: String, centre: Vector3, start: Vector3, turn: float, r0: float, r1: float, a: float, b: float, floor_y: float) -> StaticBody3D:
	return _ring_piece(label, centre, start, turn, r0, r1, a, b, TRACK_Y + TRAINING, TRACK_Y + TRAINING, &"concrete", -1, floor_y - 1.0, "wall")

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid") -> StaticBody3D:
	# a convex prism: a planar top quad extruded straight down to `base`.
	assert(not has_node(NodePath(label)), "practice: duplicate piece " + label)
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
	_add_prism(points, kind)
	manifest.append({"name": label, "role": role, "stage": stage, "points": points, "shape": "prism", "kind": kind})
	return body

func _prism_visual(top: Array, base: float, kind: StringName) -> void:
	var points: Array[Vector3] = []
	for p: Vector3 in top:
		points.append(p)
	for p: Vector3 in top:
		points.append(Vector3(p.x, base, p.z))
	_add_prism(points, kind)

func _strip_x(label: String, x0: float, x1: float, z: float, width: float, y: float = TRACK_Y) -> void:
	# a flush painted band across the track at z, `width` toward +z (negative: toward -z).
	_strip_line(label, Vector3(x0, y, z), Vector3(x1, y, z), Vector3(0, 0, width))

func _strip_line(label: String, a: Vector3, b: Vector3, inward: Vector3) -> void:
	# a flush painted band along an edge, `inward` across the walking side: visual only.
	var lift := Vector3.UP * 0.004
	_prism_visual([a + lift, b + lift, b + inward + lift, a + inward + lift], minf(a.y, b.y) - 0.05, &"ochre")
	markings.append({"name": label, "kind": "strip", "a": _v(a), "b": _v(b)})

func _gauge_ticks(label: String, land: float, side_a: float, side_b: float, across_a: float, across_b: float, drop: float, along_x: bool) -> void:
	# whole-metre ticks on a slanted take-off edge, each labelled with its width and the
	# slowest vanilla jump that clears it. along_x: the gap runs along -x (else along -z).
	var w0 := absf(side_a - land)
	var w1 := absf(side_b - land)
	var t := flight_time(drop)
	for w: int in range(ceili(minf(w0, w1)), floori(maxf(w0, w1)) + 1):
		var k := (float(w) - w0) / (w1 - w0)
		var across := lerpf(across_a, across_b, k)
		var edge := lerpf(side_a, side_b, k)
		var text := "%d m\n%d u/s" % [w, roundi(float(w) / t / U)]
		if along_x:
			_strip_line("%s_tick_%02d" % [label, w], Vector3(edge, 0, across - 0.06), Vector3(edge + 1.2, 0, across - 0.06), Vector3(0, 0, 0.12))
			_floor_label("%s_w%02d" % [label, w], Vector3(edge + 2.2, 0, across), PI * 0.5, text, 0.01)
		else:
			_strip_line("%s_tick_%02d" % [label, w], Vector3(across - 0.06, 0, edge), Vector3(across - 0.06, 0, edge + 1.2), Vector3(0.12, 0, 0))
			_floor_label("%s_w%02d" % [label, w], Vector3(across, 0, edge + 2.2), 0.0, text, 0.01)

func _gap_text(metres: float) -> String:
	return "%.1f m\n%d u" % [metres, roundi(metres / U)]

func _floor_label(label: String, at: Vector3, yaw: float, text: String, pixel: float = 0.008) -> void:
	# painted text lying on a deck, upright for a runner travelling along `yaw`.
	var mark := Label3D.new()
	mark.name = label
	mark.text = text
	mark.font_size = 64
	mark.pixel_size = pixel
	mark.outline_size = 0
	mark.modulate = Color("e2c27a")
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), at + Vector3.UP * 0.01)
	_marks.add_child(mark)
	markings.append({"name": label, "kind": "floor", "at": _v(at), "text": text})

func _wall_label(label: String, at: Vector3, yaw: float, text: String) -> void:
	var mark := Label3D.new()
	mark.name = label
	mark.text = text
	mark.font_size = 64
	mark.pixel_size = 0.01
	mark.outline_size = 8
	mark.modulate = Color("f2e6c4")
	mark.outline_modulate = Color(0.1, 0.1, 0.1, 0.8)
	mark.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	_marks.add_child(mark)
	markings.append({"name": label, "kind": "wall", "at": _v(at), "text": text})

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

# --- meshes and materials ------------------------------------------------------------------

func _add_prism(points: Array[Vector3], kind: StringName) -> void:
	# top 0-3, bottom 4-7, flat normals, winding fixed per triangle (godot fronts are clockwise).
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
		if LOOK.has(kind):
			if not _looks.has(kind):
				_looks[kind] = Materials.variant(LOOK[kind][0], LOOK[kind][1])
			return _looks[kind]
		return Materials.get_material(kind)
	var flat := StandardMaterial3D.new()
	flat.albedo_color = NEUTRAL[kind]
	flat.roughness = 0.85
	flat.metallic = 0.4 if kind == &"steel" else 0.0
	return flat

const WATER := "shader_type spatial;\nrender_mode cull_disabled;\nuniform vec3 tint : source_color = vec3(0.3, 0.45, 0.45);\nvarying vec3 wpos;\nvoid vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tvec2 p = wpos.xz * 0.35;\n\tfloat r = sin(p.x * 3.1 + TIME * 0.7) * sin(p.y * 2.3 - TIME * 0.5) + sin((p.x + p.y) * 5.7 + TIME * 1.3) * 0.4;\n\tALBEDO = tint * (0.9 + r * 0.06);\n\tROUGHNESS = 0.12 + r * 0.03;\n\tSPECULAR = 0.6;\n}\n"

func _water(center: Vector3, size: Vector2, color: Color) -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	plane.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = _water_shader
	material.set_shader_parameter("tint", color)
	plane.material_override = material
	plane.position = center
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)

# --- environment and scenery ---------------------------------------------------------------

func _environment() -> void:
	# p / late-morning sun from behind the start's right: landing tops read lightest, pit
	# floors sit in shadow, and the dam face to the east stays lit.
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("4f86bd")
	atmosphere.sky_horizon_color = Color("c3cfd1")
	atmosphere.ground_horizon_color = Color("8e988a")
	atmosphere.ground_bottom_color = Color("464e43")
	atmosphere.sun_angle_max = 20.0
	sky.sky_material = atmosphere
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 0.95
	environment.fog_enabled = true
	environment.fog_light_color = Color("c3cdd0")
	environment.fog_density = 0.0018
	environment.fog_aerial_perspective = 0.5
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color("ffeedb")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)

func _scenery() -> void:
	# the dam rises east of the yard, its reservoir behind; the yard sits on the bench at its
	# foot over the tailwater. none of it can be reached over the training walls.
	_water(Vector3(-50, -7.6, -130), Vector2(420, 420), Color("3c6163"))
	# p / the dam stands 40 m east of the runway, its 1:1.2 downstream face toward the yard.
	_prism_visual([Vector3(78, 36, 40), Vector3(92, 36, 40), Vector3(92, 36, -300), Vector3(78, 36, -300)], -8.0, &"concrete")
	_prism_visual([Vector3(48, -6, 40), Vector3(78, 36, 40), Vector3(78, 36, -300), Vector3(48, -6, -300)], -8.0, &"concrete")
	_water(Vector3(160, 33.5, -130), Vector2(140, 360), Color("4b7377"))
	# the gatehouse behind the start, and a pump house in the pump bend's core.
	_prism_visual([Vector3(-9, 9, 18), Vector3(9, 9, 18), Vector3(9, 9, 9), Vector3(-9, 9, 9)], -2.0, &"brick")
	_prism_visual([Vector3(-9.6, 9.7, 18.6), Vector3(9.6, 9.7, 18.6), Vector3(9.6, 9.7, 8.4), Vector3(-9.6, 9.7, 8.4)], 9.0, &"concrete")
	_prism_visual([Vector3(-77, 9, -200.5), Vector3(-71, 9, -200.5), Vector3(-71, 9, -206.5), Vector3(-77, 9, -206.5)], -6.0, &"brick")
	# a valve tower inside the valve bend, and steel gantries over the straight as passing marks.
	_prism_visual([Vector3(-16.5, 9, -179.5), Vector3(-12.5, 9, -179.5), Vector3(-12.5, 9, -175.5), Vector3(-16.5, 9, -175.5)], -6.0, &"brick")
	_prism_visual([Vector3(-17, 9.6, -180), Vector3(-12, 9.6, -180), Vector3(-12, 9.6, -175), Vector3(-17, 9.6, -175)], 9.0, &"concrete")
	for z: float in [-32.0, -64.0, -96.0]:
		for x: float in [-9.0, 9.0]:
			_prism_visual([Vector3(x - 0.25, 9, z + 0.25), Vector3(x + 0.25, 9, z + 0.25), Vector3(x + 0.25, 9, z - 0.25), Vector3(x - 0.25, 9, z - 0.25)], 0.0, &"steel")
		_prism_visual([Vector3(-9.6, 9.6, z + 0.35), Vector3(9.6, 9.6, z + 0.35), Vector3(9.6, 9.6, z - 0.35), Vector3(-9.6, 9.6, z - 0.35)], 8.8, &"ochre")
	# the bench's own retaining faces under the decks, so the course reads as built, not floating.
	_prism_visual([Vector3(-8.4, -0.02, 8.4), Vector3(8.4, -0.02, 8.4), Vector3(8.4, -0.02, -128), Vector3(-8.4, -0.02, -128)], -7.5, &"old_concrete")
	_prism_visual([Vector3(-200, 20, 40), Vector3(-130, 2, 40), Vector3(-130, 2, -320), Vector3(-200, 20, -320)], -8.0, &"hill")
	_prism_visual([Vector3(-200, 24, -320), Vector3(60, 24, -320), Vector3(60, 2, -275), Vector3(-200, 2, -275)], -8.0, &"hill")
