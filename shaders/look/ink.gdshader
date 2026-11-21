shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// look C ink: thin and dark up close; far lines widen to min_pixels on screen and lighten instead of
// breaking into shimmering dashes. meshes from r17_contours carry the corner distance in UV.x and the
// corner direction in NORMAL; meshes without them (UV.x == 0) draw at their authored width.
uniform vec4 ink_color : source_color = vec4(0.035,0.065,0.070,1.0);
uniform float ink_alpha = 0.78;
uniform float min_pixels = 1.2;
uniform float fade_near = 28.0;
uniform float fade_far = 95.0;
varying vec3 wp;
varying float coverage;
varying float above;
void vertex(){
 coverage=1.0;
 above=1.0;
 if(UV.x>0.0){
  vec3 centre=VERTEX-NORMAL*UV.x;
  vec3 world_centre=(MODEL_MATRIX*vec4(centre,1.0)).xyz;
  // perspective size goes with view depth (clip w), not radial distance, so screen edges match the centre.
  float depth=max(-(VIEW_MATRIX*vec4(world_centre,1.0)).z,0.05);
  float pixel=depth*2.0/(PROJECTION_MATRIX[1][1]*VIEWPORT_SIZE.y);
  float radius=max(UV.x,pixel*min_pixels*0.7071);
  coverage=UV.x/radius;
  // a deck outline (UV.y = 1) only reads from above; seen from below it would float against the sky.
  if(UV.y>0.5){above=smoothstep(-0.25,0.15,CAMERA_POSITION_WORLD.y-world_centre.y);}
  VERTEX=centre+NORMAL*radius;
 }
 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 ALBEDO=ink_color.rgb;
 ALPHA=above*ink_alpha*mix(0.45,1.0,sqrt(coverage))*(1.0-smoothstep(fade_near,fade_far,distance(wp,CAMERA_POSITION_WORLD)));
}
