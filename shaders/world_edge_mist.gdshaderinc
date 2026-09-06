// Ray-integrated, world-space mist. Shared by cliff, falls and the backdrop:
// no transparent sheets, no sorting cracks, correct orthographic view rays.
uniform vec3 mist_color = vec3(0.126, 0.179, 0.205);
float mist_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float mist_noise(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(mist_hash(i), mist_hash(i + vec3(1,0,0)), f.x),
		mix(mist_hash(i + vec3(0,1,0)), mist_hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(mist_hash(i + vec3(0,0,1)), mist_hash(i + vec3(1,0,1)), f.x),
		mix(mist_hash(i + vec3(0,1,1)), mist_hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
vec4 edge_mist(vec3 surface, vec3 to_camera) {
	float ray_length = max(0.0, -0.8 - surface.y) / max(0.1, to_camera.y);
	if (ray_length < 0.001) { return vec4(mist_color, 0.0); }
	vec3 start = surface + to_camera * ray_length;
	// Identical world-height slices on every surface and on the backdrop.
	// Variable steps caused visible differences where the cliff mesh ended.
	float slice_length = 0.5 / max(0.1, to_camera.y);
	vec3 light_sum = vec3(0.0);
	float transmission = 1.0;
	vec3 drift = vec3(TIME * 0.035, TIME * 0.009, -TIME * 0.019);
	for (int i = 0; i < 32; i++) {
		float traveled = float(i) * slice_length;
		float step_length = min(slice_length, max(0.0, ray_length - traveled));
		if (step_length <= 0.0) { break; }
		vec3 p = start - to_camera * (traveled + 0.5 * step_length);
		vec3 q = p * vec3(0.16, 0.25, 0.16) + drift;
		float broad = mist_noise(q);
		float detail = mist_noise(q * 2.31 + vec3(7.1, 3.8, 11.3));
		float cloud = smoothstep(0.33, 0.72, broad * 0.75 + detail * 0.25);
		float height_envelope = smoothstep(0.8, 3.0, -p.y);
		float basal = smoothstep(5.0, 10.0, -p.y) * 0.90;
		float density = (cloud * 0.65 + basal) * height_envelope;
		float opacity = 1.0 - exp(-density * step_length);
		float lighting = smoothstep(0.26, 0.74, mist_noise(p * vec3(0.11, 0.035, 0.11) + drift));
		vec3 color = mist_color * mix(0.48, 1.75, lighting);
		light_sum += color * transmission * opacity;
		transmission *= 1.0 - opacity;
	}
	float alpha = 1.0 - transmission;
	return vec4(light_sum / max(alpha, 0.0001), alpha);
}
