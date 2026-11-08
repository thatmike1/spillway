extends Node3D
## p / r15 Breakwater: an original container-port bhop course at dusk. it publishes the r14 level
## interface (spawn, checkpoints, segment and kill bounds, finish, routes, jump gaps, manifest,
## geometry hash, route hints, level identity), so r14_main.gd hosts it through level_script with
## no change, and the approved source runner plays it now. no part of the route needs crouch.
## layout, numbers, recoveries and limits: docs/r15/BREAKWATER.md.
##
## course, in order (forward -z, then -x on the quay, then -z out along the breakwater):
##   gate deck under the gatehouse canopy -> box rows (four blocks of container roofs over the
##   yard alleys, gaps 2.0 to 3.5 m, the last block offset left) -> crane line (a walled left bend,
##   a 40 m quay under two ship-to-shore cranes with a two-stack chicane, then a right bend whose
##   inside is open harbour) -> the breakwater (128 m runway beside the crown wall) -> the breach
##   (an 8.5 m jump onto the lighthouse roundhead, or the narrow gangway on the harbour side) ->
##   round the lighthouse to the finish band on its seaward side.
## a missed box-rows jump lands in an alley that walks back up the return ramp; any fall into
## the harbour is a respawn at the last checkpoint, which is the only use of the kill envelope.
##
## collision: every solid is a convex prism (ConvexPolygonShape3D), no walkable piece is longer
## than 32 m, and the alley floors and quays reach 5 m or more below their tops: godot 4.7.2 can
## miss a cast into a large single box (docs/r14/CONTACT-GUARD.md), so the route is split into
## modest coplanar pieces on exact shared edges, as Penstock Yard's straight is.

const Art := preload("res://scripts/r15_breakwater_art.gd")

## the identity the r14 main keys records and labels on. bump LEVEL_VERSION with any change to
## geometry, progress or timing semantics.
const LEVEL_ID := "r15-breakwater"
const LEVEL_NAME := "Breakwater"
const LEVEL_VERSION := 1
const VARIANTS := ["breakwater"]
## p / source units: 1 u = 0.0254 m (hammer inch), as Penstock Yard.
const U := 0.0254
## the vanilla cs:go figures behind the gap screening (docs/r14/SOURCE-REFERENCE.md). driven runs
## on the actual runner decide; these only sort gaps into tiers.
const VANILLA := {"run_ups": 250.0, "jump_ups": 301.993, "gravity_ups": 800.0}
const LANDING := 0.5
const EARLY := 0.1
const TIERS := [["vanilla_strafe", 330.0], ["server", 520.0], ["fast", INF]]

## iso container sizes (m): width, height and the 10, 20 and 40 ft lengths.
const CW := 2.438
const CH := 2.591
const L10 := 2.991
const L20 := 6.058
const L40 := 12.192
const TRACK_Y := 0.0
## the yard floor: one container below the roofs, deeper than a jump's 1.45 m apex.
const GROUND := -CH
const BASE := -8.0
const WATER_Y := -3.0
## p / anything below this is in the harbour: respawn. above the alleys (-2.59), below the water.
const KILL_Y := -3.3
## the yard is seven containers wide; the right column is the alley's return lane.
const HALF := 3.5 * CW
const LANE_X := HALF - CW
const GATE_START := 8.0
const GATE_END := -28.0
## box rows: [near z, length, x from, x to]. gaps 2.0, 2.5, 3.0 and 3.5 m; the last block is four
## containers wide on the left, turning the line toward the left bend.
const BLOCKS := [
	[-30.0, L20, -HALF, LANE_X],
	[-38.558, L20, -HALF, LANE_X],
	[-47.616, L40, -HALF, LANE_X],
	[-63.308, L20, -HALF, -HALF + 4.0 * CW],
]
const YARD_END := -72.366
## the return ramp climbs from the lane's head, at alley level, into the gate deck's right column.
const RAMP_TOP := -16.0
## bend 1 (left, -z to -x): centre, inner and outer radii. the band starts on the yard's width.
const BEND1 := Vector3(-HALF - 8.0, 0, YARD_END)
const BEND1_IN := 8.0
const BEND1_OUT := 8.0 + 2.0 * HALF
## the crane line along -x between these z edges (north wall, open quay edge to the south).
const QUAY_N := YARD_END - BEND1_IN
const QUAY_S := YARD_END - BEND1_OUT
const QUAY_START := -HALF - 8.0
const QUAY_END := QUAY_START - 40.0
## chicane stacks: [x near, x far, z from, z to]; each leaves an 8 m passage.
const CHICANE := [
	[-24.0, -24.0 - 2.0 * CW, QUAY_N, QUAY_N - L20 - L10],
	[-46.0, -46.0 - 2.0 * CW, QUAY_S + L20 + L10, QUAY_S],
]
## bend 2 (right, -x to -z): inside is open harbour.
const BEND2_IN := 10.0
const BEND2_OUT := 10.0 + 2.0 * HALF
const BEND2 := Vector3(QUAY_END, 0, QUAY_S - BEND2_IN)
## the breakwater runway along -z between these x edges; crown wall on the west (sea) side.
const MOLE_E := QUAY_END - BEND2_IN
const MOLE_W := QUAY_END - BEND2_OUT
const MOLE_START := QUAY_S - BEND2_IN
const MOLE_SECTIONS := 4
const MOLE_END := MOLE_START - 32.0 * MOLE_SECTIONS
const CROWN := 2.2
## the breach and the roundhead, 1 m lower; the gangway on the harbour side.
const BREACH := 8.5
const HEAD_Y := -1.0
const HEAD_N := MOLE_END - BREACH
const HEAD := Vector3((MOLE_E + MOLE_W) * 0.5, HEAD_Y, HEAD_N - 12.068)
const HEAD_R := 14.0
const GANGWAY_W := 3.5
const TOWER_R := 4.5
const FINISH_Z := HEAD.z - 8.0
const WALL := 0.4

## set by a factory before the level enters the tree; build() reads it once (r14 convention).
static var next_variant: String = ""

## p / not "course": the r14 overflow art pass dresses any "course" variant, and this map dresses itself.
var variant: String = "breakwater"
## "kit": the sourced harbour kit; "neutral": flat colours for attribution runs.
var material_mode: String = "kit"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var finish_title: String = "Lighthouse"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 4.0
## p / the harbour is scenery: no wading. a fall into it leaves the kill envelope.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var routes: Dictionary = {}
var jump_gaps: Array[Dictionary] = []
var kill_bounds := AABB(Vector3(-140, KILL_Y, -300), Vector3(200, 160 - KILL_Y, 320))
## every collision piece: name, world points, stage, role, kind. hashed without materials.
var manifest: Array[Dictionary] = []
## painted marks and labels: visual only, not hashed.
var markings: Array[Dictionary] = []
## containers to draw: centre of the footprint at its base, length axis, length, tier, colour.
var containers: Array[Dictionary] = []
## prism tops and bases drawn by kind, from collision pieces and visual-only prisms alike.
var prisms: Array[Dictionary] = []
## props placed by the level for the art pass: id, transform.
var props: Array[Dictionary] = []

var _finish_box := AABB()
var _built := false
var _running := false
var _art: RefCounted

func build() -> void:
	if _built:
		return
	_built = true
	if not next_variant.is_empty():
		variant = next_variant
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--breakwater-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "breakwater: unknown variant " + variant)
	_gate()
	_box_rows()
	_bend_one()
	_crane_line()
	_bend_two()
	_breakwater()
	_roundhead()
	_define_progress()
	_art = Art.new()
	_art.call("dress", self)

# --- the course ----------------------------------------------------------------------------

func _gate() -> void:
	# stage 0: the gate deck, 17 m wide and 36 m long under the gatehouse canopy. a sheltered
	# start with room to reach run speed (2 m) and line up on the first block.
	_deck("s0_gate_a", -HALF, HALF, GATE_START, RAMP_TOP, TRACK_Y, &"pavers", 0)
	_deck("s0_gate_b", -HALF, LANE_X, RAMP_TOP, GATE_END, TRACK_Y, &"pavers", 0)
	# the gatehouse face behind the spawn: a wall 3 m over the deck.
	_solid("s0_gatehouse", _rect(-HALF - CW, HALF + CW, GATE_START + WALL, GATE_START, TRACK_Y + 3.0), BASE, &"cladding", -1, "wall")
	# yard walls: two-high container stacks along both sides, gate to bend.
	_stack_run("s0_wall_w", false, GATE_START, YARD_END, -HALF - CW, -HALF, GROUND, 2, [L40, L40, L20, L40, L40, L40, L40], 0)
	_stack_run("s0_wall_e", false, GATE_START, YARD_END, HALF, HALF + CW, GROUND, 2, [L40, L40, L40, L20, L40, L40, L40], 3)
	_paint_x("s0_start_line", -HALF, HALF, 0.0, 0.3, TRACK_Y, &"paint_white")
	_paint_x("s0_edge", -HALF, LANE_X, GATE_END, 0.35, TRACK_Y, &"paint_yellow")

func _box_rows() -> void:
	# stage 1: four blocks of container roofs over the yard alleys. each alley is one container
	# deep (2.59 m, over a jump's apex) and opens onto the return lane on the right, level with
	# it the whole length of the yard; the lane's head climbs a ramp into the gate deck's right
	# column: a miss walks back and retries, it never leads forward.
	_deck("s1_alley_a", -HALF, HALF, GATE_END, -50.0, GROUND, &"asphalt", -1, BASE, "catch")
	_deck("s1_alley_b", -HALF, HALF, -50.0, YARD_END, GROUND, &"asphalt", -1, BASE, "catch")
	_solid("s1_return_ramp", [Vector3(LANE_X, TRACK_Y, RAMP_TOP), Vector3(HALF, TRACK_Y, RAMP_TOP), Vector3(HALF, GROUND, GATE_END), Vector3(LANE_X, GROUND, GATE_END)], BASE, &"steel_ramp", -1, "recovery")
	_paint_line("s1_ramp_head", Vector3(LANE_X, TRACK_Y, RAMP_TOP), Vector3(HALF, TRACK_Y, RAMP_TOP), Vector3(0, 0, 0.25), &"paint_yellow")
	var previous := GATE_END
	var colours := [[0, 1, 2, 3, 4, 5], [2, 4, 0, 5, 1, 3], [5, 0, 3, 1, 2, 4], [1, 3, 5, 0]]
	for i: int in BLOCKS.size():
		var b: Array = BLOCKS[i]
		var near: float = b[0]
		var far := near - float(b[1])
		var count := roundi((float(b[3]) - float(b[2])) / CW)
		for k: int in count:
			var x0 := float(b[2]) + k * CW
			_container("s1_block_%d_%d" % [i + 1, k + 1], x0, x0 + CW, near, far, GROUND, 1, colours[i][k % colours[i].size()], 1, "route")
		# yellow lashing paint on every lip that faces a gap, and the width in metres and units.
		_paint_x("s1_lip_%d_near" % (i + 1), float(b[2]), float(b[3]), near, -0.25, TRACK_Y, &"paint_yellow")
		_paint_x("s1_lip_%d_far" % (i + 1), float(b[2]), float(b[3]), far, 0.25, TRACK_Y, &"paint_yellow")
		_floor_label("s1_gap_%d" % (i + 1), Vector3(-3.0, TRACK_Y, previous + 0.9), 0.0, _gap_text(previous - near))
		previous = far
	_floor_label("s1_gap_quay", Vector3(-3.0, TRACK_Y, previous + 0.9), 0.0, _gap_text(previous - YARD_END))
	_paint_x("s1_quay_lip", -HALF, HALF, YARD_END, -0.25, TRACK_Y, &"paint_yellow")

func _bend_one() -> void:
	# stage 2 begins: a quarter ring turning left onto the quay, 17 m of asphalt between a curved
	# reefer-plinth wall inside and a container wall outside. walled both sides: the place to learn
	# to hold a strafe through a turn without a fall.
	for a: int in range(0, 90, 10):
		_ring_piece("s2_bend1_%02d" % a, BEND1, Vector3.RIGHT, 1.0, BEND1_IN, BEND1_OUT, a, a + 10, TRACK_Y, &"asphalt", 2)
		_ring_wall("s2_bend1_inner_%02d" % a, BEND1, Vector3.RIGHT, 1.0, BEND1_IN - WALL, BEND1_IN, a, a + 10, CH, &"concrete")
		_ring_wall("s2_bend1_outer_%02d" % a, BEND1, Vector3.RIGHT, 1.0, BEND1_OUT, BEND1_OUT + WALL, a, a + 10, CH, &"concrete")

func _crane_line() -> void:
	# stage 2: 40 m of quay heading -x under two ship-to-shore cranes. the north side is a row
	# of containers; the south side is the open quay edge over the harbour. two stacks, one from
	# each side, leave 8 m passages: a left-right rhythm to carry speed through.
	var mid := (QUAY_START + QUAY_END) * 0.5
	_deck_x("s2_quay_a", QUAY_START, mid, QUAY_N, QUAY_S, TRACK_Y, &"asphalt", 2)
	_deck_x("s2_quay_b", mid, QUAY_END, QUAY_N, QUAY_S, TRACK_Y, &"asphalt", 2)
	_stack_run("s2_north", true, QUAY_START, QUAY_END, QUAY_N + CW, QUAY_N, TRACK_Y, 1, [L40, L40, L40, L10], 1)
	for i: int in CHICANE.size():
		var c: Array = CHICANE[i]
		var z0: float = c[2]
		var z1: float = c[3]
		var sign := -1.0 if z1 < z0 else 1.0
		var lengths := [L20, L10]
		var z := z0
		for j: int in lengths.size():
			var z_next: float = z + sign * float(lengths[j])
			for k: int in 2:
				var x0: float = float(c[0]) - k * CW
				_container("s2_chicane_%d_%d_%d" % [i + 1, j + 1, k + 1], x0 - CW, x0, z, z_next, TRACK_Y, 2, (i * 3 + j * 2 + k) % 6, -1, "wall")
			z = z_next
	_paint_line("s2_quay_edge", Vector3(QUAY_START, TRACK_Y, QUAY_S), Vector3(QUAY_END, TRACK_Y, QUAY_S), Vector3(0, 0, 0.3), &"paint_yellow")

func _bend_two() -> void:
	# stage 2 ends: a quarter ring turning right onto the breakwater. the outside is a container
	# wall; the inside edge is open harbour: the short line is the risky one.
	for a: int in range(0, 90, 10):
		_ring_piece("s2_bend2_%02d" % a, BEND2, Vector3.BACK, -1.0, BEND2_IN, BEND2_OUT, a, a + 10, TRACK_Y, &"asphalt", 2)
		_ring_wall("s2_bend2_outer_%02d" % a, BEND2, Vector3.BACK, -1.0, BEND2_OUT, BEND2_OUT + WALL, a, a + 10, CH, &"concrete")
		var a3 := _ring_point(BEND2, Vector3.BACK, -1.0, BEND2_IN, a)
		var b3 := _ring_point(BEND2, Vector3.BACK, -1.0, BEND2_IN, a + 10)
		var inward := (_ring_point(BEND2, Vector3.BACK, -1.0, BEND2_IN + 1.0, a + 5) - _ring_point(BEND2, Vector3.BACK, -1.0, BEND2_IN, a + 5)).normalized() * 0.3
		_paint_line("s2_bend2_edge_%02d" % a, a3, b3, inward, &"paint_yellow")

func _breakwater() -> void:
	# stage 3: the breakwater runway, 17 m wide and 128 m long in four 32 m pieces, with the crown
	# wall on the sea side and the harbour open to the east. nothing on it adds or removes speed.
	# the last piece is stage 4, so a fall at the breach puts the runner back just before it.
	for k: int in MOLE_SECTIONS:
		var z0 := MOLE_START - 32.0 * k
		var z1 := z0 - 32.0
		var stage := 4 if k == MOLE_SECTIONS - 1 else 3
		var label := "s%d_runway_%d" % [stage, k + 1]
		_deck(label, MOLE_W, MOLE_E, z0, z1, TRACK_Y, &"pavers", stage)
		_solid("s3_crown_%d" % (k + 1), _rect(MOLE_W - 0.6, MOLE_W, z0, z1, TRACK_Y + CROWN), BASE, &"concrete", -1, "wall")
		_paint_line("s3_edge_%d" % (k + 1), Vector3(MOLE_E, TRACK_Y, z0), Vector3(MOLE_E, TRACK_Y, z1), Vector3(-0.3, 0, 0), &"paint_yellow")
	for i: int in range(1, 16):
		var z := MOLE_START - 8.0 * i
		_paint_line("s3_mark_%02d" % i, Vector3(MOLE_W, TRACK_Y, z), Vector3(MOLE_E, TRACK_Y, z), Vector3(0, 0, 0.3 if i % 2 == 0 else 0.12), &"paint_white")
		if i % 2 == 0:
			_wall_label("s3_label_%02d" % i, Vector3(MOLE_W + 0.02, 1.3, z), PI * 0.5, "%d m\n%d u" % [8 * i, roundi(8.0 * i / U)])
	# the breach: lips painted, its width labelled on the runway's last metre.
	_paint_line("s4_breach_lip", Vector3(MOLE_W, TRACK_Y, MOLE_END), Vector3(MOLE_E - GANGWAY_W, TRACK_Y, MOLE_END), Vector3(0, 0, 0.35), &"paint_yellow")
	_floor_label("s4_breach_gap", Vector3((MOLE_W + MOLE_E - GANGWAY_W) * 0.5, TRACK_Y, MOLE_END + 1.6), 0.0, "%.1f m  ·  1 m down\n%d u" % [BREACH, roundi(BREACH / U)])
	# p / the breach reads late from eye height (its far lip sits just over the near one), so it is
	# framed: a hazard band across the main line 3 m before the lip, and a harbour-entrance light
	# post at each side, red on the runway's west corner, green on the roundhead's.
	var band_z := MOLE_END + 3.0
	for k: int in 12:
		var x0 := MOLE_W + 0.6 + k * 1.1
		_paint_line("s4_hazard_%02d" % k, Vector3(x0, TRACK_Y, band_z), Vector3(x0 + 0.55, TRACK_Y, band_z), Vector3(0, 0, -1.2), &"paint_yellow" if k % 2 == 0 else &"paint_dark")
	_solid("s4_light_red", _rect(MOLE_W, MOLE_W + 0.5, MOLE_END + 0.5, MOLE_END, TRACK_Y + 3.2), BASE, &"frame", -1, "wall")
	_solid("s4_light_green", _rect(MOLE_W, MOLE_W + 0.5, HEAD_N, HEAD_N - 0.5, HEAD_Y + 3.2), BASE, &"frame", -1, "wall")
	# the gangway: 3.5 m wide on the harbour side, 1 m down across the breach. a steel bridge,
	# 0.6 m deep at its low end, so nothing tunnels through it.
	_solid("s4_gangway", [Vector3(MOLE_E - GANGWAY_W, TRACK_Y, MOLE_END), Vector3(MOLE_E, TRACK_Y, MOLE_END), Vector3(MOLE_E, HEAD_Y, HEAD_N), Vector3(MOLE_E - GANGWAY_W, HEAD_Y, HEAD_N)], HEAD_Y - 0.6, &"steel_ramp", 4, "route")
	# a 1.1 m steel parapet on its open west side, 0.15 m thick, following the slope.
	var gx := MOLE_E - GANGWAY_W
	_solid("s4_gangway_parapet", [Vector3(gx, TRACK_Y + 1.1, MOLE_END), Vector3(gx + 0.15, TRACK_Y + 1.1, MOLE_END), Vector3(gx + 0.15, HEAD_Y + 1.1, HEAD_N), Vector3(gx, HEAD_Y + 1.1, HEAD_N)], HEAD_Y - 0.6, &"frame", -1, "wall")
	_paint_line("s4_gangway_w", Vector3(gx + 0.15, TRACK_Y, MOLE_END), Vector3(gx + 0.15, HEAD_Y, HEAD_N), Vector3(0.25, 0, 0), &"paint_yellow")

func _roundhead() -> void:
	# stage 4: the lighthouse roundhead, 1 m below the runway: a 28 m apron across the breach and
	# a half disc to seaward, the tower at its centre. both lines go round the tower to the finish
	# band on its seaward side.
	_deck("s4_head_nw", HEAD.x - HEAD_R, HEAD.x, HEAD_N, HEAD.z, HEAD_Y, &"pavers", 4)
	_deck("s4_head_ne", HEAD.x, HEAD.x + HEAD_R, HEAD_N, HEAD.z, HEAD_Y, &"pavers", 4)
	for q: int in 4:
		# a 45 degree sector, its arc in five points, from the east side round the seaward half.
		var top: Array = [Vector3(HEAD.x, HEAD_Y, HEAD.z)]
		for s: int in 5:
			var a := deg_to_rad(45.0 * q + 11.25 * s)
			top.append(Vector3(HEAD.x + cos(a) * HEAD_R, HEAD_Y, HEAD.z - sin(a) * HEAD_R))
		_solid("s4_head_s%d" % (q + 1), top, BASE, &"pavers", 4, "route")
	var ring: Array = []
	for s: int in 16:
		var a := TAU * s / 16.0
		ring.append(Vector3(HEAD.x + cos(a) * TOWER_R, HEAD_Y + 3.0, HEAD.z + sin(a) * TOWER_R))
	_solid("s4_tower", ring, BASE, &"plaster", -1, "wall")
	_paint_line("s4_head_lip", Vector3(HEAD.x - HEAD_R, HEAD_Y, HEAD_N), Vector3(MOLE_E - GANGWAY_W, HEAD_Y, HEAD_N), Vector3(0, 0, -0.35), &"paint_yellow")
	var band := FINISH_Z
	_finish_box = AABB(Vector3(HEAD.x - HEAD_R - 1.0, HEAD_Y - 0.2, band - 6.0), Vector3(2.0 * HEAD_R + 2.0, 5.0, 6.0))
	finish_position = Vector3(HEAD.x, HEAD_Y, band - 3.0)
	var half := sqrt(HEAD_R * HEAD_R - 64.0) - 0.4
	_paint_line("s4_finish_a", Vector3(HEAD.x - half, HEAD_Y, band), Vector3(HEAD.x + half, HEAD_Y, band), Vector3(0, 0, -0.45), &"paint_white")

# --- progress, finish and hints --------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their decks (radius 0 turns off the distance rule), so
	# a flight over a gap never collects the deck beyond it.
	spawn = _pose(Vector3(0, TRACK_Y, 4), 0.0)
	var mole_x := (MOLE_W + MOLE_E) * 0.5
	var quay_z := (QUAY_N + QUAY_S) * 0.5
	checkpoints = [
		{"pose": spawn, "title": "Gate"},
		{"pose": _pose(Vector3(-1, TRACK_Y, -22), 0.0), "title": "Box rows", "radius": 0.0},
		{"pose": _pose(_ring_point(BEND1, Vector3.RIGHT, 1.0, 16.5, 6.0), deg_to_rad(6.0)), "title": "Crane line", "radius": 0.0},
		{"pose": _pose(Vector3(mole_x, TRACK_Y, MOLE_START - 4.0), 0.0), "title": "Breakwater", "radius": 0.0},
		{"pose": _pose(Vector3(mole_x, TRACK_Y, MOLE_END + 28.0), 0.0), "title": "The breach", "radius": 0.0},
	]
	segment_bounds = [
		AABB(Vector3(-HALF - 1, -4, GATE_END), Vector3(2 * HALF + 2, 30, GATE_START - GATE_END)),
		AABB(Vector3(-HALF - 1, -4, YARD_END), Vector3(2 * HALF + 2, 30, GATE_END - YARD_END)),
		AABB(Vector3(MOLE_W - 1, -4, MOLE_START), Vector3(HALF + 1 - MOLE_W + 1, 30, YARD_END - MOLE_START)),
		AABB(Vector3(MOLE_W - 1, -4, MOLE_END + 32.0), Vector3(MOLE_E - MOLE_W + 2, 30, MOLE_START - MOLE_END - 32.0)),
		AABB(Vector3(HEAD.x - HEAD_R - 1, -4, HEAD.z - HEAD_R - 1), Vector3(2 * HEAD_R + 2, 30, MOLE_END + 32.0 - HEAD.z + HEAD_R + 1)),
	]
	water_audio_sources = [Vector3(0, WATER_Y, -100), Vector3(-60, WATER_Y, -180), Vector3(-90, WATER_Y, -260)]
	var b1 := func(r: float, a: float) -> Vector3: return _ring_point(BEND1, Vector3.RIGHT, 1.0, r, a)
	var b2 := func(r: float, a: float) -> Vector3: return _ring_point(BEND2, Vector3.BACK, -1.0, r, a)
	var front: Array = [Vector3(0, 0, 4), Vector3(-1, 0, GATE_END)]
	for b: Array in BLOCKS:
		front.append(Vector3((float(b[2]) + minf(float(b[3]), 1.0)) * 0.5, 0, float(b[0]) - float(b[1]) * 0.5))
	var quay: Array = [b1.call(16.0, 20.0), b1.call(16.0, 50.0), b1.call(16.0, 80.0), Vector3(-22, 0, -93.5), Vector3(-36, 0, -93.5), Vector3(-44, 0, -84.4), Vector3(-54, 0, -84.4),
		b2.call(20.0, 30.0), b2.call(20.0, 60.0)]
	routes = {
		"basic": front + quay + [Vector3(mole_x, 0, MOLE_START - 20.0), Vector3(MOLE_E - 1.75, 0, MOLE_END + 12.0), Vector3(MOLE_E - 1.75, HEAD_Y, HEAD_N - 1.0),
			Vector3(HEAD.x + 9.0, HEAD_Y, HEAD.z), Vector3(HEAD.x + 4.0, HEAD_Y, FINISH_Z - 3.0)],
		"advanced": front + quay + [Vector3(mole_x, 0, MOLE_START - 20.0), Vector3(MOLE_W + 4.0, 0, MOLE_END + 2.0), Vector3(MOLE_W + 4.0, HEAD_Y, HEAD_N - 2.0),
			Vector3(HEAD.x - 9.0, HEAD_Y, HEAD.z), Vector3(HEAD.x - 4.0, HEAD_Y, FINISH_Z - 3.0)],
	}
	routes["ordinary"] = routes["basic"]
	var lane := (LANE_X + HALF) * 0.5
	routes["alley_recovery"] = [Vector3(0, GROUND, -46), Vector3(lane, GROUND, -46), Vector3(lane, GROUND, GATE_END), Vector3(lane, TRACK_Y, RAMP_TOP), Vector3(0, TRACK_Y, RAMP_TOP - 4.0)]
	_declare_gaps()

func _declare_gaps() -> void:
	# p / intended entry speeds are design choices for the earned line, not measurements.
	var previous := GATE_END
	for i: int in BLOCKS.size():
		var b: Array = BLOCKS[i]
		var x := -3.0
		_gap("block_%d" % (i + 1), "box_rows", "basic", Vector3(x, 0, previous), Vector3(x, 0, float(b[0])), "alley_recovery", 0.0)
		previous = float(b[0]) - float(b[1])
	_gap("block_to_quay", "box_rows", "basic", Vector3(-3.0, 0, previous), Vector3(-3.0, 0, YARD_END), "alley_recovery", 0.0)
	var mole_x := (MOLE_W + MOLE_E - GANGWAY_W) * 0.5
	_gap("breach", "breach", "advanced", Vector3(mole_x, 0, MOLE_END), Vector3(mole_x, HEAD_Y, HEAD_N), "respawn: the breach checkpoint", 450.0)

func _gap(label: String, section: String, line: String, edge: Vector3, land: Vector3, recovery: String, intended_ups: float) -> void:
	# a declared jump, screened with the vanilla figures, feet centre to feet centre.
	var distance := Vector2(land.x - edge.x, land.z - edge.z).length()
	var drop := edge.y - land.y
	var t := flight_time(drop)
	var clear_mps := (distance + LANDING) / t
	var comfortable_mps := (distance + LANDING) / (t - EARLY)
	var run_mps := float(VANILLA.run_ups) * U
	var tier := "vanilla_run" if comfortable_mps <= run_mps else "vanilla_run_tight"
	if clear_mps > run_mps:
		for entry: Array in TIERS:
			if clear_mps / U <= float(entry[1]):
				tier = entry[0]
				break
	var intended := intended_ups if intended_ups > 0.0 else float(VANILLA.run_ups)
	jump_gaps.append({
		"label": label, "section": section, "line": line, "edge": edge, "land": land, "climb": 0.0,
		"kind": "ordinary" if line == "basic" else "earned",
		"speed": snappedf(intended * U, 0.01), "drained": snappedf(run_mps, 0.01),
		"width_m": snappedf(distance, 0.01), "width_u": roundi(distance / U), "drop_m": snappedf(drop, 0.01),
		"flight_s": snappedf(t, 0.001), "clear_ups": roundi(clear_mps / U), "comfortable_ups": roundi(comfortable_mps / U),
		"intended_ups": roundi(intended), "tier": tier, "recovery": recovery,
	})

## flight time of a vanilla jump that lands `drop` metres below its take-off.
static func flight_time(drop: float) -> float:
	var v0 := float(VANILLA.jump_ups) * U
	var g := float(VANILLA.gravity_ups) * U
	return (v0 + sqrt(v0 * v0 + 2.0 * g * drop)) / g

## the full course record: stages, gaps, recoveries, pieces, units.
func course_manifest() -> Dictionary:
	var gaps: Array = []
	for gap: Dictionary in jump_gaps:
		var copy := gap.duplicate()
		copy.edge = _v(gap.edge)
		copy.land = _v(gap.land)
		gaps.append(copy)
	var stages: Array = []
	for point: Dictionary in checkpoints:
		stages.append({"title": point.title, "pose": _v((point.pose as Transform3D).origin)})
	var longest := 0.0
	for piece: Dictionary in manifest:
		if piece.role == "route" or piece.role == "catch" or piece.role == "recovery":
			var lo := Vector2(INF, INF)
			var hi := -lo
			for p: Vector3 in piece.points:
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			longest = maxf(longest, maxf(hi.x - lo.x, hi.y - lo.y))
	return {
		"level_id": LEVEL_ID, "level_name": LEVEL_NAME, "level_version": LEVEL_VERSION, "variant": variant,
		"units": {"u_m": U}, "vanilla_model": VANILLA, "judging": {"landing_margin_m": LANDING, "early_press_s": EARLY, "hull_credit": "none: feet centre to feet centre; screening only"},
		"stages": stages, "finish": {"title": finish_title, "box": [_v(_finish_box.position), _v(_finish_box.size)]},
		"gaps": gaps, "recovery": "box-rows alleys walk back up the return ramp; a fall into the harbour respawns at the last checkpoint",
		"longest_walkable_piece_m": snappedf(longest, 0.001), "crouch_required": false,
		"geometry_hash": geometry_hash(), "pieces": manifest.size(), "containers": containers.size(),
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
	if feet.y < TRACK_Y - 0.6 and feet.y > GROUND - 0.5 and feet.z < GATE_END and feet.z > YARD_END and absf(feet.x) < HALF:
		return "In the yard alley: walk right to the lane, then back up the ramp at its head to the gate deck."
	match stage:
		0:
			return "Run out of the gate and jump the container rows. Esc opens stage practice."
		1:
			return "Hop roof to roof. A miss drops into the alley; the ramp on the right brings you back."
		2:
			return "Hold the strafe left round the bend, weave the two stacks, then right onto the breakwater. The quay edge is open water."
		3:
			return "Build speed down the breakwater: hop, A/D with the mouse. The crown wall marks are 16 m apart."
		4:
			return "Jump the breach at speed, or take the gangway on the left. Round the lighthouse to finish."
	return "Cross the line on the far side of the lighthouse."

func start_wheel() -> void:
	_running = true
	if _art != null:
		_art.call("finished", self, true)

func reset_state() -> void:
	_running = false
	if _art != null:
		_art.call("finished", self, false)

func _process(delta: float) -> void:
	if _art != null:
		_art.call("tick", self, delta)

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

func _rect(x0: float, x1: float, z0: float, z1: float, y: float) -> Array:
	return [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]

func _deck(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	return _solid(label, _rect(x0, x1, z0, z1, top), base, kind, stage, role)

func _deck_x(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int) -> StaticBody3D:
	return _deck(label, x0, x1, z0, z1, top, kind, stage)

func _container(label: String, x0: float, x1: float, z0: float, z1: float, bottom: float, tiers: int, colour: int, stage: int, role: String) -> StaticBody3D:
	# one container footprint, `tiers` high: a single collision prism over the drawn stack.
	var body := _solid(label, _rect(x0, x1, z0, z1, bottom + tiers * CH), bottom, &"container", stage, role, false)
	var along_x := absf(x1 - x0) > absf(z1 - z0)
	for t: int in tiers:
		containers.append({"name": label, "centre": Vector3((x0 + x1) * 0.5, bottom + t * CH, (z0 + z1) * 0.5), "along_x": along_x,
			"length": maxf(absf(x1 - x0), absf(z1 - z0)), "width": minf(absf(x1 - x0), absf(z1 - z0)), "tier": t, "colour": (colour + t * 2) % 6, "top": t == tiers - 1})
	return body

func _stack_run(label: String, along_x: bool, a0: float, a1: float, c0: float, c1: float, bottom: float, tiers: int, lengths: Array, colour: int) -> void:
	# a wall of container stacks from a0 to a1 along its axis, between c0 and c1 across it. the
	# spacing between boxes is even; every box is its own collision prism.
	var span := absf(a1 - a0)
	var total := 0.0
	for l: float in lengths:
		total += l
	var gap := (span - total) / maxf(1.0, lengths.size() - 1)
	assert(gap >= 0.0 and gap < 0.5, "breakwater: %s does not fit (%.3f)" % [label, gap])
	var sign := 1.0 if a1 > a0 else -1.0
	var at := a0
	for i: int in lengths.size():
		var next: float = at + sign * float(lengths[i])
		if along_x:
			_container("%s_%d" % [label, i + 1], at, next, c0, c1, bottom, tiers, (colour + i) % 6, -1, "wall")
		else:
			_container("%s_%d" % [label, i + 1], c0, c1, at, next, bottom, tiers, (colour + i) % 6, -1, "wall")
		at = next + sign * gap

func _ring_point(centre: Vector3, start: Vector3, turn: float, r: float, degrees: float, y: float = TRACK_Y) -> Vector3:
	# a point on a bend: `start` is the entry radius direction, turn +1 left, -1 right.
	var d := start.rotated(Vector3.UP, deg_to_rad(degrees) * turn)
	return Vector3(centre.x + d.x * r, y, centre.z + d.z * r)

func _ring_piece(label: String, centre: Vector3, start: Vector3, turn: float, r0: float, r1: float, a: float, b: float, y: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	return _solid(label, [_ring_point(centre, start, turn, r0, a, y), _ring_point(centre, start, turn, r1, a, y), _ring_point(centre, start, turn, r1, b, y), _ring_point(centre, start, turn, r0, b, y)], base, kind, stage, role)

func _ring_wall(label: String, centre: Vector3, start: Vector3, turn: float, r0: float, r1: float, a: float, b: float, height: float, kind: StringName) -> StaticBody3D:
	return _ring_piece(label, centre, start, turn, r0, r1, a, b, TRACK_Y + height, kind, -1, BASE, "wall")

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid", draw: bool = true) -> StaticBody3D:
	# a convex prism: a planar convex top polygon extruded straight down to `base`.
	assert(not has_node(NodePath(label)), "breakwater: duplicate piece " + label)
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
	if draw:
		prisms.append({"top": top.duplicate(), "base": base, "kind": kind})
	manifest.append({"name": label, "role": role, "stage": stage, "points": points, "shape": "prism", "kind": kind})
	return body

func _prism_visual(top: Array, base: float, kind: StringName) -> void:
	prisms.append({"top": top.duplicate(), "base": base, "kind": kind})

func _paint_x(label: String, x0: float, x1: float, z: float, width: float, y: float, kind: StringName) -> void:
	_paint_line(label, Vector3(x0, y, z), Vector3(x1, y, z), Vector3(0, 0, width), kind)

func _paint_line(label: String, a: Vector3, b: Vector3, inward: Vector3, kind: StringName) -> void:
	# a flush painted band along an edge, `inward` across the walking side: visual only.
	var lift := Vector3.UP * 0.004
	_prism_visual([a + lift, b + lift, b + inward + lift, a + inward + lift], minf(a.y, b.y) - 0.02, kind)
	markings.append({"name": label, "kind": "strip", "a": _v(a), "b": _v(b)})

func _gap_text(metres: float) -> String:
	return "%.1f m\n%d u" % [metres, roundi(metres / U)]

func _floor_label(label: String, at: Vector3, yaw: float, text: String) -> void:
	markings.append({"name": label, "kind": "floor", "at": at, "yaw": yaw, "text": text})

func _wall_label(label: String, at: Vector3, yaw: float, text: String) -> void:
	markings.append({"name": label, "kind": "wall", "at": at, "yaw": yaw, "text": text})

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
