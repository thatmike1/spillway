shader_type canvas_item;
// p / peripheral speed lines and moment washes, drawn over the 3d view only near the frame edge.
uniform float amount = 0.0;           // 0 rest .. 1 the designed top speed band
uniform float burst = 0.0;            // short extra density for a takeoff or a rope release
uniform float clock = 0.0;            // presentation seconds; motion of the lines, not gameplay time
uniform vec2 pixels = vec2(1920.0, 1080.0);
uniform vec4 line_color : source_color = vec4(0.91, 0.87, 0.74, 1.0);
uniform vec4 ink_color : source_color = vec4(0.035, 0.065, 0.070, 1.0);
uniform vec4 wash_color : source_color = vec4(0.91, 0.87, 0.74, 1.0);
uniform float wash = 0.0;             // checkpoint / finish edge wash, 0..1
uniform vec2 wash_bias = vec2(0.0);   // screen direction the wash leans toward (a rope anchor)
uniform vec4 frame_color : source_color = vec4(0.85, 0.36, 0.19, 1.0);
uniform float frame = 0.0;            // thin inset frame line, 0..1

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 px = UV * pixels;
	vec2 centre = pixels * vec2(0.5, 0.46);
	vec2 d = px - centre;
	// normalise so the screen corners sit near 1.0 at any aspect.
	float r = length(d) / length(pixels * 0.5);
	float angle = atan(d.y, d.x);
	float a = clamp(amount + burst, 0.0, 1.4);
	// keep the lower centre (the deck ahead, where landings are read) free of lines.
	float down = dot(normalize(d + vec2(0.0001)), vec2(0.0, 1.0));
	float ground_clear = 1.0 - smoothstep(0.35, 0.80, down);
	float band = smoothstep(0.48 - 0.10 * a, 0.86, r) * ground_clear;
	const float BINS = 150.0;
	float cell = angle / 6.2831853 * BINS;
	float id = floor(cell);
	float seed = hash(id);
	// sparse: a bin carries a line only when its seed falls under the density.
	float live = step(seed, 0.14 + 0.36 * a);
	float rate = 0.55 + 0.9 * hash(id + 7.0);
	float phase = fract(clock * rate * (0.6 + 0.8 * a) + hash(id + 3.0));
	float head = mix(0.55, 1.25, phase);
	float len = 0.08 + 0.22 * a * (0.5 + hash(id + 11.0));
	float along = smoothstep(head - len, head - len * 0.4, r) * (1.0 - smoothstep(head - 0.01, head, r));
	// distance to the bin's centre ray in pixels keeps the stroke about one pixel at any size.
	float offset_px = (fract(cell) - 0.5) / BINS * 6.2831853 * length(d);
	float sw = max(1.0, pixels.y / 900.0);
	float core = 1.0 - smoothstep(0.35 * sw, 1.05 * sw, abs(offset_px));
	float shade = 1.0 - smoothstep(0.35 * sw, 1.05 * sw, abs(offset_px - 1.4 * sw));
	float strength = live * along * band * smoothstep(0.0, 0.15, a);
	float line_alpha = strength * core * (0.42 + 0.35 * a);
	float ink_alpha = strength * shade * (1.0 - core) * (0.22 + 0.16 * a);
	vec4 col = vec4(ink_color.rgb, ink_alpha);
	col = mix(col, vec4(line_color.rgb, line_alpha), step(ink_alpha, line_alpha));
	// moment wash: soft light from the frame edge inward, leaning toward wash_bias.
	vec2 ndc = (UV - 0.5) * 2.0;
	float lean = 1.0 + 0.8 * max(dot(normalize(ndc + vec2(0.0001)), wash_bias), 0.0) * length(wash_bias);
	float edge = smoothstep(0.55, 1.15, r * lean) * ground_clear;
	float wash_alpha = wash * edge * 0.30;
	col = mix(col, vec4(wash_color.rgb, max(col.a, wash_alpha)), step(col.a, wash_alpha));
	// thin inset frame eighteen pixels in: a coloured core between two hairline ink edges, so it
	// reads over a pale deck and a dark wall alike. wash_bias also leans it toward a rope anchor.
	vec2 inset = min(px, pixels - px);
	float rim = min(inset.x, inset.y);
	float lean_frame = mix(1.0, clamp(dot(normalize(ndc + vec2(0.0001)), normalize(wash_bias + vec2(0.0001))) * 1.6 - 0.2, 0.0, 1.0), clamp(length(wash_bias) * 2.0, 0.0, 1.0));
	float f = frame * lean_frame * ground_clear;
	float w = max(1.0, pixels.y / 900.0);
	float frame_core = (1.0 - smoothstep(0.9 * w, 1.7 * w, abs(rim - 18.0 * w))) * f * 0.9;
	float frame_ink = (1.0 - smoothstep(0.4 * w, 0.9 * w, abs(abs(rim - 18.0 * w) - 2.2 * w))) * f * 0.7;
	col = mix(col, vec4(ink_color.rgb, frame_ink), step(col.a, frame_ink));
	col = mix(col, vec4(frame_color.rgb, frame_core), step(col.a, frame_core));
	COLOR = col;
}
