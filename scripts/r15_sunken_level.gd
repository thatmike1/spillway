extends Node3D
## p / r15 Sunken Court: an original sunlit overgrown ruin, built as a checkpoint bhop course on the
## approved source movement. it publishes the r14 level interface (spawn, checkpoints, segment and
## kill bounds, finish, routes, jump gaps, manifest, geometry hash, route hints, level identity),
## so r15_main.gd hosts it as map "sunken-court". layout, numbers and limits: docs/r15/SUNKEN.md.
##
## course, in order (forward -z, a right-hand sweep round the aqueduct, then north and west):
##   gatehouse terrace under a great arch -> three falling steps (moss beds catch a short hop) ->
##   the balcony over the sunken court -> hops across six ruined arch pavilions standing in the
##   court's water garden, alternating heights -> the aqueduct head -> a curved aqueduct of stone
##   bridge spans round to the castellum (or, speed earned, four cistern towers across) ->
##   the aqueduct leg north to the cloister -> round the cloister walks (or, crouch taught, up onto
##   the fallen architrave across the sunken garth) -> rising steps to the hilltop sanctuary.
## recoveries: a missed step lands in a moss bed one step below the next deck; a fall into the
## court walks back up the court ramp to the balcony; a fall into the cistern walks up a garth
## ramp to the south walk; a fall from the aqueduct into the river is a respawn at the aqueduct
## head, the only use of the kill envelope.
##
## collision: every solid is a convex prism (planar top and bottom over the same outline). the
## library models' route surfaces, piers and arch haunches are authored from their measured
## vertices (docs/r15/SUNKEN.md), so every arch void stays open; no bounds box closes one. no
## walkable piece is longer than 32 m and decks reach 0.6 m or more under their tops (godot 4.7.2
## can miss casts into large single boxes, docs/r14/CONTACT-GUARD.md).

const Art := preload("res://scripts/r15_sunken_art.gd")

## the identity the main keys records on. bump LEVEL_VERSION with any change to geometry,
## progress or timing semantics.
const LEVEL_ID := "r15-sunken-court"
const LEVEL_NAME := "Sunken Court"
const LEVEL_VERSION := 1
const VARIANTS := ["sunken"]
const U := 0.0254
## the vanilla cs:go figures behind the gap screening (docs/r14/SOURCE-REFERENCE.md); driven runs
## decide, these only sort gaps into tiers.
const VANILLA := {"run_ups": 250.0, "jump_ups": 301.993, "gravity_ups": 800.0}
const LANDING := 0.5
const EARLY := 0.1
const TIERS := [["vanilla_strafe", 330.0], ["server", 520.0], ["fast", INF]]
const BASE := -12.0

## p / heights (m). the start is high; the route falls to the court rim, holds the aqueduct
## level, then climbs to the sanctuary.
const TERRACE_Y := 8.0
const STEP1_Y := 6.8
const STEP2_Y := 5.6
const BALCONY_Y := 4.4
const BED_DROP := 0.35
const COURT_Y := -2.0
const AQ_Y := 5.0
const CLOISTER_Y := 5.0
const CISTERN_Y := 2.5
const SANCTUARY_Y := 9.8
const RIVER_Y := -6.5
## p / anything below this is in the river: respawn. the court floor (-2) is above it.
const KILL_Y := -5.0
## p / retaining walls stand this far over the highest deck beside them: out of a jump's reach
## (jump then crouch lifts the feet 1.63 m).
const WALL_UP := 1.8

## stage 0: the gatehouse terrace and the falling steps, x in [-HALF0, HALF0].
const HALF0 := 8.0
const TERRACE_Z := [14.0, -14.0]
const STEPS := [
	# [bed near z, bed far z / deck near z, deck far z, deck y]
	[-14.0, -16.0, -26.0, STEP1_Y],
	[-26.0, -28.5, -38.5, STEP2_Y],
	[-38.5, -41.5, -52.0, BALCONY_Y],
]
const GATE := Vector3(0.0, TERRACE_Y, 2.0)
const GATE_SCALE := 8.0
## stage 1: the sunken court and its pavilions [x, z, top y]. 5.4 m arch pavilions.
const COURT_X := 22.0
const COURT_N := -52.0
const COURT_S := -99.5
const PAVILION_SCALE := 5.4
const PAVILIONS := [
	[0.0, -56.8, 5.0], [-2.5, -64.3, 4.2], [-4.5, -71.8, 5.0],
	[-2.5, -79.3, 4.2], [0.0, -86.8, 5.0], [0.5, -94.3, 4.4],
]
const RAMP_X := [-22.0, -18.0]
## stage 2: the aqueduct. head, arc, castellum, cistern towers, leg.
const HEAD := [-5.0, 5.0, -99.5, -108.5]
const ARC_C := Vector3(20.0, AQ_Y, -108.5)
const ARC_R := 20.0
const ARC_SEGMENTS := 12
const CASTELLUM := Vector3(40.0, AQ_Y, -108.5)
const CASTELLUM_INNER := 9.0
## the speed line's towers on a gentle curve from the head to the castellum, about 8 m apart
## centre to centre: one hop each at about 450 u/s, a near-maximum standing jump each at 250.
const CHORD_TOWERS := [Vector2(8.0, -105.5), Vector2(16.0, -108.0), Vector2(24.0, -109.0), Vector2(30.5, -109.0)]
const CHORD_INNER := 2.6
const AQ_FOOT := -4.0
## p / bridge-straight across the deck: 9x its 0.93 m source width (a 6.3 m walk between parapets).
const BRIDGE_WIDTH_SCALE := 9.0
const LEG_X := 40.0
const LEG_SEGMENTS := 7
## stage 3: the cloister: outer square, 5 m walks round a sunken garth.
const CLOISTER := [28.0, 56.0, -62.0, -34.0]
const WALK := 5.0
## p / the fallen architrave across the garth: 60 u over the walks. standing jumps reach 50 u but
## not 56 u; jump then crouch reaches 64 u (docs/r15/CROUCH.md, heights fixture).
## it lies diagonally, from the south lip by the leg (x range) to the north lip by the exit, so it
## is shorter than the walks round: about 29 m against 34 m.
const CAUSEWAY_S := [40.0, 44.0]
const CAUSEWAY_N := [47.0, 51.0]
const CAUSEWAY_UP := 60.0 * U
## p / the arcade lintel's underside over the walks: above a standing hop off the causeway (60 + 72 + 57 u).
const ARCADE_UP := 5.2
## stage 4: rising steps north out of the cloister's north-east corner, then west.
const RISE := 0.8
const SANCTUARY := [21.0, 37.0, -6.0, 12.0]
const FINISH_ARCH := Vector3(29.0, SANCTUARY_Y, 3.0)
const FINISH_SCALE := 7.5
const FINISH_X := 25.5

## measured source profiles (unscaled, from the imported meshes; docs/r15/SUNKEN.md).
const TOWER_MODEL := "kenney-castle/models/tower-square-arch.glb"
const BRIDGE_MODEL := "kenney-castle/models/bridge-straight.glb"
const PILLAR_MODEL := "kenney-castle/models/wall-pillar.glb"
const TOWER_HALF := 0.465
const TOWER_OPEN := 0.255
const TOWER_ROOF := 0.419
const TOWER_TOP := 1.01
const TOWER_CROWN := 0.802
const TOWER_ARCH := [[0.255, 0.547], [0.246, 0.613], [0.221, 0.674], [0.18, 0.727], [0.127, 0.768], [0.066, 0.793], [0.0, 0.802]]
const BRIDGE_HALF := 0.465
const BRIDGE_WALK := 0.269
const BRIDGE_CURB := 0.35
const BRIDGE_WALK_Y := 1.04
const BRIDGE_CURB_Y := 1.06
const BRIDGE_CRENEL_Y := 1.12
const BRIDGE_MERLON_Y := 1.176
const BRIDGE_SLAB_Y := 0.735
const BRIDGE_PIER := 0.349
const BRIDGE_PIER_Z := 0.39
const BRIDGE_MERLONS := [[-0.465, -0.349], [-0.116, 0.116], [0.349, 0.465]]
const BRIDGE_ARCH := [[0.349, 0.347], [0.337, 0.437], [0.302, 0.521], [0.247, 0.594], [0.174, 0.649], [0.09, 0.684], [0.0, 0.696]]
const PILLAR_HALF := 0.5
const PILLAR_TOP := 1.31

## set by a factory before the level enters the tree; build() reads it once (r14 convention).
static var next_variant: String = ""

var variant: String = "sunken"
## "kit": the sandstone shader and the models; "neutral": flat colours, models still drawn.
var material_mode: String = "kit"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var finish_title: String = "Sanctuary arch"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 4.0
## p / the court pool and the cistern are shallow water over stone: appearance only. no region
## is declared, so nothing about the movement changes in them.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var routes: Dictionary = {}
var jump_gaps: Array[Dictionary] = []
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-70, KILL_Y, -160), Vector3(170, 80, 200))
## every collision piece: name, world points (top ring then bottom ring), stage, role, kind.
var manifest: Array[Dictionary] = []
## painted marks and labels: visual only, not hashed.
var markings: Array[Dictionary] = []
## own prisms to draw: top ring, bottom ring, kind.
var prisms: Array[Dictionary] = []
## library models the course stands on or runs through: id, model, transform, the collision
## pieces authored for it. the art pass places them; the hash covers their pieces.
var models: Array[Dictionary] = []
## shallow water surfaces: [x0, x1, z0, z1, y].
var pools: Array = []

var _finish_box := AABB()
var _model_pieces: Array = []
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
		if arg == "--sunken-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "sunken: unknown variant " + variant)
	_gatehouse()
	_court()
	_aqueduct()
	_cloister()
	_sanctuary()
	_define_progress()
	_art = Art.new()
	_art.call("dress", self)

# --- stage 0: gatehouse and falling steps ---------------------------------------------------------

func _gatehouse() -> void:
	# the start terrace, 16 m wide, the gate arch 6 m ahead of the spawn. the flanks close the
	# terrace to the arch, so the first thing the run does is pass through it.
	_deck("s0_terrace_a", -HALF0, HALF0, TERRACE_Z[0], -0.0, TERRACE_Y, &"flag", 0)
	_deck("s0_terrace_b", -HALF0, HALF0, 0.0, TERRACE_Z[1], TERRACE_Y, &"flag", 0)
	_solid("s0_back_wall", _rect(-HALF0 - 1.0, HALF0 + 1.0, TERRACE_Z[0] + 1.0, TERRACE_Z[0], TERRACE_Y + 4.0), BASE, &"ashlar", -1, "wall")
	_tower("s0_gate", GATE, Vector3.ONE * GATE_SCALE, 0.0, -1, "wall")
	var out := TOWER_HALF * GATE_SCALE
	for side: float in [-1.0, 1.0]:
		# flank walls: one wall-pillar block from the gate to the terrace edge on each side.
		var x0 := side * out
		var x1 := side * (HALF0 + 1.0)
		var centre := Vector3((x0 + x1) * 0.5, TERRACE_Y, GATE.z)
		var width := absf(x1 - x0)
		_pillar("s0_flank_%s" % ("w" if side < 0.0 else "e"), centre, Vector3(width, 4.2 / PILLAR_TOP, 2.4), 0.0)
	# side walls along the steps, one height for the whole falling run: out of reach from every deck.
	var top := TERRACE_Y + WALL_UP
	for side: float in [-1.0, 1.0]:
		var name := "w" if side < 0.0 else "e"
		var x0 := side * HALF0
		var x1 := side * (HALF0 + 0.8)
		_solid("s0_side_%s_a" % name, _rect(minf(x0, x1), maxf(x0, x1), TERRACE_Z[0], -14.0, top), BASE, &"ashlar", -1, "wall")
		_solid("s0_side_%s_b" % name, _rect(minf(x0, x1), maxf(x0, x1), -14.0, -41.5, top), BASE, &"ashlar", -1, "wall")
	var previous_y := TERRACE_Y
	for i: int in STEPS.size():
		var s: Array = STEPS[i]
		var y: float = s[3]
		# a moss bed one step below the next deck: a short hop lands in it and walks up.
		_deck("s0_bed_%d" % (i + 1), -HALF0, HALF0, s[0], s[1], y - BED_DROP, &"moss", -1, BASE, "catch")
		if i < STEPS.size() - 1:
			_deck("s0_step_%d" % (i + 1), -HALF0, HALF0, s[1], s[2], y, &"flag", 0)
		_paint_x("s0_lip_%d" % (i + 1), -HALF0, HALF0, s[0], -0.3, previous_y, &"paint_lip")
		_floor_label("s0_gap_%d" % (i + 1), Vector3(0.0, previous_y, float(s[0]) + 1.2), 0.0, "%.1f m  ·  %.1f m down" % [float(s[0]) - float(s[1]), previous_y - y])
		previous_y = y

# --- stage 1: the sunken court --------------------------------------------------------------------

func _court() -> void:
	# the balcony over the court's north end, 44 m wide; the court 6.4 m below it, its floor a
	# shallow water garden. six ruined arch pavilions stand in the water at alternating heights.
	var near: float = (STEPS[2] as Array)[1]
	_deck("s1_balcony_w", -COURT_X, 0.0, near, COURT_N, BALCONY_Y, &"flag", 1)
	_deck("s1_balcony_e", 0.0, COURT_X, near, COURT_N, BALCONY_Y, &"flag", 1)
	_solid("s1_balcony_back_w", _rect(-COURT_X - 2.0, -HALF0 - 0.8, near + 0.8, near, TERRACE_Y + WALL_UP), BASE, &"ashlar", -1, "wall")
	_solid("s1_balcony_back_e", _rect(HALF0 + 0.8, COURT_X + 2.0, near + 0.8, near, TERRACE_Y + WALL_UP), BASE, &"ashlar", -1, "wall")
	var mid := (COURT_N + COURT_S) * 0.5
	for x: Array in [[-COURT_X, 0.0, "w"], [0.0, COURT_X, "e"]]:
		_deck("s1_floor_%s_n" % x[2], x[0], x[1], COURT_N, mid, COURT_Y, &"pool_floor", -1, BASE, "catch")
		_deck("s1_floor_%s_s" % x[2], x[0], x[1], mid, COURT_S, COURT_Y, &"pool_floor", -1, BASE, "catch")
	pools.append([-COURT_X, COURT_X, COURT_N, COURT_S, COURT_Y + 0.06])
	# court walls, out of reach from the balcony and the head.
	var wall_top := BALCONY_Y + 2.4
	for side: float in [-1.0, 1.0]:
		var name := "w" if side < 0.0 else "e"
		var x0 := side * COURT_X
		var x1 := side * (COURT_X + 2.0)
		_solid("s1_wall_%s_a" % name, _rect(minf(x0, x1), maxf(x0, x1), COURT_N, -75.75, wall_top), BASE, &"ashlar", -1, "wall")
		_solid("s1_wall_%s_b" % name, _rect(minf(x0, x1), maxf(x0, x1), -75.75, COURT_S - 2.0, wall_top), BASE, &"ashlar", -1, "wall")
		_solid("s1_wall_%s_balcony" % name, _rect(minf(x0, x1), maxf(x0, x1), near, COURT_N, wall_top), BASE, &"ashlar", -1, "wall")
	_solid("s1_wall_s_w", _rect(-COURT_X, float(HEAD[0]), COURT_S, COURT_S - 2.0, wall_top), BASE, &"ashlar", -1, "wall")
	_solid("s1_wall_s_e", _rect(float(HEAD[1]), COURT_X, COURT_S, COURT_S - 2.0, wall_top), BASE, &"ashlar", -1, "wall")
	# the court ramp up the west wall to the balcony: the walk back from any fall.
	var r0: float = RAMP_X[0]
	var r1: float = RAMP_X[1]
	_solid("s1_ramp_a", [Vector3(r0, COURT_Y, -95.5), Vector3(r1, COURT_Y, -95.5), Vector3(r1, 1.2, -75.5), Vector3(r0, 1.2, -75.5)], BASE, &"stair", -1, "recovery")
	_solid("s1_ramp_b", [Vector3(r0, 1.2, -75.5), Vector3(r1, 1.2, -75.5), Vector3(r1, BALCONY_Y, -55.5), Vector3(r0, BALCONY_Y, -55.5)], BASE, &"stair", -1, "recovery")
	_deck("s1_ramp_top", r0, r1, -55.5, COURT_N, BALCONY_Y, &"stair", -1, BASE, "recovery")
	_paint_line("s1_ramp_foot", Vector3(r0, COURT_Y, -95.5), Vector3(r1, COURT_Y, -95.5), Vector3(0, 0, 0.3), &"paint_lip")
	_paint_x("s1_balcony_lip", -COURT_X, COURT_X, COURT_N, 0.3, BALCONY_Y, &"paint_lip")
	for i: int in PAVILIONS.size():
		var p: Array = PAVILIONS[i]
		var top: float = p[2]
		var sy := (top - COURT_Y) / TOWER_TOP
		_tower("s1_pavilion_%d" % (i + 1), Vector3(p[0], COURT_Y, p[1]), Vector3(PAVILION_SCALE, sy, PAVILION_SCALE), 0.0, 1, "route")
	# broken columns standing in the pool, reachable from the floor: simple octagonal collision.
	for c: Array in [[-14.0, -60.0, 3.2], [13.0, -66.0, 2.6], [-15.5, -83.0, 2.2], [12.0, -90.0, 3.6], [9.0, -58.0, 1.4], [-11.0, -97.0, 1.8]]:
		_column("s1_column_%d" % markings.size(), Vector3(c[0], COURT_Y, c[1]), 0.9, float(c[2]))

# --- stage 2: the aqueduct ------------------------------------------------------------------------

func _aqueduct() -> void:
	# the head: a broad pier deck on the court's south wall, over the river.
	_deck("s2_head", HEAD[0], HEAD[1], HEAD[2], HEAD[3], AQ_Y, &"flag", 2)
	_paint_x("s2_head_lip_n", HEAD[0], HEAD[1], HEAD[2], -0.3, AQ_Y, &"paint_lip")
	# the arc: twelve bridge spans round the river bend, a 6.3 m walk between parapets. each span is
	# the bridge model scaled to its chord; outer joints get a filler wedge so the walk is closed.
	var sy := (AQ_Y - AQ_FOOT) / BRIDGE_WALK_Y
	var step := _arc_end() / ARC_SEGMENTS
	var points: Array[Vector3] = []
	for k: int in ARC_SEGMENTS + 1:
		points.append(_arc_point(step * k, ARC_R))
	for k: int in ARC_SEGMENTS:
		_bridge("s2_arc_%02d" % (k + 1), points[k], points[k + 1], sy, 2)
	for k: int in range(1, ARC_SEGMENTS):
		_wedge("s2_arc_joint_%02d" % k, points[k - 1], points[k], points[k + 1], sy)
	# the castellum: a big arch tower whose roof is the arc's landing and the leg's start.
	var cs := CASTELLUM_INNER / (2.0 * TOWER_ROOF)
	var foot := Vector3(CASTELLUM.x, AQ_FOOT, CASTELLUM.z)
	_tower("s2_castellum", foot, Vector3(cs, (AQ_Y - AQ_FOOT) / TOWER_TOP, cs), 0.0, 2, "route")
	# the cistern towers across the bend: the speed-earned chord, slim piers rising from the river.
	var ts := CHORD_INNER / (2.0 * TOWER_ROOF)
	for i: int in CHORD_TOWERS.size():
		var c: Vector2 = CHORD_TOWERS[i]
		_tower("s2_cistern_%d" % (i + 1), Vector3(c.x, AQ_FOOT, c.y), Vector3(ts, (AQ_Y - AQ_FOOT) / TOWER_TOP, ts), 0.0, 2, "route")
	_paint_line("s2_chord_lip", Vector3(HEAD[1], AQ_Y, -101.5), Vector3(HEAD[1], AQ_Y, -106.5), Vector3(-0.3, 0, 0), &"paint_lip")
	_floor_label("s2_chord_gap", Vector3(float(HEAD[1]) - 1.4, AQ_Y, -104.0), -PI * 0.5, "four towers  ·  speed line\nhop on landing, carry 450")
	# the leg: seven spans north to the cloister's south walk.
	var z0 := CASTELLUM.z + CASTELLUM_INNER * 0.5
	var z1 := float(CLOISTER[2])
	for k: int in LEG_SEGMENTS:
		var a := Vector3(LEG_X, AQ_Y, z0 + (z1 - z0) * k / LEG_SEGMENTS)
		var b := Vector3(LEG_X, AQ_Y, z0 + (z1 - z0) * (k + 1) / LEG_SEGMENTS)
		_bridge("s2_leg_%d" % (k + 1), a, b, sy, 2)
	water_audio_sources = [Vector3(20, RIVER_Y, -125), Vector3(46, RIVER_Y, -84), Vector3(-10, COURT_Y, -76)]

func _arc_end() -> float:
	# the arc runs from the head (angle 0, heading -z) round the south to where it meets the
	# castellum's south face.
	var s := (CASTELLUM_INNER * 0.5) / ARC_R
	return PI - asin(s)

func _arc_point(phi: float, r: float, y: float = AQ_Y) -> Vector3:
	return Vector3(ARC_C.x - cos(phi) * r, y, ARC_C.z - sin(phi) * r)

# --- stage 3: the cloister ------------------------------------------------------------------------

func _cloister() -> void:
	var x0: float = CLOISTER[0]
	var x1: float = CLOISTER[1]
	var zs: float = CLOISTER[2]
	var zn: float = CLOISTER[3]
	var gx0 := x0 + WALK
	var gx1 := x1 - WALK
	var gzs := zs + WALK
	var gzn := zn - WALK
	_deck("s3_walk_s", x0, x1, zs, gzs, CLOISTER_Y, &"flag", 3)
	_deck("s3_walk_n", x0, x1, gzn, zn, CLOISTER_Y, &"flag", 3)
	_deck("s3_walk_w", x0, gx0, gzs, gzn, CLOISTER_Y, &"flag", 3)
	_deck("s3_walk_e", gx1, x1, gzs, gzn, CLOISTER_Y, &"flag", 3)
	# the outer walls: wall-pillar blocks, 4.5 m over the walks, with the leg's entry on the south
	# and the exit at the north-east corner.
	var h := 4.5 / PILLAR_TOP
	_pillar_run("s3_wall_s_w", Vector3(x0 - 1.0, CLOISTER_Y, zs - 0.5), Vector3(LEG_X - 3.5, CLOISTER_Y, zs - 0.5), h)
	_pillar_run("s3_wall_s_e", Vector3(LEG_X + 3.5, CLOISTER_Y, zs - 0.5), Vector3(x1 + 1.0, CLOISTER_Y, zs - 0.5), h)
	_pillar_run("s3_wall_w", Vector3(x0 - 0.5, CLOISTER_Y, zs), Vector3(x0 - 0.5, CLOISTER_Y, zn + 1.0), h)
	_pillar_run("s3_wall_e", Vector3(x1 + 0.5, CLOISTER_Y, zs), Vector3(x1 + 0.5, CLOISTER_Y, zn + 1.0), h)
	_pillar_run("s3_wall_n", Vector3(x0, CLOISTER_Y, zn + 0.5), Vector3(gx1, CLOISTER_Y, zn + 0.5), h)
	# the garth is a sunken cistern, 2.5 m below the walks: shallow water over stone, with a ramp
	# in each pool back up to the south walk.
	# the pools either side of the diagonal architrave: a broad west pool and an east triangle.
	var c0: float = CAUSEWAY_S[0]
	var c1: float = CAUSEWAY_S[1]
	var n0: float = CAUSEWAY_N[0]
	var n1: float = CAUSEWAY_N[1]
	_solid("s3_cistern_w", [Vector3(gx0, CISTERN_Y, gzs), Vector3(c0, CISTERN_Y, gzs), Vector3(n0, CISTERN_Y, gzn), Vector3(gx0, CISTERN_Y, gzn)], BASE, &"pool_floor", -1, "catch")
	_solid("s3_cistern_e", [Vector3(c1, CISTERN_Y, gzs), Vector3(gx1, CISTERN_Y, gzs), Vector3(gx1, CISTERN_Y, gzn)], BASE, &"pool_floor", -1, "catch")
	pools.append([gx0, gx1, gzs, gzn, CISTERN_Y + 0.06])
	_solid("s3_cistern_ramp_w", [Vector3(gx0, CISTERN_Y, gzn - 3.0), Vector3(gx0 + 3.0, CISTERN_Y, gzn - 3.0), Vector3(gx0 + 3.0, CLOISTER_Y, gzs), Vector3(gx0, CLOISTER_Y, gzs)], BASE, &"stair", -1, "recovery")
	# the east ramp is shorter: the triangle narrows to the north.
	_solid("s3_cistern_ramp_e", [Vector3(gx1 - 2.2, CISTERN_Y, gzs + 11.0), Vector3(gx1, CISTERN_Y, gzs + 11.0), Vector3(gx1, CLOISTER_Y, gzs), Vector3(gx1 - 2.2, CLOISTER_Y, gzs)], BASE, &"stair", -1, "recovery")
	# the fallen architrave: a causeway of fallen entablature across the cistern, 1.52 m (60 u) over
	# the walks. a standing jump tops out near 1.42 m (56 u) and falls back; jump then crouch lifts
	# the feet 9 u more and lands on it. open sky over all of it: stand up anywhere.
	var top := CLOISTER_Y + CAUSEWAY_UP
	var mid := (gzs + gzn) * 0.5
	var m0 := (c0 + n0) * 0.5
	var m1 := (c1 + n1) * 0.5
	_solid("s3_causeway_s", [Vector3(c0, top, gzs), Vector3(c1, top, gzs), Vector3(m1, top, mid), Vector3(m0, top, mid)], BASE, &"architrave", 3, "route")
	_solid("s3_causeway_n", [Vector3(m0, top, mid), Vector3(m1, top, mid), Vector3(n1, top, gzn), Vector3(n0, top, gzn)], BASE, &"architrave", 3, "route")
	_paint_x("s3_causeway_lip", c0, c1, gzs, 0.35, top, &"paint_duck")
	# the leg brings the runner back toward +z, so the cloister signs read facing +z (yaw pi).
	_floor_label("s3_causeway_sign", Vector3((c0 + c1) * 0.5, CLOISTER_Y, gzs - 2.4), PI, "FALLEN ARCHITRAVE  ·  %.2f m up\njump, then crouch (Ctrl or C) in the air" % CAUSEWAY_UP)
	_floor_label("s3_walks_sign", Vector3(LEG_X + 8.0, CLOISTER_Y, zs + 0.9), PI, "walks: left and round")
	# the arcade along the garth's north lip, high enough that no hop off the causeway reaches it.
	_arcade(gx0, gzs, gzn, c0, n0)

func _arcade(gx0: float, gzs: float, gzn: float, c0: float, n0: float) -> void:
	var pier := 0.8
	var top := CLOISTER_Y + ARCADE_UP
	var lintel := 0.5
	# p / the north arcade stands in the west pool along the garth's north lip, its lintel on three
	# piers, ending short of the causeway; the south lip keeps one broken pier. the ramp tops and
	# the causeway stay clear.
	var east := n0 - 1.4
	var spots: Array = [Vector3(gx0 + 0.4, 0, gzn - 0.4), Vector3((gx0 + east) * 0.5, 0, gzn - 0.4), Vector3(east, 0, gzn - 0.4), Vector3((gx0 + c0) * 0.5, 0, gzs + 0.4)]
	for i: int in spots.size():
		var s: Vector3 = spots[i]
		var h := top if i < 3 else CLOISTER_Y + 1.9
		_solid("s3_pier_%02d" % (i + 1), _rect(s.x - pier * 0.5, s.x + pier * 0.5, s.z + pier * 0.5, s.z - pier * 0.5, h), CISTERN_Y, &"ashlar", -1, "wall")
	_slab("s3_lintel_n", _rect(gx0, east + pier * 0.5, gzn - 0.8, gzn, top + lintel), [top, top, top, top], &"ashlar", -1, "wall")

# --- stage 4: rising steps and the sanctuary ------------------------------------------------------

func _sanctuary() -> void:
	# north out of the cloister's north-east corner, five steps each 0.8 m up, a corner, one step
	# west and the sanctuary. a short hop lands in a moss bed one step down and walks back up.
	var x0 := float(CLOISTER[1]) - WALK - 1.0
	var x1 := float(CLOISTER[1]) + 1.0
	var zn: float = CLOISTER[3]
	var rises: Array = [
		# [label, x0, x1, z0, z1, y]
		["s4_rise_0", x0, x1, zn + 1.0, zn + 6.0, CLOISTER_Y],
		["s4_rise_1", x0, x1, zn + 8.0, zn + 14.0, CLOISTER_Y + RISE],
		["s4_rise_2", x0, x1, zn + 16.0, zn + 22.0, CLOISTER_Y + 2.0 * RISE],
		["s4_rise_3", x0, x1, zn + 24.0, zn + 30.0, CLOISTER_Y + 3.0 * RISE],
		["s4_rise_4", x0, x1 + 1.0, zn + 32.0, zn + 41.0, CLOISTER_Y + 4.0 * RISE],
	]
	for i: int in rises.size():
		var r: Array = rises[i]
		_deck(r[0], r[1], r[2], r[3], r[4], r[5], &"flag", 4)
		if i > 0:
			var prev: Array = rises[i - 1]
			_deck("s4_bed_%d" % i, r[1], r[2], prev[4], r[3], float(prev[5]) - BED_DROP, &"moss", -1, BASE, "catch")
			_paint_x("s4_lip_%d" % i, r[1], r[2], r[3], -0.3, r[5], &"paint_lip")
	# the gate in the cloister's north wall onto the first step.
	_deck("s4_gate", x0 + 1.0, x1 - 1.0, zn, zn + 1.0, CLOISTER_Y, &"flag", 4)
	var r4: Array = rises[4]
	var y5 := CLOISTER_Y + 5.0 * RISE
	var x5a := float(r4[1]) - 2.0
	_deck("s4_bed_5", x5a, r4[1], r4[3], r4[4], float(r4[5]) - BED_DROP, &"moss", -1, BASE, "catch")
	_deck("s4_rise_5", x5a - 9.0, x5a, r4[3], r4[4], y5, &"flag", 4)
	_paint_line("s4_lip_5", Vector3(x5a, y5, r4[3]), Vector3(x5a, y5, r4[4]), Vector3(-0.3, 0, 0), &"paint_lip")
	var sx1: float = SANCTUARY[1]
	_deck("s4_bed_6", sx1, x5a - 9.0, r4[3], r4[4], y5 - BED_DROP, &"moss", -1, BASE, "catch")
	_deck("s4_sanctuary_e", (SANCTUARY[0] + sx1) * 0.5, sx1, SANCTUARY[2], SANCTUARY[3], SANCTUARY_Y, &"flag", 4)
	_deck("s4_sanctuary_w", SANCTUARY[0], (SANCTUARY[0] + sx1) * 0.5, SANCTUARY[2], SANCTUARY[3], SANCTUARY_Y, &"flag", 4)
	_paint_line("s4_lip_6", Vector3(sx1, SANCTUARY_Y, r4[3]), Vector3(sx1, SANCTUARY_Y, r4[4]), Vector3(-0.3, 0, 0), &"paint_lip")
	# retaining walls beside the climb, out of reach from the highest deck beside them.
	var climb_top := CLOISTER_Y + 3.0 * RISE + WALL_UP
	_solid("s4_side_w", _rect(x0 - 0.8, x0, zn + 1.0, float(r4[3]), climb_top), BASE, &"ashlar", -1, "wall")
	_solid("s4_side_e", _rect(x1, x1 + 0.8, zn + 1.0, float(r4[3]), climb_top), BASE, &"ashlar", -1, "wall")
	var high := SANCTUARY_Y + WALL_UP
	_solid("s4_corner_n", _rect(SANCTUARY[1], float(r4[2]) + 0.8, r4[4], float(r4[4]) + 0.8, high), BASE, &"ashlar", -1, "wall")
	_solid("s4_corner_e", _rect(r4[2], float(r4[2]) + 0.8, r4[3], r4[4], high), BASE, &"ashlar", -1, "wall")
	_solid("s4_corner_s", _rect(SANCTUARY[1], x0 - 0.8, float(r4[3]) - 0.8, r4[3], high), BASE, &"ashlar", -1, "wall")
	# the sanctuary's parapet on its west, north and south edges, out of reach.
	var sx0: float = SANCTUARY[0]
	_solid("s4_parapet_w", _rect(sx0 - 0.8, sx0, SANCTUARY[2] - 0.8, SANCTUARY[3] + 0.8, high), BASE, &"ashlar", -1, "wall")
	_solid("s4_parapet_n", _rect(sx0, sx1, SANCTUARY[3], SANCTUARY[3] + 0.8, high), BASE, &"ashlar", -1, "wall")
	_solid("s4_parapet_s", _rect(sx0, sx1, SANCTUARY[2] - 0.8, SANCTUARY[2], high), BASE, &"ashlar", -1, "wall")
	_solid("s4_parapet_ne", _rect(sx1, sx1 + 0.8, r4[4], SANCTUARY[3] + 0.8, high), BASE, &"ashlar", -1, "wall")
	_solid("s4_parapet_se", _rect(sx1, sx1 + 0.8, SANCTUARY[2] - 0.8, r4[3], high), BASE, &"ashlar", -1, "wall")
	# the finish arch: a tall arch tower, the run passes through its opening (or round it) to the
	# finish band on the sanctuary's west end.
	_tower("s4_finish_arch", FINISH_ARCH, Vector3.ONE * FINISH_SCALE, 0.0, -1, "wall")
	_finish_box = AABB(Vector3(sx0, SANCTUARY_Y - 0.2, SANCTUARY[2]), Vector3(FINISH_X - sx0, 5.0, SANCTUARY[3] - SANCTUARY[2]))
	finish_position = Vector3((sx0 + FINISH_X) * 0.5, SANCTUARY_Y, FINISH_ARCH.z)
	_paint_line("s4_finish", Vector3(FINISH_X, SANCTUARY_Y, SANCTUARY[2]), Vector3(FINISH_X, SANCTUARY_Y, SANCTUARY[3]), Vector3(-0.45, 0, 0), &"paint_finish")

# --- progress, finish and hints -------------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their decks (radius 0), so no flight collects one.
	spawn = _pose(Vector3(0, TERRACE_Y, 10.0), 0.0)
	var near: float = (STEPS[2] as Array)[1]
	checkpoints = [
		{"pose": spawn, "title": "Gatehouse"},
		{"pose": _pose(Vector3(0, BALCONY_Y, near - 3.0), 0.0), "title": "Sunken court", "radius": 0.0},
		{"pose": _pose(Vector3(0, AQ_Y, -102.5), 0.0), "title": "Aqueduct", "radius": 0.0},
		{"pose": _pose(Vector3(LEG_X, CLOISTER_Y, float(CLOISTER[2]) + 2.5), -PI * 0.5), "title": "Cloister", "radius": 0.0},
		{"pose": _pose(Vector3(float(CLOISTER[1]) - 2.5, CLOISTER_Y, float(CLOISTER[3]) + 3.0), 0.0), "title": "Sanctuary steps", "radius": 0.0},
	]
	# the r14 convention: 0 is the spawn; facing -z with yaw 0, +x with -PI/2 and so on.
	segment_bounds = [
		AABB(Vector3(-HALF0 - 1, 0, near), Vector3(2 * HALF0 + 2, 30, TERRACE_Z[0] + 1 - near)),
		AABB(Vector3(-COURT_X - 2, -4, COURT_S), Vector3(2 * COURT_X + 4, 30, near - COURT_S)),
		AABB(Vector3(-6, -6, -130), Vector3(54, 30, float(CLOISTER[2]) + 130)),
		AABB(Vector3(CLOISTER[0] - 1, -4, CLOISTER[2]), Vector3(float(CLOISTER[1]) - float(CLOISTER[0]) + 2, 30, float(CLOISTER[3]) - float(CLOISTER[2]))),
		AABB(Vector3(SANCTUARY[0] - 1, 0, CLOISTER[3]), Vector3(float(CLOISTER[1]) + 3 - float(SANCTUARY[0]), 30, float(SANCTUARY[3]) + 1 - float(CLOISTER[3]))),
	]
	var front: Array = [Vector3(0, TERRACE_Y, 10), Vector3(0, TERRACE_Y, -10), Vector3(0, STEP1_Y, -21), Vector3(0, STEP2_Y, -33.5), Vector3(0, BALCONY_Y, -47)]
	for p: Array in PAVILIONS:
		front.append(Vector3(p[0], p[2], p[1]))
	front.append(Vector3(0, AQ_Y, -104))
	var arc: Array = []
	for k: int in range(1, 6):
		arc.append(_arc_point(_arc_end() * k / 6.0, ARC_R))
	var castle := [Vector3(CASTELLUM.x, AQ_Y, CASTELLUM.z), Vector3(LEG_X, AQ_Y, -82.0)]
	var walks := [Vector3(LEG_X, CLOISTER_Y, -59.5), Vector3(53.5, CLOISTER_Y, -59.5), Vector3(53.5, CLOISTER_Y, -36.5)]
	var causeway := [Vector3(LEG_X, CLOISTER_Y, -59.5), Vector3(42.0, CLOISTER_Y, -58.5), Vector3(45.5, CLOISTER_Y + CAUSEWAY_UP, -48.0), Vector3(49.0, CLOISTER_Y, -37.0), Vector3(53.5, CLOISTER_Y, -34.5)]
	var climb: Array = [Vector3(53.5, CLOISTER_Y, -31.0)]
	for i: int in range(1, 5):
		climb.append(Vector3(53.5, CLOISTER_Y + RISE * i, float(CLOISTER[3]) + 11.0 + 8.0 * (i - 1)))
	climb += [Vector3(42.0, CLOISTER_Y + 5.0 * RISE, 2.5), Vector3(32.0, SANCTUARY_Y, 3.0), Vector3(23.0, SANCTUARY_Y, 3.0)]
	var chord: Array = []
	for c: Vector2 in CHORD_TOWERS:
		chord.append(Vector3(c.x, AQ_Y, c.y))
	chord.append(Vector3(CASTELLUM.x, AQ_Y, CASTELLUM.z))
	routes = {
		"basic": front + arc + castle + walks + climb,
		"advanced": front + chord + [Vector3(LEG_X, AQ_Y, -82.0)] + causeway + climb,
	}
	routes["ordinary"] = routes["basic"]
	routes["earned"] = front + chord + castle.slice(1) + walks + climb
	routes["causeway"] = front + arc + castle + causeway + climb
	routes["court_recovery"] = [Vector3(-10, COURT_Y, -80), Vector3(-20, COURT_Y, -94), Vector3(-20, 1.2, -75.5), Vector3(-20, BALCONY_Y, -54), Vector3(0, BALCONY_Y, -47)]
	routes["cistern_recovery"] = [Vector3(36, CISTERN_Y, -50), Vector3(34.5, CISTERN_Y, -40), Vector3(34.5, CLOISTER_Y, -57), Vector3(40, CLOISTER_Y, -59.5)]
	_declare_gaps()

func _declare_gaps() -> void:
	# p / intended entry speeds are design choices for the earned line, not measurements.
	var previous := float(TERRACE_Z[1])
	var y := TERRACE_Y
	for i: int in STEPS.size():
		var s: Array = STEPS[i]
		_gap("step_%d" % (i + 1), "falling_steps", "basic", Vector3(0, y, previous), Vector3(0, s[3], s[1]), "moss bed: step up onto the next deck", 0.0)
		previous = s[2]
		y = s[3]
	var last := Vector3(0, BALCONY_Y, (STEPS[2] as Array)[2])
	var inner := TOWER_ROOF * PAVILION_SCALE
	for i: int in PAVILIONS.size():
		var p: Array = PAVILIONS[i]
		var land := Vector3(p[0], p[2], float(p[1]) + inner)
		_gap("pavilion_%d" % (i + 1), "court", "basic", last, land, "court floor: the west ramp back to the balcony", 0.0)
		last = Vector3(p[0], p[2], float(p[1]) - inner)
	_gap("court_to_head", "court", "basic", last, Vector3(last.x, AQ_Y, HEAD[2]), "court floor: the west ramp back to the balcony", 0.0)
	# the chord, centre to centre: chained hops take off where they land.
	var from := Vector3(1.0, AQ_Y, -101.5)
	for i: int in CHORD_TOWERS.size() + 1:
		var c: Vector2 = CHORD_TOWERS[i] if i < CHORD_TOWERS.size() else Vector2(CASTELLUM.x - CASTELLUM_INNER * 0.5 + 1.0, CASTELLUM.z)
		var land := Vector3(c.x, AQ_Y, c.y)
		_gap("chord_%d" % (i + 1), "aqueduct", "advanced", from, land, "river: respawn at the aqueduct head", 450.0)
		from = land
	var zn: float = CLOISTER[3]
	for i: int in range(1, 5):
		_gap("rise_%d" % i, "sanctuary", "basic", Vector3(53.5, CLOISTER_Y + RISE * (i - 1), zn + 8.0 * i - 2.0), Vector3(53.5, CLOISTER_Y + RISE * i, zn + 8.0 * i), "moss bed: step up and hop again", 0.0)

func _gap(label: String, section: String, line: String, edge: Vector3, land: Vector3, recovery: String, intended_ups: float) -> void:
	# a declared jump, screened with the vanilla figures, feet centre to feet centre.
	var distance := Vector2(land.x - edge.x, land.z - edge.z).length()
	var drop := edge.y - land.y
	var t := flight_time(drop)
	var clear_mps := (distance + LANDING) / t
	var comfortable_mps := (distance + LANDING) / maxf(t - EARLY, 0.05)
	var run_mps := float(VANILLA.run_ups) * U
	var tier := "vanilla_run" if comfortable_mps <= run_mps else "vanilla_run_tight"
	if clear_mps > run_mps:
		for entry: Array in TIERS:
			if clear_mps / U <= float(entry[1]):
				tier = entry[0]
				break
	var intended := intended_ups if intended_ups > 0.0 else float(VANILLA.run_ups)
	jump_gaps.append({
		"label": label, "section": section, "line": line, "edge": edge, "land": land, "climb": maxf(0.0, -drop),
		"kind": "ordinary" if line == "basic" else "earned",
		"speed": snappedf(intended * U, 0.01), "drained": snappedf(run_mps, 0.01),
		"width_m": snappedf(distance, 0.01), "width_u": roundi(distance / U), "drop_m": snappedf(drop, 0.01),
		"flight_s": snappedf(t, 0.001), "clear_ups": roundi(clear_mps / U), "comfortable_ups": roundi(comfortable_mps / U),
		"intended_ups": roundi(intended), "tier": tier, "recovery": recovery,
	})

## flight time of a vanilla jump that lands `drop` metres below its take-off (negative: a climb).
static func flight_time(drop: float) -> float:
	var v0 := float(VANILLA.jump_ups) * U
	var g := float(VANILLA.gravity_ups) * U
	return (v0 + sqrt(maxf(0.0, v0 * v0 + 2.0 * g * drop))) / g

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
		if piece.role in ["route", "catch", "recovery"]:
			longest = maxf(longest, piece_extent(piece))
	var placed: Array = []
	for m: Dictionary in models:
		var xf: Transform3D = m.xf
		placed.append({"id": m.id, "model": m.model, "origin": _v(xf.origin), "scale": _v(xf.basis.get_scale()), "role": m.role})
	return {
		"level_id": LEVEL_ID, "level_name": LEVEL_NAME, "level_version": LEVEL_VERSION, "variant": variant,
		"units": {"u_m": U}, "vanilla_model": VANILLA, "judging": {"landing_margin_m": LANDING, "early_press_s": EARLY, "hull_credit": "none: feet centre to feet centre; screening only"},
		"stages": stages, "finish": {"title": finish_title, "box": [_v(_finish_box.position), _v(_finish_box.size)]},
		"gaps": gaps, "recovery": "moss beds step back up; the court ramp returns to the balcony; the cistern ramps return to the south walk; the river respawns at the aqueduct head",
		"crouch": {"required": false, "optional": "the fallen architrave across the cloister garth: %.3f m (60 u) up; standing jumps reach 50 u not 56 u, jump then crouch reaches 64 u" % CAUSEWAY_UP},
		"water": "appearance only; no water region, no traction change",
		"longest_walkable_piece_m": snappedf(longest, 0.001), "geometry_hash": geometry_hash(), "pieces": manifest.size(), "models": placed,
	}

static func piece_extent(piece: Dictionary) -> float:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p: Vector3 in piece.points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return maxf(hi.x - lo.x, hi.y - lo.y)

func _pose(feet: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), feet + Vector3.UP * 0.04)

func is_finish_at(feet: Vector3) -> bool:
	return _finish_box.has_point(feet)

func segment_at(position: Vector3) -> int:
	for i: int in range(segment_bounds.size() - 1, -1, -1):
		if segment_bounds[i].has_point(position):
			return i
	return 0

func route_hint(stage: int, feet: Vector3) -> String:
	if feet.y < COURT_Y + 1.0 and absf(feet.x) < COURT_X and feet.z < COURT_N and feet.z > COURT_S:
		return "In the court pool: wade to the stair ramp along the side wall and walk up to the balcony."
	if feet.y < CISTERN_Y + 1.0 and feet.y > CISTERN_Y - 1.0 and feet.x > CLOISTER[0] and feet.x < CLOISTER[1] and feet.z > CLOISTER[2] and feet.z < CLOISTER[3]:
		return "In the cistern: the stair ramps at the pool's end climb back to the walk you came from."
	match stage:
		0:
			return "Through the gate arch and hop down the three steps. A short hop lands in a moss bed; step up and go on."
		1:
			return "Hop the pavilion tops down the court, up and down. A fall lands in the pool; the stair ramp on the side wall brings you back."
		2:
			return "Follow the aqueduct round the bend, or carry speed across the four cistern towers to the castellum."
		3:
			return "Round the walks to the left, or straight across on the fallen architrave: jump, then crouch (Ctrl or C) in the air."
		4:
			return "Climb the steps, each 0.8 m up, then turn through the sanctuary arch."
	return "Cross the line beyond the sanctuary arch."

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

# --- library models with authored collision -------------------------------------------------------

func _model_xf(feet: Vector3, scale: Vector3, yaw: float) -> Transform3D:
	# the r15_assets.gd wrapper: feet, yaw, then scale; these models are centred on their feet.
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), feet)

func _model_box(label: String, xf: Transform3D, x0: float, x1: float, z0: float, z1: float, top: Variant, bottom: Variant, kind: String, stage: int, role: String) -> void:
	# a prism in model coordinates: a rectangle in x/z with a top and bottom height each, either one
	# value or one per corner (x0z0, x1z0, x1z1, x0z1); placed through the model's transform.
	var corners := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
	var tops: Array = []
	var bottoms: Array = []
	for i: int in 4:
		var c: Vector2 = corners[i]
		var ty: float = top[i] if top is Array else float(top)
		var by: float = bottom[i] if bottom is Array else float(bottom)
		tops.append(xf * Vector3(c.x, ty, c.y))
		bottoms.append(xf * Vector3(c.x, by, c.y))
	_piece(label, tops, bottoms, StringName("model:" + kind), stage, role, false)
	_model_pieces.append(label)

func _tower(label: String, feet: Vector3, scale: Vector3, yaw: float, stage: int, role: String) -> Transform3D:
	# tower-square-arch: four corner piers, a roof over the crown, and the arch haunches of the
	# four arms; the arched passages through both axes stay open.
	var xf := _model_xf(feet, scale, yaw)
	_model_pieces = []
	var h := TOWER_HALF
	var o := TOWER_OPEN
	var r := TOWER_ROOF
	var corner := 0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			corner += 1
			_model_box("%s_pier_%d" % [label, corner], xf, minf(sx * o, sx * h), maxf(sx * o, sx * h), minf(sz * o, sz * h), maxf(sz * o, sz * h), TOWER_TOP, 0.0, "tower", stage, role)
	_model_box("%s_roof" % label, xf, -r, r, -r, r, TOWER_TOP, TOWER_CROWN, "tower", stage, role)
	# haunches: the solid between the arch polygon and the crown, for each arm, slice by slice.
	for arm: int in 4:
		for side: float in [-1.0, 1.0]:
			for i: int in TOWER_ARCH.size() - 1:
				var a: Array = TOWER_ARCH[i]
				var b: Array = TOWER_ARCH[i + 1]
				var u0: float = side * float(a[0])
				var u1: float = side * float(b[0])
				var lo := minf(u0, u1)
				var hi := maxf(u0, u1)
				var y_lo: float = a[1] if u0 == lo else b[1]
				var y_hi: float = b[1] if u0 == lo else a[1]
				var w0 := o if arm < 2 else -r
				var w1 := r if arm < 2 else -o
				var name := "%s_haunch_%d_%s%d" % [label, arm, "n" if side < 0.0 else "p", i]
				if arm % 2 == 0:
					# the arm along z: slices in x, through the arm's depth.
					_model_box(name, xf, lo, hi, w0, w1, TOWER_CROWN, [y_lo, y_hi, y_hi, y_lo], "tower", -1, "wall")
				else:
					# the arm along x: slices in z.
					_model_box(name, xf, w0, w1, lo, hi, TOWER_CROWN, [y_lo, y_lo, y_hi, y_hi], "tower", -1, "wall")
	models.append({"id": label, "model": TOWER_MODEL, "xf": xf, "role": role, "pieces": _model_pieces})
	return xf

func _bridge(label: String, a: Vector3, b: Vector3, sy: float, stage: int) -> void:
	# bridge-straight from a to b (its traffic runs along its own x): walk, curbs, parapet with
	# merlons, the two end piers and the arch haunches; the arch under the span stays open.
	var d := b - a
	var yaw := atan2(-d.z, d.x)
	var sx := Vector2(d.x, d.z).length() / (2.0 * BRIDGE_HALF)
	var feet := (a + b) * 0.5
	feet.y = AQ_FOOT
	var xf := _model_xf(feet, Vector3(sx, sy, BRIDGE_WIDTH_SCALE), yaw)
	_model_pieces = []
	var h := BRIDGE_HALF
	_model_box("%s_walk" % label, xf, -h, h, -BRIDGE_WALK, BRIDGE_WALK, BRIDGE_WALK_Y, BRIDGE_SLAB_Y, "bridge", stage, "route")
	for side: float in [-1.0, 1.0]:
		var s := "n" if side < 0.0 else "p"
		var c0 := side * BRIDGE_WALK
		var c1 := side * BRIDGE_CURB
		var p1 := side * h
		_model_box("%s_curb_%s" % [label, s], xf, -h, h, minf(c0, c1), maxf(c0, c1), BRIDGE_CURB_Y, BRIDGE_SLAB_Y, "bridge", stage, "route")
		_model_box("%s_parapet_%s" % [label, s], xf, -h, h, minf(c1, p1), maxf(c1, p1), BRIDGE_CRENEL_Y, BRIDGE_SLAB_Y, "bridge", -1, "wall")
		for m: int in BRIDGE_MERLONS.size():
			var mx: Array = BRIDGE_MERLONS[m]
			_model_box("%s_merlon_%s%d" % [label, s, m], xf, mx[0], mx[1], minf(c1, p1), maxf(c1, p1), BRIDGE_MERLON_Y, BRIDGE_CRENEL_Y, "bridge", -1, "wall")
		_model_box("%s_pier_%s" % [label, s], xf, minf(side * BRIDGE_PIER, p1), maxf(side * BRIDGE_PIER, p1), -BRIDGE_PIER_Z, BRIDGE_PIER_Z, BRIDGE_SLAB_Y, 0.0, "bridge", -1, "wall")
		for i: int in BRIDGE_ARCH.size() - 1:
			var p: Array = BRIDGE_ARCH[i]
			var q: Array = BRIDGE_ARCH[i + 1]
			var u0: float = side * float(p[0])
			var u1: float = side * float(q[0])
			var lo := minf(u0, u1)
			var hi := maxf(u0, u1)
			var y_lo: float = p[1] if u0 == lo else q[1]
			var y_hi: float = q[1] if u0 == lo else p[1]
			_model_box("%s_haunch_%s%d" % [label, s, i], xf, lo, hi, -BRIDGE_PIER_Z, BRIDGE_PIER_Z, BRIDGE_SLAB_Y, [y_lo, y_hi, y_hi, y_lo], "bridge", -1, "wall")
	models.append({"id": label, "model": BRIDGE_MODEL, "xf": xf, "role": "route", "pieces": _model_pieces})

func _wedge(label: String, prev: Vector3, at: Vector3, next: Vector3, sy: float) -> void:
	# the outside of a joint between two spans turning right: a sandstone wedge that closes the walk,
	# curb and parapet between the two spans' end faces. drawn by the level, not a model.
	var d0 := Vector3(at.x - prev.x, 0, at.z - prev.z).normalized()
	var d1 := Vector3(next.x - at.x, 0, next.z - at.z).normalized()
	# outward is to the left of travel on a right-hand bend.
	var n0 := Vector3(d0.z, 0, -d0.x)
	var n1 := Vector3(d1.z, 0, -d1.x)
	var w := BRIDGE_WIDTH_SCALE
	var layers := [
		[0.0, BRIDGE_WALK * w, AQ_FOOT + BRIDGE_WALK_Y * sy, "route", 2, &"flag"],
		[BRIDGE_WALK * w, BRIDGE_CURB * w, AQ_FOOT + BRIDGE_CURB_Y * sy, "route", 2, &"flag"],
		[BRIDGE_CURB * w, BRIDGE_HALF * w, AQ_FOOT + BRIDGE_CRENEL_Y * sy, "wall", -1, &"ashlar"],
	]
	var bottom := AQ_FOOT + BRIDGE_SLAB_Y * sy
	for i: int in layers.size():
		var l: Array = layers[i]
		var r0: float = l[0]
		var r1: float = l[1]
		var y: float = l[2]
		var top: Array = [at + n0 * r0, at + n0 * r1, at + n1 * r1] if r0 == 0.0 else [at + n0 * r0, at + n0 * r1, at + n1 * r1, at + n1 * r0]
		for k: int in top.size():
			top[k] = Vector3((top[k] as Vector3).x, y, (top[k] as Vector3).z)
		_solid("%s_%d" % [label, i], top, bottom, l[5], l[4], l[3])

func _pillar(label: String, centre: Vector3, scale: Vector3, yaw: float) -> void:
	# wall-pillar: a crenellated block; one box to its full height (its crenels are out of reach).
	var xf := _model_xf(centre, scale, yaw)
	var p := PILLAR_HALF
	_model_pieces = []
	_model_box(label, xf, -p, p, -p, p, PILLAR_TOP, 0.0, "wall", -1, "wall")
	models.append({"id": label, "model": PILLAR_MODEL, "xf": xf, "role": "wall", "pieces": _model_pieces})

func _pillar_run(label: String, a: Vector3, b: Vector3, sy: float) -> void:
	# a straight wall of wall-pillar blocks about 4 m long and 1 m thick from a to b.
	var d := b - a
	var length := Vector2(d.x, d.z).length()
	var count := maxi(1, roundi(length / 4.0))
	var yaw := atan2(-d.z, d.x)
	for k: int in count:
		var c := a + d * ((k + 0.5) / count)
		_pillar("%s_%d" % [label, k + 1], c, Vector3(length / count, sy, 1.0), yaw)

func _column(label: String, foot: Vector3, radius: float, height: float) -> void:
	var ring: Array = []
	for k: int in 8:
		var t := TAU * (k + 0.5) / 8.0
		ring.append(Vector3(foot.x + cos(t) * radius, foot.y + height, foot.z + sin(t) * radius))
	_solid(label, ring, BASE, &"column", -1, "scenery")
	markings.append({"name": label, "kind": "column", "at": foot, "height": height, "radius": radius})

# --- pieces ---------------------------------------------------------------------------------------

func _rect(x0: float, x1: float, z0: float, z1: float, y: float) -> Array:
	return [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]

func _deck(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	return _solid(label, _rect(x0, x1, z0, z1, top), base, kind, stage, role)

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid", draw: bool = true) -> StaticBody3D:
	# a convex prism: a planar convex top polygon extruded straight down to `base`.
	var bottom: Array = []
	for p: Vector3 in top:
		bottom.append(Vector3(p.x, base, p.z))
	return _piece(label, top, bottom, kind, stage, role, draw)

func _slab(label: String, top: Array, bottoms: Array, kind: StringName, stage: int, role: String) -> StaticBody3D:
	# a prism whose underside is its own plane: one bottom height per top vertex.
	var bottom: Array = []
	for i: int in top.size():
		var p: Vector3 = top[i]
		bottom.append(Vector3(p.x, float(bottoms[i]), p.z))
	return _piece(label, top, bottom, kind, stage, role, true)

func _piece(label: String, top: Array, bottom: Array, kind: StringName, stage: int, role: String, draw: bool) -> StaticBody3D:
	assert(not has_node(NodePath(label)), "sunken: duplicate piece " + label)
	var points: Array[Vector3] = []
	for p: Vector3 in top:
		points.append(p)
	for p: Vector3 in bottom:
		points.append(p)
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
		prisms.append({"top": top.duplicate(), "bottom": bottom.duplicate(), "kind": kind})
	manifest.append({"name": label, "role": role, "stage": stage, "points": points, "shape": "prism", "kind": kind})
	return body

func _paint_x(label: String, x0: float, x1: float, z: float, width: float, y: float, kind: StringName) -> void:
	_paint_line(label, Vector3(x0, y, z), Vector3(x1, y, z), Vector3(0, 0, width), kind)

func _paint_line(label: String, a: Vector3, b: Vector3, inward: Vector3, kind: StringName) -> void:
	# a flush band along an edge, `inward` across the walking side: visual only.
	var lift := Vector3.UP * 0.004
	var top := [a + lift, b + lift, b + inward + lift, a + inward + lift]
	var bottom: Array = []
	for p: Vector3 in top:
		bottom.append(Vector3(p.x, minf(a.y, b.y) - 0.02, p.z))
	prisms.append({"top": top, "bottom": bottom, "kind": kind})
	markings.append({"name": label, "kind": "strip", "a": _v(a), "b": _v(b)})

func _floor_label(label: String, at: Vector3, yaw: float, text: String) -> void:
	markings.append({"name": label, "kind": "floor", "at": at, "yaw": yaw, "text": text})

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
