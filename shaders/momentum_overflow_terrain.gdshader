shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// p / overflow art pass valley sides: summer grass, scrub patches, rock on steep ground and a
// darker wet bank above the waterline. only low-frequency variation, so the far slopes read
// as calm masses instead of tiled noise. original procedural work, no textures.

uniform vec3 grass : source_color = vec3(0.23, 0.28, 0.16);
uniform vec3 dry_grass : source_color = vec3(0.37, 0.36, 0.26);
uniform vec3 scrub : source_color = vec3(0.12, 0.17, 0.09);
uniform vec3 rock : source_color = vec3(0.42, 0.4, 0.36);
uniform vec3 bank : source_color = vec3(0.2, 0.2, 0.16);
uniform float water_y = -7.6;

varying vec3 wpos;
varying vec3 wnorm;

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
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float n1 = noise21(p / 55.0);
	float n2 = noise21(p / 38.0 + 9.0);
	float height = smoothstep(0.0, 60.0, wpos.y);
	vec3 c = mix(grass, dry_grass, clamp(height * 0.45 + (n1 - 0.5) * 0.6, 0.0, 1.0));
	float patches = smoothstep(0.5, 0.75, n2 * 0.6 + n1 * 0.4);
	c = mix(c, scrub, patches * 0.6);
	// strata on steep ground, banded by height.
	float strata = noise21(vec2(p.x / 30.0 + p.y / 30.0, wpos.y / 2.2));
	float rocky = smoothstep(0.32, 0.5, slope + (strata - 0.5) * 0.25);
	c = mix(c, rock * (0.85 + strata * 0.3), rocky);
	float wet = 1.0 - smoothstep(water_y + 0.2, water_y + 2.5, wpos.y);
	c = mix(c, bank, wet);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.8, rocky);
	SPECULAR = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(wnorm, 0.0)).xyz);
}
