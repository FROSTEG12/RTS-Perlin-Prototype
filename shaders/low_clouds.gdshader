shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

#include "res://shaders/cloud_common.gdshaderinc"

uniform float coverage : hint_range(0.0, 1.0) = 0.56;
uniform float thickness : hint_range(1.0, 10.0) = 4.8;
uniform float absorption : hint_range(0.1, 2.0) = 0.9;
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_speed : hint_range(0.0, 2.0, 0.01) = 0.68;
uniform float world_scale : hint_range(0.001, 0.2, 0.001) = 0.022;

const int MARCH_STEPS = 8;

varying vec3 cloud_layer_position;


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


float density_func(vec3 position, float height, float time) {
	vec2 wind = normalize(cloud_wind_direction);
	vec3 point = position * world_scale;
	point.xz -= wind * time * cloud_speed * world_scale;
	float density = fbm_clouds(point * 2.032, 2.6434, 0.5, 0.5);
	density *= smoothstep(coverage, coverage + 0.035, density);
	return density;
}


vec4 render_clouds(vec3 eye_direction, vec3 position, float time) {
	float march_step = thickness / float(MARCH_STEPS);
	// The tutorial marches upward into the sky. Our camera is above the layer,
	// so preserve the same unit-height projection while marching downward.
	vec3 projection = eye_direction / max(abs(eye_direction.y), 0.05);
	vec3 iterator = projection * march_step;
	vec3 cloud_position = position;
	float alpha = 0.0;
	vec3 cloud_color = vec3(0.0);
	float transmittance = 1.0;

	for (int step_index = 0; step_index < MARCH_STEPS; step_index++) {
		float height = (cloud_position.y - (position.y - thickness)) / thickness;
		float density = density_func(cloud_position, height, time);
		float step_transmittance = exp(-absorption * density * march_step);
		transmittance *= step_transmittance;
		cloud_color += transmittance * exp(height) * density * march_step;
		alpha += (1.0 - step_transmittance) * (1.0 - alpha);
		cloud_position += iterator;
		if (alpha > 0.99) {
			break;
		}
	}

	vec2 wind = normalize(cloud_wind_direction);
	vec3 detail_position = cloud_position * world_scale;
	detail_position.xz -= wind * time * cloud_speed * world_scale;
	float density_red = fbm_clouds(detail_position * 0.322, 2.2434, 0.55, 0.5);
	float density_green = fbm_clouds(detail_position * 0.2, 2.0, 0.5, 0.52);
	float density_blue = fbm_clouds(detail_position * 0.2, 2.0, 0.52, 0.5);
	vec3 color_detail = vec3(1.62);
	color_detail.g *= density_green + 0.2;
	color_detail.b *= density_blue + 0.1;
	color_detail = clamp(color_detail, vec3(0.0), vec3(1.0));

	return vec4(pow(cloud_color * color_detail, vec3(1.0, 0.9, 0.8)), alpha * 0.999);
}


void vertex() {
	cloud_layer_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec3 eye_direction = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	vec4 cloud = render_clouds(eye_direction, cloud_layer_position, TIME);
	if (cloud.a < 0.008) {
		discard;
	}
	ALBEDO = clamp(cloud.rgb, vec3(0.0), vec3(1.0));
	EMISSION = ALBEDO * 0.08;
	ALPHA = cloud.a;
}
