shader_type canvas_item;
// p / peripheral speed lines and moment washes, drawn over the 3d view only near the frame edge.
uniform float amount = 0.0;           // 0 rest .. 1 the designed top speed band
uniform float burst = 0.0;            // short extra density for a takeoff or a rope release
uniform float clock = 0.0;            // presentation seconds; motion of the lines, not gameplay time
uniform vec2 pixels = vec2(1920.0, 1080.0);
uniform vec2 focus = vec2(0.5, 0.46);  // where the runner is heading, in screen uv: lines radiate from it
uniform vec4 line_color : source_color = vec4(0.91, 0.87, 0.74, 1.0);
uniform vec4 ink_color : source_color = vec4(0.035, 0.065, 0.070, 1.0);
uniform vec4 wash_color : source_color = vec4(0.91, 0.87, 0.74, 1.0);
uniform float wash = 0.0;             // checkpoint / finish edge wash, 0..1
uniform vec2 wash_bias = vec2(0.0);   // screen direction the wash leans toward (a rope anchor)
uniform vec4 frame_color : source_color = vec4(0.85, 0.36, 0.19, 1.0);
uniform float frame = 0.0;            // thin inset frame line, 0..1
uniform vec2 catch_at = vec2(0.5, 0.3); // a caught rope anchor, in screen uv
uniform float catch_t = 1.0;          // 0 at the catch .. 1 done
uniform float catch_amount = 0.0;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
	vec2 px = UV * pixels;
	vec2 centre = pixels * focus;
	vec2 d = px - centre;
	// normalise so the screen corners sit near 1.0 at any aspect.
	float r = length(d) / length(pixels * 0.5);
	float angle = atan(d.y, d.x);
	float a = clamp(amount + burst, 0.0, 1.4);
	// keep the lower centre third (the deck ahead, where landings are read) free of everything.
	float middle = 1.0 - smoothstep(0.18, 0.30, abs(UV.x - 0.5));
	float ground_clear = 1.0 - middle * smoothstep(focus.y + 0.02, focus.y + 0.14, UV.y);
	// lines stay off the decks below the horizon except in a thin strip at the far sides.
	float deck = smoothstep(focus.y + 0.10, focus.y + 0.22, UV.y) * (1.0 - smoothstep(0.40, 0.46, abs(UV.x - 0.5)));
	float line_clear = ground_clear * (1.0 - deck);
	float band = smoothstep(0.48 - 0.10 * a, 0.86, r) * line_clear;
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
	// rope catch: a ring of short strokes drawn in onto the anchor, so the world reads as pulled
	// toward the rope. distinct from the outward speed lines and the checkpoint frame.
	if (catch_amount > 0.001) {
		vec2 dc = px - pixels * catch_at;
		float rc = length(dc) / length(pixels * 0.5);
		const float CB = 16.0;
		float cc = atan(dc.y, dc.x) / 6.2831853 * CB;
		float cid = floor(cc);
		float jit = hash(cid + 21.0);
		float t = clamp(catch_t, 0.0, 1.0);
		float headc = mix(0.26, 0.05, 1.0 - (1.0 - t) * (1.0 - t)) + 0.03 * jit;
		float lenc = mix(0.08, 0.02, t);
		float alongc = smoothstep(headc - 0.004, headc + 0.008, rc) * (1.0 - smoothstep(headc + lenc * 0.5, headc + lenc, rc));
		float offc = (fract(cc) - 0.5) / CB * 6.2831853 * length(dc);
		float corec = 1.0 - smoothstep(0.45 * sw, 1.25 * sw, abs(offc));
		float shadec = 1.0 - smoothstep(0.45 * sw, 1.25 * sw, abs(offc - 1.5 * sw));
		float sc = alongc * catch_amount * step(0.22, jit) * ground_clear * pow(1.0 - t, 1.2);
		float c_line = sc * corec * 0.85;
		float c_ink = sc * shadec * (1.0 - corec) * 0.55;
		col = mix(col, vec4(ink_color.rgb, c_ink), step(col.a, c_ink));
		col = mix(col, vec4(line_color.rgb, c_line), step(col.a, c_line));
	}
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
