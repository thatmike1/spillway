extends "res://tests/r20_style_stack.gd"
## read the real scorer after its step, before the fixture can seal or replace its host.
var release_observations: Array = []
var release_seen: Dictionary = {}
var release_style_seen: Dictionary = {}

class ReleaseObserver extends Node:
	var controller: SceneTree
	func _physics_process(_delta: float) -> void:
		controller.call("observe_release_style")

func _run() -> void:
	var watcher := ReleaseObserver.new()
	watcher.controller = self
	watcher.process_physics_priority = 1000
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(watcher)
	await super._run()
	write_json(out_dir.path_join("release-observed.json"), release_observations)

func observe_release_style() -> void:
	if not is_instance_valid(game) or game.paused or game.session == null:
		return
	var sample: Dictionary = game.session.last_sample
	if sample.is_empty():
		return
	var id: String = game.session.recorder.run_id
	var tick := int(sample.tick)
	if int(release_seen.get(id, -1)) == tick:
		return
	release_seen[id] = tick
	var scorer: RefCounted = game.session.style
	var all_scored: Array = scorer.get("events")
	var snap: Dictionary = scorer.call("snapshot")
	release_observations.append({"run_id": id, "tick": tick, "style_score": snap.score,
		"style_events": READER.json_safe(all_scored.slice(int(release_style_seen.get(id, 0)))),
		"style_time_s": snap.time_s, "style_direction": READER.json_safe(snap.direction),
		"style_direction_verdict": READER.json_safe(snap.diag.direction.last)})
	release_style_seen[id] = all_scored.size()
