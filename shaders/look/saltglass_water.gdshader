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
  // sparse broken ripple marks: short light dashes over darker troughs, so calm water still
  // reads as a surface out to the horizon without a repeating tile.
  vec2 cell_size = vec2(3.4, 1.1);
  vec2 p = world_position.xz / cell_size;
  p.x += sin(p.y * 1.7) * 0.6;
  vec2 cell = floor(p);
  vec2 local = fract(p) - 0.5;
  float seed = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
  float shift = fract(seed * 17.0) - 0.5;
  float dash = (1.0 - smoothstep(0.18, 0.42, abs(local.x + shift * 0.3))) * (1.0 - smoothstep(0.06, 0.2, abs(local.y)));
  float trough = (1.0 - smoothstep(0.1, 0.45, abs(local.y + 0.28))) * step(0.55, fract(seed * 7.0));
  float near = 1.0 - smoothstep(60.0, 260.0, length(CAMERA_POSITION_WORLD.xz - world_position.xz));
  water += vec3(0.07, 0.07, 0.06) * dash * step(0.72, seed) * (0.45 + 0.55 * near);
  water -= vec3(0.025, 0.03, 0.03) * trough * near;
  ALBEDO = mix(water, vec3(0.60, 0.76, 0.74), horizon * 0.5);
 }
 ROUGHNESS = 0.94;
 SPECULAR = 0.0;
}
