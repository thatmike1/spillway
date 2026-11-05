shader_type spatial;
render_mode diffuse_burley;

uniform vec4 wall_color : source_color = vec4(0.72, 0.69, 0.59, 1.0);
uniform vec4 deck_color : source_color = vec4(0.79, 0.77, 0.68, 1.0);
uniform float weathering = 0.12;
uniform float waterline = -100.0;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), t.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), t.x), t.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = abs(normalize(world_normal));
	float horizontal = smoothstep(0.55, 0.9, n.y);
	vec2 wall_uv = vec2(n.x > n.z ? world_position.z : world_position.x, world_position.y);
	float grain = noise21(world_position.xz * 9.0 + world_position.yy * 2.1);
	float clouds = noise21(world_position.xz * 0.14 + world_position.yy * 0.12);
	float streak = noise21(wall_uv * vec2(1.8, 0.12));
	float board_edge = 1.0 - smoothstep(0.008, 0.023, abs(fract(world_position.y / 0.27) - 0.5));
	float board_tone = hash21(vec2(floor(world_position.y / 0.27), floor(wall_uv.x / 3.6)));
	vec2 joint_uv = abs(fract(world_position.xz / vec2(4.8, 3.6)) - 0.5);
	float joint_distance = min(joint_uv.x, joint_uv.y);
	float joint_softness = max(fwidth(joint_distance), 0.0015);
	float deck_joint = 1.0 - smoothstep(0.0015, 0.0015 + joint_softness, joint_distance);
	vec3 base = mix(wall_color.rgb, deck_color.rgb, horizontal);
	base *= 0.97 + grain * 0.025 + clouds * 0.035;
	base *= mix(0.87, 1.0, horizontal);
	base *= world_normal.y < -0.3 ? 0.72 : 1.0;
	base *= 1.0 - (1.0 - horizontal) * (board_edge * 0.10 + board_tone * 0.028 + streak * weathering);
	base *= 1.0 - deck_joint * horizontal * 0.24;
	float damp = (1.0 - smoothstep(waterline + 0.02, waterline + 0.65, world_position.y));
	damp *= mix(1.0, 1.0 - smoothstep(0.06, 0.16, abs(world_position.y - waterline)), horizontal);
	damp *= 0.65 + noise21(wall_uv * vec2(2.0, 4.0)) * 0.35;
	base = mix(base, base * vec3(0.55, 0.66, 0.54), damp * 0.62);
	ALBEDO = base;
	ROUGHNESS = mix(0.91, 0.65, damp);
	SPECULAR = 0.25;
}
