extends "res://tools/momentum-tape.gd"
## p / independent ordinary-input review. this adds observations to the frozen tape executor;
## it never chooses input or writes game state. pass an expanded tape and the real product
## factory: --game-script=res://scripts/momentum_overflow_main.gd --game-class= (empty class).
## replay instructions and retained failures: docs/momentum/research/overflow-casual-review-sol.md.

var review_contacts: FileAccess
var review_samples: Array = []
var review_transitions: Array = []
var review_previous := ""
var review_finish: Variant = null
var review_arrival: Variant = null
var review_sources := {}

func _build_world() -> Array:
	var errors := super._build_world()
	if errors.is_empty():
		review_contacts = FileAccess.open(out_dir.path_join("evaluator/casual.contacts.jsonl"), FileAccess.WRITE)
		for path: String in ["res://project.godot", "res://scripts/momentum_overflow_main.gd", "res://scripts/momentum_overflow_level.gd", "res://scripts/momentum_overflow_hud.gd", "res://scripts/momentum_carry_air_candidate.gd", "res://scripts/momentum_carry_player.gd", "res://scripts/spillway_player.gd", "res://tools/momentum-tape.gd", "res://tests/test_overflow_casual_review.gd"]:
			review_sources[path] = FileAccess.get_sha256(path)
	return errors

func late_step() -> void:
	if finished or row.is_empty() or not armed:
		super.late_step()
		return
	var tick := int(row.tick)
	var actual := (player.global_position - pre_p) / dt
	var sample := {"tick": tick, "p": _v3(player.global_position), "actual_v": _v3(actual),
		"speed": Vector2(actual.x, actual.z).length(), "v": _v3(player.velocity), "yaw": player.get("yaw"),
		"checkpoint": game.get("checkpoint_index"), "finished": game.get("finished"),
		"finish_kind": game.get("finish_kind"), "elapsed": game.get("elapsed"),
		"respawns": game.get("respawn_count"), "jumps": player.get("jump_count")}
	var state := "%s/%s/%s" % [sample.checkpoint, sample.finished, sample.respawns]
	if state != review_previous:
		review_transitions.append(sample)
		review_previous = state
	if tick % 120 == 0:
		review_samples.append(sample)
	if sample.finished and review_finish == null:
		review_finish = sample
	if player.global_position.z <= -170.0 and review_arrival == null and not sample.finished:
		review_arrival = sample
	var manifold: Array = []
	var interesting := false
	for i: int in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		var points: Array = []
		for j: int in contact.get_collision_count():
			var collider := contact.get_collider(j) as Node
			var normal := contact.get_normal(j)
			interesting = interesting or absf(normal.y) < 0.7
			points.append({"body": str(collider.name) if collider != null else "", "normal": _v3(normal),
				"position": _v3(contact.get_position(j)), "local_shape": contact.get_local_shape(j),
				"collider_shape": contact.get_collider_shape(j)})
		manifold.append({"depth": contact.get_depth(), "travel": _v3(contact.get_travel()),
			"remainder": _v3(contact.get_remainder()), "points": points})
	var pushing := Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back")
	if interesting or (pushing and tick > 120 and float(sample.speed) < 0.25):
		var entry := sample.duplicate()
		entry["pre_p"] = _v3(pre_p)
		entry["manifold"] = manifold
		entry["post_finish"] = sample.finished
		review_contacts.store_line(JSON.stringify(entry, "", false, true))
	super.late_step()

func _finish(reason: String, code: int) -> void:
	if review_contacts != null:
		review_contacts.close()
	_write_json("evaluator/casual.summary.json", {"label": "unblinded open-loop behavior probe, normal product spawn; no state-selected input",
		"reason": reason, "source_sha256": review_sources, "finish": review_finish, "arrival_z170": review_arrival,
		"transitions": review_transitions, "one_second_samples": review_samples,
		"final_p": _v3(player.global_position) if player != null else null})
	super._finish(reason, code)
