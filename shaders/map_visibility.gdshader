shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform sampler2D previous_mask : filter_linear, repeat_disable;
uniform float mask_blend = 1.0;
uniform float world_size = 104.0;
uniform float memory_darkness = 0.65;
uniform float edge_time = 0.0;
uniform vec3 shroud_color : source_color = vec3(0.025,0.04,0.055);
float edge_hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float edge_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*f*(f*(f*6.0-15.0)+10.0);
	return mix(mix(edge_hash(cell),edge_hash(cell+vec2(1,0)),f.x),
		mix(edge_hash(cell+vec2(0,1)),edge_hash(cell+vec2(1,1)),f.x),f.y);
}
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
	float opacity = mix(1.0,memory_darkness*(1.0-sight.r),sight.g);
	// Only add cover inside the existing feather. Never reveal an unknown pixel,
	// alter logical sight/history, or animate the current-sight boundary in known land.
	if (sight.g > 0.0 && sight.g < 1.0) {
		vec2 drift = edge_time*vec2(0.055,-0.04);
		float broad = edge_noise(point.xz*0.62+drift);
		float detail = edge_noise(point.xz*1.45-drift*0.7+vec2(13.4,7.1));
		float flow = broad*0.72+detail*0.28;
		float band = smoothstep(0.0,0.18,sight.g)*(1.0-smoothstep(0.72,1.0,sight.g));
		opacity = mix(opacity,1.0,band*(0.06+flow*0.58));
	}
	ALPHA = opacity;
}
