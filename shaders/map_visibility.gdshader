shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform sampler2D previous_mask : filter_linear, repeat_disable;
uniform float mask_blend = 1.0;
uniform float world_size = 104.0;
uniform float memory_darkness = 0.65;
uniform vec3 shroud_color : source_color = vec3(0.025,0.04,0.055);
void vertex() { POSITION = vec4(VERTEX.xy,1.0,1.0); }
void fragment() {
	// One continuous ground-plane projection for terrain, cliffs, water and void.
	// Sampling scene depth switched coordinate systems at geometry edges/y=-20,
	// which exposed triangular wedges and cut the cliff silhouettes into the mask.
	vec4 p = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,1.0,1.0);
	vec3 point = p.xyz/p.w;
	vec3 ray = normalize(INV_VIEW_MATRIX[2].xyz);
	point -= ray * (point.y/ray.y);
	vec2 uv = point.xz/world_size+0.5;
	vec2 sight = mix(texture(previous_mask,uv).rg,texture(sight_mask,uv).rg,mask_blend);
	// Euclidean distance rounds corners instead of forming diagonal max-axis wedges.
	float exterior = smoothstep(0.0,6.0,length(max(abs(point.xz)-vec2(world_size*0.5),vec2(0.0))));
	sight *= 1.0-exterior;
	ALBEDO = shroud_color;
	ALPHA = mix(1.0,memory_darkness*(1.0-sight.r),sight.g);
}
