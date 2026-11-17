extends RefCounted
## elevation and exposure make the closed headlands read as rock, beach and marsh.
const SHADER := """shader_type spatial;
render_mode specular_disabled;
varying vec3 wp;
varying vec3 wn;
float grain(vec2 p){return sin(p.x*0.23+sin(p.y*0.12)*1.8)*sin(p.y*0.18+p.x*0.06);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float exposure=1.0-smoothstep(0.35,0.78,wn.y);
 float strata=0.5+0.5*sin(wp.y*1.7+grain(wp.xz)*0.45);
 vec3 rock=mix(vec3(0.39,0.46,0.44),vec3(0.55,0.57,0.50),strata*0.22);
 vec3 grass=mix(vec3(0.43,0.50,0.37),vec3(0.53,0.57,0.42),smoothstep(-0.6,0.7,grain(wp.xz)));
 vec3 land=mix(grass,rock,exposure*0.85);
 float beach=1.0-smoothstep(-1.4,1.0,wp.y+grain(wp.xz)*0.28);
 land=mix(land,vec3(0.67,0.64,0.50),beach*0.8);
 float wet=1.0-smoothstep(-2.9,-2.1,wp.y);
 land*=1.0-wet*0.25;
 ALBEDO=land;ROUGHNESS=1.0;
}
"""
static func dress(level: Node3D) -> void:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	for child: Node in level.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh:
			child.material_override = material
