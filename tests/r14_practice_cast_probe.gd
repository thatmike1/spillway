extends SceneTree
## p / engine diagnostic for Penstock Yard, not a gate: does a source hull's landing sweep
## miss any of the practice map's own floors? godot 4.7.2 misses some diagonal casts into
## large floor boxes (tests/r14_source_repair_probe.gd); this map's floors are convex prisms,
## not boxes, so this sweeps the real pieces instead of assuming either way. for every piece
## with a walkable top it samples interior points (0.6 m clear of the top's edges), starts the
## hull above the face at 0.637 of the motion's drop (2.97 u of the review fixture's 4.66) and
## casts the motions below; each ends below the face, so a cast that returns no collision
## would tunnel. writes cast_probe.json under --out.
## godot --headless --audio-driver Dummy --path . --script res://tests/r14_practice_cast_probe.gd -- --out=DIR

const LEVEL := preload("res://scripts/r14_practice_level.gd")
const P := preload("res://scripts/r14_source_player.gd")
const U := 0.0254
## u per tick: the review fixture's 64 hz landing and the same at 128 hz, then a landing
## (298 u/s down) in each of eight horizontal directions, 45 degrees apart, at 300 u/s and
## 64 hz and at 1100 u/s and 128 hz: orientation matters to the miss.
const REVIEW := Vector3(24.8896732, -298.0066223, -299.7286072)
var MOTIONS := {}
const CLEAR := 0.6
const START := 2.97 / (298.0066223 / 64.0)
## direction 0 is +x, 90 is -z (forward on the stop logs), 180 is -x (forward on the runway).
const MAX_SAMPLES := 600

var out := ""

func _initialize() -> void:
	MOTIONS["review_64"] = REVIEW / 64.0
	MOTIONS["review_128"] = REVIEW / 128.0
	for i: int in 8:
		var a := deg_to_rad(45.0 * i)
		var h := Vector3(cos(a), 0.0, -sin(a))
		MOTIONS["dir%03d_300_64" % (45 * i)] = (h * 300.0 + Vector3(0, -298.0, 0)) / 64.0
		MOTIONS["dir%03d_1100_128" % (45 * i)] = (h * 1100.0 + Vector3(0, -298.0, 0)) / 128.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	assert(out.is_absolute_path(), "cast probe: pass --out=<absolute directory>")
	_run.call_deferred()

func _run() -> void:
	var level: Node3D = LEVEL.new()
	root.add_child(level)
	level.call("build")
	var player: CharacterBody3D = P.new()
	player.input_enabled = false
	root.add_child(player)
	await physics_frame
	await physics_frame
	var space := level.get_world_3d().direct_space_state
	var rows: Array = []
	var total := {}
	for entry: Dictionary in level.get("manifest"):
		var points: Array = entry.get("points", [])
		if points.is_empty():
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		var top := -INF
		for p: Vector3 in points:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
			top = maxf(top, p.y)
		var body := level.get_node_or_null(NodePath(str(entry.name))) as CollisionObject3D
		if body == null:
			continue
		var area := (hi.x - lo.x) * (hi.y - lo.y)
		var step := maxf(0.5, sqrt(area / MAX_SAMPLES))
		var samples := 0
		var misses := {}
		var first := {}
		var x := lo.x + CLEAR
		while x <= hi.x - CLEAR:
			var z := lo.y + CLEAR
			while z <= hi.y - CLEAR:
				var hit := _face(space, body, x, z, top)
				# interior only: the same walkable face 0.6 m out on all four sides.
				if not hit.is_empty() and not _face(space, body, x + CLEAR, z, top).is_empty() and not _face(space, body, x - CLEAR, z, top).is_empty() \
						and not _face(space, body, x, z + CLEAR, top).is_empty() and not _face(space, body, x, z - CLEAR, top).is_empty():
					samples += 1
					for name: String in MOTIONS:
						var m: Vector3 = MOTIONS[name]
						player.global_position = hit.position + Vector3.UP * START * -m.y * U
						if player.move_and_collide(MOTIONS[name] * U, true, 0.001, true, 4) == null:
							misses[name] = int(misses.get(name, 0)) + 1
							if not first.has(name):
								first[name] = [snappedf(x, 0.01), snappedf(hit.position.y, 0.001), snappedf(z, 0.01)]
				z += step
			x += step
		if samples == 0:
			continue
		var size_u := [roundi((hi.x - lo.x) / U), roundi((hi.y - lo.y) / U)]
		rows.append({"piece": entry.name, "role": entry.get("role", ""), "size_m": [snappedf(hi.x - lo.x, 0.01), snappedf(hi.y - lo.y, 0.01)], "size_u": size_u,
			"samples": samples, "misses": misses, "first_miss": first})
		for name: String in MOTIONS:
			total[name] = int(total.get(name, 0)) + int(misses.get(name, 0))
		if not misses.is_empty():
			print("cast probe: %s %s u: %d samples, misses %s" % [entry.name, size_u, samples, misses])
	var sweeps := 0
	for row: Dictionary in rows:
		sweeps += int(row.samples)
	print("cast probe: %d pieces, %d sample points x %d motions, misses %s" % [rows.size(), sweeps, MOTIONS.size(), total])
	DirAccess.make_dir_recursive_absolute(out)
	var motions := {}
	for name: String in MOTIONS:
		var m: Vector3 = MOTIONS[name]
		motions[name] = [m.x, m.y, m.z]
	var f := FileAccess.open(out.path_join("cast_probe.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine": Engine.get_version_info(), "geometry_hash": level.call("geometry_hash"), "player_sha256": FileAccess.get_sha256("res://scripts/r14_source_player.gd"),
		"start_fraction_of_drop": START, "motions_u_per_tick": motions, "clear_m": CLEAR, "total_misses": total, "rows": rows}, "\t"))
	f.close()
	quit()

## the walkable face of `body` under (x, z), or {} when the first thing below is not it.
func _face(space: PhysicsDirectSpaceState3D, body: CollisionObject3D, x: float, z: float, top: float) -> Dictionary:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top + 1.0, z), Vector3(x, top - 30.0, z)))
	if hit.is_empty() or hit.collider != body or hit.normal.y < 0.7:
		return {}
	return hit
