shader_type sky;

#include "res://shaders/cloud_common.gdshaderinc"

uniform float coverage : hint_range(0.0, 1.0, 0.01) = 0.53;
uniform float thickness : hint_range(10.0, 100.0, 1.0) = 48.0;
uniform float absorption : hint_range(0.1, 2.0, 0.01) = 0.72;
uniform vec3 sun_direction = vec3(0.47, 0.72, 0.51);
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_speed : hint_range(0.0, 2.0, 0.01) = 0.32;

const int MARCH_STEPS = 8;


float sky_cloud_density(vec3 position, float time) {
	vec2 wind = normalize(cloud_wind_direction);
	vec3 sample_position = position * 0.012;
	sample_position.xz -= wind * time * cloud_speed * 0.012;
	float density = cloud_fbm(sample_position * 1.24);
	return density * smoothstep(coverage, coverage + 0.08, density);
}


vec3 render_sky_color(vec3 eye_direction) {
	vec3 horizon = vec3(0.36, 0.61, 0.73);
	vec3 zenith = vec3(0.055, 0.18, 0.34);
	vec3 sky_color = mix(horizon, zenith, clamp(eye_direction.y, 0.0, 1.0));
	float sun_amount = max(dot(eye_direction, normalize(sun_direction)), 0.0);
	sky_color += vec3(1.0, 0.77, 0.49) * min(pow(sun_amount, 180.0) * 4.0, 1.0);
	sky_color += vec3(1.0, 0.68, 0.42) * pow(sun_amount, 8.0) * 0.14;
	return sky_color;
}


vec4 render_clouds(vec3 eye_direction, float time) {
	if (eye_direction.y <= 0.015) {
		return vec4(0.0);
	}
	float march_step = thickness / float(MARCH_STEPS);
	vec3 projection = eye_direction / eye_direction.y;
	vec3 cloud_position = projection * 95.0;
	vec3 iterator = projection * march_step;
	float transmittance = 1.0;
	float alpha = 0.0;
	vec3 cloud_color = vec3(0.0);
	for (int step_index = 0; step_index < MARCH_STEPS; step_index++) {
		float height = float(step_index) / float(MARCH_STEPS - 1);
		float density = sky_cloud_density(cloud_position, time);
		float step_transmittance = exp(-absorption * density * march_step * 0.055);
		transmittance *= step_transmittance;
		cloud_color += transmittance * mix(vec3(0.48, 0.55, 0.60), vec3(1.0, 0.94, 0.82), height) * density * march_step * 0.035;
		alpha += (1.0 - step_transmittance) * (1.0 - alpha);
		cloud_position += iterator;
	}
	return vec4(clamp(cloud_color, vec3(0.0), vec3(1.0)), alpha * 0.92);
}


void sky() {
	vec3 base_sky = render_sky_color(EYEDIR);
	vec4 clouds = render_clouds(EYEDIR, TIME);
	COLOR = mix(base_sky, clouds.rgb, clouds.a);
}
