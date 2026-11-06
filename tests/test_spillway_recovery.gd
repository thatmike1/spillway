extends SceneTree
## input-only recovery episodes from the normal spawn: no pose, velocity or yaw writes after
## restart_run. they prove a physical way back, not that a miss is pleasant.
var game: Node3D
var player: CharacterBody3D
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	print("%s %s" % ["PASS" if value else "FAIL", text])
	if not value:
		failures += 1

func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## r12 / a first-time player who only holds W leaves the crest lip, lands on the crest bank
## and slides off its foot. the dam-toe runout carries them into the channel, and the same
## held W climbs the channel recovery ramp onto the terrace.
func w_first() -> void:
	game.call("restart_run")
	await physics_frame
	var touched := {}
	action("move_forward", true)
	var reached := false
	for i: int in 120 * 8:
		await physics_frame
		# every manifold contact counts, not only the first point of each slide collision.
		for j: int in player.get_slide_collision_count():
			var contact := player.get_slide_collision(j)
			for k: int in contact.get_collision_count():
				var body := contact.get_collider(k) as Node
				if body != null:
					touched[str(body.name)] = true
		var p := player.global_position
		if p.z < -36.0 and p.y > 3.9 and player.is_grounded():
			reached = true
			break
	action("move_forward", false)
	check(int(game.get("respawn_count")) == 0, "holding W off the crest lip never respawns: %s" % player.global_position)
	check(touched.has("DamToeRunout") and touched.has("ChannelRecoveryRamp"),
		"the drop runs out under the crest and climbs the channel ramp: %s" % [touched.keys()])
	check(reached, "held W alone reaches the jump terrace within 8 s: %s" % player.global_position)

func run() -> void:
	game = load("res://scripts/spillway_main.gd").new()
	root.add_child(game)
	game.set("_persist", false)
	player = game.get("player")
	await w_first()
	print("spillway recovery: %d/%d checks passed; input-only from normal spawn, not a fun claim" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
