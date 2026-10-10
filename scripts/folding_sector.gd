class_name FoldingSector
extends AnimatableBody3D
## Rigid traversal geometry. Children supply both mesh and matching collision.
## Origin is the hinge; initial transform is preserved exactly on reset.

signal fold_completed

@export var rotation_axis: Vector3 = Vector3.RIGHT
@export var fold_angle: float = PI / 2.0
@export_range(0.01, 30.0) var duration: float = 3.0
@export var auto_start: bool = false

var _initial_transform: Transform3D = Transform3D.IDENTITY
var _elapsed: float = 0.0
var _folding: bool = false
var _initialized: bool = false


func _ready() -> void:
	process_physics_priority = -50
	sync_to_physics = true
	set_meta("traversal_up", true)
	_initial_transform = transform
	_initialized = true
	if auto_start:
		start_fold()


func _physics_process(delta: float) -> void:
	if not _folding:
		return
	_elapsed = minf(_elapsed + delta, maxf(duration, 0.001))
	var progress: float = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	# Smoothstep gives stationary endpoints without changing the rigid topology.
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var axis: Vector3 = rotation_axis.normalized()
	if axis.length_squared() < 0.5:
		axis = Vector3.RIGHT
	var rotation_basis: Basis = Basis(axis, fold_angle * eased)
	transform = Transform3D(_initial_transform.basis * rotation_basis, _initial_transform.origin)
	if progress >= 1.0:
		_folding = false
		fold_completed.emit()


func start_fold() -> void:
	if not _initialized:
		_initial_transform = transform
		_initialized = true
	if _elapsed >= maxf(duration, 0.001):
		return
	_folding = true


func reset_fold() -> void:
	_folding = false
	_elapsed = 0.0
	if _initialized:
		transform = _initial_transform


func get_surface_up() -> Vector3:
	return global_basis.y.normalized()


func is_folding() -> bool:
	return _folding


func get_progress() -> float:
	return clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
