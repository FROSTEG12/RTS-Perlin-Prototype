shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform float world_size = 104.0;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 p = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth,1.0);
	vec3 world = p.xyz / p.w;
	vec2 uv = world.xz / world_size + 0.5;
	vec2 mask = texture(sight_mask, uv).rg;
	float inside = step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
	ALBEDO = vec3(0.035,0.065,0.09);
	ALPHA = inside * smoothstep(0.6,0.96,mask.g) * (1.0-mask.r) * 0.42;
}
