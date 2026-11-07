shader_type sky;
// p / overflow art pass sky: a deep zenith, a warm hazy horizon toward the sun and a cooler
// one away from it, a soft sun disc and a few static high cloud bands. static (no TIME), so
// the ambient radiance is computed once. original procedural work.

uniform vec3 zenith : source_color = vec3(0.22, 0.4, 0.66);
uniform vec3 horizon_warm : source_color = vec3(0.9, 0.82, 0.68);
uniform vec3 horizon_cool : source_color = vec3(0.64, 0.74, 0.82);
uniform vec3 ground : source_color = vec3(0.24, 0.25, 0.2);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.95, 0.88);
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.18;
uniform float sun_size = 0.9997;
uniform float sun_glow = 0.22;

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

void sky() {
	vec3 d = EYEDIR;
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 0.5, 0.86);
	float toward = clamp(dot(normalize(d.xz + 1e-4), normalize(sun_dir.xz + 1e-4)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 horizon = mix(horizon_cool, horizon_warm, toward * toward);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(horizon, zenith, pow(up, 0.55));
	if (d.y < 0.0) {
		c = mix(horizon, ground, smoothstep(0.0, 0.25, -d.y));
	}
	// high cloud: streaks projected onto a far plane, thinning near the horizon.
	if (d.y > 0.02 && cloud_amount > 0.0) {
		// p / a flat cloud deck: direction scaled to where it meets a plane, so bands keep
		// their width across the sky instead of fanning out from the zenith.
		vec2 q = d.xz / max(d.y, 0.05) * 0.9;
		float f = noise21(q * vec2(0.5, 1.6)) * 0.65 + noise21(q * vec2(1.3, 3.1) + 3.0) * 0.35;
		float cloud = smoothstep(1.0 - cloud_amount, 1.05 - cloud_amount * 0.5, f) * smoothstep(0.02, 0.2, d.y);
		vec3 lit = mix(cloud_color * 0.85, cloud_color * 1.1, toward);
		c = mix(c, lit, cloud * 0.45);
	}
	float s = dot(d, sun_dir);
	c += vec3(1.0, 0.85, 0.6) * pow(max(s, 0.0), 12.0) * sun_glow;
	if (LIGHT0_ENABLED) {
		c += vec3(1.0, 0.92, 0.8) * smoothstep(sun_size, sun_size + 0.00015, s) * 6.0;
	}
	COLOR = c;
}
