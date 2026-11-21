shader_type canvas_item;
// title wordmark: one channel cut through the letters, a tapered lens that starts as a hairline
// low in the first letters, rises and swells through the middle and thins out past the last.
// like water finding its way through a dam. coordinates are local pixels of the label.
uniform vec2 box_size = vec2(800.0, 160.0);
uniform float start = 0.27;          // where the cut begins, fraction of the width
uniform float open_by = 0.46;        // kept for older callers; the taper replaces it
uniform float finish = 1.04;         // where the cut ends (past the right edge = it exits)
uniform float height_left = 0.64;    // cut centre at the start, fraction of the height
uniform float height_right = 0.30;   // cut centre at the end
uniform float bow = 0.035;           // gentle upward bow along the run
uniform float width = 0.068;         // widest opening, fraction of the height
uniform float taper = 0.75;          // >1 keeps the ends thin for longer
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local / box_size;
	float t = clamp((p.x - start) / max(finish - start, 0.001), 0.0, 1.0);
	float centre = mix(height_left, height_right, t) - bow * sin(3.14159265 * t);
	float swell = pow(sin(3.14159265 * pow(t, 0.8)), taper);
	float half_width = width * 0.5 * swell * step(start, p.x);
	float d = abs(p.y - centre) - half_width;
	float aa = fwidth(p.y) * 1.1;
	COLOR.a *= half_width > 0.0 ? smoothstep(0.0, aa, d) : 1.0;
}
