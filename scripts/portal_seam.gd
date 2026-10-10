class_name PortalSeam
extends Node3D
## Swept front (+Z) to back (-Z) crossing of a rectangular rigid portal.
## The doorway is visually masked in this slice; no recursive portal rendering.

signal traveler_crossed(traveler: Node3D)

@export var exit_seam: Node3D
@export var width: float = 3.0
@export var height: float = 4.0
@export var enabled: bool = true
@export_range(0.01, 2.0) var cooldown_seconds: float = 0.25

var _previous_positions: Dictionary = {}
var _cooldowns: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 50
	add_to_group("portal_seam")


func _physics_process(delta: float) -> void:
	for key: Variant in _cooldowns.keys():
		var remaining: float = float(_cooldowns[key]) - delta
		if remaining <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = remaining
	var live_ids: Dictionary = {}
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var traveler: Node3D = candidate as Node3D
		if traveler == null:
			continue
		var id: int = traveler.get_instance_id()
		live_ids[id] = true
		var current: Vector3 = traveler.global_position
		if _previous_positions.has(id):
			var previous: Vector3 = _previous_positions[id]
			try_crossing(traveler, previous, current)
		_previous_positions[id] = traveler.global_position
	for key: Variant in _previous_positions.keys():
		if not live_ids.has(key):
			_previous_positions.erase(key)
			_cooldowns.erase(key)


func get_mapping() -> Transform3D:
	if not is_instance_valid(exit_seam):
		return Transform3D.IDENTITY
	var half_turn: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	return exit_seam.global_transform * half_turn * global_transform.affine_inverse()


func map_transform(source: Transform3D) -> Transform3D:
	return get_mapping() * source


func map_velocity(source: Vector3) -> Vector3:
	return get_mapping().basis * source


func map_up(source: Vector3) -> Vector3:
	return (get_mapping().basis * source).normalized()


func crosses_rectangle(previous: Vector3, current: Vector3) -> bool:
	var inverse: Transform3D = global_transform.affine_inverse()
	var start: Vector3 = inverse * previous
	var finish: Vector3 = inverse * current
	if start.z <= 0.0 or finish.z > 0.0:
		return false
	var distance: float = start.z - finish.z
	if distance <= 0.000001:
		return false
	var intersection: Vector3 = start.lerp(finish, start.z / distance)
	return absf(intersection.x) <= width * 0.5 and absf(intersection.y) <= height * 0.5


func try_crossing(traveler: Node3D, previous: Vector3, current: Vector3) -> bool:
	if not enabled or not is_instance_valid(exit_seam) or not traveler.has_method("teleport_state"):
		return false
	var id: int = traveler.get_instance_id()
	if _cooldowns.has(id) or not crosses_rectangle(previous, current):
		return false
	# Unit scale is required: scaled portals would silently change speed/body size.
	if not _is_rigid(global_basis) or not _is_rigid(exit_seam.global_basis):
		return false
	var body_velocity: Vector3 = traveler.get("velocity")
	var body_up: Vector3 = traveler.get("up_direction")
	var destination: Transform3D = map_transform(traveler.global_transform)
	traveler.call("teleport_state", destination, map_velocity(body_velocity), map_up(body_up))
	block_traveler(traveler)
	if exit_seam.has_method("block_traveler"):
		exit_seam.call("block_traveler", traveler)
	traveler_crossed.emit(traveler)
	return true


func block_traveler(traveler: Node3D) -> void:
	var id: int = traveler.get_instance_id()
	_cooldowns[id] = cooldown_seconds
	_previous_positions[id] = traveler.global_position


func reset_seam() -> void:
	_previous_positions.clear()
	_cooldowns.clear()


func _is_rigid(value: Basis) -> bool:
	return value.is_equal_approx(value.orthonormalized()) and value.determinant() > 0.0
