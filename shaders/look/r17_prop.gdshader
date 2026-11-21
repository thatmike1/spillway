shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform sampler2D original : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 top_color : source_color = vec4(0.89,0.86,0.76,1.0);
uniform vec4 side_color : source_color = vec4(0.23,0.38,0.40,1.0);
varying vec3 world_normal;
varying float topness;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float tone=dot(texture(original,UV).rgb,vec3(0.2126,0.7152,0.0722));
 float up=smoothstep(0.30,0.50,world_normal.y);
 ALBEDO=mix(side_color.rgb*(0.3+0.7*tone),top_color.rgb*(0.98+0.02*tone),up);
 ROUGHNESS=1.0; SPECULAR=0.0;
 topness=up;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=mix(0.48,0.82,smoothstep(-0.1,0.02,facing));
 band=mix(band,1.0,smoothstep(0.65,0.72,facing));
 DIFFUSE_LIGHT+=ALBEDO*band*ATTENUATION*LIGHT_COLOR/PI;
 float sun_value=dot(LIGHT_COLOR,vec3(0.2126,0.7152,0.0722));
 vec3 shade_albedo=mix(ALBEDO,vec3(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))),0.5);
 DIFFUSE_LIGHT+=shade_albedo*vec3(0.70,0.84,1.0)*0.35*topness*(1.0-ATTENUATION)*step(0.0,facing)*float(LIGHT_IS_DIRECTIONAL)*sun_value/PI;
}
