extends Node3D
## p / independent air review fixture, used only through the committed tape executor.
## motor = policy:geometry[:speed]; seed is one labelled initial write before warmup.
## no mid-episode pose, velocity, camera or progress writes are permitted here.

const MAIN := preload("res://scripts/spillway_main.gd")
const CARRY := preload("res://scripts/momentum_carry_player.gd")
const AIR := preload("res://scripts/momentum_carry_air_candidate.gd")
const OVERFLOW := preload("res://scripts/momentum_overflow_game.gd")
const GAME := preload("res://scripts/momentum_carry_game.gd")
const LEVEL := preload("res://scripts/momentum_overflow_level.gd")

class NeutralLevel:
	extends "res://scripts/momentum_overflow_level.gd"
	func _init() -> void:
		material_mode = "neutral"
var motor := "candidate:drop:13"
var player: CharacterBody3D
var level: Node3D
var settings := {"sensitivity": 1.0}
var respawn_count := 0
var checkpoint_index := 0
var elapsed := 0.0
var finished := false
var finish_kind := "fixture"
var paused := false
var child_game: Node

func _ready() -> void:
	process_physics_priority = 900
	var parts := motor.split(":")
	var policy: String = parts[0]
	var geometry: String = parts[1] if parts.size() > 1 else "drop"
	if geometry in ["block", "block_mirror", "block_offset"]:
		LEVEL.next_variant = geometry
		child_game = GAME.new()
		child_game.set("level_script", NeutralLevel)
		child_game.set("set_window_title", false)
		child_game.set("motor", policy)
		if policy == "candidate":
			child_game.set("player_script", AIR)
		add_child(child_game)
		player = child_game.get("player")
		child_game.hud.subtitle.text = "INDEPENDENT AIR REVIEW / %s / FROZEN %s" % [policy.to_upper(), geometry.to_upper()]
		level = child_game.get("level")
		print("air review frozen overflow geometry=", level.call("geometry_hash"))
		return
	MAIN.bind_inputs()
	_environment()
	var origin := Vector3(0, 180, 0)
	var yaw: float = float(parts[4]) if parts.size() > 4 else 0.0
	if geometry in ["flat", "flat_earned"]:
		box("flat", Vector3(0,-0.5,0), Vector3(800,1,800))
		origin = Vector3(0,0.04,0)
	elif geometry == "earned" or geometry == "wall":
		box("top", Vector3(0,11.5,0), Vector3(20,1,10))
		ramp("descent", Vector3(0,12,-5), Vector3(0,0,-25.78460969),20)
		box("launch", Vector3(0,-0.5,-30.78460969), Vector3(20,1,10))
		box("target", Vector3(3,-0.5,-60), Vector3(4,1,32.43078062))
		box("catch", Vector3(0,-5.5,-70), Vector3(100,1,200))
		box("return", Vector3(9,-2.5,-80), Vector3(8,1,40))
		if geometry == "wall":
			box("wall",Vector3(6,2,-60),Vector3(0.5,8,80))
		origin=Vector3(0,12.04,0)
	elif geometry == "rail":
		ramp("floor",Vector3(0,40,10),Vector3(0,40-120*tan(deg_to_rad(30.0)),-110),8)
		box("rail",Vector3(2,0,-30),Vector3(0.5,200,200))
		origin=Vector3(0,40-10*tan(deg_to_rad(30.0))+0.15,0)
		yaw=-0.12
	player = AIR.new() if policy == "candidate" else CARRY.new()
	if policy != "candidate":
		player.set("air_profile", policy)
	player.name = "Runner"
	add_child(player)
	player.call("reset_to", Transform3D(Basis(Vector3.UP,yaw),origin))
	if geometry in ["drop", "flat"]:
		var speed: float = float(parts[2]) if parts.size() > 2 else 13.0
		var seed_heading: float = float(parts[3]) if parts.size() > 3 else 0.0
		player.velocity = Vector3.FORWARD.rotated(Vector3.UP,seed_heading)*speed
		print("air review SEEDED fixture=", geometry, " initial velocity=", player.velocity)
	else:
		print("air review INPUT-EARNED fixture=", geometry, " start=", origin)
	var layer := CanvasLayer.new()
	var tag := Label.new()
	tag.text = "INDEPENDENT AIR REVIEW / %s / %s" % [policy, geometry]
	tag.position = Vector2(24,18)
	tag.add_theme_font_size_override("font_size",24)
	layer.add_child(tag)
	add_child(layer)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if child_game != null:
		for key: String in ["respawn_count", "checkpoint_index", "elapsed", "finished", "finish_kind", "paused"]:
			set(key, child_game.get(key))

func _apply_settings() -> void:
	player.set("mouse_sensitivity",0.0022*float(settings.sensitivity))

func request_quit(code: int = 0) -> void:
	get_tree().quit(code)

func box(label: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = size
	mesh.mesh = visual
	var mat := StandardMaterial3D.new()
	mat.albedo_color=Color(0.65,0.68,0.66) if label != "rail" else Color(0.25,0.3,0.38)
	if label in ["floor", "rail"]:
		# a world-space checker adds motion landmarks without changing any collision shape.
		var image := Image.create(32,32,false,Image.FORMAT_RGB8)
		for y: int in 32:
			for x: int in 32:
				image.set_pixel(x,y,Color.WHITE if (x<16)==(y<16) else Color(0.55,0.55,0.55))
		mat.albedo_texture=ImageTexture.create_from_image(image)
		mat.uv1_triplanar=true
		mat.uv1_world_triplanar=true
		mat.uv1_scale=Vector3(0.25,0.25,0.25)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body

func ramp(label: String,a: Vector3,b: Vector3,width: float) -> void:
	var run := b-a
	var tilt := atan2(run.y,-run.z)
	var basis := Basis(Vector3.RIGHT,tilt)
	var body := box(label,(a+b)*0.5-basis.y*0.5,Vector3(width,1,run.length()))
	body.transform=Transform3D(basis,(a+b)*0.5-basis.y*0.5)

func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-55,35,0)
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.55,0.68,0.82)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(0.7,0.7,0.7)
	environment.environment.ambient_light_energy=0.8
	add_child(environment)
