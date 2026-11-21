shader_type sky;
render_mode use_debanding;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
void sky() {
 vec2 uv=SKY_COORDS;
 vec3 painted=texture(panorama,uv).rgb;
 // feather opposite edge strips into the same value at the panorama wrap.
 float edge=min(uv.x,1.0-uv.x);
 vec3 opposite=texture(panorama,vec2(1.0-uv.x,uv.y)).rgb;
 COLOR=mix(painted,opposite,0.5*(1.0-smoothstep(0.0,0.04,edge)));
}
