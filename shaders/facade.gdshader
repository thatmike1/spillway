shader_type spatial;
// Original procedural facade: window bays, floor slabs and a concrete roof, laid
// out in the mesh's own space so the pattern turns with a folding block.

uniform vec3 wall_color : source_color = vec3(0.14, 0.21, 0.29);
uniform vec3 slab_color : source_color = vec3(0.36, 0.42, 0.49);
uniform vec3 glass_color : source_color = vec3(0.035, 0.05, 0.075);
uniform vec3 lit_color : source_color = vec3(1.0, 0.86, 0.68);
uniform vec3 roof_color : source_color = vec3(0.2, 0.25, 0.31);
uniform vec2 bay = vec2(2.8, 3.4);
uniform vec2 window_size = vec2(0.62, 0.6);
uniform float lit_ratio = 0.16;
uniform float lit_energy = 1.4;
uniform float seed = 0.0;
// anticipation wave for the folding tower: floors below this local height light up
uniform float wave_height = -10000.0;
uniform float wave_floor = -10000.0;
uniform vec3 wave_color : source_color = vec3(1.0, 0.9, 0.75);

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 an = abs(local_normal);
	vec3 albedo;
	float rough = 0.88;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (an.y > 0.6) {
		vec2 g = abs(fract(local_pos.xz / 3.2) - 0.5);
		vec2 w = fwidth(local_pos.xz / 3.2);
		float seam = smoothstep(0.5 - w.x * 1.5, 0.5, g.x) + smoothstep(0.5 - w.y * 1.5, 0.5, g.y);
		albedo = mix(roof_color, roof_color * 0.72, clamp(seam, 0.0, 1.0) * 0.6);
	} else {
		vec2 uv = an.x > an.z ? vec2(local_pos.z, local_pos.y) : vec2(local_pos.x, local_pos.y);
		uv.x += seed * 1.7;
		vec2 cell_uv = uv / bay;
		vec2 cell = floor(cell_uv);
		vec2 f = fract(cell_uv);
		vec2 w = fwidth(cell_uv);
		vec2 d = abs(f - vec2(0.5, 0.52)) - window_size * 0.5;
		float inside = (1.0 - smoothstep(-w.x, w.x, d.x)) * (1.0 - smoothstep(-w.y, w.y, d.y));
		float slab = 1.0 - smoothstep(0.0, 0.07 + w.y, f.y);
		float mullion = 1.0 - smoothstep(0.0, 0.025 + w.x, abs(f.x - 0.5));
		float glass = inside * (1.0 - mullion * 0.85);
		float h = hash12(cell + vec2(seed * 13.1, seed * 7.3));
		float lit = step(h, lit_ratio);
		float wave = (1.0 - step(wave_height, uv.y)) * step(wave_floor, uv.y);
		albedo = mix(wall_color, slab_color, slab * 0.8);
		albedo = mix(albedo, glass_color, glass);
		emit = glass * (lit_color * lit * lit_energy * (0.55 + 0.45 * h) + wave_color * wave * 1.5);
		rough = mix(rough, 0.32, glass);
		metal = mix(0.0, 0.25, glass);
		// distant facades melt into an average so the grid never shimmers
		float far_blend = clamp(max(w.x, w.y) * 2.2 - 0.35, 0.0, 1.0);
		vec3 average = mix(wall_color, glass_color, window_size.x * window_size.y);
		albedo = mix(albedo, average, far_blend);
		emit = mix(emit, lit_color * lit_ratio * lit_energy * window_size.x * window_size.y * 0.8, far_blend);
		rough = mix(rough, 0.6, far_blend);
		metal = mix(metal, 0.2, far_blend);
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
