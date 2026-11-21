shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// p / one wind-carried fleck, stretched along its motion relative to the runner.
uniform vec4 color : source_color = vec4(0.93, 0.90, 0.80, 1.0);
uniform float strength = 0.0;
varying float fade;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(world, CAMERA_POSITION_WORLD);
	// fade in past the near plane, out before the wrapping box edge so nothing pops.
	fade = smoothstep(1.2, 3.0, dist) * (1.0 - smoothstep(7.5, 11.0, dist)) * INSTANCE_CUSTOM.a;
}
void fragment() {
	// a soft taper at both ends of the stroke.
	float tip = 1.0 - smoothstep(0.25, 0.5, abs(UV.x - 0.5));
	float side = 1.0 - smoothstep(0.15, 0.5, abs(UV.y - 0.5));
	// nothing in the lower centre third of the screen, where the next landing is read.
	vec2 screen = FRAGCOORD.xy / VIEWPORT_SIZE;
	float clear_ = 1.0 - (1.0 - smoothstep(0.18, 0.30, abs(screen.x - 0.5))) * smoothstep(0.48, 0.60, screen.y);
	ALBEDO = color.rgb;
	ALPHA = clamp(strength * fade * tip * side * clear_, 0.0, 0.85);
}
