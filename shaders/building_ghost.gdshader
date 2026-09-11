shader_type spatial;
// A placement indicator, not geometry in the world: visible through trees,
// no depth/shadows/scene mutation. Kept below the fog-of-war composite.
render_mode unshaded, blend_mix, cull_back, depth_draw_never, depth_test_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.4,0.85,1.0,1.0);
varying vec3 world_normal;
void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float rim = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.5);
	float shape = 0.57+0.43*max(dot(normalize(world_normal),normalize(vec3(-0.4,0.85,0.3))),0.0);
	ALBEDO = tint.rgb*shape;
	ALPHA = 0.32+rim*0.16;
}
