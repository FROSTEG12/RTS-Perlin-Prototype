shader_type sky;

#include "res://shaders/cloud_common.gdshaderinc"

uniform float coverage : hint_range(0.0, 1.0, 0.01) = 0.23;
uniform float thickness : hint_range(10.0, 100.0, 1.0) = 55.0;
uniform float absorption : hint_range(0.1, 2.0, 0.01) = 0.9;
uniform vec3 sun_direction = vec3(0.0, 0.4, -1.0);

const int MARCH_STEPS = 8;


float fbm_clouds(vec3 position, float lacunarity, float initial_gain, float gain) {
	vec3 point = position;
	float amplitude = initial_gain;
	float value = 0.0;
	for (int octave = 0; octave < 5; octave++) {
		value += abs(cloud_noise(point)) * amplitude;
		point *= lacunarity;
		amplitude *= gain;
	}
	return value;
}


vec3 render_sky_color(vec3 eye_direction) {
	vec3 sun_color = vec3(4.8, 3.14, 3.15) * 0.65;
	float sun_amount = max(dot(eye_direction, normalize(sun_direction)), 0.0);
	vec3 color = mix(
		vec3(0.0, 0.1, 0.4),
		vec3(0.3, 0.67, 0.8) * 0.9,
		1.0 - eye_direction.y
	);
	color += sun_color * min(pow(sun_amount, 355.0) * 6.0, 1.0);
	color += sun_color * min(pow(sun_amount, 8.0) * 0.2, 1.0);
	return color;
}


float density_func(vec3 position, float time) {
	vec3 point = position * 0.001 + vec3(0.0, 0.0, -time * 0.11);
	float density = fbm_clouds(point * 2.032, 2.6434, 0.5, 0.5);
	density *= smoothstep(coverage, coverage + 0.035, density);
	return density;
}


vec4 render_clouds(vec3 eye_direction, vec3 position, float time) {
	if (eye_direction.y <= 0.0001) {
		return vec4(0.0);
	}
	float march_step = thickness / float(MARCH_STEPS);
	vec3 projection = eye_direction / eye_direction.y;
	vec3 iterator = projection * march_step;
	vec3 cloud_position = position + projection * 120.0;
	float alpha = 0.0;
	vec3 cloud_color = vec3(0.0);
	float transmittance = 1.0;

	for (int step_index = 0; step_index < MARCH_STEPS; step_index++) {
		float height = (cloud_position.y - position.y) / thickness;
		float density = density_func(cloud_position, time);
		float step_transmittance = exp(-absorption * density * march_step);
		transmittance *= step_transmittance;
		cloud_color += transmittance * exp(height) * density * march_step;
		alpha += (1.0 - step_transmittance) * (1.0 - alpha);
		cloud_position += iterator;
		if (alpha > 0.99) {
			break;
		}
	}

	vec3 point = cloud_position * 0.001 + vec3(0.0, 0.0, -time * 0.11);
	float detail_red = fbm_clouds(point * 0.322, 2.2434, 0.55, 0.5);
	float detail_green = fbm_clouds(point * 0.2, 2.0, 0.5, 0.52);
	float detail_blue = fbm_clouds(point * 0.2, 2.0, 0.52, 0.5);
	vec3 color_detail = vec3(1.62);
	color_detail.r *= detail_red + 0.35;
	color_detail.g *= detail_green + 0.2;
	color_detail.b *= detail_blue + 0.1;
	color_detail = clamp(color_detail, vec3(0.0), vec3(1.0));

	return vec4(
		pow(max(cloud_color * color_detail, vec3(0.0)), vec3(1.0, 0.9, 0.8)),
		alpha * 0.999
	);
}


void sky() {
	vec3 base_sky = render_sky_color(EYEDIR);
	vec4 clouds = render_clouds(EYEDIR, vec3(0.0, 2.0, 0.0), TIME);
	COLOR = mix(base_sky, clouds.rgb, clouds.a);
}
