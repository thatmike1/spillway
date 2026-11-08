extends "res://scripts/r14_main.gd"
## p / setup only, for the no-crouch parity replay: the r14 main, map and recorded look scale of
## the retained overflow f2 tape, with the r15 crouch runner built where r14 builds its source
## runner. nothing else in the main, hud, records or level changes. records stay off through
## the tape wrapper's isolated profile.

const R15_PLAYER := "res://scripts/r15_source_player.gd"

func _init():
	map_id = "overflow"
	source_sensitivity_override = 5.729577951308232

func _make_runner(entry: Dictionary) -> CharacterBody3D:
	if str(entry.family) != "source":
		return super(entry)
	var runner: CharacterBody3D = (load(R15_PLAYER) as Script).new()
	runner.name = "Runner"
	runner.call("apply_settings", _source_settings(str(entry.id)))
	return runner
