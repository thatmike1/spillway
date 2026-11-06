shader_type spatial;
render_mode diffuse_burley, cull_disabled;
// p / finish bay water: the grated tailrace pit (sheet = false) and the falling head-race sheet.
// both stay in the opaque pass; the sheet's ragged edge is an alpha scissor, not blending.

uniform bool sheet = false;
uniform float flow = 0.0;
uniform float reveal = 0.0;
// open channel rectangles in world xz: min.x, min.z, max.x, max.z.
uniform vec4 slot_a = vec4(21.3, -69.45, 26.4, -68.8);
uniform vec4 slot_b = vec4(25.3, -74.0, 26.4, -69.45);
uniform vec4 deep_water : source_color = vec4(0.05, 0.16, 0.16, 1.0);
uniform vec4 lit_water : source_color = vec4(0.23, 0.47, 0.45, 1.0);
uniform vec4 foam : source_color = vec4(0.82, 0.90, 0.88, 1.0);
uniform vec4 steel : source_color = vec4(0.20, 0.24, 0.23, 1.0);

varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), t.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), t.x), t.y);
}

float inside(vec2 p, vec4 r, float soft) {
	vec2 a = smoothstep(r.xy - soft, r.xy + soft, p);
	vec2 b = 1.0 - smoothstep(r.zw - soft, r.zw + soft, p);
	return a.x * a.y * b.x * b.y;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (sheet) {
		// u across the sheet, v down it from the lip; the front of the water advances with reveal.
		float v = UV.y;
		float streak = noise21(vec2(UV.x * 9.0, v * 5.0 - TIME * 3.2));
		float fine = noise21(vec2(UV.x * 23.0, v * 13.0 - TIME * 4.4));
		float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(0.0, 0.18, 1.0 - UV.x);
		float front = (1.0 - smoothstep(reveal - 0.06, reveal, v + (fine - 0.5) * 0.05));
		float body = edge * 0.5 + streak * 0.5 + fine * 0.3;
		float white = smoothstep(0.5, 0.82, streak * 0.75 + fine * 0.35 + v * 0.1);
		ALBEDO = mix(lit_water.rgb * 1.15, foam.rgb, white);
		ALPHA = body * front;
		ALPHA_SCISSOR_THRESHOLD = 0.55;
		ROUGHNESS = 0.2;
		SPECULAR = 0.5;
	} else {
		vec2 p = world_position.xz;
		float open = max(inside(p, slot_a, 0.015), inside(p, slot_b, 0.015));
		// the slot runs east under the wheel, then south to the tower culvert.
		vec2 along = inside(p, slot_b, 0.2) > 0.5 && p.y < slot_a.y ? vec2(p.x * 5.0, p.y * 1.6 + TIME * 1.4 * flow)
			: vec2(p.x * 1.6 - TIME * 1.4 * flow, p.y * 5.0);
		float ripple = noise21(along + TIME * 0.15);
		float churn = noise21(along * 2.6 - vec2(TIME * 0.7));
		vec3 water = mix(deep_water.rgb, lit_water.rgb, ripple * (0.35 + flow * 0.4));
		// white water under the falling sheet on the wheel's east side once the gate is open.
		float spill = inside(p, vec4(24.6, -69.5, 26.4, -68.7), 0.5) * flow;
		water = mix(water, foam.rgb, clamp(spill * (churn * 1.3 - 0.15) + flow * churn * churn * 0.25, 0.0, 1.0) * open);
		// bar grating over the pit: bearing bars across the slot run, cross rods every 0.9 m.
		vec2 g = vec2(p.x / 0.11, p.y / 0.9);
		vec2 w = fwidth(g);
		float bar = smoothstep(0.32 - w.x, 0.32 + w.x, abs(fract(g.x) - 0.5));
		bar = max(bar, 1.0 - smoothstep(0.03 - w.y, 0.03 + w.y, abs(fract(g.y) - 0.5)));
		// fine bars resolve into a mid tone with distance instead of shimmering.
		float resolve = clamp(1.4 - w.x * 1.5, 0.0, 1.0);
		bar = mix(0.4, bar, resolve);
		vec3 grate = mix(water * 0.45, steel.rgb * (0.9 + noise21(p * 3.0) * 0.2), bar);
		ALBEDO = mix(grate, water, open);
		ALPHA = 1.0;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ROUGHNESS = mix(mix(0.7, 0.85, bar), 0.12, open);
		SPECULAR = mix(0.35, 0.55, open);
	}
}
