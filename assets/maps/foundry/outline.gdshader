shader_type spatial;
render_mode cull_front, unshaded;
uniform float width = 0.025;
void vertex() {
    VERTEX += NORMAL * width;
}
void fragment() {
    ALBEDO = vec3(0.055, 0.095, 0.105);
}
