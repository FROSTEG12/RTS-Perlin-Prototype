shader_type spatial;
render_mode cull_disabled, unshaded;

#include "res://shaders/cloud_common.gdshaderinc"

uniform sampler2D grass_texture : repeat_enable, filter_nearest;
uniform sampler2D shore_distance_texture : filter_linear, repeat_disable;
uniform float texture_scale = 0.095;
uniform float map_world_size = 104.0;
uniform vec3 wet_sand_color : source_color = vec3(0.48, 0.38, 0.22);
uniform vec3 dry_sand_color : source_color = vec3(0.76, 0.63, 0.38);
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_scale : hint_range(0.005, 0.2, 0.001) = 0.046;
uniform float cloud_speed : hint_range(0.0, 2.0, 0.01) = 0.68;
uniform float cloud_coverage : hint_range(0.0, 1.0, 0.01) = 0.47;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.76;
uniform vec3 cloud_shadow_tint : source_color = vec3(0.24, 0.31, 0.35);

varying vec3 world_position;


float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 grass = texture(grass_texture, world_position.xz * texture_scale).rgb;
	vec2 map_uv = world_position.xz / map_world_size + vec2(0.5);
	float land_distance = texture(shore_distance_texture, map_uv).g;
	float sand_detail = dot(grass, vec3(0.24, 0.62, 0.14));
	float sand_macro = value_noise(world_position.xz * 0.72);
	float sand_grain = value_noise(world_position.xz * 8.5 + vec2(17.0, -9.0));
	vec3 wet_sand = wet_sand_color * mix(0.92, 1.08, sand_detail);
	vec3 dry_sand = dry_sand_color * mix(0.90, 1.10, sand_detail);
	float wet_to_dry = smoothstep(0.002, 0.019, land_distance + (sand_macro - 0.5) * 0.005);
	vec3 sand = mix(wet_sand, dry_sand, wet_to_dry);
	sand *= mix(0.94, 1.07, sand_grain);
	float beach_distance = land_distance + (sand_macro - 0.5) * 0.018;
	float sand_to_grass = smoothstep(0.030, 0.094, beach_distance);
	float irregular_transition = smoothstep(0.18, 0.82, sand_detail);
	sand_to_grass = clamp(sand_to_grass + (irregular_transition - 0.5) * 0.18, 0.0, 1.0);
	ALBEDO = mix(sand, grass, sand_to_grass);
	float cloud_shadow = projected_cloud_density(
		world_position.xz, TIME, cloud_wind_direction,
		cloud_scale, cloud_speed, cloud_coverage
	);
	ALBEDO *= mix(vec3(1.0), cloud_shadow_tint, cloud_shadow * cloud_shadow_strength);
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
