shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world;
void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float distance_m = length(VERTEX);
    float swell = sin(world.z * 0.8 + world.x * 0.15 + TIME * 0.35);
    float chop = sin(world.x * 1.3 - world.z * 0.55 - TIME * 0.6);
    vec3 deep = vec3(0.075, 0.22, 0.27) * (1.0 + swell * 0.07 + chop * 0.03);
    vec3 haze = vec3(0.20, 0.37, 0.41);
    vec3 water = mix(deep, haze, smoothstep(80.0, 300.0, distance_m));
    float band_width = 4.0 + distance_m * 0.035;
    float band = exp(-pow((world.x + 8.0 + world.z * 0.03) / band_width, 2.0));
    float glint = smoothstep(0.88, 0.99, swell) * smoothstep(0.2, 0.9, chop);
    glint *= band * smoothstep(20.0, 80.0, distance_m);
    ALBEDO = mix(water, vec3(0.69, 0.71, 0.58), glint * 0.8);
    vec2 shore = abs(world.xz - vec2(12.0, -185.0)) - vec2(25.0, 7.5);
    float shore_distance = length(max(shore, vec2(0.0))) + min(max(shore.x, shore.y), 0.0);
    float wash = sin(world.x * 2.3 + TIME * 0.9) * sin(world.z * 1.7 + TIME * 0.55);
    float foam = 1.0 - smoothstep(0.12, 1.0, abs(shore_distance - 0.35 - wash * 0.15));
    ALBEDO = mix(ALBEDO, vec3(0.56, 0.70, 0.66), foam * 0.7);
}
