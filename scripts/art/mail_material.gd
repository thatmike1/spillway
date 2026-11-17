extends RefCounted
## reuse spillway's original painted-concrete shader and redistribution-cleared wear texture.
static func concrete(side: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/look/surface.gdshader")
	material.set_shader_parameter("wear", preload("res://assets/look/painted-wear.png"))
	material.set_shader_parameter("top_color", Color("eee4cb"))
	material.set_shader_parameter("side_color", side)
	material.set_shader_parameter("wear_amount", 0.27)
	return material
