shader_type spatial;
render_mode cull_back;
varying vec3 world;
varying vec3 up_normal;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    up_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    float top = smoothstep(0.5, 0.85, up_normal.y);
    float grain = fract(sin(dot(floor(world * 12.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
    float seam = step(0.028, abs(sin(world.y * 1.1))) * step(0.018, abs(sin(world.z * 0.28 + floor(world.y * 0.35))));
    float tide = smoothstep(-6.0, 1.0, world.y);
    vec3 side = mix(vec3(0.16,0.25,0.25), vec3(0.31,0.37,0.35),tide);
    vec3 cap = vec3(0.79,0.77,0.67);
    ALBEDO = mix(side, cap, top) * (0.94 + grain * 0.06) * mix(0.65,1.0,seam);
    ROUGHNESS = 0.96;
}
