shader_type spatial;
render_mode diffuse_burley;
// p / world-projected stretcher bond for the terracotta housings; fades to flat tone at distance.

uniform vec4 brick_color : source_color = vec4(0.62, 0.33, 0.24, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.76, 0.70, 0.61, 1.0);
uniform vec4 cap_color : source_color = vec4(0.70, 0.67, 0.60, 1.0);
uniform float soldier_course = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 a = abs(n);
	float along = a.x > a.z ? world_position.z : world_position.x;
	vec2 b = vec2(along / 0.25, world_position.y / 0.09);
	float row = floor(b.y);
	b.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(b);
	vec2 f = fract(b);
	vec2 w = fwidth(b);
	vec2 joint = vec2(0.035, 0.09);
	vec2 inside = smoothstep(joint, joint + w, f) * smoothstep(joint, joint + w, 1.0 - f);
	float mortar = 1.0 - inside.x * inside.y;
	// lines alias beyond a few dozen metres, so the bond resolves into an even weathered tone.
	float detail = clamp(1.6 - max(w.x, w.y) * 2.2, 0.0, 1.0);
	float tone = hash21(cell);
	vec3 brick = brick_color.rgb * (0.86 + tone * 0.24);
	vec3 color = mix(brick_color.rgb * 0.98, brick, detail);
	color = mix(color, mortar_color.rgb, mortar * detail * 0.38);
	color = mix(color, mortar_color.rgb * 0.92, (1.0 - detail) * 0.10);
	// a darker rain line under the cap gives the boxes a made top edge.
	float wash = smoothstep(0.0, 1.0, fract(world_position.y / 3.0)) * 0.06;
	color *= 1.0 - wash;
	color = mix(color, cap_color.rgb, smoothstep(0.55, 0.9, n.y));
	color *= n.y < -0.3 ? 0.68 : 1.0;
	ALBEDO = color;
	ROUGHNESS = 0.86;
	SPECULAR = 0.3;
}
