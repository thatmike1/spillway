shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// p / overflow art pass: the kit's metre-true surface (momentum_surface.gdshader, same
// texture sets and mapping) plus per-vertex edge data written by momentum_overflow_art.gd
// from the level's geometry manifest. top faces carry signed distances to their four top
// edges in UV/UV2 (d for a contact edge against a wall or higher deck, 1000 + d for a free
// drop edge, 5000 for a joined edge); side faces carry depth below their top edge in UV.x
// and the edge kind in UV.y (1 free lip, 2 wall foot above a deck). COLOR.r marks a face
// that came from a top quad. without that data (UV 0) the surface is the kit's.

uniform sampler2D top_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 top_tile = vec2(3.0);
uniform vec3 top_tint = vec3(1.0);

uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_arm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 side_tile = vec2(4.0);
uniform vec3 side_tint = vec3(1.0);

uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float far_normal_fade : hint_range(0.0, 1.0) = 0.5;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 0.0;
uniform float specular_level : hint_range(0.0, 1.0) = 0.5;
uniform float top_min_up : hint_range(0.0, 1.0) = 0.66;
// p / reduces the scan's own tone variation on top faces (1 keeps it), so a broad deck
// reads as one calm plane at running distance.
uniform float top_detail : hint_range(0.0, 1.5) = 1.0;

uniform vec2 bay_size = vec2(0.0);
uniform float joint_width = 0.012;
uniform float joint_dark : hint_range(0.0, 1.0) = 0.45;
uniform float bay_tone : hint_range(0.0, 0.3) = 0.06;
uniform float side_joint_spacing = 0.0;
uniform float side_bay_tone : hint_range(0.0, 0.3) = 0.05;
// p / horizontal formwork lifts on side faces, metres apart; 0 disables.
uniform float lift_spacing = 0.0;

uniform float macro_strength : hint_range(0.0, 0.5) = 0.07;
uniform float macro_scale = 11.0;
uniform float stain : hint_range(0.0, 1.0) = 0.0;
uniform vec3 stain_color : source_color = vec3(0.42, 0.47, 0.40);

uniform vec3 paint_color : source_color = vec3(0.8, 0.55, 0.15);
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float paint_roughness : hint_range(0.0, 1.0) = 0.5;

uniform float waterline = -10000.0;

// --- edge treatment, from the per-vertex data ---
// a trowelled margin along free drop edges: lighter, calmer concrete, a tooled joint at its
// inner side and a worn arris on the lip itself.
uniform float margin_width = 0.0;
uniform float margin_lift = 0.12;
uniform float arris_lift = 0.22;
// darkening and grime where a deck meets a wall or a higher step.
uniform float contact_ao : hint_range(0.0, 1.0) = 0.0;
uniform float contact_reach = 0.9;
// weathering streaks down the face below a free lip, and the damp foot of a wall.
uniform float lip_stain : hint_range(0.0, 1.0) = 0.0;
uniform float foot_ao : hint_range(0.0, 1.0) = 0.0;
// transverse grooves across a sloped top (recovery ramps), metres apart; 0 disables.
uniform float rib_spacing = 0.0;
uniform float rib_strength : hint_range(0.0, 1.0) = 0.5;
// standing-water patches on top faces: dark, glossy, sky-reflecting.
uniform float puddles : hint_range(0.0, 1.0) = 0.0;
// algae in joints and along contact edges.
uniform float moss : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moss_color : source_color = vec3(0.24, 0.29, 0.16);
// a thin moving water film on top faces: glossy, darker, with foam streaks running down the
// fall line at film_speed m/s (along world -z on a level floor).
uniform float film : hint_range(0.0, 1.0) = 0.0;
uniform float film_speed = 1.4;

varying vec3 frame_position;
varying vec3 world_n;
varying vec3 world_pos;
varying vec3 top_t;
varying vec3 top_b;
varying vec3 side_t;
varying vec3 side_b;
varying vec2 top_m;
varying vec2 side_m;

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
	world_pos = world;
	vec3 n = normalize(NORMAL / scale);
	vec3 up = transpose(rotation) * vec3(0.0, 1.0, 0.0);
	vec3 tt;
	vec3 tb;
	vec3 st;
	vec3 sb;
	vec3 forward = abs(n.z) > 0.95 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, -1.0);
	plane_frame(n, forward, tt, tb);
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

vec3 unpack_normal(vec4 texel) {
	vec2 xy = texel.xy * 2.0 - 1.0;
	return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}

vec3 neutral(vec3 source) {
	return mix(source, vec3(dot(source, vec3(0.2126, 0.7152, 0.0722))), desaturate);
}

float joint_cover(float distance_m, float width, float footprint) {
	float cover = clamp((width * 0.5 - distance_m) / footprint + 0.5, 0.0, 1.0);
	return cover * min(1.0, width / footprint);
}

// nearest edge of each kind from the four encoded distances.
void decode_edges(vec4 e, out float contact_d, out float free_d) {
	contact_d = 1e4;
	free_d = 1e4;
	for (int i = 0; i < 4; i++) {
		float v = e[i];
		if (v < 900.0) {
			contact_d = min(contact_d, max(v, 0.0));
		} else if (v < 4000.0) {
			free_d = min(free_d, max(v - 1000.0, 0.0));
		}
	}
}

void fragment() {
	vec3 n = normalize(world_n);
	float top_weight = smoothstep(top_min_up - 0.04, top_min_up + 0.04, abs(n.y));
	vec2 top_uv = top_m * vec2(1.0, -1.0) / top_tile;
	vec2 top_dx = dFdx(top_uv);
	vec2 top_dy = dFdy(top_uv);
	vec2 top_pixel = max(fwidth(top_m), vec2(1e-5));
	vec2 side_uv = side_m * vec2(1.0, -1.0) / side_tile;
	vec2 side_dx = dFdx(side_uv);
	vec2 side_dy = dFdy(side_uv);
	float side_pixel = max(fwidth(side_m.x), 1e-5);
	float side_pixel_y = max(fwidth(side_m.y), 1e-5);

	// edge data. a face without it (all zero) gets no edge treatment.
	bool has_edges = COLOR.r > 0.5;
	float contact_d = 1e4;
	float free_d = 1e4;
	if (has_edges) {
		decode_edges(vec4(UV, UV2), contact_d, free_d);
	}
	float side_depth = UV.x;
	float side_kind = has_edges ? 0.0 : UV.y;

	vec3 ta = vec3(0.0);
	vec3 tn = vec3(0.0, 0.0, 1.0);
	vec3 tarm = vec3(1.0);
	float joint = 0.0;
	float grime = 0.0;
	if (top_weight > 0.0) {
		vec2 bay = bay_size.x > 0.0 ? floor(top_m / bay_size) : vec2(0.0);
		vec2 shifted = top_uv + (bay_size.x > 0.0 ? vec2(hash21(bay + 3.1), hash21(bay + 9.7)) : vec2(0.0));
		vec3 raw = neutral(textureGrad(top_albedo, shifted, top_dx, top_dy).rgb);
		// pull the scan toward its long-range mean so broad decks stay calm.
		vec3 mean = neutral(textureLod(top_albedo, vec2(0.5), 10.0).rgb);
		ta = mix(mean, raw, top_detail) * top_tint;
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
		if (lift_spacing > 0.0) {
			float d = abs(fract(world_pos.y / lift_spacing + 0.5) - 0.5) * lift_spacing;
			side_joint = max(side_joint, joint_cover(d, 0.02, side_pixel_y) * 0.8);
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
	float occlusion = 1.0;
	float roughness_bias = 0.0;

	// top faces: trowelled margin and arris along free edges, contact grime along walls.
	if (top_weight > 0.5 && has_edges) {
		if (margin_width > 0.0 && free_d < margin_width + 0.05) {
			float px = max(fwidth(free_d), 1e-4);
			float in_margin = 1.0 - smoothstep(margin_width - px, margin_width + px, free_d);
			vec3 calm = mix(albedo, vec3(dot(albedo, vec3(0.333))), 0.5);
			albedo = mix(albedo, calm * (1.0 + margin_lift), in_margin);
			float tool = joint_cover(abs(free_d - margin_width), 0.014, px);
			albedo *= 1.0 - tool * 0.45;
			float arris = 1.0 - smoothstep(0.02, 0.045 + px, free_d);
			albedo *= 1.0 + arris * arris_lift;
			grime *= 1.0 - in_margin;
			joint *= 1.0 - in_margin;
		}
		if (contact_ao > 0.0 && contact_d < contact_reach) {
			float k = 1.0 - contact_d / contact_reach;
			k = k * k;
			occlusion *= 1.0 - contact_ao * k;
			albedo *= 1.0 - contact_ao * 0.35 * k;
			if (moss > 0.0) {
				albedo = mix(albedo, moss_color, moss * k * 0.6);
			}
		}
	}
	// side faces: the lip's arris, weathering streaks below it; the damp foot of a wall.
	if (top_weight < 0.5 && side_kind > 0.5) {
		if (side_kind < 1.5) {
			float px = max(fwidth(side_depth), 1e-4);
			float arris = 1.0 - smoothstep(0.03, 0.05 + px, side_depth);
			float streak = noise21(vec2(side_m.x * 2.3, side_depth * 0.15)) * 0.6 + noise21(vec2(side_m.x * 0.6, 3.0)) * 0.4;
			float run = exp(-side_depth / 1.4) * smoothstep(0.03, 0.12, side_depth);
			albedo *= 1.0 - lip_stain * run * (0.35 + 0.65 * streak);
			albedo *= 1.0 + arris * arris_lift;
		} else {
			float k = exp(-max(side_depth, 0.0) / 0.35);
			occlusion *= 1.0 - foot_ao * k;
			albedo *= 1.0 - foot_ao * 0.4 * k;
			roughness_bias -= 0.25 * k * foot_ao;
		}
	}
	// recovery grooves across the fall line of a sloped top.
	vec3 rib_bend = vec3(0.0);
	if (rib_spacing > 0.0 && top_weight > 0.5) {
		vec2 fall = n.xz;
		float slope = length(fall);
		if (slope > 0.06) {
			fall /= slope;
			float phase = dot(world_pos.xz, fall) / rib_spacing;
			float px = fwidth(phase);
			float fade = smoothstep(0.06, 0.12, slope);
			// past about a sixth of a groove per pixel the profile cannot be resolved and
			// aliases into bands on a far ramp; blend it to its mean (0.32) so the ramp keeps
			// its average tone, and drop the tilt, whose mean is zero.
			float resolve = 1.0 - smoothstep(0.08, 0.3, px);
			float f = fract(phase);
			float groove = smoothstep(0.0, 0.18 + px, f) * (1.0 - smoothstep(0.32 - px, 0.5, f));
			groove = mix(0.32, groove, resolve);
			albedo *= 1.0 - rib_strength * 0.45 * groove * fade;
			occlusion *= 1.0 - rib_strength * 0.5 * groove * fade;
			// the groove's walls tilt the normal along the fall line.
			float tilt = (smoothstep(0.0, 0.18, f) - smoothstep(0.32, 0.5, f)) * (f < 0.25 ? 1.0 : -1.0);
			rib_bend = vec3(fall.x, 0.0, fall.y) * tilt * 0.6 * rib_strength * fade * resolve;
		}
	}
	albedo *= 1.0 - joint * joint_dark * top_weight - grime * 0.08 * top_weight - side_joint * 0.35 * (1.0 - top_weight);
	if (moss > 0.0) {
		albedo = mix(albedo, moss_color, moss * joint * top_weight * 0.7);
	}

	float metallic = arm.b * metallic_scale;
	float roughness = clamp(arm.g * roughness_scale + roughness_bias, 0.04, 1.0);
	if (paint_amount > 0.0) {
		float chips = smoothstep(0.7, 0.85, noise21(metres * 7.0)) * 0.6;
		float cover = paint_amount * (1.0 - chips);
		albedo = mix(albedo, paint_color * mix(1.0, arm.r, 0.5), cover);
		metallic = mix(metallic, 0.0, cover);
		roughness = mix(roughness, paint_roughness, cover);
	}
	float damp = 1.0 - smoothstep(waterline, waterline + 0.6, world_pos.y);
	if (damp > 0.0) {
		damp *= 0.7 + noise21(metres * vec2(2.0, 4.0)) * 0.3;
		albedo *= 1.0 - damp * 0.38;
		roughness = mix(roughness, 0.35, damp);
	}
	float flat_normal = 0.0;
	if (puddles > 0.0 && top_weight > 0.5) {
		float m = noise21(world_pos.xz / 2.6 + 31.0) * 0.6 + noise21(world_pos.xz / 7.0) * 0.4;
		float pool = smoothstep(0.62, 0.7, m) * puddles * (1.0 - smoothstep(0.08, 0.2, length(n.xz)));
		albedo *= 1.0 - pool * 0.45;
		roughness = mix(roughness, 0.06, pool);
		flat_normal = pool;
	}

	if (film > 0.0 && top_weight > 0.5) {
		vec2 fall = n.xz;
		float slope = length(fall);
		fall = slope > 0.02 ? fall / slope : vec2(0.0, -1.0);
		vec2 across = vec2(-fall.y, fall.x);
		vec2 q = vec2(dot(world_pos.xz, across) * 1.1, (dot(world_pos.xz, fall) - TIME * film_speed) * 0.22);
		float streak = noise21(q) * 0.6 + noise21(q * vec2(2.7, 1.9) + 7.0) * 0.4;
		float sheet = film * (0.75 + 0.25 * noise21(world_pos.xz / 6.0));
		albedo *= 1.0 - 0.3 * sheet;
		albedo = mix(albedo, vec3(0.62, 0.64, 0.6), smoothstep(0.66, 0.86, streak) * 0.45 * sheet);
		roughness = mix(roughness, 0.07, sheet * 0.9);
		flat_normal = max(flat_normal, sheet * 0.75);
	}
	float footprint = length(mix(abs(side_dx) + abs(side_dy), abs(top_dx) + abs(top_dy), top_weight)) * 1024.0;
	float strength = normal_strength * (1.0 - far_normal_fade * smoothstep(1.0, 4.0, footprint)) * (1.0 - flat_normal);
	vec3 tw = top_t * tn.x + top_b * tn.y;
	vec3 sw = side_t * sn.x + side_b * sn.y;
	vec3 bent = n * mix(sn.z, tn.z, top_weight) + mix(sw, tw, top_weight) * strength + rib_bend;
	bent = normalize(bent);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular_level;
	AO = arm.r * occlusion;
	AO_LIGHT_AFFECT = 0.25;
}
