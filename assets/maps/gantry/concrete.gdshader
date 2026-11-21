shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// world-scale wear follows casting joints rather than repeating orange freckles.
uniform vec4 top_color : source_color = vec4(0.84,0.81,0.73,1.0);
uniform vec4 side_color : source_color = vec4(0.32,0.44,0.46,1.0);
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_amount = 0.35;
uniform float deck = 1.0;
uniform float joint_pitch = 4.5;
uniform float waterline = -4.05;
uniform vec4 wear_color : source_color = vec4(0.53,0.56,0.51,1.0);
// design 1121: 0 keeps the delivered look; 1 adds broad sun-bleached patches, darker soffits, lifted shade.
uniform float weather = 0.0;
// design 1121: lifts tops only, for basins whose light leaves the cap below the deck-value target.
uniform float top_gain = 1.0;
// design 1121: moves the deck joint grid, e.g. off a course's centre line.
uniform vec2 joint_shift = vec2(0.0);
varying vec3 wp;
varying vec3 wn;
void vertex(){
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float top=smoothstep(0.65,0.92,wn.y);
 vec2 uv=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float patch=texture(wear,uv/vec2(1.4,5.0)).r;
 float seam=abs(mod(uv.x+joint_pitch*0.5,joint_pitch)-joint_pitch*0.5);
 float edge=1.0-smoothstep(0.025,0.095,seam);
 float runoff=(1.0-smoothstep(0.10,0.55,seam))*texture(wear,uv/vec2(0.7,8.0)).g;
 float fade=1.0-smoothstep(30.0,110.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 side=mix(side_color.rgb,wear_color.rgb,edge*smoothstep(0.48,0.53,patch)*wear_amount);
 side*=1.0-0.13*runoff*fade;
 float streak=smoothstep(0.50,0.72,texture(wear,uv/vec2(1.1,9.0)).g);
 side=mix(side,wear_color.rgb,weather*0.30*streak*fade);
 side*=1.0-weather*0.38*(1.0-smoothstep(-0.8,-0.3,wn.y));
 side*=mix(0.72,1.0,smoothstep(waterline-0.55,waterline+0.55,wp.y));
 side*=1.0-0.12*(1.0-smoothstep(0.012,0.045,abs(wp.y-3.2)));
 float grain=texture(wear,wp.xz/1.3).g;
 float wash=texture(wear,wp.xz/17.0).r;
 vec3 cap=top_color.rgb*(0.935+grain*0.065+wash*0.025);
 // weathered tops carry a few crisp-edged stains, not broad soft blotches.
 float stain=smoothstep(0.71,0.74,texture(wear,wp.xz/2.6).r);
 cap*=1.0-weather*(0.05*stain+0.035*grain);
 cap*=top_gain;
 vec2 joint=abs(mod(wp.xz+vec2(2.25)+joint_shift,vec2(4.5))-vec2(2.25));
 cap*=1.0-deck*0.14*(1.0-smoothstep(0.012,0.04,min(joint.x,joint.y)));
 ALBEDO=mix(side,cap,top);
 ROUGHNESS=0.98;
 SPECULAR=0.0;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=mix(mix(0.48,0.62,weather),0.82,smoothstep(-0.1,0.02,facing));
 band=mix(band,1.0,smoothstep(0.65,0.72,facing));
 DIFFUSE_LIGHT+=ALBEDO*band*ATTENUATION*LIGHT_COLOR/PI;
}
