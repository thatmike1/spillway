extends "res://scripts/spillway_main.gd"
## p / r13 carry game factory: spillway's main loop, hud and audio around the carry motor.
## set air_profile (or motor, for the tape executor) and optionally level_script before
## adding it to the tree. records and settings are never written and no historical best is
## loaded, so a comparison run starts from the same defaults as every other.

const CARRY_BUILD := "spillway-r13-carry"
const CARRY_PLAYER := preload("res://scripts/momentum_carry_player.gd")

class CarryHUD:
	extends "res://scripts/spillway_hud.gd"

	const CONTROLS := "WASD run. Space jump; hold to keep hopping.\nAir: W + mouse steers. A/D strafes. Carry speed through clean hops.\nS brakes. Ctrl / C ducks.\nR new run    F segment practice    Esc settings"

	func attach(main: Node) -> void:
		super(main)
		subtitle.text = main.call("identity_line")
		status.text = CONTROLS
		for node: Node in pause_panel.find_children("*", "Label", true, false):
			var label := node as Label
			if label.text == main.BUILD_ID:
				label.text = "%s / %s air / records disabled" % [main.CARRY_BUILD, main.get("air_profile")]
			elif label.text.begins_with("Run first, then hold Space"):
				label.text = CONTROLS

	func show_finish(is_best: bool, is_open_best: bool = false) -> void:
		super(is_best, is_open_best)
		# the inherited panel names spillway's three stages; use this level's own titles.
		var points: Array = game.level.get("checkpoints")
		var names := ["Crest", "Sluice yard", "Outflow"]
		for i: int in names.size():
			var title := str(points[i + 1].get("title", names[i])) if i + 1 < points.size() else "Finish"
			finish_label.text = finish_label.text.replace("\n%s   " % names[i], "\n%s   " % title)

	func _route_hint() -> String:
		# p / the inherited hints teach r12's surf and slide lines, which carry does not have.
		if game.level.has_method("route_hint"):
			return str(game.level.call("route_hint", int(game.checkpoint_index), game.player.global_position))
		if game.player.in_water:
			return "Use a recovery ramp to rejoin the decks."
		return "Follow the decks down. Height carries speed."

## "broad" or "narrow"; fixed once the runner is built.
var air_profile: String = "broad"
## the tape executor sets this string; a profile name selects that air law.
var motor: String = "":
	set(value):
		motor = value
		if CARRY_PLAYER.PROFILES.has(value):
			air_profile = value
## optional Script or res:// path of a level node with spillway_level's interface.
var level_script: Variant = null
## p / explicitly labelled comparison: comfort camera, no bob or speed fov.
var steady_camera: bool = false
var set_window_title: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	bind_inputs()
	_persist = false
	var script: Script = preload("res://scripts/spillway_level.gd")
	if level_script is Script:
		script = level_script
	elif level_script is String and not str(level_script).is_empty():
		script = load(level_script)
	level = script.new()
	level.name = "Level"
	add_child(level)
	level.call("build")
	player = CARRY_PLAYER.new()
	player.set("air_profile", air_profile)
	player.name = "Runner"
	add_child(player)
	player.connect("landed", func(_impact: float) -> void:
		if player.in_water and level.has_method("splash_at"):
			level.call("splash_at", player.global_position))
	if steady_camera:
		settings.comfort = true
	hud = CarryHUD.new()
	add_child(hud)
	hud.call("attach", self)
	audio = preload("res://scripts/spillway_audio.gd").new()
	add_child(audio)
	audio.call("attach", player, level)
	_apply_settings()
	restart_run()
	if OS.get_cmdline_user_args().has("--no-hud"):
		hud.hide()
	if set_window_title and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Spillway R13 / CARRY %s air%s / records disabled" % [air_profile, " / steady camera" if steady_camera else ""])
	print("carry: air=%s; build=%s; level=%s; steady_camera=%s; records=disabled; physics=%s; renderer=%s" % [air_profile, CARRY_BUILD, script.resource_path if not script.resource_path.is_empty() else "inner " + str(level.get("name")), steady_camera, ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"), RenderingServer.get_current_rendering_method()])

func identity_line() -> String:
	return "CARRY / %s AIR%s / R13 MOVEMENT EXPERIMENT" % [air_profile.to_upper(), " / STEADY CAMERA" if steady_camera else ""]

func _load(_path: String = SAVE_PATH, _legacy_path: String = LEGACY_SAVE_PATH) -> void:
	# comparison runs never read r12's or any other profile's records or settings.
	pass

func _save(_path: String = SAVE_PATH) -> void:
	pass
