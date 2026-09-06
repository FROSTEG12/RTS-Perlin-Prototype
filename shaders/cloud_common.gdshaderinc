float cloud_hash(float value) {
	return fract(sin(value) * 753.5453123);
}


float cloud_noise(vec3 point) {
	vec3 cell = floor(point);
	vec3 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float seed = cell.x + cell.y * 157.0 + cell.z * 113.0;
	return mix(
		mix(
			mix(cloud_hash(seed), cloud_hash(seed + 1.0), local.x),
			mix(cloud_hash(seed + 157.0), cloud_hash(seed + 158.0), local.x),
			local.y
		),
		mix(
			mix(cloud_hash(seed + 113.0), cloud_hash(seed + 114.0), local.x),
			mix(cloud_hash(seed + 270.0), cloud_hash(seed + 271.0), local.x),
			local.y
		),
		local.z
	);
}


float cloud_fbm(vec3 point) {
	float value = 0.0;
	float amplitude = 0.52;
	for (int octave = 0; octave < 5; octave++) {
		value += abs(cloud_noise(point)) * amplitude;
		// Rotate and offset every octave so the value-noise cell diagonals never
		// stack into a large geometric edge in the final cloud silhouette.
		point = vec3(
			point.x * 0.80 + point.z * 0.60,
			point.y * 0.86 + point.x * 0.32 - point.z * 0.18,
			-point.x * 0.51 + point.y * 0.22 + point.z * 0.83
		) * 2.17 + vec3(7.1, 3.7, 5.3);
		amplitude *= 0.48;
	}
	return value;
}


float projected_cloud_density(
	vec2 world_position,
	float time,
	vec2 wind_direction,
	float scale,
	float speed,
	float coverage
) {
	vec2 wind = normalize(wind_direction);
	vec2 advected = world_position * scale - wind * time * speed * scale;
	// Project the same 3D density volume used by the visible ray marcher. Four
	// height samples keep the shadow soft and in lockstep with the cloud.
	float projected = 0.0;
	for (int height_step = 0; height_step < 4; height_step++) {
		float height = (float(height_step) + 0.5) / 4.0;
		vec3 point = vec3(advected.x, (7.5 + height * 5.0) * scale, advected.y);
		float density = cloud_fbm(point * 2.032);
		projected += density * smoothstep(coverage, coverage + 0.035, density);
	}
	return smoothstep(0.18, 0.78, projected * 0.25);
}
