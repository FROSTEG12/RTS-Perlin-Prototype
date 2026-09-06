float cloud_shadow_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


float cloud_shadow_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(cloud_shadow_hash(cell), cloud_shadow_hash(cell + vec2(1.0, 0.0)), local.x),
		mix(cloud_shadow_hash(cell + vec2(0.0, 1.0)), cloud_shadow_hash(cell + vec2(1.0)), local.x),
		local.y
	);
}


// Cheap three-octave 2D shadow field. It is evaluated directly in world space,
// so camera movement cannot move or restart the drifting patches.
float projected_cloud_density(
	vec2 world_position,
	float time,
	vec2 wind_direction,
	float scale,
	float speed,
	float coverage
) {
	vec2 wind = normalize(wind_direction);
	vec2 point = world_position * scale - wind * time * speed * scale;
	float value = 0.0;
	float amplitude = 0.55;
	mat2 rotation = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int octave = 0; octave < 3; octave++) {
		value += cloud_shadow_noise(point) * amplitude;
		point = rotation * point * 2.13 + vec2(5.7, -3.9);
		amplitude *= 0.48;
	}
	return smoothstep(coverage, coverage + 0.13, value);
}
