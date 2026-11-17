extends RefCounted
## roof joints and waterline weathering replace the quay's broad wear patches on this map only.
static func concrete(side: Color, roof: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 side_color : source_color;
uniform bool roof = false;
varying vec3 wp;
varying vec3 wn;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
 float top=smoothstep(0.65,0.92,wn.y);
 vec2 wall=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 vec2 grid=abs(fract(wall/vec2(4.0,2.0)+0.5)-0.5)*vec2(4.0,2.0);
 float joint=1.0-smoothstep(0.025,0.065,min(grid.x,grid.y));
 float grain=fract(sin(dot(floor(wall*12.0),vec2(12.9898,78.233)))*43758.5453);
 vec3 side=side_color.rgb*(0.98+grain*0.025);
 side=mix(side,vec3(0.45,0.43,0.35),joint*0.18);
 side*=mix(0.66,1.0,smoothstep(-2.5,1.0,wp.y));
 vec2 cells=abs(fract(wp.xz/vec2(4.0,6.0)+0.5)-0.5)*vec2(4.0,6.0);
 vec2 aa=max(fwidth(wp.xz),vec2(0.005));
 float seam=1.0-min(smoothstep(0.025-aa.x,0.025+aa.x,cells.x),smoothstep(0.025-aa.y,0.025+aa.y,cells.y));
 vec3 cap=vec3(0.72,0.71,0.64);
 if(roof){ cap=mix(cap,vec3(0.34,0.40,0.39),seam*0.42); }
 ALBEDO=mix(side,cap,top); ROUGHNESS=0.95; SPECULAR=0.0;
}
void light(){
 float facing=dot(NORMAL,LIGHT);
 float band=mix(0.55,0.85,smoothstep(-0.1,0.02,facing));
 band=mix(band,1.0,smoothstep(0.65,0.72,facing));
 DIFFUSE_LIGHT+=ALBEDO*band*ATTENUATION*LIGHT_COLOR/PI;
}
"""
	material.shader = shader
	material.set_shader_parameter("side_color", side)
	material.set_shader_parameter("roof", roof)
	return material
