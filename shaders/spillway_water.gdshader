shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.10, 0.34, 0.34, 1.0);
uniform float flow_speed = 0.65;
uniform float foam_amount = 0.12;
uniform float vertical_flow = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * flow_speed;
	NORMAL = normalize(vec3(
		0.045 * cos(world_position.x * 2.1 + world_position.z * 0.7 + phase),
		1.0,
		0.065 * sin(world_position.z * 3.2 - phase * 1.8)));
}

void fragment() {
	float phase = TIME * flow_speed;
	float flow_axis = mix(world_position.z, world_position.y, vertical_flow);
	float ripple = sin(flow_axis * 5.2 + phase * 2.4 + sin(world_position.x * 2.2));
	float secondary = sin(flow_axis * 1.3 + world_position.x * 2.7 + phase);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float shore = (1.0 - smoothstep(0.0, 0.025, edge)) * (0.5 + secondary * 0.2);
	float fleck = smoothstep(0.94, 1.0, ripple) * smoothstep(0.6, 1.0, secondary) * foam_amount;
	vec3 color = water_color.rgb * (0.93 + ripple * 0.045 + secondary * 0.055);
	ALBEDO = mix(color, vec3(0.70, 0.81, 0.73), min(0.7, shore + fleck));
	ROUGHNESS = 0.24;
	SPECULAR = 0.7;
	METALLIC = 0.12;
}
