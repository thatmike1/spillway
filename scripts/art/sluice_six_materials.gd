extends RefCounted
## original world-space concrete, edge wear and irregular painted water.
const SURFACE := """shader_type spatial;
render_mode diffuse_toon, specular_disabled;
uniform vec4 top_color : source_color;
uniform vec4 side_color : source_color;
uniform bool deck = false;
uniform float seam_strength = 0.48;
uniform float seam_floor = 0.62;
uniform vec2 seam_scale = vec2(2.438,3.2512);
uniform float deck_stain = 0.0;
uniform vec3 bounds_min;
uniform vec3 bounds_max;
varying vec3 wp;
varying vec3 wn;
varying vec3 lp;
varying vec3 ln;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float grain(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { lp=VERTEX; ln=NORMAL; wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
 vec2 wall=abs(wn.x)>abs(wn.z)?wp.zy:wp.xy;
 vec3 lo=lp-bounds_min; vec3 hi=bounds_max-lp;
 float lateral=abs(ln.x)>abs(ln.z)?min(lo.z,hi.z):min(lo.x,hi.x);
 float edge=min(lateral,min(lo.y,hi.y));
 vec2 panel=fract(wall/vec2(3.0,2.4)+vec2(0.13,0.21));
 vec2 pd=min(panel,1.0-panel)*vec2(3.0,2.4);
 float joint=1.0-smoothstep(0.006,0.024,min(pd.x,pd.y));
 float joint_wear=(1.0-smoothstep(0.025,0.09,min(pd.x,pd.y)))*smoothstep(0.45,0.65,grain(wall*2.5));
 float fracture=grain(wall*4.0)*0.6+grain(wall*13.0)*0.3+grain(wall*41.0)*0.1;
 float chips=(1.0-smoothstep(0.015,0.18,max(edge,0.0)))*smoothstep(0.42,0.55,fracture);
 float wear=max(step(0.25,chips)*0.48,step(0.12,joint_wear)*0.12);
 vec3 side=mix(side_color.rgb,mix(side_color.rgb,vec3(0.74,0.73,0.67),0.55),wear);
 side*=0.985+grain(wall*1.5)*0.015;
 side*=1.0-joint*0.12;
 float runoff=(1.0-smoothstep(0.02,0.65,mod(-wall.y-0.5,2.4)))*pow(grain(vec2(wall.x*5.0,floor(wall.y/2.4))),6.0);
 side*=1.0-clamp(runoff*3.0,0.0,1.0)*0.16;
 float wet=1.0-smoothstep(-2.8,-1.0,wp.y);
 side*=1.0-wet*0.4;
 float tide=1.0-smoothstep(0.15,0.8,abs(wp.y+2.45));
 side=mix(side,vec3(0.28,0.40,0.38),tide*0.6);
 float salt=(1.0-smoothstep(0.03,0.16,abs(wp.y+2.75)))*grain(wall*12.0);
 side=mix(side,vec3(0.55,0.58,0.51),salt*0.25);
 vec3 cap=top_color.rgb*(0.975+grain(wp.xz*0.35)*0.025);
 vec2 scale=seam_scale;
 vec2 cell=fract(wp.xz/scale+vec2(0.37,0.19));
 vec2 dist=min(cell,1.0-cell)*scale;
 vec2 aa=max(fwidth(wp.xz),vec2(0.003));
 float seam=1.0-min(smoothstep(0.006-aa.x,0.006+aa.x,dist.x),smoothstep(0.006-aa.y,0.006+aa.y,dist.y));
 float nearfade=1.0-smoothstep(18.0,55.0,distance(wp,CAMERA_POSITION_WORLD));
 if(deck) {
  cap=mix(cap,top_color.rgb*seam_floor,seam*seam_strength*nearfade);
  // broad, soft weathering: tide stains and dried salt patches that vary across one slab.
  float stain=smoothstep(0.55,0.9,grain(wp.xz*0.09+vec2(3.1,7.7))*0.75+grain(wp.xz*0.41)*0.25);
  float salt=smoothstep(0.62,0.95,grain(wp.xz*0.23+vec2(11.0,2.0)));
  cap=mix(cap,cap*vec3(0.90,0.91,0.88),stain*deck_stain);
  cap=mix(cap,min(cap*1.04,vec3(1.0)),salt*deck_stain*0.6);
 }
 if(wn.y < -0.65) { side=mix(side_color.rgb,top_color.rgb,0.28); }
 ALBEDO=mix(side,cap,smoothstep(0.65,0.92,wn.y));
 ROUGHNESS=0.98; SPECULAR=0.0;
}
"""
const INK := """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){ALBEDO=vec3(0.035,0.055,0.065);ALPHA=0.88*(1.0-smoothstep(70.0,200.0,distance(wp,CAMERA_POSITION_WORLD)));}
"""
const WATER := """shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 supports[64];
uniform int support_count = 0;
uniform vec3 deep_color = vec3(0.16,0.35,0.40);
uniform vec3 far_color = vec3(0.33,0.52,0.54);
uniform float glitter_amount = 0.65;
varying vec3 wp;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float ridge=abs(sin(p.x*2.8+p.y*0.9+n(p*0.45)*8.0+TIME*0.25));
 float broken=smoothstep(0.56,0.69,n(p*vec2(0.8,2.2)+TIME*0.025));
 float ripple=smoothstep(0.96,0.995,ridge)*broken;
 float nearfade=1.0-smoothstep(35.0,180.0,distance(wp,CAMERA_POSITION_WORLD));
 float horizon=pow(1.0-max(dot(normalize(CAMERA_POSITION_WORLD-wp),vec3(0,1,0)),0.0),4.0);
 vec3 water=mix(deep_color,far_color,horizon);
 water+=(n(p*0.18)-0.5)*0.025;
 float contact=0.0;
 float foam=0.0;
 for(int i=0;i<64;i++){
  if(i>=support_count){break;}
  vec2 q=abs(p-supports[i].xy)-supports[i].zw;
  float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0);
  contact=max(contact,1.0-smoothstep(0.0,0.75,d));
  foam=max(foam,smoothstep(0.02,0.10,d)*(1.0-smoothstep(0.20,0.65,d)));
 }
 water*=1.0-contact*0.22;
 vec3 glint=mix(vec3(0.49,0.65,0.65),vec3(0.65,0.63,0.49),horizon*0.4);
 vec3 view_dir=normalize(CAMERA_POSITION_WORLD-wp);
 vec3 reflected=reflect(-normalize(vec3(-0.556,0.242,-0.795)),vec3(0,1,0));
 float sun_path=pow(max(dot(view_dir,reflected),0.0),64.0);
 float glitter=sun_path*smoothstep(0.65,0.86,n(p*vec2(5.0,1.4)+vec2(TIME*0.12,0)));
 vec3 base=mix(water,glint,ripple*0.22*nearfade);
 base=mix(base,vec3(0.68,0.75,0.66),foam*(0.35+0.35*n(p*4.0+TIME*0.15)));
 ALBEDO=base*1.15;
 EMISSION=base*0.08+vec3(0.75,0.53,0.26)*glitter*glitter_amount*(1.0-contact);
 ROUGHNESS=0.55; SPECULAR=0.0;
}
"""
static var _surface: Shader
static var _ink: Shader
static var _water: Shader
## seam: deck joint strength and floor, seam_scale: joint spacing in metres; outer reach keeps the defaults.
static func concrete(top: Color, side: Color, deck: bool = false, bounds: AABB = AABB(), seam: Vector2 = Vector2(0.48,0.62), seam_scale: Vector2 = Vector2(2.438,3.2512), stain: float = 0.0) -> ShaderMaterial:
	if _surface == null:
		_surface = Shader.new()
		_surface.code = SURFACE
	var material := ShaderMaterial.new()
	material.shader = _surface
	material.set_shader_parameter("top_color",top)
	material.set_shader_parameter("side_color",side)
	material.set_shader_parameter("deck",deck)
	material.set_shader_parameter("bounds_min",bounds.position)
	material.set_shader_parameter("bounds_max",bounds.end)
	material.set_shader_parameter("seam_strength",seam.x)
	material.set_shader_parameter("seam_floor",seam.y)
	material.set_shader_parameter("seam_scale",seam_scale)
	material.set_shader_parameter("deck_stain",stain)
	return material
static func ink() -> ShaderMaterial:
	if _ink == null:
		_ink = Shader.new()
		_ink.code = INK
	var material := ShaderMaterial.new()
	material.shader = _ink
	return material
## deep and far: the water's near and grazing tones; the defaults are outer reach's tuned sea.
static func water(footprints: PackedVector4Array, deep: Vector3 = Vector3(0.16,0.35,0.40), far: Vector3 = Vector3(0.33,0.52,0.54), glitter: float = 0.65) -> ShaderMaterial:
	if _water == null:
		_water = Shader.new()
		_water.code = WATER
	var material := ShaderMaterial.new()
	material.shader = _water
	var count := mini(64,footprints.size())
	var padded := footprints.duplicate()
	padded.resize(64)
	material.set_shader_parameter("supports",padded)
	material.set_shader_parameter("support_count",count)
	material.set_shader_parameter("deep_color",deep)
	material.set_shader_parameter("far_color",far)
	material.set_shader_parameter("glitter_amount",glitter)
	return material
