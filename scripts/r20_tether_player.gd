extends "res://scripts/r19_tether_player.gd"
## p / mouse controls are private to this runner; the lab's E action is untouched.
signal tether_diagnostic(data: Dictionary)
const VERSION := "r20-tether-mouse-1"
const MODELS := ["classic", "pendulum", "elastic"]
const NOTES := {
	"classic": "Classic · bounded spring and radial catch; both buttons reproduce R19 E.",
	"pendulum": "Pendulum · fixed rope, taut catch, no spring; no added speed cap.",
	"elastic": "Elastic · spring and damping with slack; stronger 1800 u/s² pull."}
const ALTERNATIVES := {
	"pendulum": {"law": "r20-pendulum-1", "max_s": 5.0, "constraint": "velocity radial projection plus excess/dt", "spring": false},
	"elastic": {"law": "r20-elastic-1", "max_s": 5.0, "stiffness": 90.0, "outward_damping": 10.0, "max_pull_ups2": 1800.0, "speed_cap_ups": 650.0}}
var model := "classic"
var auto_reel := false
var _input_blocked := true
var cue_player: AudioStreamPlayer
var cues := {}
var cue_serial := 0
var last_cue := {}
var release_notice := ""
var notice_left_s := 0.0

func movement_version() -> String:
	return VERSION

func configure_tether(next_model: String, automatic: bool) -> void:
	model = next_model if next_model in MODELS else "classic"
	auto_reel = automatic

func tether_identity() -> Dictionary:
	return {"version": VERSION, "model": model, "automatic_reel": auto_reel, "controls": "LMB attach/hold; RMB reel; E lab only",
		"classic": GRAPPLE, "alternative": ALTERNATIVES.get(model, {})}

func _ready() -> void:
	super()
	cue_player = AudioStreamPlayer.new()
	cue_player.name = "TetherReleaseCue"
	add_child(cue_player)
	for reason: String in ["released", "time", "range", "obstructed", "pause", "restart", "practice", "respawn", "map", "preset", "model", "automatic_reel", "quit"]:
		cues[reason] = _make_cue(reason)

func _make_cue(reason: String) -> AudioStreamWAV:
	# original generated signed 16-bit PCM; the three automatic breaks have distinct contours.
	var index := {"time": 1, "range": 2, "obstructed": 3}.get(reason, 0) as int
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var data := PackedByteArray()
	var length := 0.22 if index > 0 else 0.09
	data.resize(int(length * sound.mix_rate) * 2)
	for i: int in data.size() / 2:
		var t := float(i) / sound.mix_rate
		var phase := (720.0 - float(index) * 120.0) * t + (-900.0 if index == 1 else 250.0 * index) * t * t
		var gate := 0.35 if index == 3 and int(t * 40) % 2 == 0 else 1.0
		var value := sin(TAU * phase) * sin(PI * t / length) * 0.23 * gate
		data.encode_s16(i * 2, roundi(value * 32767.0))
	sound.data = data
	return sound

func _unhandled_input(event: InputEvent) -> void:
	var prior_press := _grapple_press
	super(event)
	# the inherited input handles ordinary movement/look; E cannot supply our fresh press.
	if event.is_action_pressed(GRAPPLE_ACTION):
		_grapple_press = prior_press
	if input_enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_input_blocked = false
		if event.pressed and not _input_blocked:
			_grapple_press = true

func reset_to(pose: Transform3D) -> void:
	super(pose)
	_input_blocked = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	release_notice = ""
	notice_left_s = 0.0

func block_tether(reason: String) -> void:
	if not grapple.is_empty():
		_release(reason)
	_input_blocked = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_grapple_press = false

func reel_active() -> bool:
	return auto_reel or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func max_attachment_s() -> float:
	return float(GRAPPLE.max_s) if model == "classic" else float(ALTERNATIVES[model].max_s)

func _grapple_step(v: Vector3, _grounded: bool, delta: float) -> Vector3:
	if _input_blocked:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_input_blocked = false
		return Vector3.ZERO
	if grapple.is_empty():
		grapple_target = _find_target() if mechanic_enabled("grapple") else {"state": "none"}
		if not mechanic_enabled("grapple") or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_grapple_needs_press = false
			return Vector3.ZERO
		if _grapple_needs_press and not _grapple_press:
			return Vector3.ZERO
		if str(grapple_target.state) != "ok":
			if _grapple_press:
				lab_events.append("grapple_miss")
				_count("grapple_miss")
			return Vector3.ZERO
		grapple = {"name": grapple_target.name, "position": grapple_target.position}
		grapple_length_u = (_hull_centre().distance_to(grapple.position)) / U
		grapple_ticks = 0
		grapple_count += 1
		grapple_release_reason = ""
		_grapple_needs_press = false
		lab_events.append("grapple")
		_count("grapple")
		_diagnostic("attach", "acquired")
	var anchor: Vector3 = grapple.position
	var centre := _hull_centre()
	var distance_u := centre.distance_to(anchor) / U
	var why := ""
	if not mechanic_enabled("grapple"):
		why = "off"
	elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		why = "released"
	elif grapple_ticks >= _ticks(max_attachment_s()):
		why = "time"
	elif distance_u > float(GRAPPLE.range_u) + float(GRAPPLE.stretch_u):
		why = "range"
	elif not _clear_line(centre, anchor):
		why = "obstructed"
	if not why.is_empty():
		_release(why)
		return Vector3.ZERO
	grapple_ticks += 1
	var reel := reel_active()
	if reel:
		grapple_length_u = maxf(float(GRAPPLE.min_length_u), minf(grapple_length_u, distance_u) - float(GRAPPLE.reel_ups) * delta)
	if model != "classic":
		return _alternative_step(v, anchor, centre, distance_u, delta)
	if distance_u < grapple_length_u or distance_u < 1e-3:
		return Vector3.ZERO
	var along := (anchor - centre) / (distance_u * U)
	var next := v
	var radial := next.dot(along)
	if radial < 0.0:
		var rope := -along * radial
		next += rope
		_book("grapple_rope", rope)
	var pull := along * minf(float(GRAPPLE.stiffness) * (distance_u - grapple_length_u), float(GRAPPLE.max_pull_ups2)) * delta
	var limit := maxf(v.length(), float(GRAPPLE.speed_cap_ups))
	if (next + pull).length() > limit:
		# the share of the pull that keeps |v| at the limit: |next + s pull| = limit.
		var a := pull.length_squared()
		var b := next.dot(pull)
		var c := next.length_squared() - limit * limit
		var share := clampf((-b + sqrt(maxf(b * b - a * c, 0.0))) / a, 0.0, 1.0) if a > 0.0 else 0.0
		pull *= share
	next += pull
	_book("grapple_pull", pull)
	return next - v


func _alternative_step(v: Vector3, anchor: Vector3, centre: Vector3, distance_u: float, delta: float) -> Vector3:
	if distance_u < grapple_length_u or distance_u < 1e-3:
		return Vector3.ZERO
	var along := (anchor - centre) / (distance_u * U)
	var radial := v.dot(along)
	if model == "pendulum":
		# unilateral hard radial constraint at the current rope radius, with no spring force.
		var correction := along * maxf(0.0, (distance_u - grapple_length_u) / delta - radial)
		_book("grapple_rope", correction)
		return correction
	var tuning: Dictionary = ALTERNATIVES.elastic
	var force := minf(float(tuning.max_pull_ups2), float(tuning.stiffness) * (distance_u - grapple_length_u) + float(tuning.outward_damping) * maxf(-radial, 0.0))
	var pull := along * force * delta
	var limit := maxf(v.length(), float(tuning.speed_cap_ups))
	if (v + pull).length() > limit:
		var a := pull.length_squared()
		var b := v.dot(pull)
		var c := v.length_squared() - limit * limit
		pull *= clampf((-b + sqrt(maxf(b * b - a * c, 0.0))) / a, 0.0, 1.0) if a > 0.0 else 0.0
	_book("grapple_pull", pull)
	return pull

func _release(why: String) -> void:
	var age := grapple_ticks
	var anchor := str(grapple.get("name", ""))
	super(why)
	release_notice = {"released": "Released · coast", "time": "Line expired · 3 s classic / 5 s alternatives",
		"range": "Line broke · beyond 32.03 m", "obstructed": "Line blocked · centre ray hit"}.get(why, "Line cleared · " + why)
	notice_left_s = 2.0
	cue_serial += 1
	if cue_player != null and cues.has(why):
		cue_player.stream = cues[why]
		cue_player.play()
	last_cue = {"serial": cue_serial, "reason": why, "active": cue_player != null and cue_player.playing,
		"pcm_sha256": _pcm_hash(cues[why]) if cues.has(why) else ""}
	_diagnostic("release", why, {"attached_ticks": age, "anchor": anchor, "cue": last_cue.duplicate()})

static func _pcm_hash(sound: AudioStreamWAV) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(sound.data)
	return hash.finish().hex_encode()

func _diagnostic(kind: String, reason: String, extra: Dictionary = {}) -> void:
	var data := {"v": 1, "kind": kind, "reason": reason, "model": model, "automatic_reel": auto_reel,
		"attached": not grapple.is_empty(), "length_u": grapple_length_u, "ticks": grapple_ticks}
	data.merge(extra)
	tether_diagnostic.emit(data)

func _process(delta: float) -> void:
	super(delta)
	if input_enabled:
		notice_left_s = maxf(0.0, notice_left_s - delta)

func get_motion_state() -> Dictionary:
	var out := super()
	out.experiment.version = VERSION
	out.experiment["tether"] = {"model": model, "automatic_reel": auto_reel, "reeling": reel_active() and not grapple.is_empty(),
		"blocked_until_release": _input_blocked, "armed": not _input_blocked and not _grapple_needs_press,
		"left_s": maxf(0.0, max_attachment_s() - float(grapple_ticks) / float(settings.tickrate)),
		"last_cue": last_cue.duplicate()}
	return out

func experiment_status() -> String:
	var status := ""
	if not grapple.is_empty():
		status = "LMB attached · %s · %.2f s left" % ["reeling" if reel_active() else "swinging", maxf(0.0, max_attachment_s() - float(grapple_ticks) / float(settings.tickrate))]
	elif _input_blocked or _grapple_needs_press:
		status = "Release mouse buttons, then press LMB to arm"
	else:
		status = "Armed · hold LMB at a ring · %s" % ("automatic reel" if auto_reel else "RMB reels")
	return "%s\n%s%s" % [str(model).capitalize(), status, "\n" + release_notice if notice_left_s > 0.0 else ""]
