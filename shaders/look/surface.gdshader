shader_type spatial;
render_mode diffuse_toon, specular_disabled;
// look C surface: calm pale deck, darker weathered side, darkest underside. docs/look-language.md has the values.
uniform vec4 top_color : source_color = vec4(0.89,0.86,0.76,1.0);
uniform vec4 side_color : source_color = vec4(0.23,0.38,0.40,1.0);
uniform sampler2D wear : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_amount = 0.35;
uniform float deck = 0.0;
uniform float metal = 0.0;
// faces from top_from to top_full (world normal y) blend into the deck, so walkable slopes stay pale.
uniform float top_from = 0.30;
uniform float top_full = 0.50;
uniform vec4 chip_color : source_color = vec4(0.78,0.71,0.58,1.0);
uniform float streak_amount = 0.10;
uniform float underside = 0.62;
uniform float deck_mottle = 0.02;
// tops in shadow stay pale and cool instead of dropping to the side value: the readability rule.
uniform float shade_lift = 0.35;
uniform vec4 shade_tint : source_color = vec4(0.70,0.84,1.0,1.0);
varying vec3 wp;
varying vec3 wn;
varying float topness;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
 float top=smoothstep(top_from,top_full,wn.y);
 float along=abs(wn.x)>abs(wn.z)?wp.z:wp.x;
 vec2 uv=vec2(along,wp.y);
 float farfade=1.0-smoothstep(22.0,85.0,distance(wp,CAMERA_POSITION_WORLD));
 // localized pale paint loss, larger and calmer than grain.
 // paint loss runs down the face like the streaks: tall, soft-edged and faint, never round spots.
 float w=texture(wear,uv/vec2(2.2,9.0)).r;
 float chips=smoothstep(0.70,0.84,w)*wear_amount*0.5*mix(0.35,1.0,farfade);
 // broad tonal variation, metres across, so a big face reads as weathered material and never as one flat tone.
 float tone=texture(wear,uv/vec2(11.0,7.0)).g;
 // vertical weathering: runoff streaks stretched down the face, darker toward the foot.
 float s=texture(wear,vec2(along/7.0,wp.y/48.0)).b;
 float runoff=smoothstep(0.45,0.80,s)*streak_amount*mix(0.4,1.0,farfade);
 vec3 side=side_color.rgb*(1.0-runoff)*(0.93+0.14*tone);
 // chips lift toward a lighter, warmer version of the side itself, so dark maps never read as camouflage.
 side=mix(side,mix(side_color.rgb*1.5,chip_color.rgb,0.35),chips);
 side*=1.0-0.12*(1.0-smoothstep(-2.8,-1.1,wp.y));
 float ribs=pow(0.5+0.5*cos(along*24.0),6.0);
 side*=1.0-metal*ribs*0.13*farfade;
 side*=mix(underside,1.0,smoothstep(-0.55,-0.25,wn.y));
 float grain=texture(wear,wp.xz/17.0).g;
 float mottle=texture(wear,wp.xz/53.0).b;
 vec3 cap=top_color.rgb*(0.985+grain*0.02+(mottle-0.5)*deck_mottle);
 // seams sit at x = 4+8k, z = 16+32k, off the x = 0 axis most courses start along.
 vec2 cell=abs(fract(wp.xz/vec2(8.0,32.0))-0.5)*vec2(8.0,32.0);
 vec2 aa=max(fwidth(wp.xz),vec2(0.004));
 float seam=1.0-min(smoothstep(0.012-aa.x,0.012+aa.x,cell.x),smoothstep(0.012-aa.y,0.012+aa.y,cell.y));
 cap=mix(cap,vec3(0.38,0.43,0.41),seam*0.28*deck*farfade);
 ALBEDO=mix(side,cap,top); ROUGHNESS=0.95; SPECULAR=0.0;
 topness=top;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=mix(0.48,0.82,smoothstep(-0.1,0.02,facing));
 band=mix(band,1.0,smoothstep(0.65,0.72,facing));
 DIFFUSE_LIGHT+=ALBEDO*band*ATTENUATION*LIGHT_COLOR/PI;
 // a shadowed top keeps part of the sun it lost, cooled: pale decks stay pale in shade.
 // the lift takes only the sun's brightness, not its warmth, and greys the deck a little: shade reads cool.
 float sun_value=dot(LIGHT_COLOR,vec3(0.2126,0.7152,0.0722));
 vec3 shade_albedo=mix(ALBEDO,vec3(dot(ALBEDO,vec3(0.2126,0.7152,0.0722))),0.5);
 DIFFUSE_LIGHT+=shade_albedo*shade_tint.rgb*shade_lift*topness*(1.0-ATTENUATION)*step(0.0,facing)*float(LIGHT_IS_DIRECTIONAL)*sun_value/PI;
}
