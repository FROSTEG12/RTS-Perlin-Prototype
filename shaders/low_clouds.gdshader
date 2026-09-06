shader_type canvas_item;
render_mode unshaded, blend_mix;

#include "res://shaders/cloud_common.gdshaderinc"

uniform vec3 camera_position;
uniform vec3 camera_right;
uniform vec3 camera_up;
uniform vec3 camera_forward;
uniform float ortho_size = 22.0;
uniform float viewport_aspect = 1.7778;

uniform float coverage : hint_range(0.0, 1.0, 0.01) = 0.63;
uniform float cloud_bottom = 7.5;
uniform float thickness : hint_range(1.0, 12.0, 0.1) = 5.0;
uniform float absorption : hint_range(0.1, 2.0, 0.01) = 0.82;
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_speed : hint_range(0.0, 2.0, 0.01) = 0.68;
uniform float world_scale : hint_range(0.001, 0.2, 0.001) = 0.034;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 0.82;

const int MARCH_STEPS = 8;


float density_func(vec3 position, float time) {
	vec2 wind = normalize(cloud_wind_direction);
	vec3 point = position * world_scale;
	point.xz -= wind * time * cloud_speed * world_scale;
	float density = cloud_fbm(point * 2.032);
	density *= smoothstep(coverage, coverage + 0.035, density);
	return density;
}


vec4 render_clouds(vec3 ray_origin, vec3 eye_direction, float time) {
	float cloud_top = cloud_bottom + thickness;
	if (eye_direction.y >= -0.0001 || ray_origin.y <= cloud_bottom) {
		return vec4(0.0);
	}

	float entry_distance = (cloud_top - ray_origin.y) / eye_direction.y;
	float exit_distance = (cloud_bottom - ray_origin.y) / eye_direction.y;
	float start_distance = max(entry_distance, 0.0);
	float end_distance = max(exit_distance, start_distance);
	float ray_length = end_distance - start_distance;
	if (ray_length <= 0.0001) {
		return vec4(0.0);
	}

	float march_step = ray_length / float(MARCH_STEPS);
	vec3 iterator = eye_direction * march_step;
	vec3 cloud_position = ray_origin + eye_direction * (start_distance + march_step * 0.5);
	float alpha = 0.0;
	vec3 cloud_color = vec3(0.0);
	float transmittance = 1.0;

	for (int step_index = 0; step_index < MARCH_STEPS; step_index++) {
		float height = clamp((cloud_position.y - cloud_bottom) / thickness, 0.0, 1.0);
		float density = density_func(cloud_position, time);
		float vertical_shape = smoothstep(0.0, 0.14, height) * (1.0 - smoothstep(0.78, 1.0, height));
		density *= mix(0.38, 1.0, vertical_shape);
		float step_transmittance = exp(-absorption * density * march_step);
		vec3 sample_color = mix(vec3(0.56, 0.60, 0.63), vec3(1.0, 0.98, 0.91), height);
		float contribution = transmittance * (1.0 - step_transmittance);
		cloud_color += sample_color * contribution;
		transmittance *= step_transmittance;
		alpha += (1.0 - step_transmittance) * (1.0 - alpha);
		cloud_position += iterator;
		if (alpha > 0.99) {
			break;
		}
	}

	vec2 wind = normalize(cloud_wind_direction);
	vec3 detail_position = cloud_position * world_scale;
	detail_position.xz -= wind * time * cloud_speed * world_scale;
	float detail_green = cloud_fbm(detail_position * 0.2);
	float detail_blue = cloud_fbm(detail_position * 0.2 + vec3(3.7, 5.1, 8.3));
	vec3 color_detail = vec3(
		1.0,
		mix(0.92, 1.0, clamp(detail_green, 0.0, 1.0)),
		mix(0.88, 0.98, clamp(detail_blue, 0.0, 1.0))
	);
	vec3 color = cloud_color / max(alpha, 0.001);
	color = pow(max(color * color_detail, vec3(0.0)), vec3(1.0, 0.9, 0.8));
	return vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha * opacity);
}


void fragment() {
	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	vec3 ray_origin = camera_position;
	ray_origin += camera_right * centered_uv.x * ortho_size * viewport_aspect;
	ray_origin -= camera_up * centered_uv.y * ortho_size;
	vec4 cloud = render_clouds(ray_origin, normalize(camera_forward), TIME);
	if (cloud.a < 0.004) {
		discard;
	}
	COLOR = cloud;
}
