extends Node3D
## p / r14 tape-rate test game. it is not the r14 main and not the source motor: it drives
## the executor's rate contract through the ordinary game hook, with an existing r13 motor
## on a labelled tape fixture, the way a preset-switching main would set its own rate.
## `motor` is an alias "flow@64", "r12@128" or "flow@120", optionally ":step" or ":glance"
## for another fixture, and optionally one deliberate fault for negative controls:
##   +declare-only     declares the alias rate but leaves the engine wherever it already is
##   +switch@N         sets a different engine rate on its Nth physics call
##   +timescale@N      sets Engine.time_scale to 0.5 on its Nth physics call

const MAIN := preload("res://scripts/spillway_main.gd")
const FIXTURE := preload("res://tools/momentum-tape-fixture.gd")
const MOTORS := {"flow": "res://scripts/momentum_flow_player.gd", "r12": "res://scripts/spillway_player.gd", "source_server": "res://scripts/r14_source_player.gd", "source_vanilla": "res://scripts/r14_source_player.gd"}

var motor := "flow@120"
var player: CharacterBody3D
# the rate this game is built for, read by the executor after _ready.
var physics_hz := 0
var tape_start := ""
var respawn_count := 0
var checkpoint_index := 0
# the sum of this game's own physics deltas, for the elapsed-time consistency check.
var elapsed := 0.0
var finished := false
var finish_kind := ""
var paused := false
var _fault := ""
var _fault_call := -1
var _calls := 0

func _ready() -> void:
	var parts := motor.split("+")
	var place := parts[0].split(":")
	var fixture := place[1] if place.size() > 1 else "flat"
	var alias := place[0].split("@")
	physics_hz = int(alias[1]) if alias.size() > 1 else 120
	tape_start = "fixture:%s via tests/r14_tape_rate_game.gd (labelled test game, not normal spawn)" % fixture
	if parts.size() > 1:
		var fault := parts[1].split("@")
		_fault = fault[0]
		_fault_call = int(fault[1]) if fault.size() > 1 else -1
	if _fault != "declare-only":
		Engine.physics_ticks_per_second = physics_hz
	MAIN.bind_inputs()
	var world := FIXTURE.new()
	world.name = "TapeFixture"
	add_child(world)
	world.build(fixture)
	player = (load(MOTORS[alias[0]]) as Script).new()
	var source_motor := alias[0].begins_with("source_")
	if source_motor:
		player.call("apply_preset", "csgo_server" if alias[0] == "source_server" else "csgo_vanilla", {"sensitivity": 2.5})
	player.name = "Runner"
	world.add_child(player)
	player.call("reset_to", world.spawn)
	# the game's own settings mapping and defaults, from an unattached main instance.
	if not source_motor:
		var main: Node = MAIN.new()
		main.set("player", player)
		main.call("_apply_settings")
		main.free()

func _physics_process(delta: float) -> void:
	_calls += 1
	elapsed += delta
	if _calls != _fault_call:
		return
	if _fault == "switch":
		Engine.physics_ticks_per_second = 64 if physics_hz != 64 else 128
	elif _fault == "timescale":
		Engine.time_scale = 0.5
