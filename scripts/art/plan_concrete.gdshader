shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// original yard treatment; existing mathematical wear supplies porous patches and rain runs.
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plaster : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float top_y = 3.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec2 wall=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float pores=texture(wear,wall/vec2(4.0,5.0)).r;
 float runs=texture(wear,wall/vec2(0.9,16.0)).g;
 float patches=smoothstep(0.43,0.64,pores);
 vec3 concrete=mix(vec3(0.22,0.34,0.35),vec3(0.49,0.49,0.40),patches*0.16);
 concrete*=mix(0.97,1.01,smoothstep(0.3,0.7,runs));
 float grain=dot(texture(plaster,wall/3.0).rgb,vec3(0.2126,0.7152,0.0722));
 concrete*=0.82+grain*0.65;
 concrete*=mix(0.72,1.0,smoothstep(-4.0,-0.5,wp.y));
 // coping shows the roof thickness from below without pretending its top is already visible.
 float coping=smoothstep(top_y-0.52,top_y-0.49,wp.y);
 concrete=mix(concrete,vec3(0.73,0.70,0.65),coping);
 float rim=smoothstep(top_y-0.14,top_y-0.12,wp.y);
 concrete=mix(concrete,vec3(0.63,0.28,0.12),rim);
 vec3 top=vec3(0.69,0.67,0.64)*(0.96+texture(wear,wp.xz/15.0).g*0.07);
 vec2 cell=abs(fract(wp.xz/vec2(5.0,9.0)+0.5)-0.5)*vec2(5.0,9.0);
 vec2 aa=max(fwidth(wp.xz),vec2(0.004));
 float joint=1.0-min(smoothstep(0.02-aa.x,0.02+aa.x,cell.x),smoothstep(0.02-aa.y,0.02+aa.y,cell.y));
 // joints stay quiet so only real deck edges read as gaps.
 top=mix(top,vec3(0.26,0.34,0.34),joint*0.2);
 ALBEDO=mix(concrete,top,smoothstep(0.65,0.92,wn.y));
 ROUGHNESS=0.95;
 SPECULAR=0.0;
}
