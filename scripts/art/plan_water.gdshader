shader_type spatial;
render_mode unshaded, cull_disabled;
// irregular horizontal strokes and soft sky glints retain water at the open horizon.
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wp;
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 noise=texture(wear,wp.xz/20.0+vec2(TIME*0.003,-TIME*0.002)).rg;
 float broad=sin(wp.x*0.13+noise.r*2.5+TIME*0.12);
 float wave=sin(wp.z*1.8+sin(wp.x*0.4)*0.8+noise.r*2.0+TIME*0.6);
 wave+=sin(wp.z*3.7+wp.x*0.1-TIME*0.7)*0.15;
 float fade=1.0-smoothstep(45.0,180.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 water=mix(vec3(0.14,0.32,0.34),vec3(0.23,0.45,0.46),(broad*0.5+0.5)*0.45+noise.g*0.25);
 float width=max(fwidth(wave),0.025);
 float stroke=smoothstep(0.78-width,0.98+width,wave)*fade;
 water=mix(water,vec3(0.43,0.60,0.57),stroke*0.32);
 vec3 view=normalize(CAMERA_POSITION_WORLD-wp);
 vec3 normal=normalize(vec3((noise.r-0.5)*0.15,1.0,wave*0.045));
 float glint=pow(max(dot(reflect(-view,normal),normalize(vec3(0.25,0.12,-0.9))),0.0),24.0);
 water=mix(water,vec3(0.65,0.62,0.45),glint*0.34*fade);
 float horizon=pow(1.0-max(view.y,0.0),6.0);
 ALBEDO=mix(water,vec3(0.32,0.47,0.46),horizon*0.25);
}
