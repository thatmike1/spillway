shader_type spatial;
render_mode unshaded, cull_disabled;
// original calm dock water; narrow broken reflections replace the broad graphic wave blobs.
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float ripple=sin(p.y*3.8+p.x*0.32+TIME*0.32)+0.32*sin(p.y*7.1-p.x*0.65-TIME*0.23);
 float fade=1.0-smoothstep(35.0,180.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 col=mix(vec3(0.22,0.43,0.45),vec3(0.31,0.51,0.50),smoothstep(-0.8,1.1,ripple)*0.65);
 float broken=smoothstep(0.0,0.7,sin(p.x*0.24+sin(p.y*0.7)));
 float glint=smoothstep(1.13,1.25,ripple)*broken*fade;
 col=mix(col,vec3(0.64,0.72,0.65),glint*0.28);
 float horizon=pow(1.0-max(dot(normalize(CAMERA_POSITION_WORLD-wp),vec3(0,1,0)),0.0),5.0);
 ALBEDO=mix(col,vec3(0.52,0.67,0.65),horizon*0.62);
}
