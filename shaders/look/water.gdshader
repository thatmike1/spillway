shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float wave=sin(p.x*0.48+sin(p.y*0.65+TIME*0.25)*1.5+TIME*0.32)+sin(p.y*1.7-p.x*0.12-TIME*0.48)*0.45;
 float distance_fade=1.0-smoothstep(50.0,260.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 col=mix(vec3(0.18,0.40,0.43),vec3(0.30,0.57,0.57),smoothstep(-0.6,0.0,wave));
 col=mix(col,vec3(0.60,0.73,0.66),smoothstep(1.12,1.20,wave)*0.6*distance_fade);
 float horizon=pow(1.0-max(dot(normalize(CAMERA_POSITION_WORLD-wp),vec3(0,1,0)),0.0),6.0);
 ALBEDO=mix(col,vec3(0.52,0.68,0.67),horizon*0.52);
}
