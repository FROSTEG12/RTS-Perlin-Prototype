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
	vec2 position = world_position * scale - wind * time * speed * scale;
	// Warp the low-frequency sampling lattice before building the volume. This
	// prevents the interpolation grid from showing up as diagonal polygons when
	// the shadow contrast is intentionally high.
	vec2 domain_warp = vec2(
		cloud_noise(vec3(position * 0.47, 11.3)),
		cloud_noise(vec3(position * 0.47 + vec2(5.7, -8.1), 17.6))
	) - vec2(0.5);
	position += domain_warp * 1.45;
	// Balanced height samples retain the guide's volumetric absorption idea
	// without allowing one coarse octave to dictate the complete silhouette.
	float lower = cloud_fbm(vec3(position * 1.05, 1.7));
	float middle = cloud_fbm(vec3(position * 0.88 + vec2(7.3, -4.1), 3.9));
	float upper = cloud_fbm(vec3(position * 1.27 + vec2(-3.8, 6.2), 6.4));
	float detail = cloud_fbm(vec3(position * 2.10 + vec2(13.1, 2.7), 9.2));
	float volume = lower * 0.36 + middle * 0.29 + upper * 0.22 + detail * 0.13;
	return smoothstep(coverage - 0.025, coverage + 0.19, volume);
}
