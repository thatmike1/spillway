shader_type spatial;
render_mode specular_disabled;
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 // broad, low-contrast bands keep attention on the pale running surfaces.
 float swell = sin(world_position.x * 0.19 + sin(world_position.z * 0.11));
 float ripple = sin(world_position.z * 0.71 + world_position.x * 0.13);
 ALBEDO = vec3(0.28, 0.48, 0.49) + swell * 0.012 + ripple * 0.004;
 ROUGHNESS = 0.94;
 SPECULAR = 0.0;
}
