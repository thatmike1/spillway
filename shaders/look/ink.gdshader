shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=vec3(0.035,0.065,0.070); ALPHA=0.78*(1.0-smoothstep(28.0,95.0,distance(wp,CAMERA_POSITION_WORLD)));}
