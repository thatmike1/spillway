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
 float patch=grain(wall/2.6)*0.65+grain(wall/1.1)*0.35;
 float worn=smoothstep(0.60,0.65,patch);
 float streak=grain(wall*2.3);
 vec3 side=mix(side_color.rgb,mix(side_color.rgb,vec3(0.76,0.74,0.68),0.65),worn*0.55);
 side*=0.985+streak*0.015;
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

const INK := """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=vec3(0.035,0.055,0.065);ALPHA=0.88*(1.0-smoothstep(70.0,200.0,distance(wp,CAMERA_POSITION_WORLD)));}
"""
static var _ink: Shader
static func ink() -> ShaderMaterial:
	if _ink == null:
		_ink = Shader.new()
		_ink.code = INK
	var material := ShaderMaterial.new()
	material.shader = _ink
	return material

const WATER := """shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float a=abs(sin(p.x*3.7+sin(p.y*0.9+TIME*0.2)*0.5+TIME*0.28));
 float b=abs(sin(p.y*5.3-p.x*0.8-TIME*0.36));
 float broken=smoothstep(0.3,0.8,sin(p.y*1.5-p.x*0.7)*0.5+0.5);
 float ripple=smoothstep(0.97,0.995,a)*broken+smoothstep(0.985,0.999,b)*0.22;
 float nearfade=1.0-smoothstep(35.0,180.0,distance(wp,CAMERA_POSITION_WORLD));
 float horizon=pow(1.0-max(dot(normalize(CAMERA_POSITION_WORLD-wp),vec3(0,1,0)),0.0),4.0);
 vec3 water=mix(vec3(0.16,0.35,0.40),vec3(0.33,0.52,0.54),horizon);
 ALBEDO=mix(water,vec3(0.50,0.68,0.67),ripple*0.38*nearfade);
}
"""
static var _water: Shader
static func water() -> ShaderMaterial:
	if _water == null:
		_water = Shader.new()
		_water.code = WATER
	var material := ShaderMaterial.new()
	material.shader = _water
	return material
