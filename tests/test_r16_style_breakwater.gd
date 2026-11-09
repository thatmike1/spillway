extends "res://tests/r15_breakwater_driver.gd"
## p / r16 style on the real Breakwater, unchanged r15 main. an r15 driver tape is replayed OPEN
## LOOP (--tape=, key edges and mouse counts only, after the main's own spawn), or a route runs
## closed loop as r15_breakwater_driver.gd does; tests/r16_style_probe.gd builds the post-step
## sample and runs scripts/r16_style.gd. the authored box-row gaps (r15_breakwater_level.gd BLOCKS)
## and the 8.5 m breach are the independent truth the measured gap widths are compared with.
## godot --headless --audio-driver Dummy --path . --script res://tests/test_r16_style_breakwater.gd --
##   --out=DIR (--tape=TAPE | --route=NAME) [--preset=server128]

const PROBE := preload("res://tests/r16_style_probe.gd")
const BW := preload("res://scripts/r15_breakwater_level.gd")

var probe: Node

func _start() -> void:
	super._start()
	probe = PROBE.new(game)
	probe.process_physics_priority = 1001
	root.add_child(probe)

## the authored gaps along the box-row line: gate deck edge, the four blocks, the quay.
static func authored_gaps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var previous := BW.GATE_END
	for i: int in BW.BLOCKS.size():
		var b: Array = BW.BLOCKS[i]
		out.append({"name": "gap_%d" % (i + 1), "near_z": previous, "far_z": float(b[0]), "width_m": previous - float(b[0])})
		previous = float(b[0]) - float(b[1])
	out.append({"name": "gap_quay", "near_z": previous, "far_z": BW.YARD_END, "width_m": previous - BW.YARD_END})
	out.append({"name": "breach", "near_z": BW.MOLE_END, "far_z": BW.HEAD_N, "width_m": BW.BREACH})
	return out

func _end(reason: String, tick: int) -> void:
	var gaps := authored_gaps()
	var matches: Array = []
	for event: Dictionary in probe.scored:
		if str(event.kind) != "gap":
			continue
		var from: Array = event.m.void_from
		var to: Array = event.m.void_to
		var mid := (float(from[2]) + float(to[2])) * 0.5
		var best: Dictionary = {}
		for g: Dictionary in gaps:
			if mid <= float(g.near_z) + 0.5 and mid >= float(g.far_z) - 0.5:
				best = g
		var line := Vector2(float(to[0]) - float(from[0]), float(to[2]) - float(from[2]))
		var cos_angle := absf(line.y) / maxf(line.length(), 1e-9)
		matches.append({"tick": event.tick, "attempt": event.attempt, "cleared_m": event.m.cleared_m, "void_m": event.m.void_m,
			"authored": best.get("name", ""), "authored_m": best.get("width_m", null), "line_cos_to_z": snappedf(cos_angle, 0.0001),
			"perpendicular_m": snappedf(float(event.m.void_m) * cos_angle + float(event.m.hull_width_m), 0.0001) if not best.is_empty() else null,
			"geo": event.geo, "points": event.points})
	var kinds := {}
	for event: Dictionary in probe.scored:
		kinds[event.kind] = int(kinds.get(event.kind, 0)) + 1
	var after_finish: Array = probe.scored.filter(func(e: Dictionary) -> bool: return finish_tick >= 0 and int(e.tick) > finish_tick + 1)
	var out := {"label": "r16 style probe (tests/r16_style_probe.gd, a labelled stand-in for root wiring) on the actual r15 main hosting Breakwater",
		"reason": reason, "ticks": tick, "finish_tick": finish_tick, "finish_kind": game.get("finish_kind"), "respawns": game.get("respawn_count"),
		"style_version": probe.style.STYLE_VERSION, "identity": probe.style.call("identity"), "summary": probe.style.call("summary"),
		"kinds": kinds, "gap_matches": matches, "events_after_finish": after_finish.size(), "lifecycle": probe.lifecycle,
		"diag": (probe.style.call("snapshot") as Dictionary).diag, "style_sha256": FileAccess.get_sha256("res://scripts/r16_style.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tests/r16_style_probe.gd"), "test_sha256": FileAccess.get_sha256("res://tests/test_r16_style_breakwater.gd")}
	_write("style.json", out)
	var lines := PackedStringArray()
	for event: Dictionary in probe.scored:
		lines.append(JSON.stringify(_plain(event)))
	var file := FileAccess.open(out_dir.path_join("style_events.jsonl"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	var rows := PackedStringArray()
	for row: Dictionary in probe.rows:
		rows.append(JSON.stringify(row))
	file = FileAccess.open(out_dir.path_join("style_rows.jsonl.gz"), FileAccess.WRITE)
	file.store_buffer(("\n".join(rows) + "\n").to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
	file.close()
	print("r16 style breakwater: score=%d kinds=%s after_finish=%d" % [int(probe.style.get("score")), kinds, after_finish.size()])
	for m: Dictionary in matches:
		print("  gap tick=%d cleared=%.4f perp=%s authored=%s %s" % [int(m.tick), float(m.cleared_m), str(m.perpendicular_m), str(m.authored), str(m.authored_m)])
	super._end(reason, tick)

static func _plain(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[str(key)] = _plain(value[key])
		return out
	if value is Array:
		return (value as Array).map(func(v: Variant) -> Variant: return _plain(v))
	if value is Vector3:
		return [value.x, value.y, value.z]
	return value
