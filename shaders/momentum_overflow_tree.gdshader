shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// p / overflow art pass conifers: one dark green per instance, varied by its position, with
// the foot of each tree darker so a stand reads as a mass. original procedural work.

uniform vec3 dark : source_color = vec3(0.12, 0.17, 0.1);
uniform vec3 light : source_color = vec3(0.2, 0.25, 0.13);

varying float shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	shade = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	shade = shade * (0.55 + 0.45 * VERTEX.y);
}

void fragment() {
	ALBEDO = mix(dark, light, shade);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
