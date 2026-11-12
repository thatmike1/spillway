extends Node3D
## p / r13 tape fixture: small labelled geometry for calibration and contact repros.
## it is not the course and has no game rules (no water, respawn, checkpoints or hud).
## runs that use it are fixture starts, never normal spawn; the executor labels them.

# p / every fixture places the runner once, facing -z, on an approach deck at y = 0.
const FIXTURES := {
	# a long flat deck for calibration (turn rate, sensitivity, cadence).
	"flat": {"spawn": Vector3(0, 0.02, 20)},
	# approach deck, a 0.7 m step 16 m ahead, a ledge, then a tall wall 28 m further on.
	"step": {"spawn": Vector3(0, 0.02, 4)},
	# a flat deck with one straight side wall 2 m to the left, for glancing contacts.
	"glance": {"spawn": Vector3(0, 0.02, 20)},
}

var spawn: Transform3D
var fixture_name: String = ""
var _checker: StandardMaterial3D

func build(which: String) -> bool:
	if not FIXTURES.has(which):
		return false
	fixture_name = which
	spawn = Transform3D(Basis.IDENTITY, FIXTURES[which]["spawn"])
	_checker = _material()
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(35), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.68, 0.82)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.66, 0.72)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	if which == "flat":
		_box("deck", Vector3(0, -0.5, -40), Vector3(120, 1, 160), Color(0.78, 0.76, 0.7))
	elif which == "glance":
		_box("deck", Vector3(0, -0.5, -40), Vector3(120, 1, 160), Color(0.78, 0.76, 0.7))
		_box("side_wall", Vector3(-2.5, 2, -40), Vector3(1, 5, 160), Color(0.5, 0.56, 0.66))
	else:
		_box("approach", Vector3(0, -0.5, -3), Vector3(24, 1, 18), Color(0.78, 0.76, 0.7))
		_box("step", Vector3(0, -0.15, -26), Vector3(24, 1.7, 28), Color(0.86, 0.62, 0.42))
		_box("wall", Vector3(0, 3, -40.5), Vector3(24, 8, 1), Color(0.5, 0.56, 0.66))
	var tag := Label.new()
	tag.text = "FIXTURE %s / labelled setup, not normal spawn" % which.to_upper()
	tag.position = Vector2(24, 18)
	tag.add_theme_font_size_override("font_size", 20)
	var layer := CanvasLayer.new()
	layer.add_child(tag)
	add_child(layer)
	return true

func _material() -> StandardMaterial3D:
	# 1 m world-space checks, so travel and turning read in native frames.
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in 64:
		for x: int in 64:
			image.set_pixel(x, y, Color(1, 1, 1) if (x < 32) == (y < 32) else Color(0.72, 0.72, 0.72))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return material

func _box(label: String, center: Vector3, size: Vector3, tint: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := _checker.duplicate() as StandardMaterial3D
	material.albedo_color = tint
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)
