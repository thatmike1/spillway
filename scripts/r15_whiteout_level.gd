extends Node3D
## p / r15 Whiteout Relay: an original snowy radar-station bhop course on a mountain ridge in late
## afternoon sun. it publishes the r14 level interface (spawn, checkpoints, segment and kill
## bounds, finish, routes, jump gaps, manifest, geometry hash, route hints, level identity), so
## r15_main.gd hosts it as map `whiteout-relay` and the approved source runner with real crouch
## plays it. nothing on the basic route needs crouch; one optional shortcut is a duck-jump.
## layout, numbers, recoveries and limits: docs/r15/WHITEOUT.md.
##
## course, in order (out along -z, round a half circle, back along +z):
##   service hangar (warm, enclosed) -> apron -> berm road (two cable-tray hurdles, two shallow
##   cable trenches you can jump out of) -> ridge foot -> four pylon tops climbing 0.4 m each in a
##   zigzag over a snow catch basin with a lit return stair -> the saddle, where the walled service
##   catwalk detours round the chasm, or a 6.5 m outside ridge jump crosses it -> the receiver deck,
##   a 14 m wide half ring round the big dish pit, open on its outer edge -> the cable works shed,
##   whose floor weaves round cable drums while a 1.5 m gantry along its west wall is a duck-jump
##   shortcut -> the relay road over a cable cut -> two terraces up to the relay house porch.
## falls in the catch basin and the cuts walk out; falls off the saddle, catwalk, chasm or the
## receiver deck's open edge drop into the cloud below the ridge and respawn at the last checkpoint.
##
## snow is appearance only: every surface here uses the approved movement unchanged, with no
## friction, acceleration or surface field of its own.
##
## collision: every solid is a convex prism or a convex hull. no walkable piece is longer than
## 32 m, and walkable decks are 0.9 m deep or more (the pylon tops; the rest 1.05 m): godot 4.7.2
## can miss a cast into a large single box (docs/r14/CONTACT-GUARD.md), so long runs are split
## into coplanar pieces on shared edges.

const Art := preload("res://scripts/r15_whiteout_art.gd")
const ASSETS := preload("res://scripts/r15_assets.gd")

## the identity r15_main.gd keys records and labels on. bump LEVEL_VERSION with any change to
## geometry, progress or timing semantics.
const LEVEL_ID := "r15-whiteout-relay"
const LEVEL_NAME := "Whiteout Relay"
const LEVEL_VERSION := 1
const VARIANTS := ["whiteout"]
## p / source units: 1 u = 0.0254 m (hammer inch), as the other r15 maps.
const U := 0.0254
## the vanilla cs:go figures behind the gap screening (docs/r14/SOURCE-REFERENCE.md). driven runs
## on the actual runner decide; these only sort gaps into tiers.
const VANILLA := {"run_ups": 250.0, "jump_ups": 301.993, "gravity_ups": 800.0}
const LANDING := 0.5
const EARLY := 0.1
const TIERS := [["vanilla_strafe", 330.0], ["server", 520.0], ["fast", INF]]
## the crouch runner's measured heights (docs/r15/CROUCH.md): standing jump peak, jump-then-crouch
## peak, both u above the take-off.
const STAND_PEAK_U := 55.87
const DUCK_PEAK_U := 64.87

const TRACK_Y := 0.0
## p / anything below this has dropped into the cloud under the ridge: respawn.
const KILL_Y := -6.0
const CLOUD_Y := -5.0
## ground-supported decks reach this deep; floating decks are SLAB thick.
const BASE := -3.0
const SLAB := 1.2
const WALL := 0.6
## walls and banks a jump from the deck beside them cannot top: a duck-jump reaches 1.65 m, and
## off a 0.55 m hurdle 2.2 m, so banks stand 2.4 m.
const BANK := 2.4
const RAIL := 1.1

## the service hangar and its apron.
const HANGAR_HALF := 12.0
const HANGAR_BACK := 14.0
const HANGAR_FRONT := -16.0
const HANGAR_ROOF := 8.0
const DOOR_HALF := 7.0
const APRON_HALF := 14.0
const APRON_END := -40.0
## the berm road between snow banks; hurdles [near z, depth], trenches [near z, far z].
const ROAD_HALF := 5.0
const ROAD_END := -112.0
const HURDLES := [[-55.0, 0.8], [-67.0, 0.8]]
const HURDLE_H := 0.55
const TRENCHES := [[-80.0, -82.0], [-95.0, -98.0]]
const TRENCH_FLOOR := -0.9
## the ridge foot, the catch basin under the pylons and its return stair (x from, x to).
const FOOT_END := -124.0
const BASIN_Y := -3.8
const BASIN_HALF := 12.0
const STAIR_X := [9.0, 12.0]
const STAIR_TOP_Z := -118.0
const STAIR_STEPS := 9
const STAIR_TREAD := 1.6
## pylons: [near z, far z, centre x, top].
const PYLONS := [
	[-126.0, -132.0, -1.5, 0.4],
	[-134.5, -140.5, 1.5, 0.8],
	[-143.5, -149.5, -1.5, 1.2],
	[-152.5, -158.5, 1.5, 1.6],
]
const PYLON_HALF := 3.5
## p / pylon slabs are thinner than the floating decks so a standing hull plus a jump clears
## their undersides from the basin floor (3.3 m at pylon 1).
const PYLON_SLAB := 0.9
const PIER_HALF := 1.5
## the saddle and the chasm in front of it.
const SADDLE_HALF := 9.0
const SADDLE_NEAR := -161.5
const SADDLE_END := -177.0
const SADDLE_Y := 2.0
## the receiver deck: a half ring round the dish pit, from the west point (angle 0) over the far
## side to the east point (180). the chasm is SADDLE_END to the ring's west radial edge.
const RECEIVER := Vector3(22.0, 1.0, -183.5)
const RING_IN := 16.0
const RING_OUT := 30.0
const RING_STEP := 12
const PIT_WALL := 2.2
## the service catwalk round the chasm: west from the saddle, down to deck level, east onto the ring.
const CAT_W := 4.0
const CAT_A := [-170.0, -174.0]
const CAT_WEST := -19.0
const CAT_B_END := -196.0
const CAT_C := [-196.0, -200.0]
const CAT_C_END := -2.5
## the cable works shed over the ring's east end, its gantry and drum blocks.
const SHED_X := [38.0, 52.0]
const SHED_NEAR := -183.5
const SHED_END := -128.0
const SHED_Y := 1.0
const SHED_ROOF := 7.0
const GANTRY_X := [38.0, 42.0]
const GANTRY_Z := [-177.0, -138.0]
const GANTRY_H := 1.5
const DRUM_R := 1.25
const DRUM_H := 2.4
## drum blocks: [x from, x to, z centre]: off the gantry, off the east wall, off the gantry again.
const DRUMS := [[42.0, 47.0, -168.5], [47.0, 52.0, -153.5], [42.0, 47.0, -139.5]]
## the relay road, its cable cut, the terraces and the house.
const CUT := [-110.0, -107.0]
const CUT_FLOOR := -0.2
const ROAD2_END := -96.0
const TERRACE_1 := [-96.0, -88.0, 1.8]
const TERRACE_2 := [-88.0, -76.0, 2.6]
const HOUSE := [-76.0, -64.0]
const FINISH_Z := [-82.0, -76.0]

## set by a factory before the level enters the tree; build() reads it once (r14 convention).
static var next_variant: String = ""

## p / not "course": the r14 overflow art pass dresses any "course" variant, and this map dresses itself.
var variant: String = "whiteout"
## "kit": the sourced kit and dressing; "neutral": flat colours for attribution runs.
var material_mode: String = "kit"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var finish_title: String = "Relay house"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 4.0
## p / no water: snow and ice are surfaces with the approved movement, never a region.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
## stage decks count only when their role is a route deck; catches never collect a stage.
var progress_roles: Array = ["route"]
var routes: Dictionary = {}
var jump_gaps: Array[Dictionary] = []
var kill_bounds := AABB(Vector3(-90, KILL_Y, -270), Vector3(240, 180 - KILL_Y, 330))
## every collision piece: name, world points, stage, role, kind. hashed without materials.
var manifest: Array[Dictionary] = []
## painted marks and labels: visual only, not hashed.
var markings: Array[Dictionary] = []
## prism tops and bases drawn by kind, from collision pieces and visual-only prisms alike.
var prisms: Array[Dictionary] = []
## upright drums to draw: centre of the base, radius, height.
var drums: Array[Dictionary] = []
## sourced models the level placed with collision of its own: model, feet, scale, yaw, body.
var props: Array[Dictionary] = []

var _finish_box := AABB()
var _built := false
var _art: RefCounted

func build() -> void:
	if _built:
		return
	_built = true
	if not next_variant.is_empty():
		variant = next_variant
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--whiteout-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "whiteout: unknown variant " + variant)
	_hangar()
	_berm_road()
	_ridge()
	_saddle()
	_catwalk()
	_receiver()
	_cable_works()
	_relay_road()
	_define_progress()
	_art = Art.new()
	_art.call("dress", self)

# --- stage 0: hangar, apron, berm road --------------------------------------------------------

func _hangar() -> void:
	# the service hangar: a warm enclosed hall, 24 m by 30 m under an 8 m roof, its doors open
	# onto the apron. the floor is two 15 m pieces.
	var h := HANGAR_HALF
	_deck("s0_hangar_floor_a", -h, h, HANGAR_BACK, -1.0, TRACK_Y, &"tread_warm", 0)
	_deck("s0_hangar_floor_b", -h, h, -1.0, HANGAR_FRONT, TRACK_Y, &"tread_warm", 0)
	_solid("s0_hangar_back", _rect(-h - WALL, h + WALL, HANGAR_BACK + WALL, HANGAR_BACK, HANGAR_ROOF), BASE, &"cladding_red", -1, "wall")
	for side: float in [-1.0, 1.0]:
		var x0 := h if side > 0.0 else -h - WALL
		var tag := "e" if side > 0.0 else "w"
		_solid("s0_hangar_side_%s_a" % tag, _rect(x0, x0 + WALL, HANGAR_BACK + WALL, -1.0, HANGAR_ROOF), BASE, &"cladding_red", -1, "wall")
		_solid("s0_hangar_side_%s_b" % tag, _rect(x0, x0 + WALL, -1.0, HANGAR_FRONT - WALL, HANGAR_ROOF), BASE, &"cladding_red", -1, "wall")
		var d0 := DOOR_HALF if side > 0.0 else -h - WALL
		var d1 := h + WALL if side > 0.0 else -DOOR_HALF
		_solid("s0_hangar_front_%s" % tag, _rect(d0, d1, HANGAR_FRONT, HANGAR_FRONT - WALL, HANGAR_ROOF), BASE, &"cladding_red", -1, "wall")
	# the door lintel and the roof are out of a jump's reach; they still carry collision.
	_solid("s0_hangar_lintel", _rect(-DOOR_HALF, DOOR_HALF, HANGAR_FRONT, HANGAR_FRONT - WALL, HANGAR_ROOF), 6.0, &"cladding_red", -1, "wall")
	_solid("s0_hangar_roof", _rect(-h - WALL, h + WALL, HANGAR_BACK + WALL, HANGAR_FRONT - WALL, HANGAR_ROOF + 0.6), HANGAR_ROOF, &"roof", -1, "wall")
	# reachable kit inside: two large generators and a wireless rack along the walls, with box
	# collision on their measured bounds (solid machines, no voids).
	_prop_solid("s0_generator_w", "kenney-space/models/machine_generatorLarge.glb", Vector3(-9.6, TRACK_Y, 6.0), 2.4, PI * 0.5)
	_prop_solid("s0_generator_e", "kenney-space/models/machine_generatorLarge.glb", Vector3(9.6, TRACK_Y, 2.0), 2.4, -PI * 0.5)
	_prop_solid("s0_wireless_e", "kenney-space/models/machine_wireless.glb", Vector3(10.4, TRACK_Y, -9.0), 2.0, -PI * 0.5)
	_paint_x("s0_start_line", -h, h, 6.0, 0.3, TRACK_Y, &"paint_warm")
	_paint_x("s0_door_line", -DOOR_HALF, DOOR_HALF, HANGAR_FRONT, 0.25, TRACK_Y, &"paint_yellow")
	# the apron: 28 m by 24 m of tread between snow banks, out to the berm road.
	_deck("s0_apron", -APRON_HALF, APRON_HALF, HANGAR_FRONT, APRON_END, TRACK_Y, &"tread", 0)
	for side: float in [-1.0, 1.0]:
		var tag := "e" if side > 0.0 else "w"
		var a := APRON_HALF if side > 0.0 else -APRON_HALF - 3.0
		_solid("s0_apron_bank_%s" % tag, _rect(a, a + 3.0, HANGAR_FRONT - WALL, APRON_END, TRACK_Y + BANK), BASE, &"snow_bank", -1, "wall")
		# the bank's shoulder where the apron narrows into the road.
		var c0 := ROAD_HALF if side > 0.0 else -APRON_HALF - 3.0
		var c1 := APRON_HALF + 3.0 if side > 0.0 else -ROAD_HALF
		_solid("s0_road_shoulder_%s" % tag, _rect(c0, c1, APRON_END, APRON_END - 4.0, TRACK_Y + BANK), BASE, &"snow_bank", -1, "wall")
		# the corner between the hangar's side wall and the bank, so the apron has no way round.
		var k0 := HANGAR_HALF + WALL if side > 0.0 else -APRON_HALF - 3.0
		var k1 := APRON_HALF + 3.0 if side > 0.0 else -HANGAR_HALF - WALL
		_solid("s0_apron_corner_%s" % tag, _rect(k0, k1, HANGAR_FRONT + 3.0, HANGAR_FRONT - WALL, TRACK_Y + BANK), BASE, &"snow_bank", -1, "wall")
	_prop_solid("s0_generator_apron", "kenney-space/models/machine_generator.glb", Vector3(-11.2, TRACK_Y, -30.0), 2.2, PI * 0.5)

func _berm_road() -> void:
	# stage 0: 72 m of service road between 2.4 m snow banks. two cable-tray hurdles teach the
	# jump without a fall; two shallow cable trenches teach a gap: a miss lands 0.9 m down, and a
	# jump out (forward or back) carries on. pieces end on the trench lips.
	var cuts: Array = [APRON_END]
	for t: Array in TRENCHES:
		cuts.append(t[0])
		cuts.append(t[1])
	cuts.append(ROAD_END)
	# the first run is split again at -64 so no piece passes 32 m.
	cuts.insert(1, -64.0)
	var k := 0
	for i: int in range(0, cuts.size() - 1):
		var z0: float = cuts[i]
		var z1: float = cuts[i + 1]
		if _in_trench(z0, z1):
			continue
		k += 1
		_deck("s0_road_%d" % k, -ROAD_HALF, ROAD_HALF, z0, z1, TRACK_Y, &"tread", 0)
	for i: int in TRENCHES.size():
		var t: Array = TRENCHES[i]
		_deck("s0_trench_%d" % (i + 1), -ROAD_HALF, ROAD_HALF, t[0], t[1], TRENCH_FLOOR, &"grate", -1, BASE, "catch")
		_paint_x("s0_trench_%d_near" % (i + 1), -ROAD_HALF, ROAD_HALF, float(t[0]), 0.3, TRACK_Y, &"paint_yellow")
		_paint_x("s0_trench_%d_far" % (i + 1), -ROAD_HALF, ROAD_HALF, float(t[1]), -0.3, TRACK_Y, &"paint_yellow")
		_floor_label("s0_trench_%d_gap" % (i + 1), Vector3(0, TRACK_Y, float(t[0]) + 1.2), 0.0, _gap_text(float(t[0]) - float(t[1])))
	for i: int in HURDLES.size():
		var hd: Array = HURDLES[i]
		_solid("s0_hurdle_%d" % (i + 1), _rect(-ROAD_HALF, ROAD_HALF, hd[0], float(hd[0]) - float(hd[1]), TRACK_Y + HURDLE_H), TRACK_Y - 0.5, &"hurdle", 0, "route")
	# the banks, in 24 m pieces down both sides.
	var z := APRON_END - 4.0
	var n := 0
	while z > ROAD_END + 0.01:
		var z1 := maxf(z - 24.0, ROAD_END)
		n += 1
		_solid("s0_bank_w_%d" % n, _rect(-ROAD_HALF - 3.0, -ROAD_HALF, z, z1, TRACK_Y + BANK), BASE, &"snow_bank", -1, "wall")
		_solid("s0_bank_e_%d" % n, _rect(ROAD_HALF, ROAD_HALF + 3.0, z, z1, TRACK_Y + BANK), BASE, &"snow_bank", -1, "wall")
		z = z1
	_paint_line("s0_edge_w", Vector3(-ROAD_HALF, TRACK_Y, APRON_END), Vector3(-ROAD_HALF, TRACK_Y, ROAD_END), Vector3(0.25, 0, 0), &"paint_yellow")
	_paint_line("s0_edge_e", Vector3(ROAD_HALF, TRACK_Y, APRON_END), Vector3(ROAD_HALF, TRACK_Y, ROAD_END), Vector3(-0.25, 0, 0), &"paint_yellow")

func _in_trench(z0: float, z1: float) -> bool:
	for t: Array in TRENCHES:
		if is_equal_approx(z0, float(t[0])) and is_equal_approx(z1, float(t[1])):
			return true
	return false

# --- stage 1: ridge foot and pylons -----------------------------------------------------------

func _ridge() -> void:
	# the ridge foot: an 18 m deck where the road meets the ridge, with a landing on the right for
	# the return stair. a small warm shelter stands in its left corner.
	_deck("s1_foot", -SADDLE_HALF, SADDLE_HALF, ROAD_END, FOOT_END, TRACK_Y, &"tread", 1)
	_deck("s1_stair_landing", STAIR_X[0], STAIR_X[1], ROAD_END, STAIR_TOP_Z, TRACK_Y, &"tread", 1)
	# banks either side of the road's end close the foot's corners toward the hangar.
	_solid("s1_foot_bank_w", _rect(-BASIN_HALF - 2.5, -ROAD_HALF, ROAD_END + 4.0, ROAD_END, TRACK_Y + BANK), BASE - 2.0, &"snow_bank", -1, "wall")
	_solid("s1_foot_bank_e", _rect(ROAD_HALF, BASIN_HALF + 2.5, ROAD_END + 4.0, ROAD_END, TRACK_Y + BANK), BASE - 2.0, &"snow_bank", -1, "wall")
	_solid("s1_shelter", _rect(-SADDLE_HALF, -SADDLE_HALF + 3.0, ROAD_END, ROAD_END - 3.2, TRACK_Y + 2.6), BASE, &"cladding_orange", -1, "wall")
	# the catch basin: a snow hollow 3.8 m under the foot, the full width between rock walls, in
	# two pieces. the walls top out at the foot's level; nothing in the basin leads forward.
	_deck("s1_basin_a", -BASIN_HALF, BASIN_HALF, FOOT_END + 12.0, -137.0, BASIN_Y, &"snow", -1, BASE - 2.0, "catch")
	_deck("s1_basin_b", -BASIN_HALF, BASIN_HALF, -137.0, SADDLE_NEAR, BASIN_Y, &"snow", -1, BASE - 2.0, "catch")
	_solid("s1_basin_wall_w", _rect(-BASIN_HALF - 2.5, -BASIN_HALF, ROAD_END, SADDLE_NEAR, TRACK_Y), BASE - 2.0, &"rock", -1, "wall")
	_solid("s1_basin_wall_e", _rect(BASIN_HALF, BASIN_HALF + 2.5, ROAD_END, SADDLE_NEAR, TRACK_Y), BASE - 2.0, &"rock", -1, "wall")
	# the basin's far corners beside the saddle's rock face.
	_solid("s1_basin_end_w", _rect(-BASIN_HALF - 2.5, -SADDLE_HALF, SADDLE_NEAR, SADDLE_NEAR - 2.5, TRACK_Y), BASE - 2.0, &"rock", -1, "wall")
	_solid("s1_basin_end_e", _rect(SADDLE_HALF, BASIN_HALF + 2.5, SADDLE_NEAR, SADDLE_NEAR - 2.5, TRACK_Y), BASE - 2.0, &"rock", -1, "wall")
	# the return stair: nine 0.42 m steps (under the 0.457 m step height) up the basin's east
	# side to the foot's landing. a miss walks back and tries again.
	for k: int in range(1, STAIR_STEPS + 1):
		var near := STAIR_TOP_Z - (STAIR_STEPS - k + 1) * STAIR_TREAD
		var far := near + STAIR_TREAD
		var top := BASIN_Y + k * (TRACK_Y - BASIN_Y) / STAIR_STEPS
		_solid("s1_stair_%d" % k, _rect(STAIR_X[0], STAIR_X[1], far, near, top), BASE - 2.0, &"tread", -1, "recovery")
	_paint_line("s1_stair_edge", Vector3(STAIR_X[0], TRACK_Y, STAIR_TOP_Z), Vector3(STAIR_X[1], TRACK_Y, STAIR_TOP_Z), Vector3(0, 0, 0.25), &"paint_yellow")
	# the pylons: tread slabs on concrete piers, each 0.4 m above the last, alternating 1.5 m to
	# each side so the line zigzags up the ridge. their lips are painted.
	var previous := FOOT_END
	for i: int in PYLONS.size():
		var p: Array = PYLONS[i]
		var cx: float = p[2]
		var top: float = p[3]
		_deck("s1_pylon_%d" % (i + 1), cx - PYLON_HALF, cx + PYLON_HALF, p[0], p[1], top, &"tread", 1, top - PYLON_SLAB)
		var mid := (float(p[0]) + float(p[1])) * 0.5
		_solid("s1_pier_%d" % (i + 1), _rect(cx - PIER_HALF, cx + PIER_HALF, mid + PIER_HALF, mid - PIER_HALF, top - PYLON_SLAB), BASE - 2.0, &"concrete", -1, "wall")
		_paint_x("s1_pylon_%d_near" % (i + 1), cx - PYLON_HALF, cx + PYLON_HALF, float(p[0]), -0.3, top, &"paint_yellow")
		_paint_x("s1_pylon_%d_far" % (i + 1), cx - PYLON_HALF, cx + PYLON_HALF, float(p[1]), 0.3, top, &"paint_yellow")
		var from_top := TRACK_Y if i == 0 else float(PYLONS[i - 1][3])
		_floor_label("s1_gap_%d" % (i + 1), Vector3(cx * 0.5 if i > 0 else 0.0, from_top, previous + 1.0), 0.0, _gap_text(previous - float(p[0])) + "  ▲0.4")
		previous = p[1]
	_paint_x("s1_foot_lip", -SADDLE_HALF, SADDLE_HALF, FOOT_END, 0.3, TRACK_Y, &"paint_yellow")
	_floor_label("s1_gap_saddle", Vector3(0.75, float(PYLONS[-1][3]), previous + 1.0), 0.0, _gap_text(previous - SADDLE_NEAR) + "  ▲0.4")

# --- stage 2: the saddle and its catwalk ------------------------------------------------------

func _saddle() -> void:
	# the saddle: a rock shoulder with an 18 m tread deck at the top of the pylon line, the
	# decision point. ahead is the chasm and, 1 m down across it, the receiver deck; left is the
	# walled service catwalk. its sides fall to the cloud.
	_deck("s2_saddle", -SADDLE_HALF, SADDLE_HALF, SADDLE_NEAR, SADDLE_END, SADDLE_Y, &"tread", 2, BASE - 2.0)
	_solid("s2_shelter", _rect(SADDLE_HALF - 3.0, SADDLE_HALF, SADDLE_NEAR - 0.5, SADDLE_NEAR - 3.7, SADDLE_Y + 2.6), BASE - 2.0, &"cladding_orange", -1, "wall")
	_paint_x("s2_saddle_near", -SADDLE_HALF, SADDLE_HALF, SADDLE_NEAR, -0.3, SADDLE_Y, &"paint_yellow")
	# the chasm lip, hazard banded, and its width.
	_paint_x("s2_chasm_lip", -SADDLE_HALF, SADDLE_HALF, SADDLE_END, 0.4, SADDLE_Y, &"paint_yellow")
	for k: int in 9:
		var x0 := -SADDLE_HALF + 0.5 + k * 2.0
		_paint_line("s2_hazard_%d" % k, Vector3(x0, SADDLE_Y, SADDLE_END + 2.6), Vector3(x0 + 1.0, SADDLE_Y, SADDLE_END + 2.6), Vector3(0, 0, -1.0), &"paint_yellow")
	_floor_label("s2_chasm_gap", Vector3(2.5, SADDLE_Y, SADDLE_END + 1.4), 0.0, "%.1f m  ·  1 m down\n%d u" % [SADDLE_END - RECEIVER.z, roundi((SADDLE_END - RECEIVER.z) / U)])
	_paint_line("s2_side_w", Vector3(-SADDLE_HALF, SADDLE_Y, SADDLE_NEAR), Vector3(-SADDLE_HALF, SADDLE_Y, CAT_A[0]), Vector3(0.3, 0, 0), &"paint_yellow")
	_paint_line("s2_side_e", Vector3(SADDLE_HALF, SADDLE_Y, SADDLE_NEAR), Vector3(SADDLE_HALF, SADDLE_Y, SADDLE_END), Vector3(-0.3, 0, 0), &"paint_yellow")

func _catwalk() -> void:
	# the service catwalk: 4 m of tread between 1.1 m rails. west off the saddle, a 22 m ramp down
	# 1 m, then east onto the receiver deck's outer edge. three turns and no gap.
	var y := SADDLE_Y
	var low := RECEIVER.y
	_deck("s2_cat_a", CAT_WEST, -SADDLE_HALF, CAT_A[0], CAT_A[1], y, &"tread", 2, y - SLAB)
	_solid("s2_cat_b", [Vector3(CAT_WEST, y, CAT_A[1]), Vector3(CAT_WEST + CAT_W, y, CAT_A[1]), Vector3(CAT_WEST + CAT_W, low, CAT_B_END), Vector3(CAT_WEST, low, CAT_B_END)], low - SLAB, &"tread", 2, "route")
	_deck("s2_cat_c", CAT_WEST, CAT_C_END, CAT_C[0], CAT_C[1], low, &"tread", 2, low - SLAB)
	# rails. the leg-c rails stop short of the deck they open onto.
	var t := 0.3
	_solid("s2_rail_a_n", _rect(CAT_WEST, -SADDLE_HALF, CAT_A[0] + t, CAT_A[0], y + RAIL), y - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_a_s", _rect(CAT_WEST + CAT_W, -SADDLE_HALF, CAT_A[1], CAT_A[1] - t, y + RAIL), y - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_w_a", _rect(CAT_WEST - t, CAT_WEST, CAT_A[0] + t, CAT_A[1], y + RAIL), y - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_b_w", [Vector3(CAT_WEST - t, y + RAIL, CAT_A[1]), Vector3(CAT_WEST, y + RAIL, CAT_A[1]), Vector3(CAT_WEST, low + RAIL, CAT_B_END), Vector3(CAT_WEST - t, low + RAIL, CAT_B_END)], low - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_b_e", [Vector3(CAT_WEST + CAT_W, y + RAIL, CAT_A[1] - t), Vector3(CAT_WEST + CAT_W + t, y + RAIL, CAT_A[1] - t), Vector3(CAT_WEST + CAT_W + t, low + RAIL, CAT_C[0]), Vector3(CAT_WEST + CAT_W, low + RAIL, CAT_C[0])], low - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_w_c", _rect(CAT_WEST - t, CAT_WEST, CAT_B_END, CAT_C[1] - t, low + RAIL), low - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_c_n", _rect(CAT_WEST + CAT_W, -6.0, CAT_C[0] + t, CAT_C[0], low + RAIL), low - SLAB, &"rail", -1, "wall")
	_solid("s2_rail_c_s", _rect(CAT_WEST, -4.5, CAT_C[1], CAT_C[1] - t, low + RAIL), low - SLAB, &"rail", -1, "wall")
	# trestle legs down into the cloud under each corner and mid ramp.
	for leg: Array in [[CAT_WEST + 0.6, CAT_A[0] - 0.6], [-10.6, CAT_A[0] - 0.6], [CAT_WEST + 0.6, -185.0], [CAT_WEST + 3.4, -185.0], [CAT_WEST + 0.6, CAT_C[1] + 0.6], [-9.0, CAT_C[1] + 0.6]]:
		var top := low - SLAB if float(leg[1]) < -180.0 else y - SLAB
		_solid("s2_leg_%d_%d" % [roundi(absf(float(leg[0]))), roundi(absf(float(leg[1])))], _rect(float(leg[0]) - 0.3, float(leg[0]) + 0.3, float(leg[1]) + 0.3, float(leg[1]) - 0.3, top), KILL_Y - 4.0, &"frame", -1, "wall")
	_paint_line("s2_cat_turn", Vector3(CAT_WEST, y, CAT_A[1]), Vector3(CAT_WEST + CAT_W, y, CAT_A[1]), Vector3(0, 0, -0.2), &"paint_yellow")
	_wall_label("s2_cat_sign", Vector3(-9.2, y + 1.6, CAT_A[0] + 0.32), 0.0, "SERVICE WALK\n◄  receiver deck")

# --- stage 3: the receiver deck ---------------------------------------------------------------

func _ring_point(r: float, degrees: float, y: float) -> Vector3:
	# a point on the receiver ring: angle 0 is the west point, 90 the far (-z) side, 180 east.
	var a := deg_to_rad(degrees)
	return Vector3(RECEIVER.x - cos(a) * r, y, RECEIVER.z - sin(a) * r)

func _receiver() -> void:
	# stage 3: a 14 m wide half ring of tread round the dish pit, 63 m round its middle. the inner
	# edge is the pit's 2.2 m wall, over any jump's reach; the outer edge is open to the cloud. 15 pieces of 12 degrees.
	var y := RECEIVER.y
	for a: int in range(0, 180, RING_STEP):
		var top := [_ring_point(RING_IN, a, y), _ring_point(RING_OUT, a, y), _ring_point(RING_OUT, a + RING_STEP, y), _ring_point(RING_IN, a + RING_STEP, y)]
		_solid("s3_ring_%03d" % a, top, y - SLAB, &"tread", 3, "route")
		_solid("s3_pit_wall_%03d" % a, [_ring_point(RING_IN - 0.5, a, y + PIT_WALL), _ring_point(RING_IN, a, y + PIT_WALL), _ring_point(RING_IN, a + RING_STEP, y + PIT_WALL), _ring_point(RING_IN - 0.5, a + RING_STEP, y + PIT_WALL)], y - SLAB, &"concrete", -1, "wall")
		var inward := (_ring_point(RING_OUT - 1.0, a + RING_STEP * 0.5, y) - _ring_point(RING_OUT, a + RING_STEP * 0.5, y)).normalized() * 0.4
		_paint_line("s3_edge_%03d" % a, _ring_point(RING_OUT, a, y), _ring_point(RING_OUT, a + RING_STEP, y), inward, &"paint_yellow")
		# piers under each seam, down into the cloud.
		_solid("s3_pier_%03d" % a, _ring_square(RING_OUT - 2.0, a + RING_STEP * 0.5, 0.5, y - SLAB), KILL_Y - 4.0, &"concrete", -1, "wall")
	_paint_line("s3_start", _ring_point(RING_IN, 0, y), _ring_point(RING_OUT, 0, y), Vector3(0, 0, -0.35), &"paint_yellow")
	# distance marks every 30 degrees along the middle line.
	for a: int in [30, 60, 90, 120, 150]:
		_floor_label("s3_mark_%03d" % a, _ring_point(RING_IN + 2.0, a, y), deg_to_rad(-a), "%d°" % a)

func _ring_square(r: float, degrees: float, half: float, y: float) -> Array:
	var c := _ring_point(r, degrees, y)
	return _rect(c.x - half, c.x + half, c.z + half, c.z - half, y)

# --- stage 4: cable works, relay road, house --------------------------------------------------

func _cable_works() -> void:
	# stage 4: the cable works shed, 14 m by 55.5 m under a 6 m roof, open at both ends. the floor
	# line weaves round three blocks of cable drums (5 m passages: east, west, east). along the
	# west wall a 1.5 m gantry runs 39 m straight: 59 u, over a standing jump's 55.9 u peak and
	# under jump-then-crouch's 64.9 u. the shed roof is 4.5 m over it, so standing up is never
	# refused there. the gantry face is painted with the crouch key.
	var y := SHED_Y
	var x0: float = SHED_X[0]
	var x1: float = SHED_X[1]
	var mid := (SHED_NEAR + SHED_END) * 0.5
	_deck("s4_shed_floor_a", x0, x1, SHED_NEAR, mid, y, &"tread_warm", 4)
	_deck("s4_shed_floor_b", x0, x1, mid, SHED_END, y, &"tread_warm", 4)
	for i: int in 2:
		var za := SHED_NEAR if i == 0 else mid
		var zb := mid if i == 0 else SHED_END
		_solid("s4_shed_wall_w_%d" % (i + 1), _rect(x0 - WALL, x0, za, zb, SHED_ROOF), BASE, &"cladding_slate", -1, "wall")
		_solid("s4_shed_wall_e_%d" % (i + 1), _rect(x1, x1 + WALL, za, zb, SHED_ROOF), BASE, &"cladding_slate", -1, "wall")
		_solid("s4_shed_roof_%d" % (i + 1), _rect(x0 - WALL, x1 + WALL, za, zb, SHED_ROOF + 0.5), SHED_ROOF, &"roof", -1, "wall")
	for end: Array in [["near", SHED_NEAR, SHED_NEAR - 0.4], ["far", SHED_END + 0.4, SHED_END]]:
		_solid("s4_lintel_%s" % end[0], _rect(x0 - WALL, x1 + WALL, end[1], end[2], SHED_ROOF), SHED_ROOF - 1.2, &"frame", -1, "wall")
	var g0: float = GANTRY_Z[0]
	var g1: float = GANTRY_Z[1]
	var gm := (g0 + g1) * 0.5
	_deck("s4_gantry_a", GANTRY_X[0], GANTRY_X[1], g0, gm, y + GANTRY_H, &"tread", 4, y - 0.5)
	_deck("s4_gantry_b", GANTRY_X[0], GANTRY_X[1], gm, g1, y + GANTRY_H, &"tread", 4, y - 0.5)
	_paint_x("s4_gantry_lip", GANTRY_X[0], GANTRY_X[1], g0, 0.3, y + GANTRY_H, &"paint_yellow")
	_paint_x("s4_gantry_end", GANTRY_X[0], GANTRY_X[1], g1, -0.3, y + GANTRY_H, &"paint_yellow")
	_paint_line("s4_gantry_edge", Vector3(GANTRY_X[1], y + GANTRY_H, g0), Vector3(GANTRY_X[1], y + GANTRY_H, g1), Vector3(-0.25, 0, 0), &"paint_yellow")
	_wall_label("s4_gantry_face", Vector3((GANTRY_X[0] + GANTRY_X[1]) * 0.5, y + 0.75, g0 - 0.02), PI, "DUCK-JUMP\njump, then\ncrouch (C)", 0.0055)
	_floor_label("s4_gantry_hint", Vector3((GANTRY_X[0] + GANTRY_X[1]) * 0.5, y, g0 - 3.0), PI, "1.5 m\n59 u")
	# the drum blocks: two upright cable drums on a solid winch housing between them, so no
	# crevice is left between drum and wall.
	for i: int in DRUMS.size():
		var d: Array = DRUMS[i]
		var zc: float = d[2]
		_solid("s4_winch_%d" % (i + 1), _rect(float(d[0]) + DRUM_R * 0.5, float(d[1]) - DRUM_R * 0.5, zc + DRUM_R * 0.8, zc - DRUM_R * 0.8, y + DRUM_H - 0.3), y - 0.5, &"machine", -1, "wall")
		for k: int in 2:
			var cx := float(d[0]) + DRUM_R + k * 2.0 * DRUM_R
			_drum("s4_drum_%d_%d" % [i + 1, k + 1], Vector3(cx, y, zc))
	_paint_line("s4_shed_mouth", Vector3(x0, y, SHED_NEAR), Vector3(x1, y, SHED_NEAR), Vector3(0, 0, 0.3), &"paint_warm")
	_wall_label("s4_sign", Vector3((x0 + x1) * 0.5, SHED_ROOF - 0.6, SHED_NEAR - 0.42), PI, "CABLE WORKS")

func _relay_road() -> void:
	# stage 4 ends: the relay road between snow banks, a 3 m cable cut (1.2 m deep, a jump out),
	# then two 0.8 m terraces up to the relay house. the finish band is the porch on terrace two.
	var y := SHED_Y
	var x0: float = SHED_X[0]
	var x1: float = SHED_X[1]
	_deck("s4_road_a", x0, x1, SHED_END, CUT[0], y, &"tread", 4)
	_deck("s4_cut", x0, x1, CUT[0], CUT[1], CUT_FLOOR, &"grate", -1, BASE, "catch")
	_deck("s4_road_b", x0, x1, CUT[1], ROAD2_END, y, &"tread", 4)
	_deck("s4_terrace_1", x0, x1, TERRACE_1[0], TERRACE_1[1], TERRACE_1[2], &"tread", 4)
	_deck("s4_terrace_2", x0, x1, TERRACE_2[0], TERRACE_2[1], TERRACE_2[2], &"tread_warm", 4)
	_paint_x("s4_cut_near", x0, x1, CUT[0], -0.3, y, &"paint_yellow")
	_paint_x("s4_cut_far", x0, x1, CUT[1], 0.3, y, &"paint_yellow")
	_floor_label("s4_cut_gap", Vector3((x0 + x1) * 0.5, y, CUT[0] - 1.2), PI, _gap_text(CUT[1] - CUT[0]))
	_paint_x("s4_step_1", x0, x1, TERRACE_1[0], 0.3, TERRACE_1[2], &"paint_yellow")
	_paint_x("s4_step_2", x0, x1, TERRACE_2[0], 0.3, TERRACE_2[2], &"paint_yellow")
	# banks along both sides, from the shed's end to the house.
	var z := SHED_END
	var n := 0
	while z < HOUSE[0] - 0.01:
		var z1 := minf(z + 26.0, HOUSE[0])
		n += 1
		_solid("s4_bank_w_%d" % n, _rect(x0 - 3.0, x0, z, z1, TERRACE_2[2] + BANK), BASE, &"snow_bank", -1, "wall")
		_solid("s4_bank_e_%d" % n, _rect(x1, x1 + 3.0, z, z1, TERRACE_2[2] + BANK), BASE, &"snow_bank", -1, "wall")
		z = z1
	# the relay house: a solid block with a porch canopy 3.6 m over terrace two.
	_solid("s4_house", _rect(x0 - 3.0, x1 + 3.0, HOUSE[0], HOUSE[1], TERRACE_2[2] + 5.2), BASE, &"cladding_red", -1, "wall")
	_solid("s4_porch_roof", _rect(x0, x1, FINISH_Z[0] - 0.5, HOUSE[0], TERRACE_2[2] + 3.9), TERRACE_2[2] + 3.6, &"roof", -1, "wall")
	var top := float(TERRACE_2[2])
	_finish_box = AABB(Vector3(x0, top - 0.2, FINISH_Z[0]), Vector3(x1 - x0, 3.4, float(FINISH_Z[1]) - float(FINISH_Z[0])))
	finish_position = Vector3((x0 + x1) * 0.5, top, (float(FINISH_Z[0]) + float(FINISH_Z[1])) * 0.5)
	_paint_x("s4_finish_line", x0, x1, FINISH_Z[0], 0.45, top, &"paint_warm")

# --- progress, finish and hints --------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their decks (radius 0 turns off the distance rule), so
	# a flight over a gap never collects the deck beyond it.
	spawn = _pose(Vector3(0, TRACK_Y, 8.0), 0.0)
	var cp3 := _ring_point(23.0, 8.0, RECEIVER.y)
	checkpoints = [
		{"pose": spawn, "title": "Hangar"},
		{"pose": _pose(Vector3(0, TRACK_Y, ROAD_END - 3.0), 0.0), "title": "Ridge", "radius": 0.0},
		{"pose": _pose(Vector3(0, SADDLE_Y, SADDLE_NEAR - 4.0), 0.0), "title": "Saddle", "radius": 0.0},
		{"pose": _pose(cp3, deg_to_rad(-8.0)), "title": "Receiver deck", "radius": 0.0},
		{"pose": _pose(Vector3(46.5, SHED_Y, SHED_NEAR + 3.0), PI), "title": "Cable works", "radius": 0.0},
	]
	segment_bounds = [
		AABB(Vector3(-APRON_HALF - 1, -2, ROAD_END), Vector3(2 * APRON_HALF + 2, 30, HANGAR_BACK - ROAD_END)),
		AABB(Vector3(-BASIN_HALF, -4, SADDLE_NEAR), Vector3(2 * BASIN_HALF, 30, ROAD_END - SADDLE_NEAR)),
		AABB(Vector3(CAT_WEST - 1, -4, CAT_C[1] - 1), Vector3(SADDLE_HALF - CAT_WEST + 1, 30, SADDLE_NEAR - CAT_C[1] + 1)),
		AABB(Vector3(RECEIVER.x - RING_OUT - 1, -4, RECEIVER.z - RING_OUT - 1), Vector3(2 * RING_OUT + 2, 30, RING_OUT + 1)),
		AABB(Vector3(SHED_X[0] - 1, -4, SHED_NEAR), Vector3(SHED_X[1] - SHED_X[0] + 2, 30, HOUSE[0] - SHED_NEAR)),
	]
	var mid_x := (SHED_X[0] + SHED_X[1]) * 0.5
	var front: Array = [Vector3(0, 0, -20), Vector3(0, 0, ROAD_END)]
	for p: Array in PYLONS:
		front.append(Vector3(float(p[2]) * 0.5, float(p[3]), (float(p[0]) + float(p[1])) * 0.5))
	front.append(Vector3(0, SADDLE_Y, SADDLE_NEAR - 6.0))
	var ring: Array = []
	for a: int in [45, 90, 135, 170]:
		ring.append(_ring_point(23.0, a, RECEIVER.y))
	var shed: Array = [Vector3(49.5, SHED_Y, -168.5), Vector3(44.5, SHED_Y, -153.5), Vector3(49.5, SHED_Y, -139.5), Vector3(mid_x, SHED_Y, CUT[0] - 2.0),
		Vector3(mid_x, SHED_Y, ROAD2_END - 2.0), Vector3(mid_x, TERRACE_2[2], FINISH_Z[0] + 2.0)]
	routes = {
		"basic": front + [Vector3(-14, SADDLE_Y, -172), Vector3(-17, RECEIVER.y + 0.5, -185), Vector3(-10, RECEIVER.y, -198)] + ring + shed,
		"advanced": front + [Vector3(0, RECEIVER.y, RECEIVER.z - 3.0)] + ring + shed,
		"gantry": [Vector3(40, SHED_Y, -180), Vector3(40, SHED_Y + GANTRY_H, -170), Vector3(40, SHED_Y + GANTRY_H, -140)] + shed.slice(3),
	}
	routes["ordinary"] = routes["basic"]
	routes["basin_recovery"] = [Vector3(0, BASIN_Y, -136), Vector3(10.5, BASIN_Y, -134), Vector3(10.5, TRACK_Y, STAIR_TOP_Z), Vector3(0, TRACK_Y, ROAD_END - 6.0)]
	_declare_gaps()

func _declare_gaps() -> void:
	# p / intended entry speeds are design choices for the earned line, not measurements.
	for i: int in TRENCHES.size():
		var t: Array = TRENCHES[i]
		_gap("trench_%d" % (i + 1), "berm_road", "basic", Vector3(0, 0, t[0]), Vector3(0, 0, t[1]), 0.0, "walk out: jump 0.9 m up out of the trench", 0.0)
	var previous := FOOT_END
	var previous_top := TRACK_Y
	for i: int in PYLONS.size():
		var p: Array = PYLONS[i]
		_gap("pylon_%d" % (i + 1), "ridge", "basic", Vector3(float(p[2]) * 0.5, previous_top, previous), Vector3(float(p[2]), float(p[3]), float(p[0])), float(p[3]) - previous_top, "basin: the return stair to the ridge foot", 0.0)
		previous = p[1]
		previous_top = p[3]
	_gap("pylon_to_saddle", "ridge", "basic", Vector3(0.75, previous_top, previous), Vector3(0, SADDLE_Y, SADDLE_NEAR), SADDLE_Y - previous_top, "basin: the return stair to the ridge foot", 0.0)
	_gap("chasm", "saddle", "advanced", Vector3(0, SADDLE_Y, SADDLE_END), Vector3(0, RECEIVER.y, RECEIVER.z), RECEIVER.y - SADDLE_Y, "respawn: the saddle checkpoint", 420.0)
	_gap("cable_cut", "relay_road", "basic", Vector3(45, SHED_Y, CUT[0]), Vector3(45, SHED_Y, CUT[1]), 0.0, "walk out: jump 1.2 m up out of the cut", 0.0)

func _gap(label: String, section: String, line: String, edge: Vector3, land: Vector3, climb: float, recovery: String, intended_ups: float) -> void:
	# a declared jump, screened with the vanilla figures, feet centre to feet centre. a climb
	# (land above the edge) shortens the flight.
	var distance := Vector2(land.x - edge.x, land.z - edge.z).length()
	var drop := -climb
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
		"label": label, "section": section, "line": line, "edge": edge, "land": land, "climb": snappedf(climb, 0.01),
		"kind": "ordinary" if line == "basic" else "earned",
		"speed": snappedf(intended * U, 0.01), "drained": snappedf(run_mps, 0.01),
		"width_m": snappedf(distance, 0.01), "width_u": roundi(distance / U), "drop_m": snappedf(drop, 0.01),
		"flight_s": snappedf(t, 0.001), "clear_ups": roundi(clear_mps / U), "comfortable_ups": roundi(comfortable_mps / U),
		"intended_ups": roundi(intended), "tier": tier, "recovery": recovery,
	})

## flight time of a vanilla jump that lands `drop` metres below its take-off (negative: above).
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
	var longest_name := ""
	var thinnest := INF
	var thinnest_name := ""
	for piece: Dictionary in manifest:
		if piece.role == "route" or piece.role == "catch" or piece.role == "recovery":
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for p: Vector3 in piece.points:
				lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
				hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
			var span := maxf(hi.x - lo.x, hi.z - lo.z)
			if span > longest:
				longest = span
				longest_name = piece.name
			var depth := _min_depth(piece)
			if depth < thinnest:
				thinnest = depth
				thinnest_name = piece.name
	return {
		"level_id": LEVEL_ID, "level_name": LEVEL_NAME, "level_version": LEVEL_VERSION, "variant": variant,
		"units": {"u_m": U}, "vanilla_model": VANILLA, "judging": {"landing_margin_m": LANDING, "early_press_s": EARLY, "hull_credit": "none: feet centre to feet centre; screening only"},
		"stages": stages, "finish": {"title": finish_title, "box": [_v(_finish_box.position), _v(_finish_box.size)]},
		"gaps": gaps, "recovery": "trenches and the cable cut are jumped out of; the pylon basin walks back up the return stair to the ridge foot; a fall into the cloud respawns at the last checkpoint",
		"crouch_required": false,
		"crouch_optional": {"piece": "s4_gantry_a", "height_m": GANTRY_H, "height_u": snappedf(GANTRY_H / U, 0.01), "standing_peak_u": STAND_PEAK_U, "duck_jump_peak_u": DUCK_PEAK_U,
			"headroom_above_m": SHED_ROOF - SHED_Y - GANTRY_H, "saves": "the drum weave on the shed floor"},
		"surfaces": "snow, ice and tread are appearance only; no surface changes the approved movement",
		"longest_walkable_piece_m": snappedf(longest, 0.001), "longest_walkable_piece": longest_name,
		"thinnest_walkable_depth_m": snappedf(thinnest, 0.001), "thinnest_walkable_piece": thinnest_name,
		"geometry_hash": geometry_hash(), "pieces": manifest.size(), "props_with_collision": props.size(),
	}

func _min_depth(piece: Dictionary) -> float:
	# the shallowest vertical extent of a prism under its top: top points minus the base.
	var pts: Array = piece.points
	var half := pts.size() / 2
	var depth := INF
	for i: int in half:
		depth = minf(depth, (pts[i] as Vector3).y - (pts[i + half] as Vector3).y)
	return depth

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
	if feet.y < TRACK_Y - 1.0 and feet.y > BASIN_Y - 0.6 and feet.z < FOOT_END and feet.z > SADDLE_NEAR and absf(feet.x) < BASIN_HALF:
		return "In the catch basin: the lit stair on the right climbs back to the ridge foot."
	for t: Array in TRENCHES:
		if feet.y < TRACK_Y - 0.3 and feet.z < float(t[0]) and feet.z > float(t[1]):
			return "In a cable trench: jump out and carry on."
	if feet.y < SHED_Y - 0.3 and feet.z > CUT[0] and feet.z < CUT[1] and feet.x > SHED_X[0]:
		return "In the cable cut: jump out and carry on."
	match stage:
		0:
			return "Run out of the hangar and down the berm road. Hop the trays and the trenches. Esc opens stage practice."
		1:
			return "Hop the pylons up the ridge. A miss lands in the basin; the stair on the right brings you back."
		2:
			return "Take the service walk on the left round the chasm, or jump it at speed: 6.5 m and 1 m down."
		3:
			return "Strafe round the receiver deck. The outer edge is open; keep inside the yellow band."
		4:
			return "Weave the cable drums, or duck-jump onto the gantry on the left (Space, then C). Then up to the relay house."
	return "Up the terraces to the relay house porch."

func start_wheel() -> void:
	if _art != null:
		_art.call("finished", self, true)

func reset_state() -> void:
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

func _drum(label: String, centre: Vector3) -> void:
	# an upright cable drum: a 16-sided prism the size of its flanges, drawn as flanges round a
	# full winding, so the drawn outline is the collision outline.
	var top: Array = []
	for s: int in 16:
		var a := TAU * s / 16.0
		top.append(Vector3(centre.x + cos(a) * DRUM_R, centre.y + DRUM_H, centre.z + sin(a) * DRUM_R))
	_solid(label, top, centre.y - 0.5, &"drum", -1, "wall", false)
	drums.append({"name": label, "centre": centre, "radius": DRUM_R, "height": DRUM_H})

func _prop_solid(label: String, model: String, feet: Vector3, height: float, yaw: float) -> void:
	# a reachable sourced machine: its visual is placed by the art pass from this record; its
	# collision is the measured footprint, scaled and turned, up to its measured height.
	var bounds := ASSETS.bounds(model)
	var scale := ASSETS.scale_for_height(model, height)
	var hx := bounds.size.x * scale.x * 0.5
	var hz := bounds.size.z * scale.z * 0.5
	var basis := Basis(Vector3.UP, yaw)
	var top: Array = []
	for c: Vector2 in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		top.append(feet + basis * Vector3(c.x, 0, c.y) + Vector3.UP * height)
	_solid(label, top, feet.y - 0.3, &"none", -1, "wall", false)
	props.append({"name": label, "model": model, "feet": feet, "scale": scale, "yaw": yaw})

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid", draw: bool = true) -> StaticBody3D:
	# a convex prism: a planar convex top polygon extruded straight down to `base`.
	assert(not has_node(NodePath(label)), "whiteout: duplicate piece " + label)
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

func _wall_label(label: String, at: Vector3, yaw: float, text: String, size := 0.009) -> void:
	markings.append({"name": label, "kind": "wall", "at": at, "yaw": yaw, "text": text, "size": size})

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
