shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 top_color : source_color = vec4(0.89,0.86,0.76,1.0);
uniform vec4 side_color : source_color = vec4(0.23,0.38,0.40,1.0);
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_amount = 0.35;
uniform float deck = 0.0;
uniform float metal = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
 float top=smoothstep(0.65,0.92,wn.y);
 vec2 uv=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float w=texture(wear,uv/vec2(9.0,6.0)).r;
 float grain=texture(wear,wp.xz/17.0).g;
 float farfade=1.0-smoothstep(22.0,85.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 side=mix(side_color.rgb,vec3(0.61,0.66,0.61),smoothstep(0.57,0.69,w)*wear_amount);
 side*=1.0-0.12*(1.0-smoothstep(-2.8,-1.1,wp.y));
 float ribs=pow(0.5+0.5*cos((abs(wn.x)>abs(wn.z)?wp.z:wp.x)*24.0),6.0);
 side*=1.0-metal*ribs*0.13*farfade;
 vec3 cap=top_color.rgb*(0.98+grain*0.035);
 vec2 cell=abs(fract(wp.xz/vec2(6.0,8.0)+0.5)-0.5)*vec2(6.0,8.0);
 vec2 aa=max(fwidth(wp.xz),vec2(0.004));
 float seam=1.0-min(smoothstep(0.012-aa.x,0.012+aa.x,cell.x),smoothstep(0.012-aa.y,0.012+aa.y,cell.y));
 cap=mix(cap,vec3(0.38,0.43,0.41),seam*0.52*deck*farfade);
 ALBEDO=mix(side,cap,top); ROUGHNESS=0.95; SPECULAR=0.0;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=mix(0.48,0.82,smoothstep(-0.1,0.02,facing));
 band=mix(band,1.0,smoothstep(0.65,0.72,facing));
 DIFFUSE_LIGHT+=ALBEDO*band*ATTENUATION*LIGHT_COLOR/PI;
}
