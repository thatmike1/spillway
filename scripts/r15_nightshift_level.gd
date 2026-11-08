extends Node3D
## p / r15 Night Shift: an original neon transit-depot bhop course at night. it publishes the
## level interface the r15 host reads (spawn, checkpoints, segment and kill bounds, finish,
## routes, jump gaps, manifest, geometry hash, route hints, level identity). no part of the
## ordinary route needs crouch; one optional shortcut does. docs/r15/NIGHTSHIFT.md.
##
## course, in order (forward -z down the platform, round a loop, back +z through the shed, then
## -x along a flyover that crosses over the start platform):
##   platform 1 under the station canopy, parked trains on both sides, the flyover overhead ->
##   the throat (three slalom hops over the trackbed) -> the turning loop (a 180 degree right
##   sweep, trams on the outside, the loop pit open on the inside; a speed line jumps the pit
##   onto the traverser bridge) -> the wash bays (a doorway detour round a train parked in the
##   middle bay, out through the west bay; the east bay's road door, a half-raised shutter
##   over a splash wall, lets a crouch-jump off the loop's outside lane run straight up the
##   east bay to the ramp) -> the
##   flyover ramp and the knuckle round the signal box -> the flyover, back over platform 1 ->
##   three step-down hops over the canal to the terminus concourse and the finish.
## recoveries: a throat miss walks back up the return ramp to the platform end; a fall into the
## loop pit walks back up the pit ramp to the loop's mouth; a fall into the canal leaves the
## kill envelope (y < -3) and respawns at the last checkpoint, labelled practice by the host.
##
## collision: every solid is a convex prism (ConvexPolygonShape3D). no walkable piece is longer
## than 32 m; grounded decks reach 5 m or more under their tops and catches 2.5 m. the flyover
## and its stair are elevated decks 1 m deep (declared thin, 0.6 m floor). trains are one prism
## per car, matching the drawn car; nothing is a filled bounds box over an opening.

const Art := preload("res://scripts/r15_nightshift_art.gd")

## the identity the r15 host keys records on. bump LEVEL_VERSION with any change to geometry,
## progress or timing semantics.
const LEVEL_ID := "r15-night-shift"
const LEVEL_NAME := "Night Shift"
const LEVEL_VERSION := 1
const VARIANTS := ["nightshift"]
## p / source units: 1 u = 0.0254 m (hammer inch), as Penstock Yard and Breakwater.
const U := 0.0254
## the vanilla cs:go figures behind the gap screening (docs/r14/SOURCE-REFERENCE.md). driven runs
## on the actual runner decide; these only sort gaps into tiers.
const VANILLA := {"run_ups": 250.0, "jump_ups": 301.993, "gravity_ups": 800.0}
const LANDING := 0.5
const EARLY := 0.1
const TIERS := [["vanilla_strafe", 330.0], ["server", 520.0], ["fast", INF]]

const DECK_Y := 0.0
## trackbed and pit floors: 1.2 m under the decks, under a jump's 1.45 m apex.
const BED := -1.2
const BASE := -8.0
const WATER_Y := -2.5
## p / below this the runner is in the canal: respawn. under the pits (-1.2), under the water.
const KILL_Y := -3.0
const WALL := 0.4
## p / fences and parapets: over a jump-then-crouch's 1.62 m reach, so nothing is climbed by accident.
const FENCE := 1.7
## kenney train-kit scale: a subway car becomes 3.1 x 3.6 x 6.0 m.
const TRAIN_SCALE := 2.3
const CAR_L := 2.6 * TRAIN_SCALE
const CAR_W := 1.35 * TRAIN_SCALE
const CAR_H := 1.571 * TRAIN_SCALE

## platform 1 and its apron.
const PLAT_X := 6.0
const PLAT_START := 26.0
const PLAT_END := -38.0
const APRON_END := -44.0
const STATION_X := 12.0
const CANOPY_END := 12.0
## the throat: three decks, alternating left and right of the line. [x0, x1, z near, z far].
const THROAT := [
	[-5.0, 2.0, -46.0, -52.0],
	[-2.0, 5.0, -54.5, -61.0],
	[-5.0, 2.0, -64.0, -70.0],
]
const THROAT_END := -72.5
const RETURN_FOOT := -56.0
## the loop: approach deck, then a right sweep round C, inner and outer radii; the pit inside.
const R0 := [-4.0, 6.0]
const LOOP := Vector3(22.0, 0.0, -92.0)
const LOOP_IN := 16.0
const LOOP_OUT := 26.0
const PIT_RAMP_X := 9.5
const PIT_RAMP_FOOT := -86.0
const PIT_RAMP_TOP := -74.0
## the traverser bridge over the pit, east end on the loop's exit; its 6 m west gap is the speed jump.
const TRAVERSER := [12.0, 38.0, -89.0, -95.0]
## the wash-bay shed. bays west, middle and east between wall centres; doors along z.
const SHED_X0 := 32.0
const SHED_X1 := 54.0
const SHED_S := -88.5
const SHED_N := -39.5
const BAY_WM := 39.25
const BAY_ME := 46.75
const SHED_WALL_H := 6.0
const DOOR_H := 3.5
const DOOR_1 := [-86.5, -82.5]
## the west and east bays open north onto the forecourt under a header this high.
const BAY_HEADER := 4.5
## the east bay's road door in the shed's south wall, along x: the hatch.
const SHUTTER := [47.0, 53.5]
## p / the shutter hatch: a splash wall to 1.3 m (51 u) and the shutter's bottom edge at 3.05 m,
## an opening of 69 u, under the 72 u standing hull and over the 54 u duck hull. ducked feet
## must stay between 1.30 and 1.68 m across it: a jump-then-crouch (feet to about 64 u, 1.63 m)
## passes for roughly 0.38 s of its flight, about 2.4 m of travel at run speed, against the
## 1.3 m a hull needs to cross the wall; a standing jump only meets the wall or the shutter.
const SHUTTER_SILL := 1.3
const SHUTTER_H := 3.05
const TRAIN_M := [-49.0, -80.0]
const TRAIN_E := [-49.0, -81.0]
const E_TRAIN_X := 50.4
## the loop exit runs on east of the sweep's fence to the shed corner, so the outside lane
## lines up with the east bay's road door.
const EXIT_E := 52.0
## the forecourt, the ramp up the embankment and the knuckle round the signal box.
const FORE_N := -34.0
const RAMP := [44.5, 53.5]
const FLY_Y := 5.0
const FLY_BOTTOM := 4.0
const KNUCKLE := Vector3(40.0, FLY_Y, -2.5)
const KNUCKLE_IN := 4.5
const KNUCKLE_OUT := 13.5
## the flyover along -x between these z edges, crossing over platform 1.
const FLY_S := 2.0
const FLY_N := 11.0
const FLY_START := 40.0
const FLY_END := -30.0
## the canal and the step-down stair over it: [x near, x far, top].
const CANAL := [-29.0, -46.0]
const STEPS := [
	[-33.0, -37.5, 3.4],
	[-40.0, -44.0, 1.8],
]
const STEP_Z := [3.0, 10.0]
const CONCOURSE := [-46.0, -78.0, -6.0, 19.0]
const FINISH_X := [-58.0, -64.0]

## set by a factory before the level enters the tree; build() reads it once (r14 convention).
static var next_variant: String = ""

## p / not "course": the r14 overflow art pass dresses any "course" variant, and this map dresses itself.
var variant: String = "nightshift"
## "kit": sourced textures, models and lights; "neutral": flat colours for attribution runs.
var material_mode: String = "kit"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var finish_title: String = "Terminus"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 4.0
## p / the canal is scenery: no wading. a fall into it leaves the kill envelope.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
## only route decks count as stage progress: catches and recovery ramps never collect a stage.
var progress_roles: Array = ["route"]
var routes: Dictionary = {}
var jump_gaps: Array[Dictionary] = []
var kill_bounds := AABB(Vector3(-110, KILL_Y, -135), Vector3(190, 160 - KILL_Y, 180))
## every collision piece: name, world points, stage, role, kind. hashed without materials.
var manifest: Array[Dictionary] = []
## painted marks, lip lights and labels: visual only, not hashed.
var markings: Array[Dictionary] = []
## prism tops and bases drawn by kind, from collision pieces and visual-only prisms alike.
var prisms: Array[Dictionary] = []
## parked rolling stock: model, feet, yaw, and the collision piece it stands for (or "").
var trains: Array[Dictionary] = []
## light points the art pass turns into lamps: position, kind.
var lamps: Array[Dictionary] = []

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
		if arg == "--nightshift-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "night shift: unknown variant " + variant)
	_platform()
	_throat()
	_loop()
	_wash_bays()
	_ramp()
	_flyover()
	_canal()
	_define_progress()
	_art = Art.new()
	_art.call("dress", self)

# --- the course ----------------------------------------------------------------------------

func _platform() -> void:
	# stage 0: platform 1, 12 m wide and 64 m long between two parked trains. the canopy covers
	# the spawn; 10 m on, the flyover crosses overhead 4 m up. walls and trains on both sides:
	# a sheltered start with room to reach run speed and to learn the hop.
	_deck("s0_platform_a", -PLAT_X, PLAT_X, PLAT_START, -6.0, DECK_Y, &"platform", 0)
	_deck("s0_platform_b", -PLAT_X, PLAT_X, -6.0, PLAT_END, DECK_Y, &"platform", 0)
	_deck("s0_apron", -STATION_X, STATION_X, PLAT_END, APRON_END, DECK_Y, &"platform", 0)
	_solid("s0_backwall", _rect(-STATION_X - 0.5, STATION_X + 0.5, PLAT_START + 0.5, PLAT_START, 5.5), BASE, &"brick", -1, "wall")
	for side: float in [-1.0, 1.0]:
		var tag := "w" if side < 0.0 else "e"
		var inner := side * STATION_X
		var outer := side * (STATION_X + 0.5)
		_solid("s0_wall_%s_a" % tag, _rect(minf(inner, outer), maxf(inner, outer), PLAT_START, -6.0, 3.5), BASE, &"brick", -1, "wall")
		_solid("s0_wall_%s_b" % tag, _rect(minf(inner, outer), maxf(inner, outer), -6.0, APRON_END, 3.5), BASE, &"brick", -1, "wall")
		# the trackbed under each train, a catch in the strip between train and wall.
		var bx0 := minf(side * PLAT_X, side * STATION_X)
		var bx1 := maxf(side * PLAT_X, side * STATION_X)
		_deck("s0_bed_%s_a" % tag, bx0, bx1, PLAT_START, -6.0, BED, &"bed", -1, BASE, "catch")
		_deck("s0_bed_%s_b" % tag, bx0, bx1, -6.0, PLAT_END, BED, &"bed", -1, BASE, "catch")
		# ten subway cars from the back wall to the apron, 0.44 m coupler gaps (under a hull).
		var cx0 := side * (PLAT_X + 0.15)
		var cx1 := side * (PLAT_X + 0.15 + CAR_W)
		var model := "kenney-train/models/train-electric-subway-a.glb" if side < 0.0 else "kenney-train/models/train-electric-subway-c.glb"
		_train_run("s0_train_%s" % tag, minf(cx0, cx1), maxf(cx0, cx1), PLAT_START - 0.1, PLAT_END + 0.1, BED, 10, model)
		# the flyover's piers in the strip outside the trains.
		var px0 := side * 10.0
		var px1 := side * (STATION_X - 0.05)
		_solid("s0_pier_%s" % tag, _rect(minf(px0, px1), maxf(px0, px1), FLY_N - 2.5, FLY_S + 2.5, FLY_BOTTOM), BASE, &"concrete", -1, "wall")
	# platform-end lamp posts at the edges; their lamps reach in over the deck above head height.
	for x: float in [-PLAT_X + 0.6, PLAT_X - 0.6]:
		_solid("s0_post_%s" % ("w" if x < 0.0 else "e"), _rect(x - 0.13, x + 0.13, -29.87, -30.13, 4.3), BASE, &"steel", -1, "wall")
		lamps.append({"at": Vector3(x, 4.3, -30.0), "kind": "post"})
	# canopy columns near the edges, out of the line from the spawn.
	for z: float in [22.0, 15.0]:
		for x: float in [-4.9, 4.9]:
			_solid("s0_column_%s_%d" % ["w" if x < 0.0 else "e", roundi(z)], _rect(x - 0.2, x + 0.2, z + 0.2, z - 0.2, 4.8), BASE, &"steel", -1, "wall")
	_lip_x("s0_edge_w", -PLAT_X, PLAT_START, PLAT_END, 0.3, &"paint_yellow")
	_lip_x("s0_edge_e", PLAT_X, PLAT_START, PLAT_END, -0.3, &"paint_yellow")
	_paint_z("s0_start_line", -PLAT_X, PLAT_X, 18.0, 0.3, DECK_Y, &"paint_white")
	_paint_z("s0_apron_lip", -STATION_X, STATION_X, APRON_END, 0.35, DECK_Y, &"lip")
	_floor_label("s0_gap", Vector3(-3.0, DECK_Y, APRON_END + 1.0), 0.0, _gap_text(APRON_END - float(THROAT[0][2])))

func _throat() -> void:
	# stage 1: the throat, where the platform tracks fan out. three relay-cabinet decks over the
	# trackbed, alternating left and right of the line (gaps 2.0, 2.5, 3.0 m and 2.5 m onto the
	# loop approach): a slalom that teaches aiming each hop. the trackbed is a catch one jump's
	# apex down; its return ramp on the right climbs back to the platform apron.
	_deck("s1_bed_a", -STATION_X, STATION_X, APRON_END, -58.5, BED, &"bed", -1, BASE, "catch")
	_deck("s1_bed_b", -STATION_X, STATION_X, -58.5, THROAT_END, BED, &"bed", -1, BASE, "catch")
	_solid("s1_wall_w", _rect(-STATION_X - 0.5, -STATION_X, APRON_END, THROAT_END - 0.5, 3.0), BASE, &"concrete", -1, "wall")
	_solid("s1_wall_e", _rect(STATION_X, STATION_X + 0.5, APRON_END, THROAT_END - 0.5, 3.0), BASE, &"concrete", -1, "wall")
	_solid("s1_wall_s", _rect(-STATION_X - 0.5, R0[0] - WALL, THROAT_END, THROAT_END - 0.5, 2.0), BASE, &"concrete", -1, "wall")
	_solid("s1_return_ramp", [Vector3(8.5, DECK_Y, APRON_END), Vector3(STATION_X, DECK_Y, APRON_END), Vector3(STATION_X, BED, RETURN_FOOT), Vector3(8.5, BED, RETURN_FOOT)], BASE, &"steel", -1, "recovery")
	_paint_line("s1_ramp_head", Vector3(8.5, DECK_Y, APRON_END), Vector3(STATION_X, DECK_Y, APRON_END), Vector3(0, 0, -0.25), &"paint_yellow")
	var previous := APRON_END
	for i: int in THROAT.size():
		var t: Array = THROAT[i]
		_deck("s1_cabinet_%d" % (i + 1), float(t[0]), float(t[1]), float(t[2]), float(t[3]), DECK_Y, &"cabinet", 1)
		_paint_z("s1_lip_%d_near" % (i + 1), float(t[0]), float(t[1]), float(t[2]), -0.25, DECK_Y, &"lip")
		_paint_z("s1_lip_%d_far" % (i + 1), float(t[0]), float(t[1]), float(t[3]), 0.25, DECK_Y, &"lip")
		if i > 0:
			_floor_label("s1_gap_%d" % (i + 1), Vector3((float(t[0]) + float(t[1])) * 0.5, DECK_Y, previous + 0.9), 0.0, _gap_text(previous - float(t[2])))
		previous = float(t[3])
	_floor_label("s1_gap_loop", Vector3(-1.5, DECK_Y, previous + 0.9), 0.0, _gap_text(previous - THROAT_END))
	# signal posts between the decks: lit landmarks out of the line, on the trackbed.
	for p: Vector3 in [Vector3(-9.0, BED, -53.0), Vector3(8.0, BED, -63.0), Vector3(-9.0, BED, -69.0)]:
		_solid("s1_signal_%d_%d" % [roundi(p.x), roundi(-p.z)], _rect(p.x - 0.25, p.x + 0.25, p.z + 0.25, p.z - 0.25, 3.8), BASE, &"steel", -1, "wall")
		lamps.append({"at": p + Vector3(0, 4.4, 0), "kind": "signal", "light": false})

func _loop() -> void:
	# stage 2: the turning loop. a 20 m approach deck, then a 180 degree right sweep 10 m wide
	# round the loop pit, the tram sidings fenced off outside it. the inside edge is open: the
	# short line is the risky one. a fall into the pit walks back up the pit ramp to the mouth.
	_deck("s2_approach", R0[0], R0[1], THROAT_END, LOOP.z, DECK_Y, &"platform", 2)
	_solid("s2_fence_w", _rect(R0[0] - WALL, R0[0], THROAT_END, LOOP.z, DECK_Y + 2.0), BASE, &"steel", -1, "wall")
	_paint_z("s2_mouth", R0[0], R0[1], THROAT_END, -0.35, DECK_Y, &"lip")
	for a: int in range(0, 180, 10):
		_ring_piece("s2_loop_%03d" % a, LOOP, Vector3.LEFT, -1.0, LOOP_IN, LOOP_OUT, a, a + 10, DECK_Y, &"platform", 2)
		_ring_piece("s2_fence_%03d" % a, LOOP, Vector3.LEFT, -1.0, LOOP_OUT, LOOP_OUT + WALL, a, a + 10, DECK_Y + 2.0, &"steel", -1, BASE, "wall")
		var a3 := _ring_point(LOOP, Vector3.LEFT, -1.0, LOOP_IN, a)
		var b3 := _ring_point(LOOP, Vector3.LEFT, -1.0, LOOP_IN, a + 10)
		var inward := (_ring_point(LOOP, Vector3.LEFT, -1.0, LOOP_IN + 1.0, a + 5) - _ring_point(LOOP, Vector3.LEFT, -1.0, LOOP_IN, a + 5)).normalized() * 0.3
		_paint_line("s2_inner_%03d" % a, a3, b3, inward, &"lip")
	_deck("s2_exit", LOOP.x + LOOP_IN, EXIT_E, LOOP.z, SHED_S, DECK_Y, &"platform", 2)
	_solid("s2_fence_exit", _rect(EXIT_E, EXIT_E + WALL, LOOP.z - WALL, SHED_S, DECK_Y + 2.0), BASE, &"steel", -1, "wall")
	_solid("s2_fence_exit_s", _rect(LOOP.x + LOOP_OUT, EXIT_E, LOOP.z - WALL, LOOP.z, DECK_Y + 2.0), BASE, &"steel", -1, "wall")
	_paint_line("s2_exit_edge", Vector3(LOOP.x + LOOP_IN, DECK_Y, LOOP.z), Vector3(LOOP.x + LOOP_IN, DECK_Y, SHED_S), Vector3(0.3, 0, 0), &"lip")
	# the pit, a catch 1.2 m down: the approach's east side, the bay under the shed's corner and
	# the half disc inside the sweep, in six sectors.
	_deck("s2_pit_n", R0[1], SHED_X0, THROAT_END - 0.5, LOOP.z, BED, &"bed", -1, BASE, "catch")
	_deck("s2_pit_e", SHED_X0, LOOP.x + LOOP_IN, SHED_S, LOOP.z, BED, &"bed", -1, BASE, "catch")
	for q: int in 6:
		var top: Array = [Vector3(LOOP.x, BED, LOOP.z)]
		for s: int in 4:
			top.append(_ring_point(LOOP, Vector3.LEFT, -1.0, LOOP_IN + 0.3, 30.0 * q + 10.0 * s, BED))
		_solid("s2_pit_s%d" % (q + 1), top, BASE, &"bed", -1, "catch")
	_solid("s2_pit_wall_n", _rect(R0[1], SHED_X0, THROAT_END, THROAT_END - 0.5, 2.0), BASE, &"concrete", -1, "wall")
	# the pit ramp: up the approach's east side from the pit floor to a landing at the mouth.
	_solid("s2_pit_ramp", [Vector3(R0[1], DECK_Y, PIT_RAMP_TOP), Vector3(PIT_RAMP_X, DECK_Y, PIT_RAMP_TOP), Vector3(PIT_RAMP_X, BED, PIT_RAMP_FOOT), Vector3(R0[1], BED, PIT_RAMP_FOOT)], BASE, &"steel", -1, "recovery")
	_deck("s2_pit_landing", R0[1], PIT_RAMP_X, THROAT_END - 0.5, PIT_RAMP_TOP, DECK_Y, &"steel", -1, BASE, "recovery")
	# the traverser bridge across the pit, its east end on the loop's exit. from the approach's
	# east lip it is a 6 m flat jump (clear at about 340 u/s): the earned line, cutting the sweep.
	var tr: Array = TRAVERSER
	_deck("s2_traverser", float(tr[0]), float(tr[1]), float(tr[2]), float(tr[3]), DECK_Y, &"steel", 2)
	_lip_x("s2_traverser_lip", float(tr[0]), float(tr[2]), float(tr[3]), 0.3, &"lip")
	_floor_label("s2_traverser_gap", Vector3(R0[1] - 1.4, DECK_Y, (float(tr[2]) + float(tr[3])) * 0.5), PI * 0.5, _gap_text(float(tr[0]) - R0[1]) + "\nspeed line")
	# trams parked on the siding outside the sweep, each car a wall prism along its chord, and a
	# shunting loco on a stub in the pit (reachable from the pit floor, so it has its body).
	for k: int in 12:
		var a := 8.0 + 14.0 * k
		_car_on_ring("s2_tram_%02d" % (k + 1), LOOP, LOOP_OUT + WALL + 0.3, a, DECK_Y - 1.2, "kenney-train/models/train-tram-modern.glb", 1.128 * TRAIN_SCALE, 2.687 * TRAIN_SCALE)
	_car("s2_loco", Vector3(22.0, BED, -104.0), PI * 0.5, 1.35 * TRAIN_SCALE, 2.623 * TRAIN_SCALE, 1.675 * TRAIN_SCALE, "kenney-train/models/train-diesel-box-a.glb", "wall")
	for a: float in [30.0, 90.0, 150.0]:
		lamps.append({"at": _ring_point(LOOP, Vector3.LEFT, -1.0, LOOP_OUT - 0.6, a, 4.6), "kind": "mast"})

func _wash_bays() -> void:
	# stage 3: the wash-bay shed, three bays under one roof. a train with its work stands blocks
	# the middle bay, whose north end is a dead end; the ordinary line goes round it (heading
	# north, west is on the right): right through door 1 into the west bay, up the bay and out
	# its open north end, then left along the forecourt to the ramp. the east bay's road door,
	# straight ahead of the loop's outside lane, is a hatch: a half-raised shutter over a splash
	# wall, which only a crouch-jump fits through; the east bay's lane then runs straight onto
	# the ramp, skipping door 1, the west bay and the forecourt crossing.
	var bays := [[SHED_X0 + 0.5, BAY_WM], [BAY_WM, BAY_ME], [BAY_ME, SHED_X1 - 0.5]]
	var names := ["w", "m", "e"]
	for i: int in 3:
		_deck("s3_floor_%s_a" % names[i], float(bays[i][0]), float(bays[i][1]), SHED_S, -64.0, DECK_Y, &"floor", 3)
		_deck("s3_floor_%s_b" % names[i], float(bays[i][0]), float(bays[i][1]), -64.0, SHED_N, DECK_Y, &"floor", 3)
	var top := SHED_WALL_H
	_solid("s3_wall_w_a", _rect(SHED_X0, SHED_X0 + 0.5, SHED_S, -64.0, top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_w_b", _rect(SHED_X0, SHED_X0 + 0.5, -64.0, SHED_N, top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_e_a", _rect(SHED_X1 - 0.5, SHED_X1, SHED_S, -64.0, top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_e_b", _rect(SHED_X1 - 0.5, SHED_X1, -64.0, SHED_N, top), BASE, &"cladding", -1, "wall")
	var door_m := [BAY_WM + 0.25, BAY_ME - 0.25]
	_solid("s3_wall_s_w", _rect(SHED_X0, float(door_m[0]), SHED_S, SHED_S + 0.5, top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_s_me", _rect(float(door_m[1]), float(SHUTTER[0]), SHED_S, SHED_S + 0.5, top), BASE, &"cladding", -1, "wall")
	# p / the hatch: the splash wall up to the sill, the shutter's slats down to 3.05 m above it,
	# each its own prism, so the opening between them is exactly the drawn gap.
	var sh := _rect(float(SHUTTER[0]), float(SHUTTER[1]), SHED_S, SHED_S + 0.5, SHUTTER_SILL)
	_solid("s3_splash_wall", sh, BASE, &"concrete", -1, "wall")
	_solid("s3_shutter", _rect(float(SHUTTER[0]), float(SHUTTER[1]), SHED_S, SHED_S + 0.5, DOOR_H), SHUTTER_H, &"shutter", -1, "low_clearance")
	_solid("s3_header_shutter", _rect(float(SHUTTER[0]), float(SHUTTER[1]), SHED_S, SHED_S + 0.5, top), DOOR_H, &"cladding", -1, "wall")
	_paint_line("s3_shutter_sill_out", Vector3(float(SHUTTER[0]), DECK_Y, SHED_S), Vector3(EXIT_E, DECK_Y, SHED_S), Vector3(0, 0, -0.3), &"hazard")
	_paint_line("s3_shutter_sill_in", Vector3(float(SHUTTER[0]), DECK_Y, SHED_S + 0.5), Vector3(E_TRAIN_X, DECK_Y, SHED_S + 0.5), Vector3(0, 0, 0.3), &"hazard")
	_solid("s3_header_s", _rect(float(door_m[0]), float(door_m[1]), SHED_S, SHED_S + 0.5, top), 4.5, &"cladding", -1, "wall")
	_solid("s3_header_n_w", _rect(SHED_X0 + 0.5, BAY_WM - 0.25, SHED_N - 0.5, SHED_N, top), BAY_HEADER, &"cladding", -1, "wall")
	_solid("s3_wall_n_m", _rect(BAY_WM - 0.25, BAY_ME + 0.25, SHED_N - 0.5, SHED_N, top), BASE, &"cladding", -1, "wall")
	_solid("s3_header_n_e", _rect(BAY_ME + 0.25, SHED_X1 - 0.5, SHED_N - 0.5, SHED_N, top), BAY_HEADER, &"cladding", -1, "wall")
	# the west/middle wall with door 1, the middle/east wall solid.
	var wm := [BAY_WM - 0.25, BAY_WM + 0.25]
	_solid("s3_wall_wm_a", _rect(float(wm[0]), float(wm[1]), SHED_S + 0.5, float(DOOR_1[0]), top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_wm_b", _rect(float(wm[0]), float(wm[1]), float(DOOR_1[1]), -64.0, top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_wm_c", _rect(float(wm[0]), float(wm[1]), -64.0, SHED_N - 0.5, top), BASE, &"cladding", -1, "wall")
	_solid("s3_header_1", _rect(float(wm[0]), float(wm[1]), float(DOOR_1[0]), float(DOOR_1[1]), top), DOOR_H, &"cladding", -1, "wall")
	var me := [BAY_ME - 0.25, BAY_ME + 0.25]
	_solid("s3_wall_me_a", _rect(float(me[0]), float(me[1]), SHED_S + 0.5, -64.0, top), BASE, &"cladding", -1, "wall")
	_solid("s3_wall_me_b", _rect(float(me[0]), float(me[1]), -64.0, SHED_N - 0.5, top), BASE, &"cladding", -1, "wall")
	# the middle bay: a five-car train on its road with solid work stands either side, the full
	# bay wide and 2.2 m high (over a jump-then-crouch), so it is a block to go round.
	var mx := (BAY_WM + BAY_ME) * 0.5
	_train_run("s3_train_m", mx - CAR_W * 0.5, mx + CAR_W * 0.5, float(TRAIN_M[0]) - 0.2, float(TRAIN_M[1]) + 0.2, DECK_Y, 5, "kenney-train/models/train-electric-subway-b.glb")
	_solid("s3_stand_w", _rect(BAY_WM + 0.25, mx - CAR_W * 0.5, float(TRAIN_M[0]), float(TRAIN_M[1]), 2.2), BASE, &"stand", -1, "wall")
	_solid("s3_stand_e", _rect(mx + CAR_W * 0.5, BAY_ME - 0.25, float(TRAIN_M[0]), float(TRAIN_M[1]), 2.2), BASE, &"stand", -1, "wall")
	# the east bay: a train on its east road, a 3.4 m lane beside it.
	_train_run("s3_train_e", E_TRAIN_X, E_TRAIN_X + CAR_W, float(TRAIN_E[0]), float(TRAIN_E[1]), DECK_Y, 5, "kenney-train/models/train-electric-city-b.glb", 1.3 * TRAIN_SCALE, 2.7 * TRAIN_SCALE, 2.219 * TRAIN_SCALE)
	# door marks and labels.
	_paint_line("s3_door_1", Vector3(float(wm[1]), DECK_Y, float(DOOR_1[0])), Vector3(float(wm[1]), DECK_Y, float(DOOR_1[1])), Vector3(0.3, 0, 0), &"lip")
	_paint_line("s3_exit_w", Vector3(SHED_X0 + 0.5, DECK_Y, SHED_N - 0.5), Vector3(BAY_WM - 0.25, DECK_Y, SHED_N - 0.5), Vector3(0, 0, -0.3), &"lip")
	for z: float in [-80.0, -64.0, -48.0]:
		for x: float in [(SHED_X0 + BAY_WM) * 0.5, mx, (BAY_ME + SHED_X1) * 0.5]:
			lamps.append({"at": Vector3(x, 5.4, z), "kind": "bay"})

func _ramp() -> void:
	# stage 4: the forecourt north of the shed, the full shed wide: the ordinary line comes out
	# of the west bay and runs east along it, the shutter line comes straight out of the east
	# bay. then the ramp up the embankment (5 m in 31.5 m, 9 degrees) and the knuckle: a tight
	# flat right turn round the signal box onto the flyover.
	_deck("s4_forecourt", SHED_X0 + 0.5, SHED_X1 - 0.1, SHED_N, FORE_N, DECK_Y, &"floor", 4)
	_solid("s4_fore_wall_w", _rect(SHED_X0, SHED_X0 + 0.5, SHED_N, FORE_N + WALL, DECK_Y + FENCE), BASE, &"concrete", -1, "wall")
	_solid("s4_fore_wall_e", _rect(SHED_X1 - 0.1, SHED_X1 + 0.3, SHED_N, FORE_N, DECK_Y + FENCE), BASE, &"concrete", -1, "wall")
	_solid("s4_fore_wall_n", _rect(SHED_X0, RAMP[0] - WALL, FORE_N + WALL, FORE_N, DECK_Y + FENCE), BASE, &"concrete", -1, "wall")
	var mid_z := (FORE_N + KNUCKLE.z) * 0.5
	var mid_y := (DECK_Y + FLY_Y) * 0.5
	for piece: Array in [["a", FORE_N, mid_z, DECK_Y, mid_y], ["b", mid_z, KNUCKLE.z, mid_y, FLY_Y]]:
		var z0: float = piece[1]
		var z1: float = piece[2]
		var y0: float = piece[3]
		var y1: float = piece[4]
		_solid("s4_ramp_%s" % piece[0], [Vector3(RAMP[0], y0, z0), Vector3(RAMP[1], y0, z0), Vector3(RAMP[1], y1, z1), Vector3(RAMP[0], y1, z1)], BASE, &"flyover", 4, "route")
		_solid("s4_parapet_w_%s" % piece[0], [Vector3(RAMP[0] - WALL, y0 + FENCE, z0), Vector3(RAMP[0], y0 + FENCE, z0), Vector3(RAMP[0], y1 + FENCE, z1), Vector3(RAMP[0] - WALL, y1 + FENCE, z1)], BASE, &"concrete", -1, "wall")
		_solid("s4_parapet_e_%s" % piece[0], [Vector3(RAMP[1], y0 + FENCE, z0), Vector3(RAMP[1] + WALL, y0 + FENCE, z0), Vector3(RAMP[1] + WALL, y1 + FENCE, z1), Vector3(RAMP[1], y1 + FENCE, z1)], BASE, &"concrete", -1, "wall")
	for a: int in range(0, 90, 10):
		_ring_piece("s4_knuckle_%02d" % a, KNUCKLE, Vector3.RIGHT, -1.0, KNUCKLE_IN, KNUCKLE_OUT, a, a + 10, FLY_Y, &"flyover", 4, FLY_BOTTOM - 1.0)
		_ring_piece("s4_knuckle_wall_%02d" % a, KNUCKLE, Vector3.RIGHT, -1.0, KNUCKLE_OUT, KNUCKLE_OUT + WALL, a, a + 10, FLY_Y + FENCE, &"concrete", -1, FLY_BOTTOM - 1.0, "wall")
	# the signal box: a 16-sided tower inside the knuckle, its foot on the ground.
	var ring: Array = []
	for s: int in 16:
		var a := TAU * s / 16.0
		ring.append(Vector3(KNUCKLE.x + cos(a) * (KNUCKLE_IN - 0.05), FLY_Y + 4.5, KNUCKLE.z + sin(a) * (KNUCKLE_IN - 0.05)))
	_solid("s4_signal_box", ring, BASE, &"brick", -1, "wall")
	lamps.append({"at": Vector3(49.0, 4.5, -38.6), "kind": "flood"})
	lamps.append({"at": Vector3(49.0, 4.5 + 2.5, -18.0), "kind": "mast"})

func _flyover() -> void:
	# stage 5: the flyover, 9 m wide on a 1 m deck, parapets over a jump-then-crouch on both
	# sides, straight back over platform 1 and its trains to the canal.
	var cuts := [FLY_START, 16.0, -8.0, FLY_END]
	for k: int in cuts.size() - 1:
		var x0: float = cuts[k]
		var x1: float = cuts[k + 1]
		_deck("s5_flyover_%d" % (k + 1), minf(x0, x1), maxf(x0, x1), FLY_N, FLY_S, FLY_Y, &"flyover", 5, FLY_BOTTOM)
		# p / glass parapets: a solid pane the full fence height, drawn as the glass it is, so the
		# view down onto platform 1 stays open from the deck.
		_solid("s5_parapet_s_%d" % (k + 1), _rect(minf(x0, x1), maxf(x0, x1), FLY_S, FLY_S - WALL, FLY_Y + FENCE), FLY_BOTTOM, &"glass", -1, "wall")
		_solid("s5_parapet_n_%d" % (k + 1), _rect(minf(x0, x1), maxf(x0, x1), FLY_N + WALL, FLY_N, FLY_Y + FENCE), FLY_BOTTOM, &"glass", -1, "wall")
	for i: int in range(1, 9):
		var x := FLY_START - 8.0 * i
		_paint_line("s5_mark_%d" % i, Vector3(x, FLY_Y, FLY_S), Vector3(x, FLY_Y, FLY_N), Vector3(0.25 if i % 2 == 0 else 0.1, 0, 0), &"paint_white")
	for x: float in [32.0, 14.0, -4.0, -22.0]:
		lamps.append({"at": Vector3(x, FLY_Y + 4.6, FLY_N - 0.3), "kind": "flyover"})
	_lip_x("s5_end", FLY_END, FLY_N, FLY_S, 0.35, &"lip", FLY_Y)

func _canal() -> void:
	# stage 5 ends: two step-down decks on piers in the canal, 1.6 m down each, then the terminus
	# quay 1.8 m under the second. the gaps (3.0, 2.5 and 2.0 m) are short for a drop; a miss
	# lands in the water and respawns at the flyover checkpoint.
	var previous := FLY_END
	var previous_y := FLY_Y
	for i: int in STEPS.size():
		var s: Array = STEPS[i]
		_deck("s5_step_%d" % (i + 1), float(s[1]), float(s[0]), float(STEP_Z[1]), float(STEP_Z[0]), float(s[2]), &"steel", 5)
		_lip_x("s5_step_%d_near" % (i + 1), float(s[0]), float(STEP_Z[1]), float(STEP_Z[0]), -0.3, &"lip", float(s[2]))
		_lip_x("s5_step_%d_far" % (i + 1), float(s[1]), float(STEP_Z[1]), float(STEP_Z[0]), 0.3, &"lip", float(s[2]))
		_floor_label("s5_gap_%d" % (i + 1), Vector3(previous - 0.9, previous_y, 6.5), PI * 0.5, "%s\n%.1f m down" % [_gap_text(previous - float(s[0])), previous_y - float(s[2])])
		previous = float(s[1])
		previous_y = float(s[2])
	var c: Array = CONCOURSE
	_floor_label("s5_gap_quay", Vector3(previous - 0.9, previous_y, 6.5), PI * 0.5, "%s\n%.1f m down" % [_gap_text(previous - float(c[0])), previous_y - DECK_Y])
	var cut := -62.0
	_deck("s5_concourse_a", cut, float(c[0]), float(c[3]), float(c[2]), DECK_Y, &"platform", 5)
	_deck("s5_concourse_b", float(c[1]), cut, float(c[3]), float(c[2]), DECK_Y, &"platform", 5)
	_lip_x("s5_quay", float(c[0]), float(c[3]), float(c[2]), -0.35, &"lip")
	_solid("s5_wall_n", _rect(float(c[1]) - WALL, float(c[0]), float(c[3]) + WALL, float(c[3]), DECK_Y + 3.0), BASE, &"brick", -1, "wall")
	_solid("s5_wall_s", _rect(float(c[1]) - WALL, float(c[0]), float(c[2]), float(c[2]) - WALL, DECK_Y + 3.0), BASE, &"brick", -1, "wall")
	_solid("s5_terminus", _rect(float(c[1]) - 6.0, float(c[1]), float(c[3]) + WALL, float(c[2]) - WALL, 9.0), BASE, &"brick", -1, "wall")
	# the canal's east wall stands under the flyover's end, so a drop from the end is water.
	_solid("s5_canal_wall_e", _rect(CANAL[0], CANAL[0] + 0.5, 30.0, -20.0, DECK_Y), BASE, &"concrete", -1, "wall")
	_finish_box = AABB(Vector3(FINISH_X[1], DECK_Y - 0.2, float(c[2])), Vector3(FINISH_X[0] - FINISH_X[1], 5.0, float(c[3]) - float(c[2])))
	finish_position = Vector3((FINISH_X[0] + FINISH_X[1]) * 0.5, DECK_Y, 6.5)
	_paint_line("s5_finish_a", Vector3(FINISH_X[0], DECK_Y, float(c[2])), Vector3(FINISH_X[0], DECK_Y, float(c[3])), Vector3(-0.45, 0, 0), &"paint_white")
	for p: Vector3 in [Vector3(-52.0, 5.0, -5.0), Vector3(-52.0, 5.0, 18.0), Vector3(-70.0, 6.0, 6.5)]:
		lamps.append({"at": p, "kind": "terminus"})
	lamps.append({"at": Vector3(-38.0, 4.0, 14.0), "kind": "canal"})
	water_audio_sources = [Vector3(-37.5, WATER_Y, -10.0), Vector3(-37.5, WATER_Y, 22.0)]

# --- progress, finish and hints --------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their route decks (radius 0 turns off the distance
	# rule), so a flight over a gap, or an air crouch's lift, never collects the deck beyond it.
	spawn = _pose(Vector3(0, DECK_Y, 20.0), 0.0)
	var fly_z := (FLY_S + FLY_N) * 0.5
	checkpoints = [
		{"pose": spawn, "title": "Platform 1"},
		{"pose": _pose(Vector3(-1.5, DECK_Y, -49.0), 0.0), "title": "Throat", "radius": 0.0},
		{"pose": _pose(Vector3(1.0, DECK_Y, -80.0), 0.0), "title": "Turning loop", "radius": 0.0},
		{"pose": _pose(Vector3((BAY_WM + BAY_ME) * 0.5, DECK_Y, -86.0), PI), "title": "Wash bays", "radius": 0.0},
		{"pose": _pose(Vector3(49.0, DECK_Y, -37.0), PI), "title": "Flyover ramp", "radius": 0.0},
		{"pose": _pose(Vector3(34.0, FLY_Y, fly_z), PI * 0.5), "title": "Flyover", "radius": 0.0},
	]
	segment_bounds = [
		AABB(Vector3(-STATION_X - 1, -4, APRON_END), Vector3(2 * STATION_X + 2, 30, PLAT_START + 1 - APRON_END)),
		AABB(Vector3(-STATION_X - 1, -4, THROAT_END), Vector3(2 * STATION_X + 2, 30, APRON_END - THROAT_END)),
		AABB(Vector3(R0[0] - 1, -4, LOOP.z - LOOP_OUT - 1), Vector3(LOOP.x + LOOP_OUT + 2 - R0[0], 30, THROAT_END - LOOP.z + LOOP_OUT + 1)),
		AABB(Vector3(SHED_X0, -4, SHED_S), Vector3(SHED_X1 - SHED_X0, 30, SHED_N - SHED_S)),
		AABB(Vector3(SHED_X0 - 1, -4, SHED_N), Vector3(SHED_X1 + 2 - SHED_X0, 30, FLY_N + 1 - SHED_N)),
		AABB(Vector3(float(CONCOURSE[1]) - 1, -4, float(CONCOURSE[2]) - 1), Vector3(FLY_START + 1 - float(CONCOURSE[1]), 30, float(CONCOURSE[3]) - float(CONCOURSE[2]) + 2)),
	]
	var lp := func(r: float, a: float) -> Vector3: return _ring_point(LOOP, Vector3.LEFT, -1.0, r, a)
	var kp := func(r: float, a: float) -> Vector3: return _ring_point(KNUCKLE, Vector3.RIGHT, -1.0, r, a, DECK_Y)
	var front: Array = [Vector3(0, 0, 20), Vector3(-1.5, 0, -49), Vector3(1.5, 0, -57.8), Vector3(-1.5, 0, -67), Vector3(1, 0, -80)]
	var sweep: Array = [lp.call(21.0, 30.0), lp.call(21.0, 90.0), lp.call(21.0, 150.0), Vector3(43, 0, -90)]
	var tail: Array = [Vector3(49, 0, -37), Vector3(49, 0, -10), kp.call(9.0, 45.0), Vector3(34, FLY_Y, 6.5), Vector3(-30, FLY_Y, 6.5),
		Vector3(-35.25, 3.4, 6.5), Vector3(-42, 1.8, 6.5), Vector3(-61, 0, 6.5)]
	routes = {
		"basic": front + sweep + [Vector3(43, 0, -84.5), Vector3(35.8, 0, -84.5), Vector3(35.8, 0, -37), Vector3(46, 0, -36.5)] + tail,
		"advanced": front.slice(0, 4) + [Vector3(1, 0, -86), Vector3(5.5, 0, -91.5), Vector3(25, 0, -92), Vector3(43, 0, -90)] + [Vector3(43, 0, -84.5), Vector3(35.8, 0, -84.5), Vector3(35.8, 0, -37), Vector3(46, 0, -36.5)] + tail,
		"crouch": front + sweep.slice(0, 2) + [lp.call(24.5, 165.0), Vector3(48.4, 0, -90.6), Vector3(48.7, 0, -40)] + tail,
	}
	routes["ordinary"] = routes["basic"]
	routes["throat_recovery"] = [Vector3(0, BED, -53), Vector3(10.25, BED, -58), Vector3(10.25, DECK_Y, -44), Vector3(0, DECK_Y, -42)]
	routes["pit_recovery"] = [Vector3(14, BED, -100), Vector3(8, BED, -88), Vector3(7.75, DECK_Y, -73.5), Vector3(1, DECK_Y, -76)]
	_declare_gaps()

func _declare_gaps() -> void:
	# p / intended entry speeds are design choices for the earned line, not measurements.
	var previous := APRON_END
	var previous_x := 0.0
	for i: int in THROAT.size():
		var t: Array = THROAT[i]
		var x := (float(t[0]) + float(t[1])) * 0.5
		_gap("throat_%d" % (i + 1), "throat", "basic", Vector3(previous_x, 0, previous), Vector3(x, 0, float(t[2])), "throat_recovery", 0.0)
		previous = float(t[3])
		previous_x = x
	_gap("throat_to_loop", "throat", "basic", Vector3(previous_x, 0, previous), Vector3(1.0, 0, THROAT_END), "throat_recovery", 0.0)
	var tz := (float(TRAVERSER[2]) + float(TRAVERSER[3])) * 0.5
	_gap("traverser", "loop", "advanced", Vector3(R0[1], 0, tz), Vector3(float(TRAVERSER[0]), 0, tz), "pit_recovery", 420.0)
	var edge := FLY_END
	var top := FLY_Y
	for i: int in STEPS.size():
		var s: Array = STEPS[i]
		_gap("step_%d" % (i + 1), "canal", "basic", Vector3(edge, top, 6.5), Vector3(float(s[0]), float(s[2]), 6.5), "respawn: the flyover checkpoint", 0.0)
		edge = float(s[1])
		top = float(s[2])
	_gap("quay", "canal", "basic", Vector3(edge, top, 6.5), Vector3(float(CONCOURSE[0]), DECK_Y, 6.5), "respawn: the flyover checkpoint", 0.0)

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
		if piece.role in ["route", "catch", "recovery"]:
			var lo := Vector2(INF, INF)
			var hi := -lo
			for p: Vector3 in piece.points:
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			longest = maxf(longest, maxf(hi.x - lo.x, hi.y - lo.y))
	var roles := {}
	for piece: Dictionary in manifest:
		roles[piece.role] = int(roles.get(piece.role, 0)) + 1
	return {
		"level_id": LEVEL_ID, "level_name": LEVEL_NAME, "level_version": LEVEL_VERSION, "variant": variant,
		"units": {"u_m": U}, "vanilla_model": VANILLA, "judging": {"landing_margin_m": LANDING, "early_press_s": EARLY, "hull_credit": "none: feet centre to feet centre; screening only"},
		"stages": stages, "finish": {"title": finish_title, "box": [_v(_finish_box.position), _v(_finish_box.size)]},
		"gaps": gaps, "recovery": "throat misses walk back up the return ramp; loop-pit falls walk back up the pit ramp; a fall into the canal respawns at the last checkpoint",
		"longest_walkable_piece_m": snappedf(longest, 0.001), "crouch_required": false,
		"crouch_shortcut": {"piece": "s3_shutter", "sill_m": SHUTTER_SILL, "top_m": SHUTTER_H, "opening_u": roundi((SHUTTER_H - SHUTTER_SILL) / U), "standing_hull_u": 72, "duck_hull_u": 54, "technique": "jump, then crouch in the air", "line": "crouch"},
		"geometry_hash": geometry_hash(), "pieces": manifest.size(), "roles": roles, "trains": trains.size(),
	}

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
	if feet.y < DECK_Y - 0.6 and feet.y > BED - 0.5:
		if feet.z < APRON_END and feet.z > THROAT_END and absf(feet.x) < STATION_X:
			return "On the trackbed: walk right to the return ramp; it climbs back to the platform end."
		if feet.z < THROAT_END and feet.x > R0[1] - 0.5:
			return "In the loop pit: walk to the ramp at the loop's mouth (north-west corner) and climb back."
	match stage:
		0:
			return "Run down the platform and hop the throat. Esc opens stage practice."
		1:
			return "Slalom: aim each hop at the next lit cabinet. A miss drops onto the trackbed; the ramp on the right brings you back."
		2:
			return "Hold the strafe right round the loop; the inside edge is open. With speed, jump the pit onto the traverser bridge. Wide at the end lines up the east road door's hatch."
		3:
			return "Right through door 1, up the west bay and out its north end. Or, from the loop's outside lane, jump then crouch (Ctrl) through the hatch on the left for the straight east bay."
		4:
			if feet.x < RAMP[0] - 1.0 and feet.z < FORE_N:
				return "Left along the forecourt, then right up the ramp and round the signal box."
			return "Up the ramp and right round the signal box onto the flyover."
		5:
			return "Back over Platform 1, then hop down the steps over the canal to the Terminus."
	return "Cross the white line on the Terminus concourse."

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

func _train_run(label: String, x0: float, x1: float, z0: float, z1: float, rail: float, cars: int, model: String, width: float = CAR_W, length: float = CAR_L, height: float = CAR_H) -> void:
	# `cars` cars along z from z0 to z1, evenly spaced; every car is its own wall prism over
	# exactly the footprint and height it is drawn at.
	var span := absf(z1 - z0)
	var gap := (span - cars * length) / maxf(1.0, cars - 1)
	assert(gap >= 0.0 and gap < 0.6, "night shift: %s does not fit (%.3f)" % [label, gap])
	var sign := 1.0 if z1 > z0 else -1.0
	var at := z0
	for i: int in cars:
		var next := at + sign * length
		var centre := Vector3((x0 + x1) * 0.5, rail, (at + next) * 0.5)
		_car("%s_%02d" % [label, i + 1], centre, 0.0 if i % 2 == 0 else PI, width, length, height, model, "wall")
		at = next + sign * gap

func _car(label: String, feet: Vector3, yaw: float, width: float, length: float, height: float, model: String, role: String) -> void:
	# one car: a prism over its rotated footprint, rail to roof, and the model drawn on it.
	var along := Vector3(sin(yaw), 0, cos(yaw)) * length * 0.5
	var across := Vector3(cos(yaw), 0, -sin(yaw)) * width * 0.5
	var c := feet + Vector3.UP * height
	_solid(label, [c - along - across, c - along + across, c + along + across, c + along - across], feet.y, &"train", -1, role, false)
	trains.append({"name": label, "model": model, "feet": feet, "yaw": yaw, "height": height})

func _car_on_ring(label: String, centre: Vector3, r: float, degrees: float, rail: float, model: String, width: float, length: float) -> void:
	# a tram car whose inner long side touches radius r at its middle, along the ring's tangent.
	var radial := Vector3.LEFT.rotated(Vector3.UP, -deg_to_rad(degrees))
	var feet := Vector3(centre.x, rail, centre.z) + radial * (r + width * 0.5)
	var tangent := radial.rotated(Vector3.UP, -PI * 0.5)
	_car(label, feet, atan2(tangent.x, tangent.z), width, length, 2.301 * TRAIN_SCALE, model, "wall")

func _ring_point(centre: Vector3, start: Vector3, turn: float, r: float, degrees: float, y: float = DECK_Y) -> Vector3:
	# a point on a bend: `start` is the entry radius direction, turn +1 left, -1 right.
	var d := start.rotated(Vector3.UP, deg_to_rad(degrees) * turn)
	return Vector3(centre.x + d.x * r, y, centre.z + d.z * r)

func _ring_piece(label: String, centre: Vector3, start: Vector3, turn: float, r0: float, r1: float, a: float, b: float, y: float, kind: StringName, stage: int, base: float = BASE, role: String = "route") -> StaticBody3D:
	return _solid(label, [_ring_point(centre, start, turn, r0, a, y), _ring_point(centre, start, turn, r1, a, y), _ring_point(centre, start, turn, r1, b, y), _ring_point(centre, start, turn, r0, b, y)], base, kind, stage, role)

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid", draw: bool = true) -> StaticBody3D:
	# a convex prism: a planar convex top polygon extruded straight down to `base`.
	assert(not has_node(NodePath(label)), "night shift: duplicate piece " + label)
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

func _paint_z(label: String, x0: float, x1: float, z: float, width: float, y: float, kind: StringName) -> void:
	# a band across the line at z (x0 to x1), `width` along z toward the walking side.
	if is_zero_approx(width) or is_equal_approx(x0, x1):
		return
	_paint_line(label, Vector3(x0, y, z), Vector3(x1, y, z), Vector3(0, 0, width), kind)

func _lip_x(label: String, x: float, z0: float, z1: float, width: float, kind: StringName, y: float = DECK_Y) -> void:
	# a band along an edge at x from z0 to z1, `width` along x toward the deck.
	_paint_line(label, Vector3(x, y, z0), Vector3(x, y, z1), Vector3(width, 0, 0), kind)

func _paint_line(label: String, a: Vector3, b: Vector3, inward: Vector3, kind: StringName) -> void:
	# a flush painted band along an edge, `inward` across the walking side: visual only.
	var lift := Vector3.UP * 0.004
	_prism_visual([a + lift, b + lift, b + inward + lift, a + inward + lift], minf(a.y, b.y) - 0.02, kind)
	markings.append({"name": label, "kind": "strip", "a": _v(a), "b": _v(b), "paint": String(kind)})

func _gap_text(metres: float) -> String:
	return "%.1f m\n%d u" % [metres, roundi(metres / U)]

func _floor_label(label: String, at: Vector3, yaw: float, text: String) -> void:
	markings.append({"name": label, "kind": "floor", "at": at, "yaw": yaw, "text": text})

func _wall_label(label: String, at: Vector3, yaw: float, text: String) -> void:
	markings.append({"name": label, "kind": "wall", "at": at, "yaw": yaw, "text": text})

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
