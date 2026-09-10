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
// Cubic B-spline reconstruction: four bilinear taps remove the mask's square
// texel shoulders at close zoom without changing its CPU resolution or sight rules.
vec2 smooth_mask(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex,0));
	vec2 p = uv*size-0.5;
	vec2 base = floor(p);
	vec2 f = fract(p);
	vec2 a = (1.0-f)*(1.0-f)*(1.0-f)/6.0;
	vec2 b = (3.0*f*f*f-6.0*f*f+4.0)/6.0;
	vec2 c = (-3.0*f*f*f+3.0*f*f+3.0*f+1.0)/6.0;
	vec2 d = f*f*f/6.0;
	vec2 lo = a+b;
	vec2 hi = c+d;
	vec2 p0 = (base-1.0+b/lo+0.5)/size;
	vec2 p1 = (base+1.0+d/hi+0.5)/size;
	return texture(tex,p0).rg*lo.x*lo.y
		+texture(tex,vec2(p1.x,p0.y)).rg*hi.x*lo.y
		+texture(tex,vec2(p0.x,p1.y)).rg*lo.x*hi.y
		+texture(tex,p1).rg*hi.x*hi.y;
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
	vec2 raw_sight = mix(texture(previous_mask,uv).rg,texture(sight_mask,uv).rg,mask_blend);
	vec2 sight = mix(smooth_mask(previous_mask,uv),smooth_mask(sight_mask,uv),mask_blend);
	// Reconstruction must not uncover any fully unknown pixel.
	sight *= smoothstep(vec2(0.0),vec2(0.025),raw_sight);
	// Euclidean distance rounds corners instead of forming diagonal max-axis wedges.
	float exterior = smoothstep(0.0,6.0,length(max(abs(point.xz)-vec2(world_size*0.5),vec2(0.0))));
	sight *= 1.0-exterior;
	ALBEDO = shroud_color;
	float opacity = mix(1.0,memory_darkness*(1.0-sight.r),sight.g);
	// Only add cover inside the existing feather. Never reveal an unknown pixel,
	// alter logical sight/history, or animate the current-sight boundary in known land.
	if (sight.g > 0.0 && sight.g < 1.0) {
		vec2 drift = edge_time*vec2(0.28,-0.19);
		vec2 warp = vec2(edge_noise(point.xz*0.22+drift*0.7),
			edge_noise(point.xz*0.22-drift*0.6+vec2(17.1,8.3)))-0.5;
		float broad = edge_noise(point.xz*0.42+warp*1.8+drift);
		float curl = edge_noise(point.xz*0.75-warp-drift*0.8+vec2(13.4,7.1));
		float flow = smoothstep(0.18,0.82,broad*0.78+curl*0.22);
		// Move the silhouette through the feather, not just its faint brightness.
		// Exponent >= 1 only pulls darkness inward: no visibility is granted.
		float living_edge = pow(sight.g,1.0+7.0*flow);
		opacity = mix(1.0,memory_darkness*(1.0-sight.r),living_edge);
	}
	ALPHA = opacity;
}
