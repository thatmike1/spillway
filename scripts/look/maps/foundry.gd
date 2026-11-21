extends RefCounted
## design 1121 look pass for Foundry: presentation only, called at the end of foundry_hall.dress().
## it never adds collision or touches manifest/art_manifest, so geometry_hash() stays exact.

const RING := Color("d2683a")
const TROLLEY := Color("e0d6bf")
const STRAP := Color("29464a")

static func dress(level: Node3D) -> void:
	# shell decks with quiet joints; weathered blue-grey walls instead of olive.
	var deck := level.get_node_or_null("Mesh_deck_entry_back_0_0") as MeshInstance3D
	if deck != null and deck.material_override is ShaderMaterial:
		var concrete := deck.material_override as ShaderMaterial
		concrete.set_shader_parameter("cap_color", Vector3(0.80, 0.785, 0.74))
		concrete.set_shader_parameter("joint_depth", 0.09)
		concrete.set_shader_parameter("slab_spread", 0.05)
		concrete.set_shader_parameter("dry_concrete", Vector3(0.40, 0.46, 0.47))
	for anchor: Node in level.get_children():
		if anchor is Node3D and str(anchor.name).begins_with("FoundryAnchor"):
			_anchor(level, anchor as Node3D)

static func _anchor(level: Node3D, anchor: Node3D) -> void:
	# rings are signal paint, unshaded so the hall's shade cannot turn them rust-brown.
	for child: Node in anchor.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is TorusMesh:
			var paint := StandardMaterial3D.new()
			paint.albedo_color = RING
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			(child as MeshInstance3D).material_override = paint
	# a pale trolley clamps the crane beam above each ring, so the anchor reads against dark steel.
	var at := anchor.position
	var trolley := MeshInstance3D.new()
	trolley.name = "Look_foundry_trolley_" + str(anchor.name).trim_prefix("FoundryAnchor")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.0, 1.3, 1.6)
	trolley.mesh = mesh
	trolley.position = Vector3(at.x, at.y + 1.5, at.z)
	var pale := StandardMaterial3D.new()
	pale.albedo_color = TROLLEY
	pale.roughness = 1.0
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://assets/maps/foundry/outline.gdshader")
	ink.set_shader_parameter("width", 0.06)
	pale.next_pass = ink
	trolley.material_override = pale
	level.add_child(trolley)
