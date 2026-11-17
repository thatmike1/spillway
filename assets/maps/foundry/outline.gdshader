shader_type spatial;
render_mode cull_front, unshaded;
void vertex() {
    VERTEX += NORMAL * 0.025;
}
void fragment() {
    ALBEDO = vec3(0.055, 0.095, 0.105);
}
