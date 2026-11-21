shader_type spatial;
render_mode unshaded, cull_disabled;
// look C water: bright sea-glass, so supports standing in it stay readable. value scales the whole sea
// for dim maps (night); shallow lifts pools and sheets toward their pale floor colour. waves come from
// two drifting layers of soft noise, so no regular tile repeats and distance settles through mipmaps.
uniform sampler2D noise : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec4 deep_color : source_color = vec4(0.17,0.46,0.49,1.0);
uniform vec4 lit_color : source_color = vec4(0.31,0.63,0.62,1.0);
uniform vec4 glint_color : source_color = vec4(0.82,0.89,0.81,1.0);
uniform vec4 horizon_color : source_color = vec4(0.55,0.72,0.71,1.0);
uniform float value = 1.0;
uniform float shallow = 0.0;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float broad=texture(noise,p/vec2(61.0,37.0)+vec2(TIME*0.004,TIME*0.002)).r;
 float chop=texture(noise,p/vec2(13.0,5.5)+vec2(-TIME*0.011,TIME*0.006)).g;
 float wave=broad*0.6+chop*0.4;
 float distance_fade=1.0-smoothstep(40.0,220.0,distance(wp,CAMERA_POSITION_WORLD));
 vec3 col=mix(deep_color.rgb,lit_color.rgb,smoothstep(0.30,0.70,wave));
 col=mix(col,lit_color.rgb*1.18,shallow*0.55);
 // sparse glints: elongated across the view like painted strokes.
 col=mix(col,glint_color.rgb,smoothstep(0.70,0.78,chop)*smoothstep(0.45,0.65,broad)*0.55*distance_fade);
 float horizon=pow(1.0-max(dot(normalize(CAMERA_POSITION_WORLD-wp),vec3(0,1,0)),0.0),5.0);
 ALBEDO=mix(col,horizon_color.rgb,horizon*0.6)*value;
}
