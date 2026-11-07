shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// p / momentum kit surface: two texture sets projected in metres, no mesh UVs.
// positions are taken in the object's rotation frame (scale removed), so a rotated
// or non-uniformly scaled box keeps metre-true texels aligned to its own edges, and
// equally rotated neighbours continue the same pattern. faces whose world normal
// points up (or down) use the top set; steeper faces use the side set.

uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// metres covered by one repeat of the top set (from the source's measured dimensions).
uniform vec2 top_tile = vec2(3.0);
// linear multipliers on the source albedo; above 1 brightens a dark scan.
uniform vec3 top_tint = vec3(1.0);

uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 side_tile = vec2(4.0);
uniform vec3 side_tint = vec3(1.0);

// 0 keeps the source colour, 1 removes its chroma before tinting.
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// p / extra flattening once a texel is smaller than a pixel; 0 leaves only mip averaging.
uniform float far_normal_fade : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 0.0;
uniform float specular_level : hint_range(0.0, 1.0) = 0.5;
// slope at which the side set takes over, as world normal.y (0.7 is about 45 degrees).
uniform float top_min_up : hint_range(0.0, 1.0) = 0.66;

// deck joints on top faces: bay size in metres, 0 disables. each bay shifts the
// source texture under the joint so repeats do not line up across a broad floor.
uniform vec2 bay_size = vec2(0.0);
uniform float joint_width = 0.012;
uniform float joint_dark : hint_range(0.0, 1.0) = 0.45;
uniform float bay_tone : hint_range(0.0, 0.3) = 0.06;
// vertical monolith joints on side faces, metres apart; 0 disables.
uniform float side_joint_spacing = 0.0;
uniform float side_bay_tone : hint_range(0.0, 0.3) = 0.05;

// broad tone variation at running distance, as a fraction of value.
uniform float macro_strength : hint_range(0.0, 0.5) = 0.07;
uniform float macro_scale = 11.0;
// old concrete: cool green staining and run-off streaks on side faces.
uniform float stain : hint_range(0.0, 1.0) = 0.0;
uniform vec3 stain_color : source_color = vec3(0.42, 0.47, 0.40);

// paint over the source (ochre hardware) with sparse chips showing the metal.
uniform vec3 paint_color : source_color = vec3(0.8, 0.55, 0.15);
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float paint_roughness : hint_range(0.0, 1.0) = 0.5;

// wet band below a world height; far below the course disables it.
uniform float waterline = -10000.0;

varying vec3 frame_position;
varying vec3 world_n;
varying vec3 top_t;
varying vec3 top_b;
varying vec3 side_t;
varying vec3 side_b;
varying vec2 top_m;
varying vec2 side_m;
varying float world_y;

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

// returns tangent (image right) and bitangent (image up) for a plane with normal n.
void plane_frame(vec3 n, vec3 reference, out vec3 t, out vec3 b) {
	b = normalize(reference - n * dot(n, reference));
	t = cross(b, n);
}

void vertex() {
	mat3 basis = mat3(MODEL_MATRIX);
	vec3 scale = vec3(length(basis[0]), length(basis[1]), length(basis[2]));
	mat3 rotation = mat3(basis[0] / scale.x, basis[1] / scale.y, basis[2] / scale.z);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	frame_position = transpose(rotation) * world;
	world_y = world.y;
	vec3 n = normalize(NORMAL / scale);
	vec3 up = transpose(rotation) * vec3(0.0, 1.0, 0.0);
	vec3 tt;
	vec3 tb;
	vec3 st;
	vec3 sb;
	// top faces look along the frame's -z; near-vertical normals fall back to x.
	vec3 forward = abs(n.z) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, -1.0);
	plane_frame(n, forward, tt, tb);
	// side faces keep world up as image up; flat faces fall back to the frame forward.
	vec3 side_ref = abs(dot(n, up)) > 0.95 ? forward : up;
	plane_frame(n, side_ref, st, sb);
	top_m = vec2(dot(frame_position, tt), dot(frame_position, tb));
	side_m = vec2(dot(frame_position, st), dot(frame_position, sb));
	top_t = rotation * tt;
	top_b = rotation * tb;
	side_t = rotation * st;
	side_b = rotation * sb;
	world_n = rotation * n;
}

// open-gl convention normal map, z rebuilt so two-channel compression also works.
vec3 unpack_normal(vec4 texel) {
	vec2 xy = texel.xy * 2.0 - 1.0;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

vec3 neutral(vec3 source) {
	return mix(source, vec3(dot(source, vec3(0.2126, 0.7152, 0.0722))), desaturate);
}

float joint_cover(float distance_m, float width, float footprint) {
	float cover = clamp((width * 0.5 - distance_m) / footprint + 0.5, 0.0, 1.0);
	// a joint thinner than a pixel keeps its average darkness instead of flickering.
	return cover * min(1.0, width / footprint);
}

void fragment() {
	vec3 n = normalize(world_n);
	float top_weight = smoothstep(top_min_up - 0.04, top_min_up + 0.04, abs(n.y));
	// derivatives are taken before the branches, so each face samples only its own set.
	vec2 top_uv = top_m * vec2(1.0, -1.0) / top_tile;
	vec2 top_dx = dFdx(top_uv);
	vec2 top_dy = dFdy(top_uv);
	vec2 top_pixel = max(fwidth(top_m), vec2(1e-5));
	vec2 side_uv = side_m * vec2(1.0, -1.0) / side_tile;
	vec2 side_dx = dFdx(side_uv);
	vec2 side_dy = dFdy(side_uv);
	float side_pixel = max(fwidth(side_m.x), 1e-5);

	// top set: deck bays, each with its own texture offset hidden under the joint.
	vec3 ta = vec3(0.0);
	vec3 tn = vec3(0.0, 0.0, 1.0);
	vec3 tarm = vec3(1.0);
	float joint = 0.0;
	float grime = 0.0;
	if (top_weight > 0.0) {
		vec2 bay = bay_size.x > 0.0 ? floor(top_m / bay_size) : vec2(0.0);
		vec2 shifted = top_uv + (bay_size.x > 0.0 ? vec2(hash21(bay + 3.1), hash21(bay + 9.7)) : vec2(0.0));
		ta = neutral(textureGrad(top_albedo, shifted, top_dx, top_dy).rgb) * top_tint;
		tn = unpack_normal(textureGrad(top_normal, shifted, top_dx, top_dy));
		tarm = textureGrad(top_arm, shifted, top_dx, top_dy).rgb;
		if (bay_size.x > 0.0) {
			vec2 edge = abs(fract(top_m / bay_size + 0.5) - 0.5) * bay_size;
			float d = min(edge.x, edge.y);
			joint = joint_cover(d, joint_width, edge.x < edge.y ? top_pixel.x : top_pixel.y);
			grime = 1.0 - smoothstep(0.0, 0.07, d);
			ta *= 1.0 + (hash21(bay + vec2(13.0, 7.0)) - 0.5) * 2.0 * bay_tone;
		}
	}

	// side set: formwork faces, optional monolith joints with a tone step per pour.
	vec3 sa = vec3(0.0);
	vec3 sn = vec3(0.0, 0.0, 1.0);
	vec3 sarm = vec3(1.0);
	float side_joint = 0.0;
	if (top_weight < 1.0) {
		sa = neutral(textureGrad(side_albedo, side_uv, side_dx, side_dy).rgb) * side_tint;
		sn = unpack_normal(textureGrad(side_normal, side_uv, side_dx, side_dy));
		sarm = textureGrad(side_arm, side_uv, side_dx, side_dy).rgb;
		if (side_joint_spacing > 0.0) {
			float monolith = floor(side_m.x / side_joint_spacing);
			float d = abs(fract(side_m.x / side_joint_spacing + 0.5) - 0.5) * side_joint_spacing;
			side_joint = joint_cover(d, 0.025, side_pixel);
			sa *= 1.0 + (hash21(vec2(monolith, 41.0)) - 0.5) * 2.0 * side_bay_tone;
		}
	}

	vec3 albedo = mix(sa, ta, top_weight);
	vec3 arm = mix(sarm, tarm, top_weight);

	vec2 metres = mix(side_m, top_m, top_weight);
	float macro = noise21(metres / macro_scale) * 0.65 + noise21(metres / (macro_scale * 2.7) + 17.0) * 0.35;
	albedo *= 1.0 + (macro - 0.5) * 2.0 * macro_strength;
	if (stain > 0.0) {
		float runoff = noise21(vec2(side_m.x * 1.7, side_m.y * 0.07)) * (1.0 - top_weight);
		float blot = smoothstep(0.45, 0.8, noise21(metres / 3.3 + 5.0));
		albedo = mix(albedo, albedo * stain_color * 1.6, stain * clamp(runoff * 0.8 + blot * 0.5, 0.0, 1.0));
	}
	albedo *= 1.0 - joint * joint_dark * top_weight - grime * 0.08 * top_weight - side_joint * 0.35 * (1.0 - top_weight);

	float metallic = arm.b * metallic_scale;
	float roughness = clamp(arm.g * roughness_scale, 0.04, 1.0);
	if (paint_amount > 0.0) {
		// sparse chips only; seams darken the paint through ao instead of stripping it.
		float chips = smoothstep(0.7, 0.85, noise21(metres * 7.0)) * 0.6;
		float cover = paint_amount * (1.0 - chips);
		albedo = mix(albedo, paint_color * mix(1.0, arm.r, 0.5), cover);
		metallic = mix(metallic, 0.0, cover);
		roughness = mix(roughness, paint_roughness, cover);
	}
	float damp = 1.0 - smoothstep(waterline, waterline + 0.6, world_y);
	if (damp > 0.0) {
		damp *= 0.7 + noise21(metres * vec2(2.0, 4.0)) * 0.3;
		albedo *= 1.0 - damp * 0.38;
		roughness = mix(roughness, 0.35, damp);
	}

	// far texels flatten a little more than the mip average to keep running views calm.
	float footprint = length(mix(abs(side_dx) + abs(side_dy), abs(top_dx) + abs(top_dy), top_weight)) * 1024.0;
	float strength = normal_strength * (1.0 - far_normal_fade * smoothstep(1.0, 4.0, footprint));
	vec3 tw = top_t * tn.x + top_b * tn.y;
	vec3 sw = side_t * sn.x + side_b * sn.y;
	vec3 bent = n * mix(sn.z, tn.z, top_weight) + mix(sw, tw, top_weight) * strength;
	bent = normalize(bent);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular_level;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.25;
}
