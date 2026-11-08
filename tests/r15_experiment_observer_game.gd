extends SceneTree
## p / setup only, for the movement lab's os-input demo (tests/r15_experiment_native.py): the
## actual r15 main (scripts/r15_main.gd, as scenes/r15.tscn builds it) started on the lab map, plus
## a read-only observer. after every physics tick (priority 1000) the observer writes the runner's
## state to DIR/latest.json and appends it to DIR/telemetry.jsonl; it never writes pose, velocity,
## view, moves or game state. a file DIR/quit asks the main's own quit path to run.
##
## godot --path . --script res://tests/r15_experiment_observer_game.gd -- --no-records --observer=DIR

class Observer:
	extends Node
	var game: Node
	var dir := ""
	var tick := 0
	var lines := PackedStringArray()

	func _physics_process(_delta: float) -> void:
		var body: CharacterBody3D = game.get("player")
		if body == null:
			return
		var state: Dictionary = body.call("get_motion_state")
		var lab: Dictionary = state.get("experiment", {})
		var row := {"t": tick, "p": _v(body.global_position), "v": _v(body.velocity), "g": bool(body.call("is_grounded")),
			"yaw": body.get("yaw"), "pitch": body.get("pitch"), "duck": body.get("ducked"), "eye_m": float(body.get("_eye_u")) * 0.0254,
			"per_px_rad": deg_to_rad(float(body.get("settings").sensitivity) * 0.022), "paused": game.get("paused"),
			"finished": game.get("finished"), "kind": game.get("finish_kind"), "elapsed": game.get("elapsed"),
			"checkpoint": game.get("checkpoint_index"), "respawns": game.get("respawn_count"), "map": game.get("map_id"),
			"runner": str(body.get_script().resource_path), "mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
			"lab": {"events": lab.get("events", []), "counts": lab.get("counts", {}), "slide": lab.get("slide", {}).get("active", false),
				"wall": lab.get("wall_jump", {}).get("flight", 0), "line": lab.get("grapple", {}).get("attached", false),
				"target": lab.get("grapple", {}).get("target", {}).get("state", ""), "release": lab.get("grapple", {}).get("release", "")}}
		var line := JSON.stringify(row)
		lines.append(line)
		var latest := FileAccess.open(dir.path_join("latest.tmp"), FileAccess.WRITE)
		latest.store_string(line)
		latest.close()
		DirAccess.rename_absolute(dir.path_join("latest.tmp"), dir.path_join("latest.json"))
		if lines.size() >= 256:
			flush()
		tick += 1
		if FileAccess.file_exists(dir.path_join("quit")):
			flush()
			game.call("request_quit")

	func flush() -> void:
		var path := dir.path_join("telemetry.jsonl")
		var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		file.seek_end()
		file.store_string("\n".join(lines) + "\n")
		file.close()
		lines.clear()

	func _v(v: Vector3) -> Array:
		return [v.x, v.y, v.z]

const MAIN := preload("res://scripts/r15_main.gd")

func _initialize() -> void:
	var game: Node = MAIN.new()
	game.name = "R15"
	game.set("map_id", "experiment")
	root.add_child(game)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--observer="):
			var observer := Observer.new()
			observer.name = "ReadOnlyObserver"
			observer.game = game
			observer.dir = arg.trim_prefix("--observer=")
			observer.process_physics_priority = 1000
			observer.process_mode = Node.PROCESS_MODE_ALWAYS
			root.add_child(observer)
