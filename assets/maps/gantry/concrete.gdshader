shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// world-scale wear follows casting joints rather than repeating orange freckles.
uniform vec4 top_color : source_color = vec4(0.84,0.81,0.73,1.0);
uniform vec4 side_color : source_color = vec4(0.32,0.44,0.46,1.0);
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_amount = 0.35;
uniform float deck = 1.0;
varying vec3 wp;
varying vec3 wn;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float top=smoothstep(0.65,0.92,wn.y);
 vec2 uv=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float patch=texture(wear,uv/vec2(9.0,18.0)).r;
 float runoff=texture(wear,uv/vec2(1.4,24.0)).g;
 float fade=1.0-smoothstep(30.0,110.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 side=mix(side_color.rgb,vec3(0.53,0.56,0.51),smoothstep(0.46,0.72,patch)*wear_amount);
 side*=1.0-0.10*runoff*fade;
 side*=mix(0.72,1.0,smoothstep(-4.6,-3.5,wp.y));
 side*=1.0-0.12*(1.0-smoothstep(0.012,0.045,abs(wp.y-3.2)));
 float grain=texture(wear,wp.xz/17.0).g;
 vec3 cap=top_color.rgb*(0.97+grain*0.035);
 ALBEDO=mix(side,cap,top);
 ROUGHNESS=0.98;
 SPECULAR=0.0;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=mix(0.48,0.82,smoothstep(-0.1,0.02,facing));
 band=mix(band,1.0,smoothstep(0.65,0.72,facing));
 DIFFUSE_LIGHT+=ALBEDO*band*ATTENUATION*LIGHT_COLOR/PI;
}
