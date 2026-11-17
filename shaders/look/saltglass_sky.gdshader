shader_type sky;
render_mode use_debanding;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
void sky() {
 vec2 uv=SKY_COORDS;
 vec3 painted=texture(panorama,uv).rgb;
 // feather opposite edge strips into the same value at the panorama wrap.
 float edge=min(uv.x,1.0-uv.x);
 vec3 opposite=texture(panorama,vec2(1.0-uv.x,uv.y)).rgb;
 vec3 original = mix(painted,opposite,0.5*(1.0-smoothstep(0.0,0.04,edge)));
 float cloud = smoothstep(0.52, 0.83, dot(original, vec3(0.2126, 0.7152, 0.0722)));
 vec3 clear = mix(vec3(0.13, 0.34, 0.53), original, 0.30);
 COLOR = mix(clear, original, cloud);
}
