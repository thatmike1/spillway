shader_type spatial;
render_mode cull_disabled;
// p / a real maintenance mesh, with openings smaller than the runner's capsule.
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
void fragment() {
    vec2 p = vec2(abs(world_normal.x) > 0.5 ? world_position.z : world_position.x, world_position.y);
    vec2 grid = p / 0.14;
    vec2 distance_to_wire = abs(fract(grid + 0.5) - 0.5);
    vec2 width = max(fwidth(grid), vec2(0.001));
    vec2 wire = 1.0 - smoothstep(vec2(0.022), vec2(0.022) + width * 0.65, distance_to_wire);
    ALBEDO = vec3(0.16, 0.21, 0.20);
    ALPHA = max(wire.x, wire.y);
    ALPHA_SCISSOR_THRESHOLD = 0.5;
    ROUGHNESS = 0.78;
}
