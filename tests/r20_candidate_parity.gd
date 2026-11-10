extends "res://tests/r19_parity.gd"
## complete inherited executor and controls; only add independent scorer observations.
const ORDINARY_REFERENCE := preload("res://tests/r20_candidate_reference.gd")
var reference_style: Variant
var reference_run := ""
var reference_breaks := 0
var reference_tick := -1

func _build_world() -> Array:
	if str(ProjectSettings.get_setting("application/run/main_scene")) != "res://scenes/r20.tscn":
		return ["candidate must configure scenes/r20.tscn"]
	if str(opts.get("host-scene", "")) != "res://scenes/r20.tscn" or str(opts.get("host-script", "")) != "res://scripts/r20_main.gd":
		return ["candidate requires explicit actual R20 scene and script"]
	var errors := super._build_world()
	if errors.is_empty():
		check(game.look_enabled == (variant != "old"), "actual configured initial look matches requested variant")
	return errors

func late_step(delta: float) -> void:
	player = game.player
	var session: Node = game.session
	if session.tick > 0 and int(session.last_sample.get("tick", -1)) == session.tick - 1:
		var run_id := str(session.last_begin.get("run_id", ""))
		var key := run_id + ":" + str(session.last_sample.tick)
		if key != last_observation:
			last_observation = key
			if not identity_texts.has(run_id):
				identity_texts[run_id] = game.record_identity_text()
			var sample: Dictionary = session.last_sample
			var snap: Dictionary = session.style.snapshot()
			if reference_run != run_id:
				reference_style = ORDINARY_REFERENCE.new()
				reference_style.reset(snap.context)
				reference_run = run_id
				reference_breaks = 0
				reference_tick = -1
			if int(sample.tick) != reference_tick + 1:
				check(false, "reference missed an original sample")
			reference_tick = int(sample.tick)
			var breaks: Array = snap.diag.discontinuities
			if breaks.size() < reference_breaks or breaks.size() >= 16:
				check(false, "reference lifecycle list lost its prefix")
			for reason: String in breaks.slice(reference_breaks):
				if reason != "pause" and reason != "resume":
					reference_style.discontinuity(reason)
			reference_breaks = breaks.size()
			var ordinary: Array = reference_style.step(sample, player, game.level)
			var scored: Array = []
			for event: Dictionary in session.style.events:
				if int(event.tick) == int(sample.tick):
					scored.append(event)
			var observed: Dictionary = READER.json_safe(sample)
			observed["input_events"] = READER.json_safe(session.describe_all(sample.input_events))
			observations.store_line(JSON.stringify({"run_id": run_id, "sample": observed,
				"actual": gameplay(), "style_events": scored, "style_score": snap.score,
				"style_time_s": snap.time_s, "style_direction": READER.json_safe(snap.direction),
				"style_direction_verdict": READER.json_safe(snap.diag.direction.last),
				"ordinary_reference": READER.json_safe(ordinary),
				"ordinary_snapshot": READER.json_safe(reference_style.snapshot())}, "", false, true))
	# the parent sees the same key and does not duplicate observations; all tape and tour code still runs.
	super.late_step(delta)
