extends "res://tools/r16-pack-probe.gd"
## p / component negatives of the exact visibility predicate used by the release probe.
## headless glyph layout only; no claim that these controls were rendered by a release pack.

class Host extends Node:
	var paused := false
	var clean_eligible := true
	var finished := false
	var style_best := -1
	var style_new_best := false

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var label := Label.new()
	label.text = "score 123"
	label.position = Vector2(30, 30)
	label.size = Vector2(200, 40)
	label.add_theme_font_size_override("font_size", 20)
	add_child(label)
	await _frames(3)
	check("ordinary full glyph label accepted", _drawn_label(label))
	label.visible_characters = 2
	check("partially drawn text refused", not _drawn_label(label))
	label.visible_characters = -1
	label.modulate.a = 0.0
	check("transparent text refused", not _drawn_label(label))
	label.modulate.a = 1.0
	label.position.x = -500
	check("offscreen text refused", not _drawn_label(label))
	label.position.x = 30
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	check("transparent theme text refused", not _drawn_label(label))
	label.remove_theme_color_override("font_color")
	label.visible = false
	check("hidden text refused", not _drawn_label(label))
	label.visible = true
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = Vector2(2, 2)
	add_child(clip)
	label.reparent(clip)
	check("ancestor clipping refused", not _drawn_label(label))
	label.reparent(self)
	label.position = Vector2(30, 30)
	label.clip_text = true
	label.custom_minimum_size = Vector2.ZERO
	label.size = Vector2(2, 40)
	check("internal glyph clipping refused", not _drawn_label(label))
	var host := Host.new()
	add_child(host)
	var style: RefCounted = load("res://scripts/r16_style.gd").new()
	style.call("reset")
	var panel: Control = load("res://scripts/r16_style_panel.gd").new()
	add_child(panel)
	panel.call("attach", host, style)
	await _frames(3)
	check("actual style panel score fully laid out", _drawn_label(panel.get("score_label")))
	(panel.get("score_label") as Label).modulate.a = 0.0
	check("actual style panel transparent score refused", not _drawn_label(panel.get("score_label")))
	var failed := checks.filter(func(c: Dictionary) -> bool: return not c.ok)
	var file := FileAccess.open(out_dir.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks.size(), "failed": failed.size(), "results": checks}, "  "))
	file.close()
	print("r16 delivery visibility: %d checks, %d failed" % [checks.size(), failed.size()])
	get_tree().quit(0 if failed.is_empty() else 1)
