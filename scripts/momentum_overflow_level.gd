extends Node3D
## p / r13 overflow: a compact gravity-fed maintenance course on a dam, for the carry motor.
## one script builds the full course or the neutral jump/turn block (and its mirrored and
## landing-offset holdouts). every walkable or reachable solid is a convex prism or a kit
## prop proxy listed in a geometry manifest; its hash freezes the block before air profiles
## are compared. layout, numbers and criteria: docs/momentum/OVERFLOW.md.
##
## course, in order (forward is -z until the tail race, then -x):
##   crest -> 15 degree apron -> slot hop (3.0 m, 1 m down) -> terrace -> descent ->
##   slot hop (3.5 m, 1 m down) -> pier (hop it to keep speed) -> spill bay: jump it straight
##   on with carried speed, or take the slipway down and up on the left -> crest -> converging
##   chute -> flip bucket over the plunge pool -> tail race turn -> uphill arrival onto the
##   sluice deck. every gap lands short on a catch apron that climbs forward.
## the block variants keep the first prototype's pier section unchanged as frozen controls.

const Materials := preload("res://scripts/momentum_materials.gd")

const VARIANTS := ["course", "block", "block_mirror", "block_offset"]
## p / the landing-offset holdout moves everything after the block's gap this far sideways.
const OFFSET := 3.0
const WALL_THICK := 0.4
## p / training walls are taller than a hop's 1.3 m apex; parapets are ordinary guards.
const TRAINING := 2.0
const PARAPET := 1.1
const NEUTRAL := {
	&"deck": Color("c9c9c6"), &"concrete": Color("a3a5a6"), &"old_concrete": Color("6e7571"),
	&"steel": Color("56616c"), &"ochre": Color("b08a40"), &"brick": Color("8a4b3c"),
	&"landing": Color("d8d6cf"), &"apron": Color("7d827c"), &"pool": Color("6a716c"), &"hill": Color("5f6b52"),
}
## p / course look over the kit's kinds: run decks a step below landing decks, catch aprons
## darker and stained, walls a mid value so they neither glare nor go black in shadow, and
## valley sides mossy so the course separates from its background. the block keeps the kit.
const COURSE_LOOK := {
	&"deck": [&"deck", {"top_tint": Vector3(1.06, 1.05, 1.01), "side_tint": Vector3(1.0, 1.0, 1.02), "bay_tone": 0.08, "joint_dark": 0.55}],
	&"landing": [&"deck", {"top_tint": Vector3(1.24, 1.21, 1.13), "side_tint": Vector3(1.0, 1.0, 1.02), "bay_tone": 0.04, "joint_dark": 0.45}],
	&"concrete": [&"concrete", {"top_tint": Vector3(1.02, 1.02, 1.02), "side_tint": Vector3(1.04, 1.04, 1.05)}],
	&"apron": [&"old_concrete", {"top_tint": Vector3(0.66, 0.69, 0.65), "stain": 0.7, "bay_size": Vector2(3.0, 3.0), "bay_tone": 0.1}],
	&"pool": [&"old_concrete", {"top_tint": Vector3(0.62, 0.66, 0.63), "stain": 0.8, "waterline": -4.6}],
	&"hill": [&"old_concrete", {"desaturate": 0.15, "top_tint": Vector3(0.5, 0.58, 0.4), "side_tint": Vector3(0.44, 0.5, 0.36), "stain": 0.9, "bay_size": Vector2(0.0, 0.0), "macro_strength": 0.2, "macro_scale": 23.0}],
}
## p / course heights (m). the pier is shared with the block; everything past it is course only.
const PIER_Y := 8.5
const DIP_Y := 2.0
const CREST_Y := 3.5
const CREST_Z := -82.0
const TOE_Y := -4.5
const LIP_Y := -3.0
const LIP_Z := -115.0
const POOL_Y := -6.5
const TAIL_Y := -3.5
const POOL_END := -126.5
const SLUICE_Y := 0.5
const SLUICE_Z := -190.0

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
## declared jumps for the geometry test: edge, landing, the design approach speed and the
## take-off surface's climb (rise per metre); "earned" gaps also name a drained speed that
## must fall short. design coordinates mapped to world.
var jump_gaps: Array[Dictionary] = []
## the respawn envelope: leaving it (falling past the tailwater) restores the last stage.
var kill_bounds := AABB(Vector3(-180, -8.3, -400), Vector3(360, 400, 460))
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
var _looks: Dictionary = {}

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
		_course_pier()
		_spill_bay()
		_chute_and_bucket()
		_tail_race()
		_sluice()
	else:
		_pier_section()
		_block_finish()
	_scenery()
	_commit_meshes()
	_define_progress()

# --- the course ---------------------------------------------------------------------------

func _crest_and_apron() -> void:
	# beat 1: open descent. the crest walk, a 15 degree apron and the first slot hop.
	_deck("crest", -5, 5, 56, 44, 20.5, &"deck", 0)
	_ramp_z("apron", -5, 5, 44, 22, 20.5, 14.5, &"deck", 0)
	_deck("terrace_1", -5, 5, 22, 11, 14.5, &"landing", 0)
	_slot_hop("slot_1", 11.0, 8.0, 14.5, 13.5, 0.0)
	# training walls along both sides; the right side steps out around slot 1's return.
	_wall_z("crest_l", -5, 58, 44, 20.5, 20.5, -1, TRAINING)
	_wall_z("crest_r", 5, 58, 44, 20.5, 20.5, 1, TRAINING)
	_wall_z("apron_l", -5, 44, 22, 20.5, 14.5, -1, TRAINING)
	_wall_z("apron_r", 5, 44, 22, 20.5, 14.5, 1, TRAINING)
	_wall_z("terrace_1_l", -5, 22, 11, 14.5, 14.5, -1, TRAINING)
	_wall_z("terrace_1_r", 5, 22, 11, 14.5, 14.5, 1, TRAINING)
	_wall_z("terrace_2_l", -5, 8, -4, 13.5, 13.5, -1, TRAINING)

func _course_pier() -> void:
	# terrace 2, the descent and slot 2 as in the block, then a longer pier that widens to the
	# left before its end. running it bleeds overspeed; hopping it keeps the speed.
	_deck("terrace_2", -5, 5, 8, -4, 13.5, &"landing", 0)
	_wall_z("terrace_2_r_tail", 5, -2.92, -4, 13.5, 13.5, 1, TRAINING)
	_ramp_z("descent", -5, 5, -4, -18, 13.5, 9.5, &"deck", 0)
	_deck("runout", -5, 5, -18, -28, 9.5, &"deck", 0)
	_wall_z("descent_l", -5, -4, -18, 13.5, 9.5, -1, TRAINING)
	_wall_z("descent_r", 5, -4, -18, 13.5, 9.5, 1, TRAINING)
	_wall_z("runout_l", -5, -18, -28, 9.5, 9.5, -1, TRAINING)
	_wall_z("runout_r", 5, -18, -28, 9.5, 9.5, 1, TRAINING)
	_wall_x("wing_2_end", 5, 8.4, -4, 13.5, -1, TRAINING)
	_slot_hop("slot_2", -28.0, -31.5, 9.5, 8.5, 0.0)
	# p / the pier runs 34.5 m to the bay's wide edge. from z -36 it widens 20 m left, where a
	# slipway lane leaves the platform at z -54 and dips through the bay to the chute's crest.
	# bases reach below the bay apron so nothing walks under the pier.
	_deck("pier", -5, 5, -31.5, -66, PIER_Y, &"deck", 1, -4.0)
	_solid("platform_e", [Vector3(-5, PIER_Y, -36), Vector3(-5, PIER_Y, -66), Vector3(-11, PIER_Y, -66), Vector3(-11, PIER_Y, -39.6)], -4.0, &"deck", 1, "route")
	_solid("platform_w", [Vector3(-11, PIER_Y, -39.6), Vector3(-11, PIER_Y, -54), Vector3(-25, PIER_Y, -54), Vector3(-25, PIER_Y, -48)], -4.0, &"deck", 1, "route")
	_wall_z("pier_l", -5, -31.5, -36, PIER_Y, PIER_Y, -1, PARAPET)
	_wall_line("platform_nw", Vector3(-5, PIER_Y, -36), Vector3(-25, PIER_Y, -48), Vector2(-1, 1), PARAPET)
	_rail_line("pier_rail", Vector3(4.86, PIER_Y, -42.6), Vector3(4.86, PIER_Y, -65.86))
	# the ochre nosing marks the jump edge; nothing stands on it.
	_strip("bay_nosing", Vector3(-11, PIER_Y, -66), Vector3(5, PIER_Y, -66), Vector3(0, 0, 0.35))

func _spill_bay() -> void:
	# beat 2: the spill bay. straight on, the chute's crest is 16 m beyond the pier's edge and
	# 5 m lower: a hopped pier carries enough speed to clear it, a run along the pier drains
	# too much. short jumps land on a catch apron that rises forward to the crest. on the
	# left, the slipway lane keeps its height as speed: down 6.5 m, through a dip and up 1.5 m
	# over the crest, where the climb's rate lifts the runner onto the chute.
	_solid("slipway", [Vector3(-25, PIER_Y, -54), Vector3(-11, PIER_Y, -54), Vector3(-11, DIP_Y, -72), Vector3(-25, DIP_Y, -72)], -4.0, &"deck", 1, "route")
	_solid("slip_dip", [Vector3(-25, DIP_Y, -72), Vector3(-11, DIP_Y, -72), Vector3(-11, DIP_Y, -74), Vector3(-25, DIP_Y, -74)], -4.0, &"deck", 1, "route")
	_solid("slip_rise", [Vector3(-25, DIP_Y, -74), Vector3(-11, DIP_Y, -74), Vector3(-11, CREST_Y, CREST_Z), Vector3(-25, CREST_Y, CREST_Z)], -4.0, &"deck", 1, "route")
	_solid("bay_apron", [Vector3(-11, CREST_Y - 5.8, -66), Vector3(9, CREST_Y - 5.8, -66), Vector3(9, CREST_Y, CREST_Z), Vector3(-11, CREST_Y, CREST_Z)], -4.0, &"apron", -1, "catch")
	_wall_line("slip_w_head", Vector3(-25, PIER_Y, -48), Vector3(-25, PIER_Y, -54), Vector2(-1, 0), PARAPET)
	_wall_line("slip_w", Vector3(-25, PIER_Y, -54), Vector3(-25, DIP_Y, -72), Vector2(-1, 0), PARAPET)
	_wall_line("slip_w_dip", Vector3(-25, DIP_Y, -72), Vector3(-25, DIP_Y, -74), Vector2(-1, 0), PARAPET)
	_wall_line("slip_w_rise", Vector3(-25, DIP_Y, -74), Vector3(-25, CREST_Y, CREST_Z), Vector2(-1, 0), PARAPET)
	# the bay's east wall stands 2 m above the pier, so a sideways flight stays in the bay.
	_solid("bay_e", [Vector3(9, PIER_Y + TRAINING, -65.6), Vector3(9.4, PIER_Y + TRAINING, -65.6), Vector3(9.4, PIER_Y + TRAINING, CREST_Z), Vector3(9, PIER_Y + TRAINING, CREST_Z)], -4.0, &"concrete", -1, "wall")
	_solid("bay_ne", [Vector3(5, PIER_Y + TRAINING, -65.6), Vector3(9, PIER_Y + TRAINING, -65.6), Vector3(9, PIER_Y + TRAINING, -66), Vector3(5, PIER_Y + TRAINING, -66)], -4.0, &"concrete", -1, "wall")

func _chute_and_bucket() -> void:
	# beat 3: the spillway chute narrows onto a flip bucket; its lip throws the runner over a
	# dry plunge pool. a run-off without a jump drops onto the pool apron, which climbs ahead.
	# p / 8 m down over 24 m from the crest (18 degrees): steep enough to outpace push drag, so even a runner
	# who arrives at run speed reaches the lip near 14 m/s.
	_solid("chute", [Vector3(-25, CREST_Y, CREST_Z), Vector3(9, CREST_Y, CREST_Z), Vector3(9, TOE_Y, -106), Vector3(-14, TOE_Y, -106)], -8.0, &"deck", 2, "route")
	_strip("crest_nosing", Vector3(-25, CREST_Y, CREST_Z), Vector3(9, CREST_Y, CREST_Z), Vector3(0, 0, -0.35))
	_solid("chute_toe", [Vector3(-14, TOE_Y, -106), Vector3(9, TOE_Y, -106), Vector3(9, TOE_Y, -109), Vector3(-14, TOE_Y, -109)], -8.0, &"deck", 2, "route")
	_solid("bucket", [Vector3(-14, TOE_Y, -109), Vector3(9, TOE_Y, -109), Vector3(9, LIP_Y, LIP_Z), Vector3(-14, LIP_Y, LIP_Z)], -8.0, &"deck", 2, "route")
	_strip("bucket_lip", Vector3(-14, LIP_Y, LIP_Z), Vector3(9, LIP_Y, LIP_Z), Vector3(0, 0, 0.35))
	_wall_line("chute_l", Vector3(-25, CREST_Y, CREST_Z), Vector3(-14, TOE_Y, -106), Vector2(-1, 0), PARAPET)
	_wall_line("chute_r", Vector3(9, CREST_Y, CREST_Z), Vector3(9, TOE_Y, -106), Vector2(1, 0), PARAPET)
	_wall_line("toe_l", Vector3(-14, TOE_Y, -106), Vector3(-14, TOE_Y, -109), Vector2(-1, 0), PARAPET)
	_wall_line("toe_r", Vector3(9, TOE_Y, -106), Vector3(9, TOE_Y, -109), Vector2(1, 0), PARAPET)
	_wall_line("bucket_l", Vector3(-14, TOE_Y, -109), Vector3(-14, LIP_Y, LIP_Z), Vector2(-1, 0), PARAPET)
	_wall_line("bucket_r", Vector3(9, TOE_Y, -109), Vector3(9, LIP_Y, LIP_Z), Vector2(1, 0), PARAPET)
	# the plunge pool: a catch apron rising 3 m to the tail race (15 degrees), wider than the
	# bucket. p / 11.5 m from the lip: a jump clears it from 14 m/s with 0.26 s to spare, a
	# run off the lip without one falls in.
	var wall_top := LIP_Y + 2.0
	_solid("pool_apron", [Vector3(-18, POOL_Y, LIP_Z), Vector3(13, POOL_Y, LIP_Z), Vector3(13, TAIL_Y, POOL_END), Vector3(-18, TAIL_Y, POOL_END)], -8.0, &"pool", -1, "catch")
	_solid("pool_n_w", [Vector3(-18, wall_top, LIP_Z + 0.4), Vector3(-14, wall_top, LIP_Z + 0.4), Vector3(-14, wall_top, LIP_Z), Vector3(-18, wall_top, LIP_Z)], -8.0, &"concrete", -1, "wall")
	_solid("pool_n_e", [Vector3(9, wall_top, LIP_Z + 0.4), Vector3(13, wall_top, LIP_Z + 0.4), Vector3(13, wall_top, LIP_Z), Vector3(9, wall_top, LIP_Z)], -8.0, &"concrete", -1, "wall")
	_solid("pool_w", [Vector3(-18.4, wall_top, LIP_Z + 0.4), Vector3(-18, wall_top, LIP_Z + 0.4), Vector3(-18, wall_top, POOL_END), Vector3(-18.4, wall_top, POOL_END)], -8.0, &"concrete", -1, "wall")
	_solid("pool_e", [Vector3(13, wall_top, LIP_Z + 0.4), Vector3(13.4, wall_top, LIP_Z + 0.4), Vector3(13.4, wall_top, POOL_END), Vector3(13, wall_top, POOL_END)], -8.0, &"concrete", -1, "wall")

func _tail_race() -> void:
	# beat 4: the tail race bends left, then right, for the sluice house. each bend is wide
	# enough to carry the speed round on a wide line, or brake for the inside; past each outer
	# edge a run-off berm climbs and slows instead of a wall. the arrival ramp then spends what
	# is left on the way up to the sluice deck.
	_solid("tail_deck", [Vector3(-62, TAIL_Y, POOL_END), Vector3(13, TAIL_Y, POOL_END), Vector3(13, TAIL_Y, -156), Vector3(-62, TAIL_Y, -156)], -8.0, &"landing", 3, "route")
	_solid("tail_straight", [Vector3(-62, TAIL_Y, -156), Vector3(-42, TAIL_Y, -156), Vector3(-42, TAIL_Y, -170), Vector3(-62, TAIL_Y, -170)], -8.0, &"landing", 3, "route")
	_solid("berm_s", [Vector3(-24, TAIL_Y, -156), Vector3(13, TAIL_Y, -156), Vector3(13, TAIL_Y + 3.0, -163), Vector3(-24, TAIL_Y + 3.0, -163)], -8.0, &"apron", 3, "recovery")
	_solid("berm_w", [Vector3(-69, TAIL_Y + 3.0, POOL_END), Vector3(-62, TAIL_Y, POOL_END), Vector3(-62, TAIL_Y, -170), Vector3(-69, TAIL_Y + 3.0, -170)], -8.0, &"apron", 3, "recovery")
	_wall_line("berm_s_back", Vector3(-24.4, TAIL_Y + 3.0, -163), Vector3(13.4, TAIL_Y + 3.0, -163), Vector2(0, -1), TRAINING)
	_wall_line("berm_w_back", Vector3(-69, TAIL_Y + 3.0, POOL_END), Vector3(-69, TAIL_Y + 3.0, -170), Vector2(-1, 0), TRAINING)
	_wall_line("tail_e", Vector3(13, TAIL_Y, POOL_END), Vector3(13, TAIL_Y, -156), Vector2(1, 0), TRAINING + 1.0)
	_wall_line("berm_s_e", Vector3(13, TAIL_Y, -156), Vector3(13, TAIL_Y + 3.0, -163), Vector2(1, 0), TRAINING)
	_wall_line("berm_s_w", Vector3(-24, TAIL_Y, -156), Vector3(-24, TAIL_Y + 3.0, -163), Vector2(-1, 0), TRAINING)
	_wall_line("tail_n", Vector3(-69.4, TAIL_Y + 3.0, POOL_END), Vector3(-18, TAIL_Y + 3.0, POOL_END), Vector2(0, 1), TRAINING)
	_wall_line("tail_s_mid", Vector3(-42, TAIL_Y, -156), Vector3(-24, TAIL_Y, -156), Vector2(0, -1), PARAPET)
	_wall_line("straight_e", Vector3(-42, TAIL_Y, -156), Vector3(-42, TAIL_Y, -170), Vector2(1, 0), PARAPET)
	_solid("arrival_ramp", [Vector3(-62, TAIL_Y, -170), Vector3(-42, TAIL_Y, -170), Vector3(-42, SLUICE_Y, SLUICE_Z), Vector3(-62, SLUICE_Y, SLUICE_Z)], -8.0, &"deck", 3, "route")
	_wall_line("arrival_e", Vector3(-42, TAIL_Y, -170), Vector3(-42, SLUICE_Y, SLUICE_Z), Vector2(1, 0), PARAPET)
	_wall_line("arrival_w", Vector3(-62, TAIL_Y, -170), Vector3(-62, SLUICE_Y, SLUICE_Z), Vector2(-1, 0), PARAPET)
	_wall_line("berm_w_s", Vector3(-62.4, TAIL_Y + 3.0, -170), Vector3(-69.4, TAIL_Y + 3.0, -170), Vector2(0, -1), TRAINING)

func _sluice() -> void:
	# the finish line is the arrival ramp's top edge. the sluice deck beyond leaves 25 m of
	# level deck before the house: crossing the line turns the handwheel on the house's face,
	# lifts the outlet gate beside it and lets the outflow run back toward the tail race.
	var z0 := SLUICE_Z
	var house := SLUICE_Z - 26.0
	_solid("sluice_deck", [Vector3(-64, SLUICE_Y, z0), Vector3(-40, SLUICE_Y, z0), Vector3(-40, SLUICE_Y, house), Vector3(-64, SLUICE_Y, house)], -8.0, &"landing", 3, "route")
	_strip("finish_line", Vector3(-62, SLUICE_Y, z0), Vector3(-42, SLUICE_Y, z0), Vector3(0, 0, -0.5))
	_wall_line("sluice_deck_w", Vector3(-64, SLUICE_Y, z0), Vector3(-64, SLUICE_Y, house), Vector2(-1, 0), PARAPET)
	_wall_line("sluice_deck_e", Vector3(-40, SLUICE_Y, z0), Vector3(-40, SLUICE_Y, house), Vector2(1, 0), PARAPET)
	_wall_line("sluice_deck_n_w", Vector3(-64, SLUICE_Y, z0), Vector3(-62, SLUICE_Y, z0), Vector2(0, 1), PARAPET)
	_wall_line("sluice_deck_n_e", Vector3(-42, SLUICE_Y, z0), Vector3(-40, SLUICE_Y, z0), Vector2(0, 1), PARAPET)
	_finish_box = _box(Vector3(-62, SLUICE_Y - 0.3, z0 - 2.5), Vector3(20, 3.5, 3.0))
	finish_position = _w(Vector3(-52, SLUICE_Y, house + 12))
	# the sluice house: a brick tower across the deck's far end, its handwheel facing the runner.
	_solid("sluice_house", [Vector3(-66, 15, house), Vector3(-38, 15, house), Vector3(-38, 15, house - 11), Vector3(-66, 15, house - 11)], -8.0, &"brick", -1, "scenery")
	_prism_visual([Vector3(-66.6, 15.8, house + 0.6), Vector3(-37.4, 15.8, house + 0.6), Vector3(-37.4, 15.8, house - 11.6), Vector3(-66.6, 15.8, house - 11.6)], 15.0, &"concrete")
	_prism_visual([Vector3(-56, 7.6, house + 0.4), Vector3(-48, 7.6, house + 0.4), Vector3(-48, 7.6, house), Vector3(-56, 7.6, house)], 2.6, &"concrete")
	_solid("wheel_plinth", [Vector3(-54.5, SLUICE_Y + 0.9, house + 0.8), Vector3(-49.5, SLUICE_Y + 0.9, house + 0.8), Vector3(-49.5, SLUICE_Y + 0.9, house), Vector3(-54.5, SLUICE_Y + 0.9, house)], SLUICE_Y, &"steel")
	_wheel = _handwheel(_w(Vector3(-52, 5.0, house + 0.7)), 1.9)
	# the outlet: two piers and a steel gate on the house's east side; the release runs +z
	# down a channel beside the arrival ramp, back toward the tail race.
	_solid("outlet_pier_w", [Vector3(-40, 9, house + 1), Vector3(-39, 9, house + 1), Vector3(-39, 9, house - 7), Vector3(-40, 9, house - 7)], -8.0, &"concrete")
	_solid("outlet_pier_e", [Vector3(-29, 9, house + 1), Vector3(-28, 9, house + 1), Vector3(-28, 9, house - 7), Vector3(-29, 9, house - 7)], -8.0, &"concrete")
	_prism_visual([Vector3(-40, 9.8, house + 1), Vector3(-28, 9.8, house + 1), Vector3(-28, 9.8, house - 1), Vector3(-40, 9.8, house - 1)], 9.0, &"steel")
	_solid("outflow_channel", [Vector3(-39, -5.0, house + 1), Vector3(-29, -5.0, house + 1), Vector3(-29, -5.0, -163.4), Vector3(-39, -5.0, -163.4)], -8.0, &"pool", -1, "scenery")
	_gate = Node3D.new()
	_gate.name = "SluiceGate"
	add_child(_gate)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(10.0, 8.0, 0.35)
	plate.mesh = plate_mesh
	plate.material_override = _material(&"steel")
	plate.position = Vector3(0, -1.0, 0)
	_gate.add_child(plate)
	_gate.position = _w(Vector3(-34, 0, house + 0.6))
	_release = MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2(9.6, 52.0)
	_release.mesh = sheet
	_release.material_override = _water_material(Color("6f9d96"), -3.0)
	_release.set_meta("gate_at", _w(Vector3(-34, -4.8, house + 1.0)))
	_release.set_meta("flow", Vector3(0, 0, 1))
	_release.set_meta("length", 52.0)
	_release.visible = false
	add_child(_release)

func _pier_section() -> void:
	# the first prototype's pier section, now built only as the frozen neutral block and its
	# holdouts. the neutral block is this section: terrace 2, a 16 degree descent, a 3.5 m slot hop,
	# the pier and its head turn, the diagonal over the bay, the exit ramp and the pier deck.
	_deck("terrace_2", -5, 5, 8, -4, 13.5, &"deck", 0)
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
	_wall_x("pier_deck_south", -45.4, -19, -62, 3.5, -1, PARAPET)
	_shift = Vector3.ZERO

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
		# bounds hug the decks they name, so a flight over a gap never collects the stage
		# beyond it; standing on a deck of that stage also collects it.
		checkpoints = [
			{"pose": spawn, "title": "Crest"},
			{"pose": _pose(Vector3(0, PIER_Y, -35), 0.0), "title": "Pier", "bounds": _box(Vector3(-25, PIER_Y - 0.2, -66), Vector3(30, 4, 34.5))},
			{"pose": _pose(Vector3(-8, CREST_Y - 0.7, -84), 0.0), "title": "Chute", "bounds": _box(Vector3(-25, CREST_Y - 0.9, CREST_Z - 2.0), Vector3(34, 1.6, 2.0))},
			{"pose": _pose(Vector3(-10, TAIL_Y, -142), PI * 0.5), "title": "Tail race", "bounds": _box(Vector3(-62, TAIL_Y - 0.2, -156), Vector3(75, 1.6, 156 + POOL_END))},
		]
		segment_bounds = [_box(Vector3(-9, 5, -31.5), Vector3(18, 30, 91.5)), _box(Vector3(-26, -5, -86), Vector3(36, 20, 54.5)),
			_box(Vector3(-26, -8, POOL_END), Vector3(40, 20, 86 + POOL_END)), _box(Vector3(-70, -8, SLUICE_Z - 40), Vector3(84, 30, 40 - SLUICE_Z + POOL_END))]
		water_audio_sources = [_w(Vector3(14, 6, 10)), _w(Vector3(-2, -5, -121)), _w(Vector3(-34, -4, SLUICE_Z - 20))]
		routes = {
			"ordinary": [Vector3(0, 20.5, 52), Vector3(0, 14.5, 12), Vector3(0, 13.5, 0), Vector3(0, 9.5, -27), Vector3(0, PIER_Y, -44), Vector3(-17, PIER_Y, -52), Vector3(-18, PIER_Y, -54.5),
				Vector3(-18, DIP_Y, -73), Vector3(-17, CREST_Y, CREST_Z), Vector3(-6, -2.0, -100), Vector3(-1, TOE_Y, -107), Vector3(-1, LIP_Y, LIP_Z + 0.5), Vector3(-1, TAIL_Y, -132),
				Vector3(-10, TAIL_Y, -144), Vector3(-36, TAIL_Y, -145), Vector3(-50, TAIL_Y, -152), Vector3(-52, TAIL_Y, -168), Vector3(-52, SLUICE_Y, SLUICE_Z), Vector3(-52, SLUICE_Y, SLUICE_Z - 10)],
			"shortcut": [Vector3(0, PIER_Y, -50), Vector3(0, PIER_Y, -66), Vector3(0, CREST_Y - 1.0, -85), Vector3(0, -2.0, -100)],
			"bay_recovery": [Vector3(0, 0.0, -72), Vector3(0, CREST_Y, CREST_Z)],
			"pool_recovery": [Vector3(0, POOL_Y + 1.0, LIP_Z - 3.0), Vector3(0, TAIL_Y, POOL_END - 2.0)],
		}
		# p / speeds: the bay's wide end at the speed a hopped pier keeps and the speed a run
		# along it drains to (both measured with W only, see OVERFLOW.md); the bucket lip at a
		# conservative arrival from the chute.
		jump_gaps = [
			{"label": "bay_wide", "edge": _w(Vector3(0, PIER_Y, -66)), "land": _w(Vector3(0, CREST_Y, CREST_Z)), "speed": 16.8, "drained": 11.8, "climb": 0.0, "kind": "earned"},
			{"label": "plunge_pool", "edge": _w(Vector3(0, LIP_Y, LIP_Z)), "land": _w(Vector3(0, TAIL_Y, POOL_END)), "speed": 14.0, "climb": 0.25, "kind": "ordinary"},
		]
		kill_bounds = AABB(Vector3(-180, -8.3, -400), Vector3(360, 400, 460))
	else:
		spawn = _pose(Vector3(0, 13.5, 5), 0.0)
		# p / metadata correction (no geometry change): the pier-deck box now covers the deck
		# alone (x -45..-19); the first prototype's box also spanned the bay's airspace, so a
		# diagonal falling short collected it in flight. the exit ramp still collects it by
		# standing, as stage 2.
		checkpoints = [
			{"pose": spawn, "title": "Block start"},
			{"pose": _pose(Vector3(o, 8.5, -35), 0.0), "title": "Pier", "bounds": _box(Vector3(-5 + o, 8.3, -62), Vector3(13, 4, 30.5))},
			{"pose": _pose(Vector3(-24 + o, 3.5, -54.5), PI * 0.5), "title": "Pier deck", "bounds": _box(Vector3(-45 + o, 3.3, -62), Vector3(26, 6, 15))},
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
		return _block_hint(stage, d)
	if d.z < -66.0 and d.z > CREST_Z and d.y < CREST_Y - 0.1 and d.x > -11.0:
		return "Short of the crest: the apron ahead climbs back to the chute."
	if d.z < -121.0 and d.z > POOL_END and d.y < TAIL_Y - 0.1:
		return "Short of the tail race: the pool apron ahead climbs out."
	if (d.z < -156.0 and d.x > -24.0) or d.x < -62.0:
		return "Past the bend: come off the berm toward the sluice house."
	if (absf(d.z - 9.5) < 6.0 and d.y < 12.6) or (absf(d.z + 30.0) < 8.0 and d.y < 8.4 and d.x > -5.5):
		return "Missed the hop: the ramp on the right climbs back out."
	match stage:
		0:
			return "Run down. Height turns into speed; hop the slots."
		1:
			return "Hop along the pier to keep speed and jump the bay straight on. Slower: take the slipway on the left."
		2:
			return "Down the chute, and jump from the lip of the bucket."
		3:
			return "Left, then right for the sluice house. Brake if a bend is too tight."
	return "Cross the line at the top of the ramp."

func _block_hint(stage: int, d: Vector3) -> String:
	d.x -= _shift_x() if d.z < -28.0 else 0.0
	if d.y < 3.0 and d.z < -31.0 and d.z > -53.0 and d.x < -4.0:
		return "Short of the pier deck: the ramp at the far side of the bay climbs back up."
	if (absf(d.z - 9.5) < 6.0 and d.y < 12.6) or (absf(d.z + 30.0) < 8.0 and d.y < 8.4 and d.x > -5.5):
		return "Missed the hop: the ramp on the right climbs back out."
	match stage:
		0:
			return "Run down and hop the slot onto the pier."
		1:
			return "Turn left at the pier head, or carry speed and hop the bay from the ochre edge."
	return "Cross the band on the pier deck."

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
		var reach := maxf(0.02, smoothstep(0.1, 1.0, _gate_open))
		_release.scale = Vector3(1, 1, reach)
		_release.position = (_release.get_meta("gate_at") as Vector3) + (_release.get_meta("flow") as Vector3) * float(_release.get_meta("length")) * 0.5 * reach

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

func _strip(label: String, a: Vector3, b: Vector3, inward: Vector3) -> void:
	# a flush painted band along a level edge, `inward` across the walking side: visual only.
	var lift := Vector3.UP * 0.004
	_prism_visual([a + lift, b + lift, b + inward + lift, a + inward + lift], minf(a.y, b.y) - 0.05, &"ochre")
	set_meta(label, [_w(a), _w(b)])

func _wall_line(label: String, a: Vector3, b: Vector3, out: Vector2, height: float) -> StaticBody3D:
	# a wall outside the deck edge a-b on the `out` side, its top `height` above the edge all
	# along it, so it follows a sloped edge too.
	var along := Vector2(b.x - a.x, b.z - a.z).normalized()
	var normal := Vector2(-along.y, along.x)
	if normal.dot(out) < 0.0:
		normal = -normal
	var o := Vector3(normal.x, 0.0, normal.y) * WALL_THICK
	var up := Vector3.UP * height
	return _solid(label, [a + up, b + up, b + o + up, a + o + up], minf(a.y, b.y) - 4.0, &"concrete", -1, "wall")

func _plane_y(p1: Vector3, p2: Vector3, p3: Vector3, x: float, z: float) -> float:
	# height at (x, z) of the plane through three points, for exactly planar sloped quads.
	var n := (p2 - p1).cross(p3 - p1)
	return p1.y - (n.x * (x - p1.x) + n.z * (z - p1.z)) / n.y

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
		if variant == "course" and COURSE_LOOK.has(kind):
			if not _looks.has(kind):
				_looks[kind] = Materials.variant(COURSE_LOOK[kind][0], COURSE_LOOK[kind][1])
			return _looks[kind]
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
	# tops read lightest, and long shadows fall forward down the course. the course's sun sits
	# behind the runner's right so the tail race and the sluice house's face, which look -x,
	# are lit too; its ambient is higher so walls in shadow keep a mid value.
	var course := variant == "course"
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("4f86bd") if course else Color("5d8fbf")
	atmosphere.sky_horizon_color = Color("c3cfd1") if course else Color("bccbd0")
	atmosphere.ground_horizon_color = Color("8e988a") if course else Color("a9b2ac")
	atmosphere.ground_bottom_color = Color("464e43") if course else Color("56605a")
	atmosphere.sun_angle_max = 20.0
	sky.sky_material = atmosphere
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9 if course else 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 0.92 if course else 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("c3cdd0") if course else Color("b7c4c8")
	environment.fog_density = 0.0021 if course else 0.0016
	environment.fog_aerial_perspective = 0.5 if course else 0.35
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	if course:
		sun.rotation = Vector3(deg_to_rad(-36.0), deg_to_rad(35.0), 0.0)
		sun.light_energy = 1.25
		sun.light_color = Color("ffeedb")
		sun.directional_shadow_max_distance = 220.0
	else:
		sun.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-28.0) * _mirror, 0.0)
		sun.light_energy = 1.3
		sun.light_color = Color("fff2df")
		sun.directional_shadow_max_distance = 160.0
	sun.shadow_enabled = true
	add_child(sun)

func _scenery() -> void:
	if variant != "course":
		# tailwater around the piers and basin, deep enough that leaving the course over a
		# guard drops out of bounds rather than into a hidden pocket.
		_water(_w(Vector3(-20, -1.2, -60)), Vector2(320, 300), Color("3f6466"))
		return
	# tailwater well below the lowest catch apron; leaving the course drops out of bounds.
	_water(_w(Vector3(-40, -7.6, -110)), Vector2(420, 380), Color("3c6163"))
	# the dam: crest wall, reservoir behind it, and its downstream faces either side of the
	# stepped spillway. none of it is reachable over the training walls.
	_water(_w(Vector3(0, 19.6, 140)), Vector2(400, 160), Color("4b7377"))
	for side: float in [-1.0, 1.0]:
		var inner := side * 5.4
		var outer := side * 95.0
		_solid("dam_crest_%s" % ("l" if side < 0 else "r"), [Vector3(minf(inner, outer), 23.0, 60), Vector3(maxf(inner, outer), 23.0, 60), Vector3(maxf(inner, outer), 23.0, 46), Vector3(minf(inner, outer), 23.0, 46)], -1.5, &"concrete", -1, "scenery")
		_prism_visual([Vector3(minf(inner, outer), 23.0, 46), Vector3(maxf(inner, outer), 23.0, 46), Vector3(maxf(inner, outer), -6.0, -12), Vector3(minf(inner, outer), -6.0, -12)], -6.0, &"old_concrete")
	# the gatehouse behind the spawn, with an overflow weir and spill sheet to the right.
	_solid("gatehouse", [Vector3(-7, 28.5, 61), Vector3(7, 28.5, 61), Vector3(7, 28.5, 56), Vector3(-7, 28.5, 56)], 20.5, &"brick", -1, "scenery")
	_prism_visual([Vector3(-7.6, 29.2, 61.6), Vector3(7.6, 29.2, 61.6), Vector3(7.6, 29.2, 55.4), Vector3(-7.6, 29.2, 55.4)], 28.5, &"concrete")
	_water(_w(Vector3(16, 10.5, 22)), Vector2(8, 52), Color("8fb3ae"), -3.0)
	var spill := get_child(get_child_count() - 1) as Node3D
	spill.rotation.x = atan2(24.0, 50.0)
	# steel gantries over the terraces and the chute: scale and a passing reference at speed.
	for z: float in [26.0, 2.0]:
		_gantry(z, -5.6, 5.6, 13.5, 25.0)
	_gantry(-99.0, -17.0, 12.0, -8.0, 9.5)
	# a brick pump house beside the pier: the bay's landmark on the right.
	_solid("pump_house", [Vector3(14, 17.0, -42), Vector3(24, 17.0, -42), Vector3(24, 17.0, -58), Vector3(14, 17.0, -58)], -6.0, &"brick", -1, "scenery")
	_prism_visual([Vector3(13.5, 17.6, -41.5), Vector3(24.5, 17.6, -41.5), Vector3(24.5, 17.6, -58.5), Vector3(13.5, 17.6, -58.5)], 17.0, &"concrete")
	# valley sides and the far bank, so the horizon is land rather than a uniform sky.
	_prism_visual([Vector3(-190, 40, 40), Vector3(-112, 4, 40), Vector3(-112, 4, -300), Vector3(-190, 40, -300)], -8.0, &"hill")
	_prism_visual([Vector3(60, 6, 40), Vector3(150, 38, 40), Vector3(150, 38, -300), Vector3(60, 6, -300)], -8.0, &"hill")
	_prism_visual([Vector3(-190, 30, -300), Vector3(150, 30, -300), Vector3(150, 2, -250), Vector3(-190, 2, -250)], -8.0, &"hill")

func _gantry(z: float, x0: float, x1: float, foot: float, top: float) -> void:
	# two steel legs and an ochre beam across the route: visual only, high above any flight.
	for x: float in [x0, x1]:
		_prism_visual([Vector3(x - 0.25, top, z + 0.25), Vector3(x + 0.25, top, z + 0.25), Vector3(x + 0.25, top, z - 0.25), Vector3(x - 0.25, top, z - 0.25)], foot, &"steel")
	_prism_visual([Vector3(x0 - 0.6, top + 0.6, z + 0.35), Vector3(x1 + 0.6, top + 0.6, z + 0.35), Vector3(x1 + 0.6, top + 0.6, z - 0.35), Vector3(x0 - 0.6, top + 0.6, z - 0.35)], top - 0.4, &"ochre")
