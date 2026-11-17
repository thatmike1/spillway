extends RefCounted
## elevation and exposure make the closed headlands read as rock, beach and marsh.
const GEO := preload("res://scripts/r19_course_geometry.gd")
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
			if str(child.name).begins_with("EstuaryHeadland_"):
				level.remove_child(child)
				child.free()
			else:
				child.material_override = material
	_headland(level,material)

static func _shore_point(u: float, v: float) -> Vector3:
	var x := lerpf(-215.0,205.0,u)
	var front := -258.0-18.0*sin((x+80.0)*0.008)-8.0*sin(x*0.021)
	var ridge := 30.0*exp(-pow((x+80.0)/115.0,2.0))+10.0*exp(-pow((x-145.0)/95.0,2.0))+3.0
	var shoulder := 2.2*sin(x*0.034+v*3.0)+1.1*cos(x*0.067-v*5.0)
	var taper := pow(maxf(sin(PI*u),0.0),0.8)*pow(maxf(sin(PI*v),0.0),0.8)
	return Vector3(x,-4.0+(ridge+shoulder)*taper,lerpf(front,-410.0,v))

static func _shore_normal(u: float, v: float) -> Vector3:
	var du := _shore_point(minf(u+0.01,1.0),v)-_shore_point(maxf(u-0.01,0.0),v)
	var dv := _shore_point(u,minf(v+0.01,1.0))-_shore_point(u,maxf(v-0.01,0.0))
	return du.cross(dv).normalized()

static func _headland(level: Node3D, material: Material) -> void:
	# one continuous ridge has unequal shoulders and an irregular shore; its entire boundary is submerged.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: int in 48:
		for z: int in 16:
			var corners: Array[Vector2] = [Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]
			for i: int in [0,2,1,0,3,2]:
				var uv := corners[i]/Vector2(48,16)
				surface.set_normal(_shore_normal(uv.x,uv.y))
				surface.add_vertex(_shore_point(uv.x,uv.y))
	# a bottom and side curtain close the landform below the visible waterline.
	var centre := Vector3(-5,-8,-330)
	for x: int in 48:
		for z: int in 16:
			var points: Array[Vector3] = []
			for uv: Vector2 in [Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
				var point := _shore_point(uv.x/48.0,uv.y/16.0)
				point.y = -12
				points.append(point)
			GEO.triangle(surface,points[0],points[1],points[2],centre)
			GEO.triangle(surface,points[0],points[2],points[3],centre)
	var boundary: Array[Vector3] = []
	for x: int in 49:
		boundary.append(_shore_point(x/48.0,0))
	for z: int in range(1,17):
		boundary.append(_shore_point(1,z/16.0))
	for x: int in range(47,-1,-1):
		boundary.append(_shore_point(x/48.0,1))
	for z: int in range(15,0,-1):
		boundary.append(_shore_point(0,z/16.0))
	for i: int in boundary.size():
		var a := boundary[i]
		var b := boundary[(i+1)%boundary.size()]
		var c := Vector3(b.x,-12,b.z)
		var d := Vector3(a.x,-12,a.z)
		GEO.triangle(surface,a,b,c,centre)
		GEO.triangle(surface,a,c,d,centre)
	var land := MeshInstance3D.new()
	land.name = "OuterEstuaryHeadland"
	land.mesh = surface.commit()
	land.material_override = material
	level.add_child(land)
