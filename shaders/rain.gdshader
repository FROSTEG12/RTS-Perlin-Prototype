shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform float strength = 0.0;
uniform float brightness = 0.6;
uniform float map_half_extent = 52.0;
varying vec3 world_point;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	// Narrow ribbons aligned with their falling trajectory, facing the camera.
	vec3 down = normalize(vec3(0.065, -1.0, 0.025));
	vec3 right = normalize(cross(down, INV_VIEW_MATRIX[2].xyz));
	vec3 p = center + right * VERTEX.x + down * VERTEX.y;
	world_point = p;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
}
void fragment() {
	if (world_point.y < -0.17 || max(abs(world_point.x), abs(world_point.z)) > map_half_extent) { discard; }
	float width = 1.0 - smoothstep(0.0, 0.5, abs(UV.x - 0.5));
	float tips = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	ALBEDO = vec3(0.63, 0.71, 0.76) * brightness;
	ALPHA = width * tips * strength * 0.55;
}
