extends RefCounted
## original world-space concrete: broad wear, fine joints and a restrained wet base.
const SURFACE := """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 top_color : source_color;
uniform vec4 side_color : source_color;
uniform bool deck = false;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float grain(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
 vec2 wall=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 float patch=grain(wall/vec2(5.7,4.1))+grain(wall/vec2(2.3,3.7))*0.25;
 float worn=smoothstep(0.62,0.92,patch);
 float streak=grain(vec2(wall.x*2.8,wall.y*0.13));
 vec3 side=mix(side_color.rgb,vec3(0.39,0.35,0.28),worn*0.28);
 side*=0.95+streak*0.05;
 side*=1.0-(1.0-smoothstep(-2.8,-1.0,wp.y))*0.22;
 vec3 cap=top_color.rgb*(0.975+grain(wp.xz*0.35)*0.025);
 vec2 scale=vec2(2.438,3.2512);
 vec2 cell=fract(wp.xz/scale+vec2(0.37,0.19));
 vec2 dist=min(cell,1.0-cell)*scale;
 vec2 aa=max(fwidth(wp.xz),vec2(0.003));
 float seam=1.0-min(smoothstep(0.006-aa.x,0.006+aa.x,dist.x),smoothstep(0.006-aa.y,0.006+aa.y,dist.y));
 float nearfade=1.0-smoothstep(18.0,55.0,distance(wp,CAMERA_POSITION_WORLD));
 if(deck) { cap=mix(cap,top_color.rgb*0.62,seam*0.48*nearfade); }
 ALBEDO=mix(side,cap,smoothstep(0.65,0.92,wn.y));
 ROUGHNESS=0.98; SPECULAR=0.0;
}
"""
static var _surface: Shader
static func concrete(top: Color, side: Color, deck: bool = false) -> ShaderMaterial:
	if _surface == null:
		_surface = Shader.new()
		_surface.code = SURFACE
	var material := ShaderMaterial.new()
	material.shader = _surface
	material.set_shader_parameter("top_color",top)
	material.set_shader_parameter("side_color",side)
	material.set_shader_parameter("deck",deck)
	return material
