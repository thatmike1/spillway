shader_type sky;
render_mode use_debanding;
// painted sky for the current look. two modes share one shader:
//  - panorama_mix 1, card_count 0 (the defaults): the original static painted panorama, unchanged.
//  - scripts/look/sky_light.gd sets a painted gradient, a horizon band, a sun glow and painted
//    cumulus cards cut from an original atlas, recoloured per map with a lit side and a shadow side.
// cost per pixel: one gradient, up to eight card tests (a texture read only inside a card), one glow.
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float panorama_mix = 1.0;
uniform float panorama_turn = 0.0;

uniform vec3 zenith : source_color = vec3(0.16, 0.40, 0.62);
uniform vec3 upper : source_color = vec3(0.33, 0.60, 0.76);
uniform vec3 horizon : source_color = vec3(0.72, 0.82, 0.83);
uniform vec3 band : source_color = vec3(0.96, 0.86, 0.70);
uniform float band_strength = 0.5;
uniform float band_height = 0.06;
uniform vec3 below : source_color = vec3(0.55, 0.70, 0.74);

// direction toward the sun, set from the map's sun angles (not LIGHT0: the fill light may come first).
uniform vec3 sun_dir = vec3(0.0, 0.5, -0.86);
uniform vec3 glow_color : source_color = vec3(1.0, 0.88, 0.66);
uniform float glow_strength = 0.35;
uniform float glow_size = 8.0;
uniform float disc_strength = 0.0;
uniform float stars = 0.0;
uniform float brush = 0.035;

// cumulus atlas: 2x2 cells, red = painted value (dark shadow to bright lit side), alpha = coverage.
uniform sampler2D clouds : filter_linear_mipmap, repeat_disable;
// wisp atlas: four horizontal strips stacked top to bottom, same channels.
uniform sampler2D wisps : filter_linear_mipmap, repeat_disable;
uniform vec3 cloud_light : source_color = vec3(1.0, 0.95, 0.84);
uniform vec3 cloud_mid : source_color = vec3(0.86, 0.80, 0.78);
uniform vec3 cloud_shadow : source_color = vec3(0.52, 0.60, 0.72);
uniform vec3 cloud_rim : source_color = vec3(1.0, 0.85, 0.62);
uniform float cloud_contrast = 1.0;
uniform float cloud_opacity = 1.0;
uniform float cloud_haze = 0.55;
// per card: azimuth degrees (0 is -Z, clockwise seen from above), bottom elevation degrees,
// width degrees, atlas cell 0..3. cards mirror themselves so their lit side faces the sun.
uniform int card_count = 0;
uniform vec4 cards[8];
uniform float card_aspect = 1.5;
uniform int wisp_count = 0;
uniform vec4 wisp_cards[4];
uniform float wisp_aspect = 6.0;
uniform float wisp_opacity = 0.55;
uniform float drift = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 paint(float value) {
	float v = clamp((value - 0.5) * cloud_contrast + 0.5, 0.0, 1.0);
	vec3 c = mix(cloud_shadow, cloud_mid, smoothstep(0.0, 0.5, v));
	c = mix(c, cloud_light, smoothstep(0.45, 0.85, v));
	return mix(c, cloud_rim, smoothstep(0.88, 1.0, v));
}

// returns rgb in xyz and coverage in w
vec4 card(sampler2D atlas, vec4 placement, float aspect, vec2 cells, float az, float el, float cos_el, float speed) {
	float width = radians(abs(placement.z));
	float height = width / aspect;
	float d = az - radians(placement.x) - speed;
	d = mod(d + PI, TAU) - PI;
	float u = d * cos_el / width + 0.5;
	float v = 1.0 - (el - radians(placement.y)) / height;
	if (u <= 0.0 || u >= 1.0 || v <= 0.0 || v >= 1.0) {
		return vec4(0.0);
	}
	// the paintings are lit from the left: mirror a card whose sun stands to its right.
	float sun_side = mod(atan(sun_dir.x, -sun_dir.z) - radians(placement.x) - speed + PI, TAU) - PI;
	if (sun_side > 0.0) {
		u = 1.0 - u;
	}
	float cell = placement.w;
	vec2 origin = vec2(mod(cell, cells.x), floor(cell / cells.x)) / cells;
	vec4 texel = texture(atlas, origin + vec2(u, v) / cells);
	return vec4(paint(texel.r), texel.a);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float el = asin(clamp(dir.y, -1.0, 1.0));
	float az = atan(dir.x, -dir.z);
	float cos_el = max(cos(el), 0.05);
	float up = max(dir.y, 0.0);

	// painted gradient: zenith over an upper sky, easing into a pale horizon, with a soft brush grain.
	vec3 grad = mix(horizon, upper, smoothstep(0.0, 0.32, up));
	grad = mix(grad, zenith, smoothstep(0.30, 0.95, up));
	vec2 stroke = vec2(az * 3.0, el * 14.0);
	grad *= 1.0 + brush * (vnoise(stroke) + 0.5 * vnoise(stroke * 2.7) - 0.75);
	// the warm band hugs the horizon and thins upward.
	grad = mix(grad, band, band_strength * exp(-up / max(band_height, 0.001)));
	if (dir.y < 0.0) {
		grad = mix(horizon, below, smoothstep(0.0, 0.25, -dir.y));
	}

	if (stars > 0.0) {
		vec2 cell = floor(vec2(az, el) * 160.0);
		float s = step(0.996, hash(cell)) * smoothstep(0.05, 0.4, up);
		grad += vec3(s * stars * (0.5 + 0.5 * hash(cell + 7.0)));
	}

	// sun glow and an optional soft disc around the map's sun.
	{
		float facing = max(dot(dir, normalize(sun_dir)), 0.0);
		grad += glow_color * glow_strength * pow(facing, glow_size);
		grad += glow_color * glow_strength * 0.35 * pow(facing, glow_size * 0.15);
		grad = mix(grad, vec3(1.0, 0.97, 0.9), disc_strength * smoothstep(0.9993, 0.9997, facing));
	}

	vec3 color = grad;
	float aerial = 1.0 - smoothstep(0.0, 0.42, el);
	for (int i = 0; i < wisp_count; i++) {
		vec4 w = card(wisps, wisp_cards[i], wisp_aspect, vec2(1.0, 4.0), az, el, cos_el, TIME * drift * 0.7);
		vec3 tint = mix(w.rgb, horizon, cloud_haze * aerial);
		color = mix(color, tint, w.a * wisp_opacity);
	}
	for (int i = 0; i < card_count; i++) {
		float speed = TIME * drift * (0.75 + 0.5 * fract(float(i) * 0.37));
		vec4 c = card(clouds, cards[i], card_aspect, vec2(2.0, 2.0), az, el, cos_el, speed);
		vec3 tint = mix(c.rgb, horizon, cloud_haze * aerial);
		color = mix(color, tint, c.a * cloud_opacity);
	}

	if (panorama_mix > 0.0) {
		vec2 uv = SKY_COORDS;
		uv.x = fract(uv.x + panorama_turn);
		vec3 painted = texture(panorama, uv).rgb;
		// feather opposite edge strips into the same value at the panorama wrap.
		float edge = min(uv.x, 1.0 - uv.x);
		vec3 opposite = texture(panorama, vec2(1.0 - uv.x, uv.y)).rgb;
		painted = mix(painted, opposite, 0.5 * (1.0 - smoothstep(0.0, 0.04, edge)));
		color = mix(color, painted, panorama_mix);
	}
	COLOR = color;
}
