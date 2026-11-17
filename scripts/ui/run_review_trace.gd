extends Control
## paired horizontal-speed traces on the course clock, with shared axes.
const LOOK := preload("res://scripts/r18_ui_theme.gd")
var series: Array = []
var duration := 1.0
var cursor := 0.0
var font_size := 13
func _draw() -> void:
	var area := Rect2(Vector2(48, 24), size - Vector2(64, 56))
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var peak := 1.0
	for track: Array in series:
		for point: Vector2 in track:
			peak = maxf(peak, point.y)
	for step: int in 3:
		var y := area.end.y - step * area.size.y / 2.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(LOOK.INK, 0.12))
		draw_string(LOOK.font("smallnum"), Vector2(0, y + 4), "%.0f" % (peak * step / 2.0), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LOOK.INK)
	for n: int in series.size():
		var points := PackedVector2Array()
		var track: Array = series[n]
		# bin to pixels, retaining the speed extrema so short landings remain visible.
		var previous_x := -1
		var low := Vector2.ZERO
		var high := Vector2.ZERO
		for sample: Vector2 in track:
			var point := Vector2(area.position.x + sample.x / maxf(duration, 0.001) * area.size.x, area.end.y - sample.y / peak * area.size.y)
			var x := int(point.x)
			if x != previous_x and previous_x >= 0:
				points.append(low)
				if low != high:
					points.append(high)
			if x != previous_x:
				low = point
				high = point
			else:
				if point.y < low.y: low = point
				if point.y > high.y: high = point
			previous_x = x
		if previous_x >= 0:
			points.append(low)
			points.append(high)
		if points.size() > 1:
			draw_polyline(points, LOOK.TEAL if n == 0 else LOOK.CORAL_DEEP, 2.0, true)
	var x := area.position.x + cursor / maxf(duration, 0.001) * area.size.x
	draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), LOOK.INK, 1.0)
	draw_string(LOOK.font("smallnum"), Vector2(area.position.x, size.y - 7), "0 s", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LOOK.INK)
	var end_label := "%.2f s" % duration
	var end_width := LOOK.font("smallnum").get_string_size(end_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(LOOK.font("smallnum"), Vector2(area.end.x - end_width, size.y - 7), end_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, LOOK.INK)
