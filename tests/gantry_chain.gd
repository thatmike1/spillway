extends "res://tests/gantry_routes.gd"
## prove the preserved two-slot prefix, then earn and replay the longer third transfer.
const CHAIN := preload("res://scripts/maps/gantry_chain.gd")
var third_release := 18.0

func _initialize() -> void:
	output = "/tmp/r22-03-hop-into-swing/chain"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func control(fast: bool, tick: int, slot: int) -> Dictionary:
	var original_release := release_after
	var original_lead := entry_lead
	if slot == 2:
		release_after = third_release
		entry_lead = 14
	var cmd := super.control(fast, tick, slot)
	release_after = original_release
	entry_lead = original_lead
	return cmd

func chain_config() -> void:
	route_map = CHAIN.CHAIN_ID
	registry = {"catalog": {CHAIN.CHAIN_ID: CHAIN.CHAIN_ENTRY.duplicate(true)}, "order": [CHAIN.CHAIN_ID], "default_chain": [CHAIN.CHAIN_ID]}
	route_edges = [-12.0, -60.0, -108.0]
	route_limits = [-30.0, -78.0, -136.0]
	route_anchors = [LEVEL.ANCHORS[0], LEVEL.ANCHORS[1], CHAIN.THIRD_ANCHOR]
	goal_z = -190

func run() -> void:
	RenderingServer.render_loop_enabled = false
	Engine.physics_ticks_per_second = 128
	DirAccess.make_dir_recursive_absolute(output)
	jump_after = 80
	release_after = 12
	trace_enabled = true
	var base: Dictionary = await attempt(true)
	var tape: Array = base.tape
	chain_config()
	stop_tick = base.ticks
	var prefix: Dictionary = await attempt(true, tape)
	var same_prefix: bool = base.finished and base.respawns == 0 and prefix.respawns == 0 and base.motion_trace == prefix.motion_trace
	var worst_position := 0.0
	var worst_velocity := 0.0
	for i: int in mini(base.motion_trace.size(), prefix.motion_trace.size()):
		worst_position = maxf(worst_position, (base.motion_trace[i][0] as Vector3).distance_to(prefix.motion_trace[i][0]))
		worst_velocity = maxf(worst_velocity, (base.motion_trace[i][1] as Vector3).distance_to(prefix.motion_trace[i][1]))
	var prefix_receipt := {"ok": same_prefix, "ticks": base.ticks, "samples": base.motion_trace.size(), "chain_samples": prefix.motion_trace.size(), "worst_position_error_m": worst_position, "worst_velocity_error_m_s": worst_velocity, "fields": ["position", "velocity", "jumps", "landings", "grounded"], "base_finished": base.finished, "chain_finished_at_old_finish": prefix.finished}
	FileAccess.open(output.path_join("prefix.json"), FileAccess.WRITE).store_string(JSON.stringify(prefix_receipt, "\t"))
	print("CHAIN_PREFIX ", JSON.stringify(prefix_receipt))
	if not same_prefix or prefix.finished:
		quit(1)
		return
	trace_enabled = false
	stop_tick = 0
	var result: Dictionary = {}
	for distance: float in [8, 10, 12, 14, 16, 18, 20]:
		third_release = distance
		result = await attempt(true)
		print("CHAIN_SWEEP release=", distance, " ", JSON.stringify({"finished": result.finished, "ticks": result.ticks, "transfers": result.transfers, "position": result.position}))
		if result.finished:
			break
	tape = result.tape
	result.erase("tape")
	result.erase("motion_trace")
	result["third_release_m"] = third_release
	result["prefix_exact"] = same_prefix
	var replay: Dictionary = await attempt(true, tape) if result.finished else {}
	result["host_replay_exact"] = not replay.is_empty() and replay.finished and replay.ticks == result.ticks and replay.transfers == result.transfers and replay.respawns == 0
	var arrivals: Array = result.transfers.filter(func(row: Dictionary) -> bool: return row.attached)
	result["third_entry_faster"] = arrivals.size() == 3 and arrivals[2].speed_ups > arrivals[1].speed_ups
	result["third_direct_from_hop"] = arrivals.size() == 3 and arrivals[2].since_jump_ticks <= 32
	FileAccess.open(output.path_join("timeline.json"), FileAccess.WRITE).store_string(JSON.stringify(tape))
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("CHAIN_RESULT ", JSON.stringify(result))
	quit(0 if result.finished and result.host_replay_exact and result.third_entry_faster and result.third_direct_from_hop else 1)
