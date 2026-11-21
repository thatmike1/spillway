shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform bool surf = false;
uniform float crest = 18.0;
uniform bool pan = false;
uniform vec4 pan_bounds = vec4(0.0);
// look c (L on): shell-white decks and faces, salt-white pans, lighter weathered sides.
uniform bool look_c = false;
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
 vec3 side = look_c ? mix(vec3(0.36, 0.48, 0.53), vec3(0.22, 0.32, 0.37), tide) : mix(vec3(0.24, 0.35, 0.41), vec3(0.17, 0.26, 0.31), tide);
 vec3 cap = surf ? vec3(0.81, 0.86, 0.79) : vec3(0.93, 0.88, 0.75);
 if (look_c) {
  // one warm shell-white family with the salt pans, so quays and pans read as one works.
  cap = vec3(0.93, 0.90, 0.84);
 }
 if (look_c) {
  // look c: wear runs down from the edges as soft vertical streaks, never round olive spots.
  float runoff = texture(wear, side_uv / vec2(2.2, 11.0) + 0.21).r;
  side = mix(side, side * vec3(0.84, 0.88, 0.90), smoothstep(0.50, 0.80, runoff) * 0.55);
 } else {
  side = mix(side, vec3(0.42, 0.43, 0.36), smoothstep(0.60, 0.80, scuff) * 0.24);
 }
 if (surf) {
  if (look_c) {
   // the face reads as a slope: pale at the crest, sea-glass at the wet toe.
   cap = mix(vec3(0.55, 0.70, 0.69), cap, smoothstep(0.5, 11.0, world_position.y));
  } else {
   cap = mix(vec3(0.62, 0.76, 0.73), cap, smoothstep(1.0, 15.0, world_position.y));
  }
 }
 cap *= 0.96 + grain * 0.08;
 if (pan) {
  vec2 edge_distance = min(world_position.xz - pan_bounds.xy, pan_bounds.zw - world_position.xz);
  float bed = smoothstep(0.32, 0.52, min(edge_distance.x, edge_distance.y));
  vec2 crystal = abs(fract(world_position.xz / vec2(1.7, 2.3) + grain * 0.15) - 0.5);
  float crust = smoothstep(0.37, 0.49, max(crystal.x, crystal.y));
  if (look_c) {
   // look c: crust is an irregular bloom from the wear texture, not a regular grid.
   crust = smoothstep(0.55, 0.85, texture(wear, world_position.xz / 6.0).r);
  }
  vec3 salt = look_c ? mix(vec3(0.94, 0.91, 0.86), vec3(0.98, 0.96, 0.91), crust * 0.12) : mix(vec3(0.88, 0.89, 0.79), vec3(0.98, 0.95, 0.85), crust * 0.25);
  cap = mix(look_c ? vec3(0.60, 0.67, 0.66) : vec3(0.48, 0.57, 0.56), salt, bed);
 }
 if (!surf && !pan) {
  vec2 joint_distance = abs(fract(world_position.xz / vec2(8.0, 24.0) + 0.5) - 0.5) * vec2(8.0, 24.0);
  vec2 aa_joint = max(fwidth(world_position.xz), vec2(0.004));
  float concrete_joint = 1.0 - min(smoothstep(0.012 - aa_joint.x, 0.012 + aa_joint.x, joint_distance.x), smoothstep(0.012 - aa_joint.y, 0.012 + aa_joint.y, joint_distance.y));
  cap = mix(cap, vec3(0.38, 0.43, 0.41), concrete_joint * (look_c ? 0.30 : 0.10));
  if (look_c) {
   // sparse brine stains with a crisp edge, so a broad quay is not one blank plane or a fog.
   float stain = smoothstep(0.76, 0.79, texture(wear, world_position.xz / 5.0 + 0.37).r);
   cap = mix(cap, cap * vec3(0.94, 0.945, 0.94), stain);
  }
 }
 // look c's lighter tops already sit near white under lane 02's noon light; both share this scale.
 cap *= 0.80;
 ALBEDO = mix(side, cap, face);
 // ink is part of the face material, not a second crest mesh or a collision lip.
 if (surf) {
  float edge = min(abs(world_position.y - crest), abs(world_position.y - (crest - 18.0)));
  float aa = max(fwidth(world_position.y), 0.012);
  float ink = 1.0 - smoothstep(0.10 - aa, 0.10 + aa, edge);
  float joint = abs(mod(world_position.z + 10.5, 21.0) - 10.5);
  float seam = 1.0 - smoothstep(0.015, 0.045, joint);
  float longitudinal = abs(mod(world_position.y + 2.25, 4.5) - 2.25);
  float pour_line = 1.0 - smoothstep(0.025 - aa, 0.025 + aa, longitudinal);
  ALBEDO = mix(ALBEDO, vec3(0.09, 0.15, 0.16), max(ink, max(seam * 0.22, pour_line * 0.20)) * face);
 }
 ROUGHNESS = 0.96;
 SPECULAR = 0.0;
}
void light() {
 // match the established look-c light bands instead of the default toon light response.
 float facing = dot(NORMAL, LIGHT);
 float band = mix(0.48, 0.82, smoothstep(-0.1, 0.02, facing));
 band = mix(band, 1.0, smoothstep(0.65, 0.72, facing));
 DIFFUSE_LIGHT += ALBEDO * band * ATTENUATION * LIGHT_COLOR / PI;
}
