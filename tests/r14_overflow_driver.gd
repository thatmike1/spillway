extends "res://tests/momentum_overflow_driver.gd"
## p / actual R14 Overflow route recording. run with one draw per physics tick:
## godot --headless --fixed-fps 128 --path . --script res://tests/r14_overflow_driver.gd
##   -- --air=server128 --route=ordinary --out=ABSOLUTE_OUTSIDE_CHECKOUT
## vanilla64 needs --fixed-fps 64; r13_original120 needs 120. output is a version 2 tape.
## this is a state-aware execution proof, not discovery, imperfect play or feel evidence.
## current actual-game route recording. the original coordinate-aware driver chooses
## only key/mouse events. no pose, velocity or progress override after normal game startup.
const R14 := preload("res://scripts/r14_main.gd")
const REGISTRY := preload("res://scripts/r14_presets.gd")
func _initialize() -> void:
 var id := "server128"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--air="):id=REGISTRY.resolve(arg.trim_prefix("--air="))
 Engine.physics_ticks_per_second=int(REGISTRY.entry(id).rate)
 super._initialize()
func _start() -> void:
 max_ticks=int(opts.get("max-ticks","16000"))
 game=R14.new()
 game.motor=str(opts.get("air","server128"))
 game.map_id="overflow"
 game.source_sensitivity_override=5.729577951308232
 game.set_window_title=false
 root.add_child(game)
 player=game.player
 level=game.level
 # the inherited recording controller reads this compatibility value; R14 gameplay does not.
 var radians_per_count := float(player.get("tape_radians_per_count")) if "tape_radians_per_count" in player else float(player.get("mouse_sensitivity"))
 game.settings["sensitivity"]=radians_per_count/PX
 nodes=_route(str(opts.get("route","ordinary")),"course")
 trace=FileAccess.open(out_dir.path_join("trace.jsonl"),FileAccess.WRITE)
 for early:bool in [true,false]:
  var hook=Hook.new()
  hook.driver=self
  hook.early=early
  hook.process_physics_priority=-1000 if early else 1000
  root.add_child(hook)
func _end(reason:String) -> void:
 super._end(reason)
 var tape:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out_dir.path_join("events.tape.json")))
 tape.version=2
 tape.input_profile="physics_tick"
 tape.physics_hz=Engine.physics_ticks_per_second
 tape.duration_ticks=int(tape.duration_ticks)
 for event:Dictionary in tape.events:event.tick=int(event.tick)
 tape.duration_s=float(tape.duration_ticks)/Engine.physics_ticks_per_second
 tape.description="P actual R14-main Overflow closed-loop input recording on Source guard3; authored coordinate-aware route, not human play"
 _write("events.tape.json",tape)
 var summary:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out_dir.path_join("summary.json")))
 summary.label="P actual R14 main, normal spawn, coordinate-aware input only; Source guard3"
 summary.preset=game.preset_id
 summary.record_key=game.course_key
 summary.record_identity=game.record_identity()
 for path:String in ["res://scripts/r14_main.gd", "res://scripts/r14_presets.gd", "res://scripts/r14_source_player.gd", "res://scripts/r14_source_motion.gd", "res://tests/r14_overflow_driver.gd"]:
  summary.sources_sha256[path]=FileAccess.get_sha256(path)
 summary.player_sha256=FileAccess.get_sha256(player.get_script().resource_path)
 summary.driver_sha256=FileAccess.get_sha256(get_script().resource_path)
 _write("summary.json",summary)
