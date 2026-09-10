shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform sampler2D previous_mask : filter_linear, repeat_disable;
uniform float mask_blend = 1.0;
uniform float world_size = 104.0;
uniform vec3 shroud_color : source_color = vec3(0.025,0.04,0.055);
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
	float depth = texture(depth_texture,SCREEN_UV).r;
	vec4 p = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth,1.0);
	vec3 point = p.xyz/p.w;
	// Transparent water/sky: use the orthographic ray's ground intersection.
	if (depth < 0.000001 || point.y < -20.0) {
		vec3 ray = normalize(INV_VIEW_MATRIX[2].xyz);
		point -= ray * (point.y/ray.y);
	}
	vec2 uv = point.xz/world_size+0.5;
	vec2 sight = mix(texture(previous_mask,uv).rg,texture(sight_mask,uv).rg,mask_blend);
	// Continue over cliff faces and blend into the void, with no raised-plane gap.
	float exterior = smoothstep(world_size*0.5,world_size*0.5+4.0,max(abs(point.x),abs(point.z)));
	sight *= 1.0-exterior;
	ALBEDO = shroud_color;
	ALPHA = mix(1.0,0.26*(1.0-sight.r),sight.g);
}
