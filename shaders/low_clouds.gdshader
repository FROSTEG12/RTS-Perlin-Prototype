shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

#include "res://shaders/cloud_common.gdshaderinc"

uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_scale : hint_range(0.005, 0.2, 0.001) = 0.035;
uniform float cloud_speed : hint_range(0.0, 2.0, 0.01) = 0.68;
uniform float visible_coverage : hint_range(0.0, 1.0, 0.01) = 0.61;
uniform float cloud_opacity : hint_range(0.0, 1.0, 0.01) = 0.48;
uniform vec3 cloud_light_color : source_color = vec3(1.0, 0.97, 0.88);
uniform vec3 cloud_shade_color : source_color = vec3(0.48, 0.58, 0.62);

varying vec3 cloud_world_position;


void vertex() {
	cloud_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float density = projected_cloud_density(
		cloud_world_position.xz, TIME, cloud_wind_direction,
		cloud_scale, cloud_speed, visible_coverage
	);
	if (density < 0.012) {
		discard;
	}
	vec2 wind = normalize(cloud_wind_direction);
	vec2 detail_position = cloud_world_position.xz * cloud_scale * 2.8 - wind * TIME * cloud_speed * cloud_scale * 2.8;
	float wisps = cloud_noise(vec3(detail_position, 12.7));
	float soft_core = smoothstep(0.12, 0.88, density);
	vec3 cloud_color = mix(cloud_shade_color, cloud_light_color, clamp(soft_core * 0.76 + wisps * 0.24, 0.0, 1.0));
	ALBEDO = cloud_color;
	EMISSION = cloud_color * 0.14;
	ALPHA = density * cloud_opacity * mix(0.62, 1.0, soft_core);
}
