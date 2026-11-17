shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
// original inverted hull for the drawn structural meshes; no collision is added.
void vertex(){ VERTEX += NORMAL * 0.025; }
void fragment(){ ALBEDO=vec3(0.055,0.075,0.080); }
