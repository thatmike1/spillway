extends "res://scripts/spillway_audio.gd"
## p / r13 overflow audio: spillway's original synthesis (steps, hop breath, landing thump,
## wind from actual travel, water beds), plus two cues that describe real motion on this
## course. footsteps follow the material of the support the runner is standing on, and a
## ground brake skids only while the runner's own ledger books braking. nothing plays
## because of speed alone besides the wind, and nothing moves the camera.

## p / ground braking at or above this rate (m/s^2) plays the skid at full level.
const SKID_FULL := 34.0
const SKID_LEVEL := 0.14
const STEEL_KINDS := ["steel", "rail"]

var skid_level: float = 0.0
## the kind of the last support a footstep or landing found, for tests and traces.
var last_surface: String = ""
var _kinds: Dictionary = {}
var _skid: AudioStreamPlayer

func attach(player: CharacterBody3D, level: Node3D) -> void:
	super(player, level)
	var manifest: Variant = level.get("manifest")
	if manifest is Array:
		for piece: Dictionary in manifest:
			_kinds[str(piece.get("name", ""))] = str(piece.get("kind", ""))
	if not _enabled:
		return
	_skid = AudioStreamPlayer.new()
	_skid.stream = _wav(_skid_loop(1.6), true)
	_skid.volume_db = -70.0
	add_child(_skid)
	_skid.play()

func _process(delta: float) -> void:
	super(delta)
	if not _enabled or _player == null or _skid == null:
		return
	var target := 0.0
	if not get_tree().paused and _player.call("is_grounded"):
		var ledger: Dictionary = (_player.call("get_motion_state") as Dictionary).get("ledger", {})
		var change: Vector3 = ledger.get("brake", Vector3.ZERO)
		var rate := Vector2(change.x, change.z).length() * Engine.physics_ticks_per_second
		target = clampf(rate / SKID_FULL, 0.0, 1.0) * clampf(float(_player.call("get_speed")) / 4.0, 0.0, 1.0)
	skid_level = lerpf(skid_level, target, 1.0 - exp(-18.0 * delta))
	_skid.volume_db = linear_to_db(maxf(skid_level * SKID_LEVEL, 0.0001))
	_skid.pitch_scale = 0.85 + clampf(float(_player.call("get_speed")) / 14.0, 0.0, 1.0) * 0.45

## the material kind under the feet, from the runner's own floor contacts.
func support_kind() -> String:
	for i: int in _player.get_slide_collision_count():
		var contact: KinematicCollision3D = _player.get_slide_collision(i)
		for j: int in contact.get_collision_count():
			if contact.get_normal(j).y < 0.6:
				continue
			var body := contact.get_collider(j) as Node
			if body == null:
				continue
			if str(body.get_meta("surface", "")) == "rail":
				return "rail"
			return str(_kinds.get(str(body.name), "concrete"))
	return "concrete"

func _on_footstep(strength: float) -> void:
	if not _enabled:
		return
	last_surface = support_kind()
	var pitch := _rng.randf_range(0.92, 1.08)
	if _player.in_water:
		_play(_sounds.hand, -24.0 + strength * 3.0, pitch * 0.6)
	elif last_surface in STEEL_KINDS:
		_play(_steps[_rng.randi() % _steps.size()], -23.0 + strength * 6.0, pitch * 1.45)
	elif last_surface == "old_concrete":
		_play(_steps[_rng.randi() % _steps.size()], -21.0 + strength * 6.0, pitch * 0.88)
	elif last_surface == "brick":
		_play(_steps[_rng.randi() % _steps.size()], -22.0 + strength * 6.0, pitch * 0.95)
	else:
		_play(_steps[_rng.randi() % _steps.size()], -22.0 + strength * 6.0, pitch)

func _on_landed(impact: float) -> void:
	super(impact)
	if not _enabled or _player.in_water:
		return
	last_surface = support_kind()
	if last_surface in STEEL_KINDS:
		# a steel deck rings over the thump.
		_play(_steps[_rng.randi() % _steps.size()], -18.0 + minf(impact * 0.4, 5.0), 1.5)

func _skid_loop(seconds: float) -> PackedFloat32Array:
	# gritty band noise with an uneven grain, like a shoe dragging on concrete.
	var samples := _buffer(seconds)
	var fade := int(RATE * 0.08)
	samples.resize(samples.size() + fade)
	var low := 0.0
	var band := 0.0
	var grain := 0.0
	for i: int in samples.size():
		var noise := _rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.08
		band += (noise - band) * 0.45
		if _rng.randf() < 0.004:
			grain = _rng.randf_range(0.6, 1.0)
		grain *= 0.9993
		samples[i] = ((band - low) * (0.55 + grain * 0.6) + low * 0.6) * 0.6
	return _join_loop(samples, fade)

func stop_all() -> void:
	super()
	if _skid != null:
		_skid.stop()
		_skid.stream = null
