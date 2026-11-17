extends Node
## map-local presentation: clone drawn resources and restore them when the map leaves the tree.
var _target: MeshInstance3D
var _original_mesh: Mesh
var _original_material: Material
var _applied_mesh: Mesh
var _applied_material: Material

func _ready() -> void:
	process_priority = 90

func _process(_delta: float) -> void:
	var host := get_parent().get_parent()
	if host == null or not host.has_method("map_entry"):
		return
	var body := host.get("player") as Node3D
	if body == null:
		return
	var tether := body.get_node_or_null("GrappleTether") as MeshInstance3D
	if tether == null or not tether.mesh is CylinderMesh or (tether == _target and tether.mesh == _applied_mesh):
		return
	_restore()
	_target = tether
	_original_mesh = tether.mesh
	_original_material = tether.material_override
	var cable := tether.mesh.duplicate() as CylinderMesh
	cable.top_radius = 0.0015
	cable.bottom_radius = 0.0015
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("87765c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	tether.mesh = cable
	tether.material_override = material
	_applied_mesh = cable
	_applied_material = material

func _exit_tree() -> void:
	_restore()

func _restore() -> void:
	if is_instance_valid(_target):
		if _target.mesh == _applied_mesh:
			_target.mesh = _original_mesh
		if _target.material_override == _applied_material:
			_target.material_override = _original_material
	_target = null
	_original_mesh = null
	_original_material = null
	_applied_mesh = null
	_applied_material = null
