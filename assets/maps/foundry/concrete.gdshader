shader_type spatial;
render_mode cull_back;
varying vec3 world;
varying vec3 up_normal;
float hash(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
float weather(vec2 point) {
    vec2 cell = floor(point);
    vec2 f = fract(point);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
        mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}
float joint(vec2 uv, vec2 scale) {
    vec2 f = fract(uv);
    vec2 d = min(f, 1.0 - f) * scale;
    return 1.0 - smoothstep(0.018, 0.045, min(d.x, d.y));
}
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    up_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    float top = smoothstep(0.5, 0.85, up_normal.y);
    vec2 deck_uv = world.xz / vec2(4.0, 5.0);
    float slab = hash(floor(deck_uv));
    float deck_joint = joint(deck_uv, vec2(4.0, 5.0));
    vec3 cap = vec3(0.72, 0.69, 0.59) * (0.92 + slab * 0.12);
    cap *= 1.0 - deck_joint * 0.20;
    vec2 face = abs(up_normal.x) > 0.5 ? world.zy : world.xy;
    vec2 wall_uv = face / vec2(4.5, 2.5);
    wall_uv.x += mod(floor(wall_uv.y), 2.0) * 0.5;
    float wall_joint = joint(wall_uv, vec2(4.5, 2.5));
    float block = hash(floor(wall_uv));
    float tide = smoothstep(-7.0, 1.0, world.y);
    vec3 side = mix(vec3(0.15, 0.24, 0.24), vec3(0.34, 0.39, 0.36), tide);
    side *= 0.86 + block * 0.20;
    side *= 1.0 - wall_joint * 0.24;
    float coarse = hash(floor(face * vec2(1.1, 1.7)));
    float chip = smoothstep(0.76, 0.98, coarse) * smoothstep(0.15, 0.9, wall_joint);
    side = mix(side, vec3(0.46, 0.46, 0.39), chip * 0.55);
    float streak = smoothstep(0.82, 0.97, hash(vec2(floor(face.x * 1.8), 4.0)));
    side *= 1.0 - streak * 0.15 * (1.0 - tide * 0.6);
    float worn = weather(face * vec2(0.38, 0.48));
    float broken = weather(face * 2.4);
    float coating = smoothstep(0.36, 0.68, worn + (broken - 0.5) * 0.18);
    side = mix(side * 0.78, side * 1.23 + vec3(0.025, 0.021, 0.008), coating);
    float edge_wear = smoothstep(0.05, 0.32, wall_joint) * smoothstep(0.48, 0.72, broken);
    side = mix(side, vec3(0.49, 0.47, 0.39), edge_wear * 0.35);
    float damp = (1.0 - tide) * smoothstep(0.28, 0.73, weather(face * vec2(0.6, 0.16)));
    side *= 1.0 - damp * 0.24;
    ALBEDO = mix(side, cap, top);
    ROUGHNESS = 0.97;
}
