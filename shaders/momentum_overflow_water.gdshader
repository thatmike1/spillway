shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// p / overflow art pass water: deep still water that takes its brightness from the sky's
// reflection rather than its own albedo, and a falling or released sheet whose foam streaks
// run along the plane's UV v (the flow) in metres. original procedural work.

uniform vec3 deep : source_color = vec3(0.05, 0.11, 0.105);
uniform vec3 shallow : source_color = vec3(0.12, 0.2, 0.17);
uniform vec3 foam_color : source_color = vec3(0.86, 0.88, 0.84);
// 0 still water; above 0 a sheet whose foam streaks move this many m/s along +v.
uniform float flow_speed = 0.0;
// metres covered by UV 0..1 on the plane (x across, y along the flow).
uniform vec2 sheet_size = vec2(10.0, 50.0);
// share of a sheet covered by foam, and how much of it is churned near v = 0.
uniform float foam_amount : hint_range(0.0, 1.0) = 0.0;
uniform float churn : hint_range(0.0, 1.0) = 0.0;
// p / white water between the streaks: an aerated sheet is mostly foam, not clear water.
uniform float aeration : hint_range(0.0, 1.0) = 0.0;
// still water ripples: metres per wave and normal strength.
uniform float ripple_scale = 6.0;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.25;
uniform float drift = 0.15;

varying vec3 wpos;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (flow_speed <= 0.0) {
		// still water: two drifting ripple fields; detail fades with distance so the far
		// surface is a calm mirror of the sky instead of sparkle.
		vec2 p = wpos.xz / ripple_scale;
		float fade = 1.0 - smoothstep(30.0, 160.0, length(VERTEX));
		float t = TIME * drift;
		float e = 0.08;
		float h0 = noise21(p + vec2(t, t * 0.6)) + noise21(p * 2.3 - vec2(t * 0.7, -t)) * 0.5;
		float hx = noise21(p + vec2(e, 0.0) + vec2(t, t * 0.6)) + noise21((p + vec2(e, 0.0)) * 2.3 - vec2(t * 0.7, -t)) * 0.5;
		float hz = noise21(p + vec2(0.0, e) + vec2(t, t * 0.6)) + noise21((p + vec2(0.0, e)) * 2.3 - vec2(t * 0.7, -t)) * 0.5;
		vec3 bend = vec3(h0 - hx, 0.0, h0 - hz) / e * ripple_strength * 0.12 * fade;
		vec3 wn = normalize(vec3(0.0, 1.0, 0.0) + bend);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		float tone = noise21(wpos.xz / 40.0);
		ALBEDO = mix(deep, shallow, tone * 0.5);
		ROUGHNESS = mix(0.16, 0.05, 1.0 - fade);
		SPECULAR = 0.5;
		METALLIC = 0.0;
	} else {
		// a sheet: foam streaks stretched along the flow, sliding at flow_speed, with a
		// churned band near the source and darker green water showing between streaks.
		vec2 m = UV * sheet_size;
		float t = TIME * flow_speed;
		float streak = noise21(vec2(m.x * 1.6, (m.y - t) * 0.12)) * 0.55 + noise21(vec2(m.x * 4.1, (m.y - t * 1.3) * 0.35)) * 0.45;
		float churned = churn * (1.0 - smoothstep(0.0, 0.35, UV.y));
		float cover = smoothstep(1.0 - foam_amount - churned, 1.0 - foam_amount * 0.4, streak + churned * 0.4);
		// streaks thin out toward the plane's sides.
		cover *= smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
		vec3 water = mix(mix(deep, shallow, 0.7), foam_color * 0.8, aeration);
		ALBEDO = mix(water, foam_color, cover);
		ROUGHNESS = mix(0.12, 0.7, cover);
		SPECULAR = 0.5;
		METALLIC = 0.0;
		float ripple = noise21(vec2(m.x * 3.0, (m.y - t) * 0.8)) - 0.5;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple * 0.15, 0.0, 0.0, 0.0)).xyz);
	}
}
