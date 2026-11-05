shader_type spatial;
render_mode diffuse_burley;
// p / meadow, dry grass and exposed bank by height and slope; no texture or noise lookups.

uniform vec4 meadow_low : source_color = vec4(0.24, 0.31, 0.19, 1.0);
uniform vec4 meadow_high : source_color = vec4(0.38, 0.44, 0.26, 1.0);
uniform vec4 dry_grass : source_color = vec4(0.53, 0.50, 0.32, 1.0);
uniform vec4 bank_earth : source_color = vec4(0.44, 0.38, 0.29, 1.0);
uniform float valley_floor = -9.5;
uniform float ridge_height = 30.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float h = clamp((world_position.y - valley_floor) / ridge_height, 0.0, 1.0);
	vec3 color = mix(meadow_low.rgb, meadow_high.rgb, smoothstep(0.0, 0.8, h));
	// broad sun-dried patches drift across the slopes at field scale.
	float patches = sin(world_position.x * 0.071 + sin(world_position.z * 0.043) * 2.3)
		* sin(world_position.z * 0.058 - world_position.x * 0.031);
	color = mix(color, dry_grass.rgb, smoothstep(0.15, 0.75, patches) * (0.25 + h * 0.45));
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	color = mix(color, bank_earth.rgb, smoothstep(0.30, 0.62, slope));
	// damp, darker grass where the valley holds water.
	color *= mix(0.82, 1.0, smoothstep(0.0, 0.12, h));
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
