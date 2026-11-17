shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// restrained exposed-metal patches keep functional gantry members darker than landing decks.
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_strength = 0.10;
varying vec3 wp;
varying vec3 wn;
void vertex() {
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec2 plane=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float patch=texture(wear,plane/vec2(3.5,4.5)).r;
 float chip=smoothstep(0.65,0.8,patch);
 vec3 paint=mix(vec3(0.13,0.22,0.24),vec3(0.27,0.30,0.29),chip*wear_strength);
 paint*=0.98+texture(wear,plane/9.0).g*0.04;
 ALBEDO=paint;
 ROUGHNESS=0.85;
 SPECULAR=0.05;
}
