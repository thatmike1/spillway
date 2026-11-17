shader_type spatial;
uniform vec4 paint : source_color = vec4(0.25, 0.40, 0.43, 1.0);
varying vec3 world;
float grain(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
float chips(vec2 point) {
    vec2 cell = floor(point);
    vec2 f = fract(point);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), f.x),
        mix(grain(cell + vec2(0.0, 1.0)), grain(cell + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 edge_distance = min(UV, 1.0 - UV);
    float edge = 1.0 - smoothstep(0.008, 0.07, min(edge_distance.x, edge_distance.y));
    float broken = chips(world.xy * 3.0) * 0.65 + chips(world.zy * 3.0) * 0.35;
    float wear = edge * smoothstep(0.48, 0.64, broken);
    ALBEDO = mix(paint.rgb, vec3(0.48, 0.46, 0.35), wear * 0.72);
    ROUGHNESS = 0.86;
}
