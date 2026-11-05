class_name FoldBlock
extends AnimatableBody3D
## a rigid piece of city that turns about a hinge. The node origin is the hinge.
## three beats: a short tremble that announces it, one continuous turn, and a
## small settle when it lands in its new role. Collision moves with the mesh.

signal fold_started
signal fold_settled

enum Phase { IDLE, ANTICIPATE, TURN, SETTLE, DONE }

@export var axis: Vector3 = Vector3.RIGHT
@export var angle: float = -PI / 2.0
@export var anticipation: float = 1.1
@export var duration: float = 3.4
@export var settle_time: float = 0.7
@export var tremble_degrees: float = 0.7

var phase: Phase = Phase.IDLE
var _time: float = 0.0
var _initial: Transform3D = Transform3D.IDENTITY
var _ready_done: bool = false


func _ready() -> void:
	sync_to_physics = true
	process_physics_priority = -50
	_initial = transform
	_ready_done = true


func start_fold() -> void:
	if phase != Phase.IDLE:
		return
	if not _ready_done:
		_initial = transform
		_ready_done = true
	phase = Phase.ANTICIPATE
	_time = 0.0
	fold_started.emit()


## jump straight to the folded state, used when a checkpoint lies past the fold.
func finish_now() -> void:
	phase = Phase.DONE
	_time = 0.0
	_cut_to(_pose(1.0, 0.0))


func reset_fold() -> void:
	phase = Phase.IDLE
	_time = 0.0
	if _ready_done:
		_cut_to(_initial)


func is_done() -> bool:
	return phase == Phase.DONE


## 0 before the turn starts, 1 once it has landed; anticipation reads as 0.
func get_progress() -> float:
	match phase:
		Phase.IDLE, Phase.ANTICIPATE:
			return 0.0
		Phase.TURN:
			return clampf(_time / duration, 0.0, 1.0)
	return 1.0


## 0..1 through the anticipation beat, 1 afterwards. Drives lights and sound.
func get_warning() -> float:
	match phase:
		Phase.IDLE:
			return 0.0
		Phase.ANTICIPATE:
			return clampf(_time / maxf(anticipation, 0.001), 0.0, 1.0)
	return 1.0


# a jump cut must reach the physics server now, not on the next physics tick,
# or a body placed on the new surface this frame falls through it. with sync on,
# animatableBody3D puts the node back to its last physics pose, so cut with it off
func _cut_to(target: Transform3D) -> void:
	sync_to_physics = false
	transform = target
	if is_inside_tree():
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
	sync_to_physics = true


func get_final_transform() -> Transform3D:
	return Transform3D(_initial.basis * Basis(axis.normalized(), angle), _initial.origin)


func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE or phase == Phase.DONE:
		return
	_time += delta
	match phase:
		Phase.ANTICIPATE:
			var t: float = _time / maxf(anticipation, 0.001)
			# a growing shudder plus a slight lean into the coming turn
			var shudder: float = sin(_time * 38.0) * deg_to_rad(tremble_degrees) * t * (1.0 - t * 0.4)
			transform = _pose(0.012 * t * t, shudder)
			if _time >= anticipation:
				phase = Phase.TURN
				_time = 0.0
		Phase.TURN:
			var t: float = clampf(_time / duration, 0.0, 1.0)
			transform = _pose(0.012 + (1.0 - 0.012) * _ease(t), 0.0)
			if t >= 1.0:
				phase = Phase.SETTLE
				_time = 0.0
		Phase.SETTLE:
			var t: float = clampf(_time / settle_time, 0.0, 1.0)
			# a damped rebound of about a degree, so the landing reads as weight
			var rebound: float = -deg_to_rad(1.1) * sin(t * PI * 2.0) * (1.0 - t) * (1.0 - t)
			transform = _pose(1.0, rebound)
			if t >= 1.0:
				phase = Phase.DONE
				transform = _pose(1.0, 0.0)
				fold_settled.emit()


func _pose(fraction: float, extra: float) -> Transform3D:
	var turn: Basis = Basis(axis.normalized(), angle * fraction + extra * signf(angle))
	return Transform3D(_initial.basis * turn, _initial.origin)


# slow start like a heavy mass tipping, accelerating, then braking into place
func _ease(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	var u: float = -2.0 * t + 2.0
	return 1.0 - u * u * u / 2.0
