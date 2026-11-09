shader_type canvas_item;
// p / r18 title wordmark: a narrow sloped channel cut through the letters, opening from nothing
// on the left like water finding its way through a dam. local pixels of the label.
uniform vec2 box_size = vec2(800.0, 160.0);
uniform float start = 0.22;
uniform float open_by = 0.46;
uniform float height_left = 0.80;
uniform float height_right = 0.40;
uniform float width = 0.055;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local / box_size;
	float centre = mix(height_left, height_right, p.x);
	float half_width = width * 0.5 * smoothstep(start, open_by, p.x);
	float d = abs(p.y - centre) - half_width;
	float aa = fwidth(p.y) * 1.2;
	COLOR.a *= half_width > 0.0 ? smoothstep(0.0, aa, d) : 1.0;
}
