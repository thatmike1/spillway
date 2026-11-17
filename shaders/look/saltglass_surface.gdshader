shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform bool surf = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 // the 56 degree running face has an upward normal of 0.555; undersides stay dark.
 float face = smoothstep(0.35, 0.52, world_normal.y);
 float grain = sin(world_position.x * 2.4 + sin(world_position.z * 3.1)) * 0.012;
 float tide = 1.0 - smoothstep(-4.0, 1.0, world_position.y);
 vec3 side = mix(vec3(0.20, 0.32, 0.33), vec3(0.12, 0.22, 0.23), tide);
 vec3 cap = surf ? vec3(0.81, 0.86, 0.79) : vec3(0.93, 0.88, 0.75);
 ALBEDO = mix(side, cap + grain, face);
 ROUGHNESS = 0.96;
 SPECULAR = 0.0;
}
