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
    side *= 0.96 + block * 0.07;
    side *= 1.0 - wall_joint * 0.24;
    vec2 joint_distance = min(fract(wall_uv), 1.0 - fract(wall_uv)) * vec2(4.5, 2.5);
    float seam_edge = 1.0 - smoothstep(0.035, 0.16, min(joint_distance.x, joint_distance.y));
    float broken = weather(face * 5.0);
    float damage = hash(vec2(floor(face.x / 1.7), floor(wall_uv.y)));
    float chipped = seam_edge * smoothstep(0.62, 0.85, damage) * smoothstep(0.43, 0.76, broken);
    side = mix(side, vec3(0.46, 0.45, 0.38), chipped * 0.42);
    float course_distance = (1.0 - fract(wall_uv.y)) * 2.5;
    float stain = hash(vec2(floor(face.x / 0.65), floor(wall_uv.y) + 17.0));
    float runoff = (1.0 - smoothstep(0.04, mix(0.18, 0.9, stain), course_distance))
        * smoothstep(0.80, 0.96, stain) * smoothstep(0.45, 0.8, damage);
    side *= 1.0 - runoff * 0.13;
    float waterline = (1.0 - smoothstep(-6.2, -4.8, world.y))
        * (0.8 + weather(vec2(face.x * 1.2, world.y * 2.0)) * 0.2);
    side *= 1.0 - waterline * 0.18;
    ALBEDO = mix(side, cap, top);
    ROUGHNESS = 0.97;
}
