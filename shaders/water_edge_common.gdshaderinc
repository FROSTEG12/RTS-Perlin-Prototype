// Continuous signed flow coordinate: sea < 0, rounded lip = 0.., fall > 0.
// Both surfaces sample the same field at their common boundary.
uniform sampler2D edge_flow_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 edge_shallow_color : source_color = vec3(0.20, 0.43, 0.43);
uniform vec3 edge_deep_color : source_color = vec3(0.10, 0.28, 0.31);
uniform vec3 edge_foam_color : source_color = vec3(0.82, 0.96, 0.93);
uniform float edge_flow_speed = 0.42;

// A shared world-space displacement field, including the two copies of a corner.
vec2 waterfall_outward(vec2 boundary, float half_extent) {
	vec2 proximity = vec2(1.0) - smoothstep(vec2(0.0), vec2(0.65), vec2(half_extent) - abs(boundary));
	return sign(boundary) * proximity;
}

float waterfall_wave(vec2 boundary, float travel, float time) {
	float swell = sin(boundary.x * 0.79 + boundary.y * 0.67 - travel * 0.62 + time * 0.32);
	float ripple = sin(boundary.x * 1.73 - boundary.y * 1.19 - travel * 0.91 + time * 0.23);
	return smoothstep(0.28, 1.4, travel) * (0.13 + 0.10 * swell + 0.025 * ripple);
}

float overflow_crest_foam(vec2 boundary, float travel, float time) {
	// Independent of sea depth/wind gating, so it reaches shallow lateral ends.
	float phase = travel * 0.26 - time * edge_flow_speed * 0.26;
	vec2 uv = vec2(phase * 7.7, (boundary.x + boundary.y) * 2.23);
	float grains = texture(edge_flow_noise, uv + vec2(0.67, 0.21)).b;
	float patch = texture(edge_flow_noise, uv * 0.27 + vec2(0.31, 0.73)).r;
	float zone = (1.0 - smoothstep(0.65, 1.35, abs(travel))) * 0.08;
	return smoothstep(0.52, 0.85, grains) * mix(0.45, 1.0, patch) * zone;
}

vec3 edge_flow(vec2 boundary, float travel, float time) {
	float travel_time = travel <= 0.0 ? travel : log(1.0 + travel * 0.22) / 0.22;
	float along = boundary.x + boundary.y;
	vec2 uv = vec2(travel_time * 0.26 - time * edge_flow_speed * 0.26, along * 0.42);
	float broad = texture(edge_flow_noise, uv).r;
	float fine = texture(edge_flow_noise, uv * vec2(3.1, 2.7) + vec2(0.31, 0.73)).r;
	// High-frequency broken flecks, not broad white Voronoi cell outlines.
	float micro = texture(edge_flow_noise, uv * vec2(7.7, 5.3) + vec2(0.67, 0.21)).b;
	float breakup = smoothstep(0.45, 0.78, micro);
	float foam = smoothstep(0.48, 0.80, fine) * breakup * 0.35;
	return vec3(broad, fine, foam);
}

vec3 edge_water_color(float depth, vec3 flow) {
	return mix(edge_shallow_color, edge_deep_color, smoothstep(0.10, 1.7, depth))
		* mix(0.94, 1.07, flow.x);
}

vec2 edge_outward(vec2 p) {
	return abs(p.x) > abs(p.y) ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y));
}

float overflow_corner_weight(vec2 p, float half_extent) {
	vec2 d = max(vec2(0.0), vec2(half_extent) - abs(p));
	vec2 availability = vec2(1.0) - smoothstep(vec2(0.0), vec2(1.5), d);
	vec2 weights = availability * d.yx * d.yx;
	float total = weights.x + weights.y;
	float x_weight = total > 0.000001 ? weights.x / total : (d.x < d.y ? 1.0 : 0.0);
	// Blend samples, not UVs: interpolated UVs stretch textures on diagonals.
	return x_weight;
}
