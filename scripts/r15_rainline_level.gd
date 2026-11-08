extends Node3D
## p / r15 Rainline: an original rainy rooftop bhop course at night. it publishes the r14 level
## interface (spawn, checkpoints, segment and kill bounds, finish, routes, jump gaps, manifest,
## geometry hash, route hints, level identity), so r15_main.gd hosts it as map `rainline`.
## layout, numbers, recoveries and limits: docs/r15/RAINLINE.md.
##
## the course is a loop round a city block, high to low and back up:
##   tannery roof (spawn under the stairhead canopy) and three terrace drops -> the gantry, a
##   plate-girder bridge over the first street with two missing deck panels -> the print works
##   roof -> the scaffold, wrapped round three faces of Halden tower behind debris netting, down
##   one lift and up again -> the lamp room, a warm lit rooftop workshop -> the cold store roof,
##   where the plant room blocks the way: round it on the right, or crouch through its low duct
##   -> the signal runway: jump the second street onto the comms roof, or take the ramp down to
##   the footbridge and the ramp back up -> the finish line short of the comms mast.
## a fall into either street, or off the gantry, respawns at the last checkpoint: the kill
## envelope sits 3 m under the footbridge, the lowest deck.
##
## wet roofs are a look only: no surface here carries friction, and the approved movement is
## unchanged. collision: every solid is a convex prism (ConvexPolygonShape3D); walkable pieces
## are 32 m or shorter on exact shared edges; building roofs reach the street, the bridges and
## scaffold boards are the declared 0.8 m thin pieces (docs/r14/CONTACT-GUARD.md).

const Art := preload("res://scripts/r15_rainline_art.gd")

## the identity the r15 main keys records on. bump LEVEL_VERSION with any change to geometry,
## progress or timing semantics.
const LEVEL_ID := "r15-rainline"
const LEVEL_NAME := "Rainline"
const LEVEL_VERSION := 1
const VARIANTS := ["rainline"]
const U := 0.0254
## the vanilla cs:go figures behind the gap screening (docs/r14/SOURCE-REFERENCE.md); driven runs
## on the actual runner decide, these only sort gaps into tiers.
const VANILLA := {"run_ups": 250.0, "jump_ups": 301.993, "gravity_ups": 800.0}
const LANDING := 0.5
const EARLY := 0.1
const TIERS := [["vanilla_strafe", 330.0], ["server", 520.0], ["fast", INF]]

## the street floor; every building's prism reaches it.
const STREET := -18.0
## p / under the footbridge (-6.5) with 3 m to spare: a fall into a street respawns.
const KILL_Y := -9.5
## the declared thin decks (bridges, scaffold boards) are this deep.
const THIN := 0.8
const PARAPET := 1.0
const PARAPET_W := 0.35
## netting on the scaffold's open side: over a standing jump (55 u, 1.4 m), so nobody leaves it.
const NET := 2.4
## p / standing hull 72 u plus a jump's 57 u apex: nothing hangs lower over a deck, except the
## declared crouch duct.
const HEADROOM := (72.0 + 57.0) * U
## the plant-room duct: 1.6 m (63 u), under the standing hull (72 u) and over the duck hull (54 u).
const DUCT_CLEAR := 1.6
## p / its hood: the ceiling slopes down to the duct over 6 m from 3.35 m (over a standing jump), so
## a crouch hop that meets it high is turned down into the duct, not stopped by a lip.
const HOOD_LEN := 6.0
const HOOD_CLEAR := 3.35

## heights of the levels the route passes through.
const Y_START := 0.0
const Y_GANTRY := -3.0
const Y_LIFT := -4.5
const Y_COLD := -3.0
const Y_BRIDGE := -6.5
const Y_COMMS := -5.0

## stage 0: the tannery roof and its terraces, x from -8 to 8 going -z.
const ROOF_X := 8.0
## the tannery roof's north edge, under the stairhead.
const ROOF_N := 16.0
const TERRACES := [[ROOF_N, -8.0, 0.0], [-8.0, -24.0, 0.0], [-24.0, -32.0, -1.0], [-32.0, -40.0, -2.0], [-40.0, -58.0, -3.0]]
## the gantry over the first street (x 8 to 22), 5 m wide; [x from, x to] of its three decks.
const GANTRY_Z := [-46.5, -51.5]
const GANTRY := [[8.0, 11.5], [13.1, 16.1], [18.3, 22.0]]
## the print works roof across the street.
const PRINT := [22.0, 36.0, -42.0, -66.0]
## halden tower, wrapped by the scaffold on its west, south and east faces.
const TOWER := [30.0, 48.0, -66.0, -118.0]
const TOWER_TOP := 22.0
const SCAF_W := 5.0
## the lamp room: a rooftop workshop, floor at the cold-store level.
const LAMP := [46.0, 60.0, -52.0, -66.0]
const LAMP_CEIL := 3.8
const LAMP_OPEN_S := [48.0, 53.0]
const LAMP_OPEN_N := [50.0, 54.0]
const OPENING := 3.4
## the cold store roof and its plant room with the duct.
const COLD_S := [46.0, 66.0, -52.0, -44.0]
const PLANT := [42.0, 60.0, -44.0, -32.0]
const PLANT_TOP := 3.6
const DUCT_X := [50.0, 53.0]
const EAST_X := [60.0, 66.0]
## the signal runway to the second street; the street (z 0 to 8.5) and the comms roof beyond.
const RUNWAY := [46.0, 58.0, -32.0, 0.0]
const STREET_B := [0.0, 8.5]
const COMMS := [42.0, 68.0, 8.5, 44.0]
## the antenna deck over the comms roof's north end, ramps up both sides, the mast on it.
const Y_DECK := -3.4
const DECK_Z := 34.0
const MAST := [52.0, 56.0, 38.5, 42.5]
const FINISH_Z := 36.0

## set by a factory before the level enters the tree; build() reads it once (r14 convention).
static var next_variant: String = ""

## p / not "course": the r14 overflow art pass dresses any "course" variant, and this map dresses itself.
var variant: String = "rainline"
## "kit": the sourced and authored look; "neutral": flat colours for attribution runs.
var material_mode: String = "kit"
var level_id: String = LEVEL_ID
var level_name: String = LEVEL_NAME
var level_version: int = LEVEL_VERSION
var finish_title: String = "Comms mast"
var spawn: Transform3D = Transform3D.IDENTITY
var checkpoints: Array[Dictionary] = []
var segment_bounds: Array[AABB] = []
var finish_position: Vector3 = Vector3.ZERO
var finish_radius: float = 4.0
## p / rain is a look: no wading regions. gutters and drains carry the water sound.
var water_regions: Array[Dictionary] = []
var water_audio_sources: Array[Vector3] = []
var routes: Dictionary = {}
var jump_gaps: Array[Dictionary] = []
## the low passages a standing hull cannot enter: name, clearance, floor, way in and out.
var crouch_passages: Array[Dictionary] = []
## p / only decks count as stage progress; props, walls and the duct roof never do.
var progress_roles: Array = ["route"]
var kill_bounds := AABB(Vector3(-40, KILL_Y, -170), Vector3(150, 120 - KILL_Y, 240))
## every collision piece: name, world points, stage, role, kind. hashed without materials.
var manifest: Array[Dictionary] = []
## painted marks and labels: visual only, not hashed.
var markings: Array[Dictionary] = []
## prism tops and bases drawn by kind, from collision pieces and visual-only prisms alike.
var prisms: Array[Dictionary] = []
## props placed for the art pass: model or kind, transform, and the collision piece if any.
var props: Array[Dictionary] = []
## lights the level asks for at authored spots: position, colour, energy, range, purpose.
var lamps: Array[Dictionary] = []

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
		if arg == "--rainline-neutral":
			material_mode = "neutral"
	assert(variant in VARIANTS, "rainline: unknown variant " + variant)
	_tannery()
	_gantry()
	_print_works()
	_scaffold()
	_lamp_room()
	_cold_store()
	_signal_crossing()
	_comms_roof()
	_city()
	_define_progress()
	_art = Art.new()
	_art.call("dress", self)

# --- stage 0: the tannery roof ----------------------------------------------------------------

func _tannery() -> void:
	# the start: a broad flat roof under the stairhead's canopy, then three 1 m terrace drops to the
	# laundry roof. nothing here can be failed except by jumping a parapet into the street: the
	# place to find the speed, the hop and the turn before the first crossing.
	for i: int in TERRACES.size():
		var t: Array = TERRACES[i]
		var name: String = ["s0_roof_a", "s0_roof_b", "s0_terrace_1", "s0_terrace_2", "s0_roof_c"][i]
		_deck(name, -ROOF_X, ROOF_X, t[0], t[1], t[2], &"roof_tar" if i < 2 else &"roof_felt", 0)
		_parapet_z("s0_parapet_w_%d" % i, -ROOF_X - PARAPET_W, -ROOF_X, t[0], t[1], t[2])
		if i < 4:
			_parapet_z("s0_parapet_e_%d" % i, ROOF_X, ROOF_X + PARAPET_W, t[0], t[1], t[2])
		if i > 1:
			# the terrace drop's lip, painted on the deck above it.
			_paint_x("s0_lip_%d" % i, -ROOF_X, ROOF_X, t[0], 0.3, float(TERRACES[i - 1][2]), &"paint_yellow")
	# the laundry roof's east parapet stops for the gantry; its south edge is walled.
	var c: Array = TERRACES[4]
	_parapet_z("s0_parapet_e_4a", ROOF_X, ROOF_X + PARAPET_W, c[0], GANTRY_Z[0] + 0.3, c[2])
	_parapet_z("s0_parapet_e_4b", ROOF_X, ROOF_X + PARAPET_W, GANTRY_Z[1] - 0.3, c[1], c[2])
	_solid("s0_parapet_s", _rect(-ROOF_X - PARAPET_W, ROOF_X + PARAPET_W, c[1], c[1] - PARAPET_W, c[2] + PARAPET), STREET, &"brick_cap", -1, "wall")
	# the stairhead behind the spawn, its door lit, and a canopy 3.5 m up (over the headroom).
	_solid("s0_stairhead", _rect(-3.5, 3.5, ROOF_N + 3.5, ROOF_N, Y_START + 3.4), STREET, &"render", -1, "wall")
	_solid("s0_canopy", _rect(-3.8, 3.8, ROOF_N, ROOF_N - 3.6, Y_START + 3.8), Y_START + 3.5, &"steel_dark", -1, "canopy")
	_solid("s0_parapet_n_w", _rect(-ROOF_X - PARAPET_W, -3.5, ROOF_N + PARAPET_W, ROOF_N, Y_START + PARAPET), STREET, &"brick_cap", -1, "wall")
	_solid("s0_parapet_n_e", _rect(3.5, ROOF_X + PARAPET_W, ROOF_N + PARAPET_W, ROOF_N, Y_START + PARAPET), STREET, &"brick_cap", -1, "wall")
	# roof plant along the parapets, out of the middle 10 m: air handlers and a vent hood.
	_prop("s0_ac_1", "kenney-factory/models/machine.glb", Vector3(-6.7, Y_START, -3.0), 0.0, Vector3(1.6, 1.15, 2.0))
	_prop("s0_ac_2", "kenney-factory/models/machine.glb", Vector3(6.7, Y_START, -14.0), PI, Vector3(1.6, 1.15, 2.0))
	_prop("s0_vent_1", "kenney-factory/models/hopper-square.glb", Vector3(6.6, Y_START, 1.5), 0.0, Vector3(1.2, 1.1, 1.2))
	_prop("s0_vent_2", "kenney-factory/models/hopper-square.glb", Vector3(-6.6, Y_START, -20.0), 0.0, Vector3(1.2, 1.1, 1.2))
	_prop("s0_tank_1", "kenney-industrial/models/detail-tank-large.glb", Vector3(-5.8, -3.0, -54.6), 0.0, Vector3(3.2, 1.3, 3.0))
	_paint_x("s0_start_line", -ROOF_X, ROOF_X, ROOF_N - 6.0, 0.3, Y_START, &"paint_white")
	_prop("s0_ac_3", "kenney-factory/models/machine.glb", Vector3(-6.7, Y_START, 9.0), 0.0, Vector3(1.6, 1.15, 2.0))
	_floor_label("s0_hint_c", Vector3(0.0, Y_GANTRY, -44.0), PI * 0.5, "GANTRY  →")
	_lamp(Vector3(0.0, Y_START + 3.45, ROOF_N - 2.0), Color("ffb978"), 2.2, 11.0, "stairhead", "ceiling")
	_post_lamp("s0_lamp_post_1", Vector3(-ROOF_X - 0.18, 0.0, -28.0), -1.0 + 3.6, Vector3(0.9, 0, 0), Color("ffb978"), 1.4, 10.0, "terraces")
	_post_lamp("s0_lamp_post_2", Vector3(ROOF_X + 0.18, Y_GANTRY + PARAPET, -45.0), Y_GANTRY + 3.6, Vector3(-0.9, 0, 0), Color("ffc890"), 1.8, 11.0, "gantry head")

# --- stage 1: the gantry and the print works ---------------------------------------------------

func _gantry() -> void:
	# a plate-girder footbridge over the first street, 5 m between its girders. two deck panels are
	# missing: gaps of 1.6 and 2.2 m, well inside a run-speed jump. the girders stand 1.1 m over the
	# deck the whole way, so the only way off is through a gap, 15 m down to a respawn.
	for i: int in GANTRY.size():
		var g: Array = GANTRY[i]
		_deck("s1_gantry_%d" % (i + 1), g[0], g[1], GANTRY_Z[0], GANTRY_Z[1], Y_GANTRY, &"grating", 1, Y_GANTRY - THIN)
		if i > 0:
			_paint_z("s1_gantry_lip_%d" % (i + 1), g[0], GANTRY_Z[0], GANTRY_Z[1], 0.3, Y_GANTRY, &"paint_yellow")
		if i < GANTRY.size() - 1:
			_paint_z("s1_gantry_edge_%d" % (i + 1), g[1], GANTRY_Z[0], GANTRY_Z[1], -0.3, Y_GANTRY, &"paint_yellow")
	_solid("s1_girder_n", _rect(GANTRY[0][0], GANTRY[2][1], GANTRY_Z[0] + 0.3, GANTRY_Z[0], Y_GANTRY + 1.1), Y_GANTRY - 1.2, &"steel_paint", -1, "wall")
	_solid("s1_girder_s", _rect(GANTRY[0][0], GANTRY[2][1], GANTRY_Z[1], GANTRY_Z[1] - 0.3, Y_GANTRY + 1.1), Y_GANTRY - 1.2, &"steel_paint", -1, "wall")
	var mid := (GANTRY_Z[0] + GANTRY_Z[1]) * 0.5
	_floor_label("s1_gap_1", Vector3(GANTRY[0][1] - 1.2, Y_GANTRY, mid), -PI * 0.5, _gap_text(GANTRY[1][0] - GANTRY[0][1]))
	_floor_label("s1_gap_2", Vector3(GANTRY[1][1] - 1.0, Y_GANTRY, mid), -PI * 0.5, _gap_text(GANTRY[2][0] - GANTRY[1][1]))
	_post_lamp("s1_lamp_post_1", Vector3(15.0, Y_GANTRY + 1.1, GANTRY_Z[0] + 0.15), Y_GANTRY + 3.6, Vector3(0, 0, -1.0), Color("dfe9ff"), 1.6, 9.0, "gantry")

func _print_works() -> void:
	# the print works roof across the street: two 12 m pieces, walled on three sides, glazed north
	# lights on the east half. its south edge opens onto the scaffold beside the tower.
	var p: Array = PRINT
	var mid_z := (float(p[2]) + float(p[3])) * 0.5
	_deck("s1_print_a", p[0], p[1], p[2], mid_z, Y_GANTRY, &"roof_felt", 1)
	_deck("s1_print_b", p[0], p[1], mid_z, p[3], Y_GANTRY, &"roof_felt", 1)
	_solid("s1_parapet_n", _rect(float(p[0]) - PARAPET_W, float(p[1]) + PARAPET_W, float(p[2]) + PARAPET_W, p[2], Y_GANTRY + PARAPET), STREET, &"brick_cap", -1, "wall")
	_parapet_z("s1_parapet_w_a", float(p[0]) - PARAPET_W, p[0], p[2], GANTRY_Z[0] + 0.3, Y_GANTRY)
	_parapet_z("s1_parapet_w_b", float(p[0]) - PARAPET_W, p[0], GANTRY_Z[1] - 0.3, p[3], Y_GANTRY)
	_parapet_z("s1_parapet_e", p[1], float(p[1]) + PARAPET_W, p[2], float(TOWER[2]), Y_GANTRY)
	_solid("s1_parapet_s", _rect(float(p[0]) - PARAPET_W, float(TOWER[0]) - SCAF_W, p[3], float(p[3]) - PARAPET_W, Y_GANTRY + PARAPET), STREET, &"brick_cap", -1, "wall")
	# north lights: glazed ridges 0.7 m tall, a hop or a walk round.
	for i: int in 2:
		var z0 := -44.0 - 5.0 * i
		_solid("s1_northlight_%d" % (i + 1), _rect(31.5, 35.0, z0, z0 - 3.0, Y_GANTRY + 0.7), Y_GANTRY - 0.5, &"glass_frame", -1, "prop")
	_paint_x("s1_print_lip", float(TOWER[0]) - SCAF_W, TOWER[0], p[3], -0.3, Y_GANTRY, &"paint_yellow")
	_floor_label("s1_hint_scaffold", Vector3(27.5, Y_GANTRY, -61.0), 0.0, "SCAFFOLD  ↓")
	_post_lamp("s1_lamp_post_2", Vector3(float(p[0]) - 0.18, Y_GANTRY + PARAPET, -60.0), Y_GANTRY + 3.6, Vector3(1.0, 0, 0), Color("ffb978"), 1.6, 10.0, "print works")

# --- stage 2: the scaffold round halden tower -------------------------------------------------

func _scaffold() -> void:
	# a 5 m scaffold on the tower's west, south and east faces: boards on a lift, debris netting
	# 2.4 m tall on the open side, the tower wall on the other. it drops one lift (1.5 m) down the
	# west face and climbs it again up the east face; the two outer corners are chamfered loading
	# bays, 7 m square, so a turn at speed has room.
	var t: Array = TOWER
	var x0: float = t[0]
	var x1: float = t[1]
	var zn: float = t[2]
	var zs: float = t[3]
	_solid("s2_tower_n", _rect(x0, x1, zn, (zn + zs) * 0.5, TOWER_TOP), STREET, &"tower", -1, "wall")
	_solid("s2_tower_s", _rect(x0, x1, (zn + zs) * 0.5, zs, TOWER_TOP), STREET, &"tower", -1, "wall")
	var w0 := x0 - SCAF_W
	var e1 := x1 + SCAF_W
	# west face, -z: a lift, a ramp down, the lower lift.
	_board("s2_scaf_w1", _rect(w0, x0, zn, -82.0, Y_GANTRY), 2)
	_board("s2_scaf_w_ramp", [Vector3(w0, Y_GANTRY, -82.0), Vector3(x0, Y_GANTRY, -82.0), Vector3(x0, Y_LIFT, -90.0), Vector3(w0, Y_LIFT, -90.0)], 2)
	_board("s2_scaf_w2", _rect(w0, x0, -90.0, zs, Y_LIFT), 2)
	var sw := [Vector3(w0 - 2.0, Y_LIFT, zs), Vector3(x0, Y_LIFT, zs), Vector3(x0, Y_LIFT, zs - 7.0), Vector3(w0 + 1.0, Y_LIFT, zs - 7.0), Vector3(w0 - 2.0, Y_LIFT, zs - 4.0)]
	_board("s2_scaf_sw", sw, 2)
	_board("s2_scaf_s", _rect(x0, x1, zs, zs - SCAF_W, Y_LIFT), 2)
	var se := [Vector3(x1, Y_LIFT, zs), Vector3(e1 + 2.0, Y_LIFT, zs), Vector3(e1 + 2.0, Y_LIFT, zs - 4.0), Vector3(e1 - 1.0, Y_LIFT, zs - 7.0), Vector3(x1, Y_LIFT, zs - 7.0)]
	_board("s2_scaf_se", se, 2)
	# east face, +z: the lower lift, a ramp up, the upper lift to the lamp room door.
	_board("s2_scaf_e1", _rect(x1, e1, zs, -90.0, Y_LIFT), 2)
	_board("s2_scaf_e_ramp", [Vector3(x1, Y_LIFT, -90.0), Vector3(e1, Y_LIFT, -90.0), Vector3(e1, Y_COLD, -82.0), Vector3(x1, Y_COLD, -82.0)], 2)
	_board("s2_scaf_e2", _rect(x1, e1, -82.0, zn, Y_COLD), 2)
	# the netting: outside every open edge, following the boards.
	_net_z("s2_net_w1", w0, zn, -82.0, Y_GANTRY, Y_GANTRY, -1.0)
	_net_z("s2_net_w_ramp", w0, -82.0, -90.0, Y_GANTRY, Y_LIFT, -1.0)
	_net_z("s2_net_w2", w0, -90.0, zs, Y_LIFT, Y_LIFT, -1.0)
	_net_edge("s2_net_sw_n", Vector3(w0 - 2.0, Y_LIFT, zs), Vector3(w0, Y_LIFT, zs), Vector3(0, 0, 1))
	_net_edge("s2_net_sw_w", Vector3(w0 - 2.0, Y_LIFT, zs - 4.0), Vector3(w0 - 2.0, Y_LIFT, zs), Vector3(-1, 0, 0))
	_net_edge("s2_net_sw_c", Vector3(w0 + 1.0, Y_LIFT, zs - 7.0), Vector3(w0 - 2.0, Y_LIFT, zs - 4.0), Vector3(-1, 0, -1).normalized())
	_net_edge("s2_net_sw_s", Vector3(x0, Y_LIFT, zs - 7.0), Vector3(w0 + 1.0, Y_LIFT, zs - 7.0), Vector3(0, 0, -1))
	_net_edge("s2_net_s", Vector3(x0, Y_LIFT, zs - SCAF_W), Vector3(x1, Y_LIFT, zs - SCAF_W), Vector3(0, 0, -1))
	# the bays reach 7 m out from the tower, the run between them only 5: their inner faces.
	_net_edge("s2_net_sw_i", Vector3(x0, Y_LIFT, zs - SCAF_W), Vector3(x0, Y_LIFT, zs - 7.0), Vector3(1, 0, 0))
	_net_edge("s2_net_se_i", Vector3(x1, Y_LIFT, zs - 7.0), Vector3(x1, Y_LIFT, zs - SCAF_W), Vector3(-1, 0, 0))
	_net_edge("s2_net_se_s", Vector3(x1, Y_LIFT, zs - 7.0), Vector3(e1 - 1.0, Y_LIFT, zs - 7.0), Vector3(0, 0, -1))
	_net_edge("s2_net_se_c", Vector3(e1 - 1.0, Y_LIFT, zs - 7.0), Vector3(e1 + 2.0, Y_LIFT, zs - 4.0), Vector3(1, 0, -1).normalized())
	_net_edge("s2_net_se_e", Vector3(e1 + 2.0, Y_LIFT, zs - 4.0), Vector3(e1 + 2.0, Y_LIFT, zs), Vector3(1, 0, 0))
	_net_edge("s2_net_se_n", Vector3(e1, Y_LIFT, zs), Vector3(e1 + 2.0, Y_LIFT, zs), Vector3(0, 0, 1))
	_net_z("s2_net_e1", e1, zs, -90.0, Y_LIFT, Y_LIFT, 1.0)
	_net_z("s2_net_e_ramp", e1, -90.0, -82.0, Y_LIFT, Y_COLD, 1.0)
	_net_z("s2_net_e2", e1, -82.0, float(LAMP[3]), Y_COLD, Y_COLD, 1.0)
	_paint_x("s2_ramp_w_top", w0, x0, -82.0, -0.3, Y_GANTRY, &"paint_yellow")
	_paint_x("s2_ramp_e_foot", x1, e1, -90.0, -0.3, Y_LIFT, &"paint_yellow")
	_floor_label("s2_hint_down", Vector3(w0 + 2.5, Y_GANTRY, -79.0), 0.0, "LIFT 2  ↓ 1.5 m")
	_floor_label("s2_hint_up", Vector3(x1 + 2.5, Y_LIFT, -92.5), PI, "LIFT 3  ↑ 1.5 m")
	# work lights under the lift above, about every 8 m, none over a ramp: the boards overhead
	# shut out the sky, so the walkway is lit only by these.
	var lights: Array[Vector3] = [Vector3(w0 + 1.5, Y_LIFT, zs - 3.5), Vector3((x0 + x1) * 0.5, Y_LIFT, zs - 2.5), Vector3(e1 - 1.5, Y_LIFT, zs - 3.5),
		Vector3(x0 + 4.5, Y_LIFT, zs - 2.5), Vector3(x1 - 4.5, Y_LIFT, zs - 2.5)]
	for z: float in [-70.0, -78.0]:
		lights.append(Vector3(w0 + 2.5, Y_GANTRY, z))
		lights.append(Vector3(x1 + 2.5, Y_COLD, z))
	for z: float in [-94.0, -102.0, -110.0, -117.0]:
		lights.append(Vector3(w0 + 2.5, Y_LIFT, z))
		lights.append(Vector3(x1 + 2.5, Y_LIFT, z))
	for at: Vector3 in lights:
		_lamp(at + Vector3.UP * 3.45, Color("e4ecff"), 1.3, 9.0, "scaffold lift light", "ceiling")

func _board(label: String, top: Array, stage: int) -> void:
	# a scaffold lift: boards over ledgers, 0.8 m deep in all (the declared thin pieces).
	var low := INF
	for p: Vector3 in top:
		low = minf(low, p.y)
	_solid(label, top, low - THIN, &"board", stage, "route")

func _net_z(label: String, x: float, z0: float, z1: float, y0: float, y1: float, outward: float) -> void:
	# netting along a run's open side at x, 0.3 m thick outward, from deck height y0 at z0 to y1 at z1.
	var xa := x if outward > 0.0 else x - 0.3
	var xb := x + 0.3 if outward > 0.0 else x
	_solid(label, [Vector3(xa, y0 + NET, z0), Vector3(xb, y0 + NET, z0), Vector3(xb, y1 + NET, z1), Vector3(xa, y1 + NET, z1)], minf(y0, y1) - THIN, &"netting", -1, "wall")

func _net_edge(label: String, a: Vector3, b: Vector3, outward: Vector3) -> void:
	var o := outward.normalized() * 0.3
	var up := Vector3.UP * NET
	_solid(label, [a + up, b + up, b + o + up, a + o + up], minf(a.y, b.y) - THIN, &"netting", -1, "wall")

# --- stage 3: the lamp room and the cold store -------------------------------------------------

func _lamp_room() -> void:
	# a warm rooftop workshop with a glazed east wall. in from the scaffold through the south
	# opening, out through the north door onto the cold store roof. 3.8 m to the ceiling, 3.4 m
	# openings: a hop through either never touches the lintel.
	var l: Array = LAMP
	var x0: float = l[0]
	var x1: float = l[1]
	var zn: float = l[2]
	var zs: float = l[3]
	var floor := Y_COLD
	var ceil := floor + LAMP_CEIL
	var head := floor + OPENING
	var w := 0.4
	_deck("s3_lamp_floor", x0, x1, zs, zn, floor, &"workshop_floor", 3)
	_solid("s3_lamp_ceiling", _rect(x0, x1, zs, zn, ceil + 0.3), ceil, &"render", -1, "ceiling")
	_solid("s3_lamp_wall_s_w", _rect(x0, LAMP_OPEN_S[0], zs + w, zs, ceil), floor - 0.2, &"brick", -1, "wall")
	_solid("s3_lamp_wall_s_e", _rect(LAMP_OPEN_S[1], x1, zs + w, zs, ceil), floor - 0.2, &"brick", -1, "wall")
	_solid("s3_lamp_lintel_s", _rect(LAMP_OPEN_S[0], LAMP_OPEN_S[1], zs + w, zs, ceil), head, &"brick", -1, "wall")
	_solid("s3_lamp_wall_n_w", _rect(x0, LAMP_OPEN_N[0], zn, zn - w, ceil), floor - 0.2, &"brick", -1, "wall")
	_solid("s3_lamp_wall_n_e", _rect(LAMP_OPEN_N[1], x1, zn, zn - w, ceil), floor - 0.2, &"brick", -1, "wall")
	_solid("s3_lamp_lintel_n", _rect(LAMP_OPEN_N[0], LAMP_OPEN_N[1], zn, zn - w, ceil), head, &"brick", -1, "wall")
	_solid("s3_lamp_wall_w", _rect(x0, x0 + w, zs + w, zn - w, ceil), floor - 0.2, &"brick", -1, "wall")
	# the east wall: a sill, three piers, glass between them and a header over the glass.
	var sill := floor + 0.9
	_solid("s3_lamp_sill_e", _rect(x1 - w, x1, zs + w, zn - w, sill), floor - 0.2, &"brick", -1, "wall")
	var piers := [[zn - w, zn - 2.0], [-57.0, -59.0], [zs + 2.0, zs + w]]
	for i: int in piers.size():
		_solid("s3_lamp_pier_%d" % (i + 1), _rect(x1 - w, x1, piers[i][0], piers[i][1], ceil), sill, &"brick", -1, "wall")
	_solid("s3_lamp_header_e", _rect(x1 - w, x1, zs + w, zn - w, ceil), head, &"brick", -1, "wall")
	var panes := [[zn - 2.0, -57.0], [-59.0, zs + 2.0]]
	for i: int in panes.size():
		_solid("s3_lamp_glass_%d" % (i + 1), _rect(x1 - 0.25, x1 - 0.15, panes[i][0], panes[i][1], head), sill, &"glass", -1, "glass")
	# a workbench on the west wall and a crate stack in the north-west corner.
	_solid("s3_bench", _rect(x0 + w, x0 + w + 1.0, zn - 3.0, zn - 9.0, floor + 0.95), floor - 0.2, &"timber", -1, "prop")
	_prop("s3_crates", "kenney-factory/models/box-large.glb", Vector3(x0 + w + 0.8, floor, zs + w + 1.2), 0.0, Vector3(1.4, 0.8, 1.3))
	for at: Vector3 in [Vector3(51.0, ceil - 0.35, -55.5), Vector3(51.0, ceil - 0.35, -62.5), Vector3(56.0, ceil - 0.35, -59.0)]:
		_lamp(at, Color("ffbe7c"), 2.4, 9.0, "lamp room pendant", "ceiling")
	_floor_label("s3_hint_duct", Vector3(52.0, floor, -53.8), PI, "LOW DUCT AHEAD\nhold C / Ctrl to crouch\nor go round →")
	_paint_x("s3_lamp_line", LAMP_OPEN_S[0], LAMP_OPEN_S[1], zs, 0.25, floor, &"paint_white")

func _cold_store() -> void:
	# the cold store roof north of the lamp room. the plant room fills it but for a 6 m strip on the
	# east: round it is the ordinary way. straight through it from the lamp room door is the duct,
	# 1.6 m high and 3 m wide, a crouch-only passage 12 m long that opens onto the runway.
	var c: Array = COLD_S
	var p: Array = PLANT
	_deck("s3_cold_a", c[0], c[1], c[2], c[3], Y_COLD, &"roof_tar", 3)
	_deck("s3_cold_east", EAST_X[0], EAST_X[1], p[2], p[3], Y_COLD, &"roof_tar", 3)
	_deck("s3_duct_floor", DUCT_X[0], DUCT_X[1], p[2], p[3], Y_COLD, &"duct_floor", 3)
	var top := Y_COLD + PLANT_TOP
	_solid("s3_plant_w", _rect(p[0], DUCT_X[0], p[2], p[3], top), STREET, &"plant", -1, "wall")
	_solid("s3_plant_e", _rect(DUCT_X[1], p[1], p[2], p[3], top), STREET, &"plant", -1, "wall")
	_solid("s3_duct_lid", _rect(DUCT_X[0], DUCT_X[1], p[2], p[3], top), Y_COLD + DUCT_CLEAR, &"duct", -1, "ceiling")
	var z0: float = p[2]
	var zb := z0 - HOOD_LEN
	var low := Y_COLD + DUCT_CLEAR
	var high := Y_COLD + HOOD_CLEAR
	var hood: Array[Vector3] = [Vector3(DUCT_X[0], low, z0), Vector3(DUCT_X[1], low, z0), Vector3(DUCT_X[1], high, zb), Vector3(DUCT_X[0], high, zb),
		Vector3(DUCT_X[0], top, z0), Vector3(DUCT_X[1], top, z0), Vector3(DUCT_X[1], top, zb), Vector3(DUCT_X[0], top, zb)]
	_hull("s3_duct_hood", hood, [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]], &"duct", "ceiling")
	_parapet_z("s3_parapet_w", float(c[0]) - PARAPET_W, c[0], c[2], c[3], Y_COLD)
	_parapet_z("s3_parapet_e", c[1], float(c[1]) + PARAPET_W, c[2], float(RUNWAY[2]), Y_COLD)
	_solid("s3_parapet_s", _rect(LAMP[1], float(c[1]) + PARAPET_W, c[2], float(c[2]) - PARAPET_W, Y_COLD + PARAPET), STREET, &"brick_cap", -1, "wall")
	# the duct mouth: hazard chevrons on its lip, a strip light inside, the clearance on its face.
	_paint_x("s3_duct_mouth", DUCT_X[0], DUCT_X[1], p[2], 0.4, Y_COLD, &"paint_yellow")
	_paint_x("s3_duct_exit", DUCT_X[0], DUCT_X[1], p[3], -0.4, Y_COLD, &"paint_yellow")
	_wall_label("s3_duct_sign", Vector3((DUCT_X[0] + DUCT_X[1]) * 0.5, Y_COLD + DUCT_CLEAR + 0.55, float(p[2]) + 0.03), PI, "CROUCH  1.6 m")
	_wall_label("s3_round_sign", Vector3(float(p[1]) - 2.2, Y_COLD + 2.2, float(p[2]) + 0.03), PI, "ROUND  →")
	crouch_passages.append({"name": "s3_duct_floor", "ceiling": "s3_duct_lid", "clearance_m": DUCT_CLEAR, "clearance_u": roundi(DUCT_CLEAR / U),
		"floor_y": Y_COLD, "x": DUCT_X.duplicate(), "z": [p[2], p[3]], "entry": _v(Vector3(51.5, Y_COLD, float(p[2]))), "exit": _v(Vector3(51.5, Y_COLD, float(p[3]))),
		"stand_room_m": "open runway beyond the exit, no solid under %.2f m" % HEADROOM, "optional": true,
		"hood": {"name": "s3_duct_hood", "z": [zb, z0], "clearance_from_m": HOOD_CLEAR, "clearance_to_m": DUCT_CLEAR}})
	_lamp(Vector3(51.5, Y_COLD + DUCT_CLEAR - 0.06, -38.0), Color("bfe0ff"), 0.9, 6.0, "duct strip", "strip")
	_post_lamp("s3_lamp_post_1", Vector3(float(c[1]) + 0.18, Y_COLD + PARAPET, -40.0), Y_COLD + 3.6, Vector3(-1.0, 0, 0), Color("ffb978"), 1.5, 10.0, "east strip")
	_lamp(Vector3(52.0, Y_COLD + 3.6, float(LAMP[2]) + 0.25), Color("ffc890"), 1.4, 9.0, "lamp room door", "wall")
	# ducts and fans on the plant-room roof: out of reach (3.6 m up).
	_prop("s3_fan_1", "kenney-factory/models/hopper-high-square.glb", Vector3(45.0, top, -36.0), 0.0, Vector3.ZERO, 2.2)
	_prop("s3_fan_2", "kenney-factory/models/hopper-high-square.glb", Vector3(57.0, top, -41.0), 0.0, Vector3.ZERO, 2.2)
	_prop("s3_duct_run_1", "kenney-factory/models/pipe-large-long.glb", Vector3(47.0, top, -41.5), 0.0, Vector3.ZERO, 1.0)
	_prop("s3_duct_run_2", "kenney-factory/models/pipe-large-bend.glb", Vector3(55.0, top, -35.5), PI * 0.5, Vector3.ZERO, 1.0)

# --- stage 4: the signal runway and the second street -----------------------------------------

func _signal_crossing() -> void:
	# the runway: 32 m of roof from the duct exit to the second street, 12 m wide. its north lip is
	# the earned jump, 8.5 m over the street and 2 m down onto the comms roof. on the right, behind a
	# 1.5 m duct run, the east strip goes on to a ramp down to the footbridge (ordinary).
	var r: Array = RUNWAY
	_deck("s4_runway_1", r[0], r[1], r[2], -16.0, Y_COLD, &"roof_tar", 4)
	_deck("s4_runway_2", r[0], r[1], -16.0, r[3], Y_COLD, &"roof_tar", 4)
	_deck("s4_link", r[1], EAST_X[0], r[2], -24.0, Y_COLD, &"roof_tar", 4)
	_deck("s4_cold_east_n", EAST_X[0], EAST_X[1], r[2], -16.0, Y_COLD, &"roof_tar", 4)
	_solid("s4_duct_run", _rect(r[1], EAST_X[0], -24.0, r[3], Y_COLD + 1.5), STREET, &"duct", -1, "wall")
	_parapet_z("s4_parapet_w", float(r[0]) - PARAPET_W, r[0], r[2], r[3], Y_COLD)
	# the ramp down to the footbridge, 3.5 m over 16 m, walled on its street side.
	_solid("s4_ramp_down", [Vector3(EAST_X[0], Y_COLD, -16.0), Vector3(EAST_X[1], Y_COLD, -16.0), Vector3(EAST_X[1], Y_BRIDGE, STREET_B[0]), Vector3(EAST_X[0], Y_BRIDGE, STREET_B[0])], STREET, &"concrete", 4, "route")
	_solid("s4_ramp_wall_e", _rect(EAST_X[1], EAST_X[1] + PARAPET_W, -32.0, STREET_B[0], Y_COLD + PARAPET), STREET, &"brick_cap", -1, "wall")
	# the footbridge, open, plate girders 1.1 m tall on both sides.
	_deck("s4_footbridge", EAST_X[0], EAST_X[1], STREET_B[0], STREET_B[1], Y_BRIDGE, &"grating", 4, Y_BRIDGE - THIN)
	_solid("s4_girder_w", _rect(EAST_X[0] - 0.3, EAST_X[0], STREET_B[0], STREET_B[1], Y_BRIDGE + 1.1), Y_BRIDGE - 1.2, &"steel_paint", -1, "wall")
	_solid("s4_girder_e", _rect(EAST_X[1], EAST_X[1] + 0.3, STREET_B[0], STREET_B[1], Y_BRIDGE + 1.1), Y_BRIDGE - 1.2, &"steel_paint", -1, "wall")
	# the runway's lip: hazard band 3 m before it, the gap and drop on the deck.
	var lip: float = r[3]
	_paint_x("s4_lip", r[0], r[1], lip, 0.35, Y_COLD, &"paint_yellow")
	for k: int in 10:
		var x0 := float(r[0]) + 0.6 + k * 1.1
		_paint_line("s4_hazard_%02d" % k, Vector3(x0, Y_COLD, lip + 3.0), Vector3(x0 + 0.55, Y_COLD, lip + 3.0), Vector3(0, 0, -1.0), &"paint_yellow" if k % 2 == 0 else &"paint_dark")
	_floor_label("s4_gap", Vector3((float(r[0]) + float(r[1])) * 0.5, Y_COLD, lip - 1.8), PI, "%.1f m  ·  2 m down\n%d u" % [STREET_B[1] - STREET_B[0], roundi((STREET_B[1] - STREET_B[0]) / U)])
	_floor_label("s4_hint_bridge", Vector3(63.0, Y_COLD, -20.0), PI, "FOOTBRIDGE  ↓")
	_post_lamp("s4_lamp_post_1", Vector3(float(r[0]) - 0.18, Y_COLD + PARAPET, -6.0), Y_COLD + 3.6, Vector3(1.0, 0, 0), Color("ffb978"), 1.8, 12.0, "runway lip")
	_post_lamp("s4_lamp_post_2", Vector3(EAST_X[1] + 0.15, Y_BRIDGE + 1.1, 4.25), Y_BRIDGE + 3.6, Vector3(-1.0, 0, 0), Color("dfe9ff"), 1.4, 9.0, "footbridge")
	_post_lamp("s4_lamp_post_3", Vector3(59.0, Y_COLD + 1.5, -20.0), Y_COLD + 3.6, Vector3(-1.0, 0, 0), Color("ffb978"), 1.4, 11.0, "runway")

func _comms_roof() -> void:
	# the comms roof: pieces round the ramp up from the footbridge; no parapet on its south lip,
	# the earned landing. its north end is the antenna deck, 1.6 m up, reached by a ramp on either
	# side; the finish line crosses the deck short of the mast.
	var k: Array = COMMS
	var x0: float = k[0]
	var x1: float = k[1]
	var zs: float = k[2]
	var zn: float = k[3]
	_deck("s4_comms_1", x0, EAST_X[0], zs, 24.5, Y_COMMS, &"roof_gravel", 4)
	_deck("s4_comms_2", EAST_X[0], x1, 20.5, 24.5, Y_COMMS, &"roof_gravel", 4)
	_deck("s4_comms_3", 48.0, EAST_X[0], 24.5, DECK_Z, Y_COMMS, &"roof_gravel", 4)
	_solid("s4_ramp_up", [Vector3(EAST_X[0], Y_BRIDGE, STREET_B[1]), Vector3(EAST_X[1], Y_BRIDGE, STREET_B[1]), Vector3(EAST_X[1], Y_COMMS, 20.5), Vector3(EAST_X[0], Y_COMMS, 20.5)], STREET, &"concrete", 4, "route")
	_solid("s4_deck_ramp_w", [Vector3(x0, Y_COMMS, 24.5), Vector3(48.0, Y_COMMS, 24.5), Vector3(48.0, Y_DECK, DECK_Z), Vector3(x0, Y_DECK, DECK_Z)], STREET, &"concrete", 4, "route")
	_solid("s4_deck_ramp_e", [Vector3(EAST_X[0], Y_COMMS, 24.5), Vector3(EAST_X[1], Y_COMMS, 24.5), Vector3(EAST_X[1], Y_DECK, DECK_Z), Vector3(EAST_X[0], Y_DECK, DECK_Z)], STREET, &"concrete", 4, "route")
	_deck("s4_deck_w", x0, 55.0, DECK_Z, zn, Y_DECK, &"roof_gravel", 4)
	_deck("s4_deck_e", 55.0, x1, DECK_Z, zn, Y_DECK, &"roof_gravel", 4)
	_solid("s4_comms_edge_e", _rect(EAST_X[1], x1, zs, 20.5, Y_COMMS + 1.0), STREET, &"brick_cap", -1, "wall")
	_solid("s4_deck_edge_e", _rect(EAST_X[1], x1, 24.5, DECK_Z, Y_DECK + 1.0), STREET, &"brick_cap", -1, "wall")
	_parapet_z("s4_comms_parapet_w", x0 - PARAPET_W, x0, zs, 24.5, Y_COMMS)
	_parapet_z("s4_deck_parapet_w", x0 - PARAPET_W, x0, 24.5, zn, Y_DECK)
	_parapet_z("s4_comms_parapet_e", x1, x1 + PARAPET_W, 20.5, 24.5, Y_COMMS)
	_parapet_z("s4_deck_parapet_e", x1, x1 + PARAPET_W, 24.5, zn, Y_DECK)
	_solid("s4_comms_parapet_n", _rect(x0 - PARAPET_W, x1 + PARAPET_W, zn + PARAPET_W, zn, Y_DECK + PARAPET), STREET, &"brick_cap", -1, "wall")
	_paint_x("s4_comms_lip", x0, EAST_X[0], zs, 0.35, Y_COMMS, &"paint_yellow")
	_paint_x("s4_deck_lip", 48.0, EAST_X[0], DECK_Z, -0.3, Y_COMMS, &"paint_yellow")
	_floor_label("s4_hint_deck", Vector3(54.0, Y_COMMS, DECK_Z - 2.5), PI, "←  RAMP  ·  RAMP  →")
	# the mast: a lattice tower on a plinth, a dish array beside it, all solid where reachable.
	var m: Array = MAST
	_solid("s4_mast_plinth", _rect(m[0], m[1], m[2], m[3], Y_DECK + 0.6), Y_DECK - 0.5, &"concrete", -1, "prop")
	# its four legs are solid; the bracing between them starts out of reach, so the lattice stays open.
	for i: int in 4:
		var lx := float(m[0]) + 0.8 if i % 2 == 0 else float(m[1]) - 1.05
		var lz := float(m[2]) + 0.8 if i < 2 else float(m[3]) - 1.05
		_solid("s4_mast_leg_%d" % (i + 1), _rect(lx, lx + 0.25, lz, lz + 0.25, Y_DECK + 34.0), Y_DECK + 0.5, &"lattice", -1, "wall")
	_prop("s4_dish_1", "kenney-space/models/satelliteDish_large.glb", Vector3(46.0, Y_DECK, 41.0), deg_to_rad(200.0), Vector3(2.6, 2.6, 2.6), 2.8)
	_prop("s4_dish_2", "kenney-space/models/satelliteDish_detailed.glb", Vector3(63.5, Y_DECK, 41.0), deg_to_rad(150.0), Vector3(2.2, 2.0, 2.2), 2.2)
	_prop("s4_cabinet_1", "kenney-space/models/machine_wireless.glb", Vector3(60.0, Y_DECK, 42.8), PI, Vector3(1.6, 1.3, 1.1), 1.3)
	_prop("s4_cabinet_2", "kenney-space/models/machine_generatorLarge.glb", Vector3(44.0, Y_COMMS, 21.0), PI * 0.5, Vector3(1.4, 0.9, 1.8), 0.9)
	_finish_box = AABB(Vector3(x0, Y_DECK - 0.3, FINISH_Z), Vector3(x1 - x0, 5.0, zn - FINISH_Z))
	finish_position = Vector3(50.0, Y_DECK, FINISH_Z + 2.5)
	_paint_x("s4_finish", x0, x1, FINISH_Z, 0.5, Y_DECK, &"paint_white")
	_post_lamp("s4_lamp_post_4", Vector3(x0 - 0.18, Y_DECK + PARAPET, 37.0), Y_DECK + 3.6, Vector3(1.0, 0, 0), Color("ffd0a0"), 2.0, 13.0, "finish")
	_post_lamp("s4_lamp_post_5", Vector3(x0 - 0.18, Y_COMMS + PARAPET, 14.0), Y_COMMS + 3.6, Vector3(1.0, 0, 0), Color("ffb978"), 1.6, 12.0, "comms landing")
	_post_lamp("s4_lamp_post_6", Vector3(67.0, Y_COMMS + 1.0, 18.0), Y_COMMS + 3.6, Vector3(-1.0, 0, 0), Color("ffb978"), 1.4, 10.0, "ramp head")
	_post_lamp("s4_lamp_post_7", Vector3(67.0, Y_DECK + 1.0, 30.0), Y_DECK + 3.6, Vector3(-1.0, 0, 0), Color("ffb978"), 1.4, 10.0, "deck ramp")

# --- the city round the route -----------------------------------------------------------------

## blocks round the route: [name, x0, x1, z0, z1, roof y, facade]. each is a collision prism to the
## street (split at 32 m), set back from the route or tall enough that no jump reaches its roof.
const CITY := [
	["city_n1", -14.0, 6.0, 20.0, 38.0, 9.0, &"facade_brick"],
	["city_n2", 6.5, 22.0, 22.0, 38.0, 5.0, &"facade_render"],
	["city_w1", -26.0, -10.0, 18.0, -20.0, 6.0, &"facade_brick"],
	["city_w2", -26.0, -10.0, -20.0, -62.0, 2.6, &"facade_dark"],
	["city_sw", -12.0, 7.5, -60.8, -100.0, 4.0, &"facade_render"],
	["city_e1", 22.0, 40.0, -41.3, -0.5, 4.5, &"facade_brick"],
	["city_ne", 22.0, 41.3, 9.0, 44.0, 7.0, &"facade_render"],
	["city_far_n", 30.0, 80.0, 44.7, 62.0, 13.0, &"facade_brick"],
	["city_east_k", 68.7, 90.0, 9.0, 44.0, 3.5, &"facade_dark"],
	["city_east_c", 66.7, 90.0, -66.0, -0.5, 6.0, &"facade_brick"],
	["city_se", 56.0, 90.0, -66.5, -124.0, 1.0, &"facade_dark"],
	["city_s", -12.0, 90.0, -137.0, -154.0, 12.0, &"facade_brick"],
]

func _city() -> void:
	for block: Array in CITY:
		var x0: float = block[1]
		var x1: float = block[2]
		var z0: float = minf(block[3], block[4])
		var z1: float = maxf(block[3], block[4])
		var nx := ceili((x1 - x0) / 32.0 - 1e-6)
		var nz := ceili((z1 - z0) / 32.0 - 1e-6)
		for i: int in nx:
			for j: int in nz:
				var label: String = block[0] if nx * nz == 1 else "%s_%d_%d" % [block[0], i + 1, j + 1]
				var a := x0 + (x1 - x0) * i / nx
				var b := x0 + (x1 - x0) * (i + 1) / nx
				var c := z0 + (z1 - z0) * j / nz
				var d := z0 + (z1 - z0) * (j + 1) / nz
				_solid(label, _rect(a, b, c, d, block[5]), STREET, block[6], -1, "scenery")

# --- progress, finish and hints --------------------------------------------------------------

func _define_progress() -> void:
	# stages are collected by standing on their decks (radius 0 turns off the distance rule), so
	# a flight over a gap or through the duct never collects the deck beyond it by itself.
	spawn = _pose(Vector3(0, Y_START, ROOF_N - 5.0), 0.0)
	var gz := (GANTRY_Z[0] + GANTRY_Z[1]) * 0.5
	checkpoints = [
		{"pose": spawn, "title": "Tannery roof"},
		{"pose": _pose(Vector3(2.0, Y_GANTRY, gz), -PI * 0.5), "title": "Gantry", "radius": 0.0},
		{"pose": _pose(Vector3(27.5, Y_GANTRY, -62.0), 0.0), "title": "Scaffold", "radius": 0.0},
		{"pose": _pose(Vector3(51.5, Y_COLD, -61.0), PI), "title": "Lamp room", "radius": 0.0},
		{"pose": _pose(Vector3(52.0, Y_COLD, -29.0), PI), "title": "Signal runway", "radius": 0.0},
	]
	segment_bounds = [
		AABB(Vector3(-9, -4, -59), Vector3(18, 12, 79)),
		AABB(Vector3(8, -5, -67), Vector3(29, 10, 25)),
		AABB(Vector3(22, -6, -126), Vector3(36, 10, 60)),
		AABB(Vector3(45, -5, -67), Vector3(22, 10, 35)),
		AABB(Vector3(41, -8, -33), Vector3(28, 12, 80)),
	]
	water_audio_sources = [Vector3(15, STREET + 0.2, -30), Vector3(15, STREET + 0.2, -90), Vector3(55, STREET + 0.2, 4), Vector3(80, STREET + 0.2, 4)]
	var ordinary: Array = [Vector3(0, 0, -20), Vector3(0, -3, -49), Vector3(22, -3, -49), Vector3(27.5, -3, -64), Vector3(27.5, -4.5, -118),
		Vector3(39, -4.5, -120.5), Vector3(50.5, -4.5, -118), Vector3(50.5, -3, -66), Vector3(52, -3, -52)]
	routes = {
		"ordinary": ordinary + [Vector3(63, -3, -40), Vector3(63, -3, -16), Vector3(63, Y_BRIDGE, 4.25), Vector3(63, Y_COMMS, 24.5), Vector3(63, Y_DECK, 34), Vector3(58, Y_DECK, 38)],
		"duct": ordinary + [Vector3(51.5, -3, -44), Vector3(51.5, -3, -32), Vector3(63, -3, -20), Vector3(63, Y_BRIDGE, 4.25), Vector3(63, Y_COMMS, 24.5), Vector3(63, Y_DECK, 34), Vector3(58, Y_DECK, 38)],
		"earned": ordinary + [Vector3(63, -3, -40), Vector3(59, -3, -28), Vector3(52, -3, -20), Vector3(52, -3, 0), Vector3(52, Y_COMMS, 11), Vector3(45, Y_COMMS, 24.5), Vector3(45, Y_DECK, 34), Vector3(48, Y_DECK, 38)],
	}
	routes["basic"] = routes["ordinary"]
	routes["advanced"] = routes["earned"]
	_declare_gaps()

func _declare_gaps() -> void:
	# p / intended entry speeds are design choices for the earned line, not measurements.
	var gz := (GANTRY_Z[0] + GANTRY_Z[1]) * 0.5
	_gap("gantry_1", "gantry", "ordinary", Vector3(GANTRY[0][1], Y_GANTRY, gz), Vector3(GANTRY[1][0], Y_GANTRY, gz), "respawn: the gantry checkpoint", 0.0)
	_gap("gantry_2", "gantry", "ordinary", Vector3(GANTRY[1][1], Y_GANTRY, gz), Vector3(GANTRY[2][0], Y_GANTRY, gz), "respawn: the gantry checkpoint", 0.0)
	_gap("signal_street", "signal", "earned", Vector3(52, Y_COLD, STREET_B[0]), Vector3(52, Y_COMMS, STREET_B[1]), "respawn: the signal runway checkpoint", 420.0)

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
		"kind": "earned" if line == "earned" else "ordinary",
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

## the full course record: stages, gaps, crouch passages, recoveries, pieces, units.
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
		if piece.role == "route":
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
		"gaps": gaps, "crouch_passages": crouch_passages, "crouch_required": false,
		"recovery": "a fall through a gantry gap, off the runway lip or over any parapet leaves the kill envelope (y < %.1f) and respawns at the last checkpoint" % KILL_Y,
		"surfaces": "wet look only; no surface changes traction",
		"longest_walkable_piece_m": snappedf(longest, 0.001), "geometry_hash": geometry_hash(), "pieces": manifest.size(),
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
	if feet.x > DUCT_X[0] - 0.2 and feet.x < DUCT_X[1] + 0.2 and feet.z < PLANT[2] and feet.z > PLANT[3] and absf(feet.y - Y_COLD) < 0.5:
		return "In the duct: keep crouch held (C or Ctrl) until you are out on the runway."
	match stage:
		0:
			return "Run the tannery roof and drop down the terraces, then right onto the gantry. Esc opens stage practice."
		1:
			return "Hop the two missing panels on the gantry. A fall is a respawn here. Then left onto the scaffold."
		2:
			return "Follow the scaffold round the tower: down a lift, two wide corner bays, back up to the lamp room."
		3:
			return "North door: crouch through the low duct ahead (hold C or Ctrl), or run round the plant room on the right."
		4:
			return "With speed, jump the street off the runway lip. Otherwise take the ramp on the right to the footbridge."
	return "Up either ramp onto the antenna deck and cross the line short of the mast."

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

func _deck(label: String, x0: float, x1: float, z0: float, z1: float, top: float, kind: StringName, stage: int, base: float = STREET, role: String = "route") -> StaticBody3D:
	return _solid(label, _rect(x0, x1, z0, z1, top), base, kind, stage, role)

func _parapet_z(label: String, x0: float, x1: float, z0: float, z1: float, deck: float) -> void:
	_solid(label, _rect(x0, x1, z0, z1, deck + PARAPET), STREET, &"brick_cap", -1, "wall")

func _prop(label: String, model: String, feet: Vector3, yaw: float, box: Vector3, height: float = 0.0) -> void:
	# a sourced model at `feet`. a reachable one gets a box of `box` (x, height, z in its own frame)
	# as its collision, drawn by the model; an out-of-reach one (box zero) is visual only.
	var entry := {"name": label, "model": model, "feet": feet, "yaw": yaw, "height": height if height > 0.0 else box.y, "box": box}
	if box != Vector3.ZERO:
		var basis := Basis(Vector3.UP, yaw)
		var hx := basis * Vector3(box.x * 0.5, 0, 0)
		var hz := basis * Vector3(0, 0, box.z * 0.5)
		var top := feet.y + box.y
		var c := Vector3(feet.x, top, feet.z)
		_solid(label, [c - hx - hz, c + hx - hz, c + hx + hz, c - hx + hz], feet.y - 0.3, &"prop", -1, "prop", false)
		entry["collision"] = label
	props.append(entry)

func _lamp(at: Vector3, colour: Color, energy: float, reach: float, purpose: String, mount: String) -> void:
	# a light at `at`, hung from a ceiling or a strip, or on a wall bracket: never over a deck lower
	# than the headroom, so the fixture needs no collision.
	lamps.append({"at": at, "colour": colour, "energy": energy, "range": reach, "purpose": purpose, "mount": mount})

func _post_lamp(label: String, foot: Vector3, top_y: float, arm: Vector3, colour: Color, energy: float, reach: float, purpose: String) -> void:
	# a lamp post standing on a parapet or girder: a 0.2 m solid post up to top_y, its head on an
	# arm reaching over the deck at the headroom or higher.
	_solid(label, _rect(foot.x - 0.1, foot.x + 0.1, foot.z + 0.1, foot.z - 0.1, top_y), foot.y - 0.1, &"lamp_post", -1, "wall")
	lamps.append({"at": Vector3(foot.x + arm.x, top_y - 0.12, foot.z + arm.z), "colour": colour, "energy": energy, "range": reach, "purpose": purpose, "mount": "post", "post": label, "foot": foot})

func _solid(label: String, top: Array, base: float, kind: StringName, stage: int = -1, role: String = "solid", draw: bool = true) -> StaticBody3D:
	# a convex prism: a planar or sloped convex top polygon extruded straight down to `base`.
	assert(not has_node(NodePath(label)), "rainline: duplicate piece " + label)
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
		prisms.append({"name": label, "top": top.duplicate(), "base": base, "kind": kind, "role": role})
	manifest.append({"name": label, "role": role, "stage": stage, "points": points, "shape": "prism", "kind": kind})
	return body

func _hull(label: String, points: Array[Vector3], faces: Array, kind: StringName, role: String) -> StaticBody3D:
	# a general convex piece from its corners, with its faces listed for drawing.
	assert(not has_node(NodePath(label)), "rainline: duplicate piece " + label)
	var body := StaticBody3D.new()
	body.name = label
	body.set_meta("surface", role)
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array(points)
	shape.shape = hull
	body.add_child(shape)
	add_child(body)
	prisms.append({"name": label, "hull": points.duplicate(), "faces": faces, "kind": kind, "role": role})
	manifest.append({"name": label, "role": role, "stage": -1, "points": points, "shape": "hull", "kind": kind})
	return body

func _prism_visual(top: Array, base: float, kind: StringName) -> void:
	prisms.append({"name": "", "top": top.duplicate(), "base": base, "kind": kind, "role": "visual"})

func _paint_x(label: String, x0: float, x1: float, z: float, width: float, y: float, kind: StringName) -> void:
	_paint_line(label, Vector3(x0, y, z), Vector3(x1, y, z), Vector3(0, 0, width), kind)

func _paint_z(label: String, x: float, z0: float, z1: float, width: float, y: float, kind: StringName) -> void:
	_paint_line(label, Vector3(x, y, z0), Vector3(x, y, z1), Vector3(width, 0, 0), kind)

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
