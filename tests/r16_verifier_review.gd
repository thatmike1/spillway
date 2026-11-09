extends SceneTree
## independent component challenges against copied, hash-pinned verifier dependencies.

const READER := preload("res://scripts/r16_run_reader.gd")

class Visibility extends "res://tools/r16-pack-probe.gd":
	func _ready() -> void:
		pass

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var manifest := ""
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="):
			manifest = arg.trim_prefix("--manifest=")
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var decoded := {}
	for path: String in spec.paths:
		var run: Dictionary = READER.read(path)
		var item: Dictionary = READER.json_safe(run)
		item["column_hex"] = {}
		item["input_hex"] = {}
		for field: String in run.columns:
			item.column_hex[field] = run.columns[field].to_byte_array().hex_encode()
		for field: String in run.inputs:
			item.input_hex[field] = run.inputs[field].to_byte_array().hex_encode()
		decoded[path] = item
	var probe := Visibility.new()
	root.add_child(probe)
	var label := Label.new()
	label.text = "style 12345"
	label.position = Vector2(30, 30)
	label.size = Vector2(200, 40)
	probe.add_child(label)
	for i: int in 5:
		await process_frame
	var rows: Array = []
	rows.append({"name": "ordinary glyphs", "expected": true, "accepted": probe._drawn_label(label),
		"viewport": str(root.get_visible_rect()), "rect": str(label.get_global_rect()),
		"lines": label.get_line_count(), "visible_lines": label.get_visible_line_count(),
		"first_glyph": str(label.get_character_bounds(0))})
	label.modulate.a = 0.0
	rows.append({"name": "transparent glyphs", "expected": false, "accepted": probe._drawn_label(label)})
	label.modulate.a = 1.0
	label.visible_characters = 2
	rows.append({"name": "partial glyphs", "expected": false, "accepted": probe._drawn_label(label)})
	label.visible_characters = -1
	label.position.x = -1000
	rows.append({"name": "offscreen glyphs", "expected": false, "accepted": probe._drawn_label(label)})
	label.position.x = 30
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { COLOR.a = 0.0; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	label.material = material
	rows.append({"name": "shader discards all glyph alpha", "expected": false, "accepted": probe._drawn_label(label)})
	label.material = null
	probe.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"reader_runs": decoded, "visibility": rows}, "  ", false, true))
	file.close()
	quit(0)
