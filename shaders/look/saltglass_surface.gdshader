shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform bool surf = false;
uniform float crest = 18.0;
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 // the 56 degree running face has an upward normal of 0.555; undersides stay dark.
 float face = smoothstep(0.35, 0.52, world_normal.y);
 float grain = texture(wear, world_position.xz / 17.0).g;
 vec2 side_uv = abs(world_normal.x) > abs(world_normal.z) ? world_position.zy : world_position.xy;
 float scuff = texture(wear, side_uv / 3.0).r;
 float tide = 1.0 - smoothstep(-4.0, 1.0, world_position.y);
 vec3 side = mix(vec3(0.20, 0.32, 0.33), vec3(0.12, 0.22, 0.23), tide);
 vec3 cap = surf ? vec3(0.81, 0.86, 0.79) : vec3(0.93, 0.88, 0.75);
 side = mix(side, vec3(0.42, 0.43, 0.36), smoothstep(0.60, 0.80, scuff) * 0.24);
 if (surf) {
  cap = mix(vec3(0.62, 0.76, 0.73), cap, smoothstep(1.0, 15.0, world_position.y));
 }
 cap *= 0.96 + grain * 0.08;
 ALBEDO = mix(side, cap, face);
 // ink is part of the face material, not a second crest mesh or a collision lip.
 if (surf) {
  float edge = min(abs(world_position.y - crest), abs(world_position.y - (crest - 18.0)));
  float ink = 1.0 - smoothstep(0.025, 0.065, edge);
  float joint = abs(mod(world_position.z + 10.5, 21.0) - 10.5);
  float seam = 1.0 - smoothstep(0.015, 0.045, joint);
  ALBEDO = mix(ALBEDO, vec3(0.09, 0.15, 0.16), max(ink, seam * 0.22) * face);
 }
 ROUGHNESS = 0.96;
 SPECULAR = 0.0;
}
