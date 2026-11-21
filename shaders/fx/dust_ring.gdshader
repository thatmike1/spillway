shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// p / a landing ring on the deck: a broken ink contour with a pale dust band inside it,
// spreading and fading. widths are in metres so the ink reads as a thin line at any radius.
uniform vec4 pale : source_color = vec4(0.95, 0.93, 0.86, 1.0);
uniform vec4 ink : source_color = vec4(0.035, 0.065, 0.070, 1.0);
uniform float age = 0.0;      // 0 touch-down .. 1 gone
uniform float strength = 1.0;
uniform float radius_m = 1.0;
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n * 91.7 + seed * 13.1) * 43758.5453); }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p) * radius_m;
	float edge_r = 0.9 * radius_m;
	float angle = atan(p.y, p.x);
	float id = floor((angle + 3.14159265) / 6.2831853 * 18.0);
	// a few short gaps read as dust kicked out, not a drawn circle.
	float gap = step(0.25, hash(id));
	float aa = fwidth(r) * 0.75;
	float ink_w = mix(0.035, 0.018, age);
	float line = (1.0 - smoothstep(ink_w, ink_w + aa, abs(r - edge_r))) * gap;
	float dust_w = mix(0.22, 0.06, age);
	float dust = (1.0 - smoothstep(0.0, dust_w, edge_r - r)) * step(r, edge_r) * mix(0.5, 1.0, gap);
	float life = (1.0 - smoothstep(0.35, 1.0, age)) * strength;
	ALBEDO = mix(pale.rgb, ink.rgb, step(dust * 0.55, line * 0.8));
	ALPHA = max(line * 0.8, dust * 0.55) * life;
}
