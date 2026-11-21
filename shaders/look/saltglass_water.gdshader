shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool look_c = false;
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 // broad, low-contrast bands keep attention on the pale running surfaces.
 float swell = sin(world_position.x * 0.19 + sin(world_position.z * 0.11));
 float ripple = sin(world_position.z * 0.71 + world_position.x * 0.13);
 vec3 water = vec3(0.19, 0.46, 0.55) + swell * 0.012 + ripple * 0.004;
 float horizon = pow(1.0 - max(dot(normalize(CAMERA_POSITION_WORLD - world_position), vec3(0, 1, 0)), 0.0), 6.0);
 ALBEDO = mix(water, vec3(0.52, 0.69, 0.72), horizon * 0.45);
 if (look_c) {
  // sea-glass: lighter and greener, so the dark supports standing in it stay readable.
  water = vec3(0.30, 0.58, 0.58) + swell * 0.014 + ripple * 0.005;
  ALBEDO = mix(water, vec3(0.60, 0.76, 0.74), horizon * 0.5);
 }
 ROUGHNESS = 0.94;
 SPECULAR = 0.0;
}
