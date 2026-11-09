shader_type spatial;
render_mode unshaded;
uniform vec4 base_color : source_color = vec4(0.5,0.6,0.65,1.0);
varying vec3 world_normal;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 n=normalize(world_normal);
 float band=abs(n.x)>0.7?0.78:1.0;
 if(n.y < -0.7){band=0.88;}
 if(n.y > 0.7){band=1.08;}
 ALBEDO=base_color.rgb*band;
}
