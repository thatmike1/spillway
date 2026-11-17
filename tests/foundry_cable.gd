extends SceneTree
## real render resources prove local cloning, reuse and restoration across map exit.
const CABLE := preload("res://scripts/art/foundry_cable.gd")
class Host extends Node3D:
	var player: Node3D
	func map_entry() -> Dictionary:
		return {"grapple":true}
var output := "/tmp/r22-02-swing-height/cable"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	var host := Host.new()
	root.add_child(host)
	host.player = Node3D.new()
	host.add_child(host.player)
	var tether := MeshInstance3D.new()
	tether.name = "GrappleTether"
	var original := CylinderMesh.new()
	original.top_radius = 0.018
	original.bottom_radius = 0.018
	original.height = 1.0
	var material := StandardMaterial3D.new()
	tether.mesh = original
	tether.material_override = material
	host.player.add_child(tether)
	var level := Node3D.new()
	host.add_child(level)
	var cable := CABLE.new()
	level.add_child(cable)
	cable._process(0.0)
	var applied := tether.mesh as CylinderMesh
	var cloned := applied != original and is_equal_approx(applied.top_radius,0.0015) and is_equal_approx(applied.bottom_radius,0.0015)
	cable._process(0.0)
	var reused := tether.mesh == applied
	applied.height = 3.0
	var original_untouched := original.height == 1.0 and is_equal_approx(original.top_radius,0.018) and is_equal_approx(original.bottom_radius,0.018)
	level.remove_child(cable)
	var restored := tether.mesh == original and tether.material_override == material
	cable.free()
	var second := CABLE.new()
	level.add_child(second)
	second._process(0.0)
	var external := StandardMaterial3D.new()
	tether.material_override = external
	level.remove_child(second)
	var external_preserved := tether.mesh == original and tether.material_override == external
	second.free()
	var ok := cloned and reused and original_untouched and restored and external_preserved
	var result := {"ok":ok,"local_mesh_clone":cloned,"stable_clone_reused":reused,"original_resource_untouched":original_untouched,"map_exit_restores_resources":restored,"other_presentation_material_preserved":external_preserved,"scope":"render-resource ownership only; native input replay covers motion"}
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("summary.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	host.free()
	await process_frame
	quit(0 if ok else 1)
