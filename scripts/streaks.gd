extends Control
## port choice (P): original peripheral air trails; centre stays entirely clear.
var player: CharacterBody3D
var phase: float = 0
var strength: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if player == null:
		return
	phase = fmod(phase + player.get_presentation_speed() * delta * .45, 1)
	strength = player.sprint_effect * (.22 if player.comfort_enabled else 1.0)
	queue_redraw()

func _draw() -> void:
	if strength < .002:
		return
	var centre: Vector2 = size / 2
	for side: float in [-1.0, 1.0]:
		for i: int in 15:
			var progress: float = fmod(phase + i * .381966, 1)
			var y: float = size.y * (.08 + fmod(i * .618034, .84))
			var x: float = size.x * (.015 + .045 * (1 - progress))
			if side > 0:
				x = size.x - x
			var head := Vector2(x, y)
			var direction: Vector2 = (head - centre).normalized()
			var length: float = (28 + 45 * progress) * strength
			var alpha: float = strength * .23 * sin(progress * PI)
			draw_line(head - direction * length, head, Color(.75, .85, .95, alpha), 1.8, true)
