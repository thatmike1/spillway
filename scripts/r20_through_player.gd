extends "res://scripts/r15_source_player.gd"
## p / through line: one vertical impulse after a real forward crossing; ordinary motor stays inherited.
signal through_diagnostic(data: Dictionary)
const VERSION := "r20-through-launch-1"
const LAW := {"version": VERSION, "experimental": true, "units": "u, u/s; 1u=0.0254m",
	"phase": "after inherited motor step, before recording", "minimum_u": 230.0, "alignment": 0.94,
	"gate": "swept reference feet cross z=-40 forward; full hull inside x=-5..5, feet y=3.8..8",
	"support": "not required; authored gate accepts airborne bhops", "up_law": "vy_after=max(vy_before,420+0.7*length(vxz_before))",
	"horizontal": "x and z untouched, no normalization or cap", "reuse": "once per reset_to; pause retains used state",
	"forces": "instantaneous only; no continuing experimental force", "map": "r20-through-line", "landing": "actual grounded ray support named second_start"}
var monitoring := false
var used := false
var last_launch := {}
var last_landing := {}
var apex := {}
var continued := false
var launched_airborne := false
var cue_player: AudioStreamPlayer
var cue: AudioStreamWAV
var cue_serial := 0
var cue_left_s := 0.0
var _prior_vy := 0.0

func movement_version() -> String:
	return VERSION

func _ready() -> void:
	super()
	cue = make_cue()
	cue_player = AudioStreamPlayer.new()
	cue_player.name = "ThroughLaunchCue"
	cue_player.stream = cue
	add_child(cue_player)

static func make_cue() -> AudioStreamWAV:
	# self-made two-tone rising whistle and soft impact, deterministic signed 16-bit mono PCM.
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var data := PackedByteArray()
	var duration := 0.38
	data.resize(int(duration * sound.mix_rate) * 2)
	for i: int in data.size() / 2:
		var t := float(i) / sound.mix_rate
		var envelope := sin(PI * t / duration) * exp(-2.0 * t)
		var phase := TAU * (240.0 * t + 1100.0 * t * t)
		var value := (sin(phase) * 0.65 + sin(phase * 1.5) * 0.20 + sin(TAU * 90.0 * t) * exp(-30.0 * t) * 0.3) * envelope * 0.38
		data.encode_s16(i * 2, roundi(value * 32767.0))
	sound.data = data
	return sound

func reset_to(pose: Transform3D) -> void:
	monitoring = false
	used = false
	last_launch = {}
	last_landing = {}
	apex = {}
	continued = false
	launched_airborne = false
	clear_through("reset")
	super(pose)

func clear_through(reason: String) -> void:
	# there is no stored force to resume; used is deliberately retained across pause/preset.
	cue_left_s = 0.0
	if reason not in ["pause", "resume"]:
		monitoring = false
	if cue_player != null:
		cue_player.stop()

static func crossing(from: Vector3, to: Vector3, before: Vector3, width_m: float, already_used: bool, correct_map: bool) -> Dictionary:
	if already_used or not correct_map or from.z <= -40.0 or to.z > -40.0 or to.z >= from.z:
		return {}
	var at := from.lerp(to, (-40.0 - from.z) / (to.z - from.z))
	if absf(at.x) + width_m * 0.5 > 5.0 or at.y < 3.8 or at.y > 8.0:
		return {}
	var horizontal := Vector2(before.x, before.z)
	var speed := horizontal.length()
	if speed < float(LAW.minimum_u) or -before.z / speed < float(LAW.alignment):
		return {}
	return {"crossing": at, "speed_u": speed, "up_u": maxf(before.y, 420.0 + 0.7 * speed)}

func _physics_process(delta: float) -> void:
	var start := global_position
	super(delta)
	if not input_enabled:
		return
	cue_left_s = maxf(0.0, cue_left_s - delta)
	var world: Node = get_parent().get("level")
	var correct: bool = world != null and world.get("level_id") == "r20-through-line"
	var from := start - _duck_compensation_u * U + _duck_shift
	var to := global_position - _duck_compensation_u * U
	var response := crossing(from, to, velocity / U, float(settings.hull_width) * U, used, correct)
	if not response.is_empty():
		used = true
		monitoring = true
		launched_airborne = not is_grounded()
		var before := velocity
		# only y is assigned: the exact incoming horizontal float32 values survive this law.
		velocity.y = float(response.up_u) * U
		flight = {"takeoff": response.speed_u, "ticks": 0, "eligible": 0, "good": 0, "start_tick": motion_tick}
		state.grounded = false
		state.ground_normal = Vector3.ZERO
		_ground_normal = Vector3.ZERO
		state.velocity = Vector3((state.velocity as Vector3).x, float(response.up_u), (state.velocity as Vector3).z)
		mode = "air"
		last_launch = {"kind": "launch", "motor_tick": motion_tick, "p": global_position, "reference_p": to,
			"crossing": response.crossing, "before_mps": before, "after_mps": velocity, "speed_u": response.speed_u,
			"airborne_entry": launched_airborne, "law": VERSION}
		cue_serial += 1
		cue_left_s = 0.38
		cue_player.play()
		last_launch["cue"] = {"serial": cue_serial, "playing": cue_player.playing, "pcm_sha256": _pcm_hash(cue), "samples": cue.data.size() / 2}
		through_diagnostic.emit(last_launch.duplicate(true))
	elif correct and monitoring and used and last_landing.is_empty():
		if apex.is_empty() and _prior_vy > 0.0 and velocity.y <= 0.0:
			apex = {"kind": "apex", "motor_tick": motion_tick, "p": global_position, "reference_p": to, "v": velocity}
			through_diagnostic.emit(apex.duplicate(true))
		if is_grounded() and not last_launch.is_empty():
			var support := landing_support()
			if not support.is_empty():
				last_landing = {"kind": "landing", "motor_tick": motion_tick, "p": global_position, "reference_p": to, "v": velocity, "support": support}
				through_diagnostic.emit(last_landing.duplicate(true))
	elif correct and monitoring and not last_landing.is_empty() and not continued:
		if Vector2(to.x - last_landing.reference_p.x, to.z - last_landing.reference_p.z).length() >= 6.0:
			continued = true
			through_diagnostic.emit({"kind": "continued", "motor_tick": motion_tick, "p": global_position, "v": velocity})
	_prior_vy = velocity.y

func landing_support() -> Dictionary:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.08, global_position + Vector3.DOWN * 0.12, 1, [get_rid()]))
	if not hit.is_empty() and hit.normal.y >= float(settings.sv_walkable_normal) and str(hit.collider.name).begins_with("second_start_"):
		return {"body": str(hit.collider.name), "normal": hit.normal, "position": hit.position}
	return {}

static func _pcm_hash(sound: AudioStreamWAV) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(sound.data)
	return hash.finish().hex_encode()

func get_motion_state() -> Dictionary:
	var motion := super()
	motion["through"] = {"version": VERSION, "used": used, "monitoring": monitoring, "launch": last_launch, "apex": apex, "landing": last_landing, "continued": continued, "cue_serial": cue_serial}
	return motion

func experiment_status() -> String:
	if not last_landing.is_empty():
		return "THROUGH LINE · SECOND RUN · momentum carried · experimental"
	if used:
		return "THROUGH LINE · FLIGHT · steer toward the raised cream court"
	return "THROUGH LINE · 230+ u/s through the fork · more speed, more lift · experimental"
