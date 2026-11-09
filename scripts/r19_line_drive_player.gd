extends "res://scripts/r15_source_player.gd"
## an explicitly experimental launch impulse, available only on this map's real support pads.
const LAUNCH_LAW := {"version": "r19-line-launch-2", "minimum_u": 300.0, "alignment": 0.94,
	"support": "grounded actual hull sweep onto named pad, 2u probe, walkable normal", "phase": "before inherited input/motor step",
	"gain_u": 160.0, "up_u": 480.0, "cap_u": 900.0, "cap_policy": "limit boost without reducing faster entry", "reuse": "once per pad per attempt"}
var used_pads: Dictionary = {}
var launch_events: Array[Dictionary] = []
var last_launch: Dictionary = {}

func movement_version() -> String:
	return str(LAUNCH_LAW.version)

func reset_to(pose: Transform3D) -> void:
	used_pads.clear()
	launch_events.clear()
	last_launch.clear()
	super(pose)

static func response(before: Vector3, direction: Vector3, used: bool) -> Dictionary:
	var horizontal := Vector3(before.x, 0, before.z)
	if used or horizontal.length() < float(LAUNCH_LAW.minimum_u):
		return {}
	if horizontal.normalized().dot(direction) < float(LAUNCH_LAW.alignment):
		return {}
	var next := horizontal + direction * float(LAUNCH_LAW.gain_u)
	var ceiling := maxf(float(LAUNCH_LAW.cap_u), horizontal.length())
	if next.length() > ceiling:
		next = next.normalized() * ceiling
	next.y = maxf(before.y, float(LAUNCH_LAW.up_u))
	return {"before_u": before, "after_u": next}

func _physics_process(delta: float) -> void:
	if input_enabled and is_grounded():
		var level: Node = get_parent().get("level")
		if level != null and level.get("level_id") == "r19-line-drive":
			for pad: Dictionary in level.launch_pads:
				if not (pad.bounds as AABB).has_point(global_position):
					continue
				var support := pad_support(pad)
				if support.is_empty():
					continue
				var impulse := response(velocity / U, pad.direction, used_pads.has(pad.id))
				if impulse.is_empty():
					continue
				used_pads[pad.id] = true
				velocity = (impulse.after_u as Vector3) * U
				state.grounded = false
				state.ground_normal = Vector3.ZERO
				flight = {"takeoff": Vector2(velocity.x, velocity.z).length() / U, "ticks": 0, "eligible": 0, "good": 0, "start_tick": motion_tick + 1}
				last_launch = {"pad": pad.id, "tick": motion_tick + 1, "before_u": impulse.before_u,
					"after_u": impulse.after_u, "position": global_position, "support": support}
				launch_events.append(last_launch.duplicate(true))
				break
	super(delta)

## a test-only sweep of this actual hull also catches grounded categorization contacts,
## which the inherited motor does not put in its slide-only contact history.
func pad_support(pad: Dictionary) -> Dictionary:
	var probe := Vector3.DOWN * float(settings.ground_probe) * U
	var hit := move_and_collide(probe, true, safe_margin, false, 4)
	if hit == null:
		var caught := _missed_support(global_position, probe, "probe")
		if not caught.is_empty():
			hit = caught.hit
	if hit != null:
		for i: int in hit.get_collision_count():
			var body := hit.get_collider(i) as Node
			if body != null and str(body.name).begins_with(str(pad.id) + "_") and hit.get_normal(i).y >= float(settings.sv_walkable_normal):
				return {"body": str(body.name), "normal": hit.get_normal(i), "position": hit.get_position(i), "probe_m": -probe.y}
	return {}

func get_motion_state() -> Dictionary:
	var motion := super()
	motion["line_drive"] = {"law": LAUNCH_LAW, "used": used_pads.keys(), "last_launch": last_launch}
	return motion

func experiment_status() -> String:
	return "EXPERIMENTAL LAUNCH · %d/3 pads · 300+ u/s aligned · R resets" % used_pads.size()
