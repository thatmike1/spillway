extends RefCounted
## p / r12 input-only driver for the spillway motor, reusable by fixtures and stage bots.
## every effect on the runner goes through engine input: InputEventAction for keys and
## InputEventMouseMotion for yaw. closed-loop helpers read the runner's state only to pick
## the next input, the way a player reads the screen. nothing here sets a pose or velocity.

const MOVE_KEYS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch"]
const TICK: float = 1.0 / 120.0

var tree: SceneTree
var player: CharacterBody3D
var label: String = ""
var tick: int = 0
var held: Dictionary = {}
var trace: FileAccess
## optional per-tick hook run before the physics step, e.g. a fixture's water regions.
var before_tick: Callable
## when true every tick's sample is also kept here, ready for replay().
var keep_samples: bool = false
var samples: Array[Dictionary] = []

func _init(scene_tree: SceneTree, runner: CharacterBody3D, trace_file: FileAccess = null) -> void:
	tree = scene_tree
	player = runner
	trace = trace_file

func press(action_name: String, strength: float = 1.0) -> void:
	_send(action_name, true, strength)
	held[action_name] = strength

func release(action_name: String) -> void:
	_send(action_name, false, 0.0)
	held.erase(action_name)

func release_all() -> void:
	for action_name: String in MOVE_KEYS:
		_send(action_name, false, 0.0)
	held.clear()

## hold exactly these movement keys, releasing any others.
func keys(names: Array) -> void:
	for action_name: String in MOVE_KEYS:
		if names.has(action_name) and not held.has(action_name):
			press(action_name)
		elif not names.has(action_name) and held.has(action_name):
			release(action_name)

func _send(action_name: String, pressed: bool, strength: float) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = strength
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## turn the view by mouse motion; positive radians turn left, like the motor's yaw.
func turn(radians: float, pitch_radians: float = 0.0) -> void:
	if is_zero_approx(radians) and is_zero_approx(pitch_radians):
		return
	var sensitivity: float = player.get("mouse_sensitivity")
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-radians, -pitch_radians) / sensitivity
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func face(target_yaw: float) -> void:
	turn(angle_difference(float(player.get("yaw")), target_yaw))

func view_yaw() -> float:
	return float(player.get("yaw"))

## the yaw a view would need to look along the current horizontal velocity.
func velocity_yaw() -> float:
	return atan2(-player.velocity.x, -player.velocity.z)

static func yaw_toward(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)

func step(count: int = 1) -> void:
	for i: int in count:
		if before_tick.is_valid():
			before_tick.call()
		await tree.physics_frame
		tick += 1
		_record()

## one tick of strafe: side +1 holds D and curves right, -1 holds A and curves left.
## turn_rate < 0 keeps the wish perpendicular to the velocity (the largest gain); a
## positive rate in rad/s lets the view lag just enough to curve at that rate.
func strafe(side: int, turn_rate: float = -1.0, extra_keys: Array = []) -> void:
	var names: Array = extra_keys.duplicate()
	names.append("move_right" if side > 0 else "move_left")
	keys(names)
	var speed: float = player.call("get_speed")
	var lag := 0.0
	if turn_rate >= 0.0 and speed > 0.1:
		var cap: float = (player.get_script() as GDScript).get_script_constant_map().get("AIR_WISH_CAP", 0.75)
		lag = asin(clampf((cap - turn_rate * speed * TICK) / speed, 0.0, 1.0))
	face(velocity_yaw() + side * lag)
	await step()

## one tick of surf: hold the strafe key into the ramp (side +1 ramp on the right, D) and
## look along it. opening the view away from the ramp by about asin(cap / speed) is
## neutral; more lets the runner sink, turning height into forward speed, less climbs.
func surf(side: int, along_yaw: float, target_y: float, extra_keys: Array = []) -> void:
	var along := Vector3(-sin(along_yaw), 0.0, -cos(along_yaw))
	var cap: float = (player.get_script() as GDScript).get_script_constant_map().get("AIR_WISH_CAP", 0.75)
	var forward_speed := maxf(player.velocity.dot(along), 0.5)
	var neutral := asin(clampf(cap / forward_speed, 0.0, 1.0))
	var lead := clampf(neutral + 0.08 * (player.global_position.y - target_y) + 0.03 * player.velocity.y, 0.0, 0.6)
	var names: Array = extra_keys.duplicate()
	names.append("move_right" if side > 0 else "move_left")
	keys(names)
	face(along_yaw + side * lead)
	await step()

## repeat a one-tick action (a bound strafe, surf or step) until the condition holds;
## returns whether it held before the limit ran out.
func until(condition: Callable, tick_action: Callable, limit: int = 1200) -> bool:
	for i: int in limit:
		if condition.call():
			return true
		await tick_action.call()
	return bool(condition.call())

## play recorded samples back as plain input: the same held keys and the same view each
## tick, with no state read. a closed-loop run recorded with keep_samples replays open-loop.
func replay(recorded: Array[Dictionary]) -> void:
	for entry: Dictionary in recorded:
		keys(entry["keys"])
		turn(angle_difference(float(player.get("yaw")), float(entry["yaw"])), float(entry["pitch"]) - float(player.get("pitch")))
		await step()

## steer a bhop or air phase toward a point with synced strafes; inside the dead band it
## zigzags with the gain strafe so the line keeps speed instead of holding W.
func strafe_toward(target: Vector3, turn_rate: float = 2.4, dead_band: float = 0.08, extra_keys: Array = []) -> void:
	var to_target := target - player.global_position
	var error := angle_difference(velocity_yaw(), yaw_toward(to_target))
	var side := -1 if error > 0.0 else 1
	if absf(error) < dead_band:
		side = 1 if int(tick / 30.0) % 2 == 0 else -1
	await strafe(side, turn_rate, extra_keys)

func contacts() -> Array:
	var normals: Array = []
	for i: int in player.get_slide_collision_count():
		var normal: Vector3 = player.get_slide_collision(i).get_normal()
		normals.append([snappedf(normal.x, 0.001), snappedf(normal.y, 0.001), snappedf(normal.z, 0.001)])
	return normals

func sample() -> Dictionary:
	var held_names: Array = held.keys()
	held_names.sort()
	var p: Vector3 = player.global_position
	var v: Vector3 = player.velocity
	return {"run": label, "tick": tick, "keys": held_names,
		# the view keeps full precision so a replay reproduces the same mouse input.
		"yaw": float(player.get("yaw")), "pitch": float(player.get("pitch")),
		"position": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)],
		"velocity": [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)],
		"speed": snappedf(float(player.call("get_speed")), 0.001), "mode": str(player.get("mode")),
		"floor": player.is_on_floor(), "water": bool(player.get("in_water")), "contacts": contacts(),
		"jumps": int(player.get("jump_count")), "hops": int(player.get("hop_count")), "surf_ticks": int(player.get("surf_ticks"))}

func _record() -> void:
	if trace == null and not keep_samples:
		return
	var entry := sample()
	if trace != null:
		trace.store_line(JSON.stringify(entry))
	if keep_samples:
		samples.append(entry)
