class_name GravityZone
extends Area3D
## Zones expose gravity; the player resolves overlap priority once per tick.
## They never independently overwrite a player's gravity on enter/exit.

@export var local_up: Vector3 = Vector3.UP
@export var strength: float = 22.0
# Area3D already exports priority (float); use its inherited field for selection.


func _ready() -> void:
	add_to_group("gravity_zone")
	monitoring = true
	# CharacterBody owns gravity integration, so disable built-in body override.
	gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED


func get_world_up() -> Vector3:
	var world_up: Vector3 = global_basis * local_up
	if world_up.length_squared() < 0.000001:
		return Vector3.UP
	return world_up.normalized()
