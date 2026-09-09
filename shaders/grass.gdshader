shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/cloud_common.gdshaderinc"

uniform sampler2D grass_texture : repeat_enable, filter_nearest;
uniform sampler2D shore_distance_texture : filter_linear, repeat_disable;
uniform sampler2D trail_wear_texture : filter_linear, repeat_disable;
uniform sampler2D trail_soil_texture : repeat_enable, filter_linear_mipmap;
uniform float trail_pixel_size = 0.08;
uniform float trail_soil_scale = 0.28;
uniform bool trails_enabled = true;
uniform sampler2D blood_field_texture : filter_linear, repeat_disable;
uniform bool blood_enabled = false;
uniform vec3 blood_fresh_color : source_color = vec3(0.40, 0.065, 0.075);
uniform vec3 blood_dry_color : source_color = vec3(0.27, 0.060, 0.045);
uniform float texture_scale = 0.095;
uniform float map_world_size = 104.0;
uniform vec3 wet_sand_color : source_color = vec3(0.69, 0.63, 0.49);
uniform vec3 dry_sand_color : source_color = vec3(0.88, 0.82, 0.67);
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform vec2 cloud_shadow_offset = vec2(0.0);
uniform float cloud_shadow_scale : hint_range(0.005, 0.2, 0.001) = 0.085;
uniform float cloud_shadow_speed : hint_range(0.0, 2.0, 0.01) = 0.18;
uniform float cloud_shadow_coverage : hint_range(0.0, 1.0, 0.01) = 0.64;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform vec3 cloud_shadow_tint : source_color = vec3(0.46, 0.52, 0.53);

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
	if (trails_enabled) {
		float wear = texture(trail_wear_texture, map_uv).r;
		// Fixed world-space thresholds reveal more pixels as traffic increases.
		// No TIME/screen-space noise: existing patches never shuffle or sparkle.
		vec2 pixel_grid = world_position.xz / trail_pixel_size;
		float threshold = mix(0.10, 0.90, hash21(floor(pixel_grid)));
		float patches = smoothstep(threshold - 0.075, threshold + 0.075, wear);
		// Subpixel details converge to coverage when zoomed out, avoiding aliasing.
		vec2 footprint = fwidth(pixel_grid);
		float distant = smoothstep(0.7, 1.6, max(footprint.x, footprint.y));
		float coverage = mix(patches, wear, distant);
		// Trails replace grass, not beach sand or the submerged seabed.
		coverage *= smoothstep(0.70, 0.97, sand_to_grass);
		vec3 soil = texture(trail_soil_texture, world_position.xz * trail_soil_scale).rgb;
		soil = floor(soil * 24.0 + 0.5) / 24.0;
		soil *= vec3(1.25, 1.15, 1.0);
		ALBEDO = mix(ALBEDO, soil, coverage);
	}
	if (blood_enabled) {
		vec2 grid = world_position.xz / 0.025;
		vec2 fixed_point = (floor(grid) + vec2(0.5)) * 0.025;
		vec2 blood = texture(blood_field_texture, fixed_point / map_world_size + vec2(0.5)).rg;
		// Two fixed noise scales create lobes and pixel-sized broken edges.
		// No TIME or per-stamp colour: intersections merge into one material.
		float shape = value_noise(fixed_point * 9.0 + vec2(31.7, 9.4));
		float detail = hash21(floor(grid) + vec2(17.0, 83.0));
		float threshold = mix(0.045, 0.92, shape * 0.35 + detail * 0.65);
		float coverage = step(threshold, blood.r);
		vec2 footprint = fwidth(grid);
		float distant = smoothstep(1.0, 2.0, max(footprint.x, footprint.y));
		coverage = mix(coverage, smoothstep(0.10, 0.85, blood.r), distant);
		coverage *= smoothstep(0.015, 0.10, blood.r) * 0.94;
		coverage *= smoothstep(-0.11, -0.07, world_position.y);
		float freshness = floor(blood.g * 3.0 + 0.5) / 3.0;
		vec3 pigment = mix(blood_dry_color, blood_fresh_color, freshness);
		// Four discrete pigment tones per age stage, not a noise-driven gradient.
		// World-anchored cells share a palette even where contacts overlap.
		float mottling = value_noise(fixed_point * 18.0 + vec2(92.0, 4.0));
		float tone = floor(clamp(mottling * 0.85 + (1.0 - blood.r) * 0.15, 0.0, 0.999) * 4.0) / 3.0;
		pigment *= mix(0.48, 1.4, tone);
		ALBEDO = mix(ALBEDO, pigment, coverage);
	}
	float cloud_shadow = projected_cloud_density(
		world_position.xz + cloud_shadow_offset, TIME, cloud_wind_direction,
		cloud_shadow_scale, cloud_shadow_speed, cloud_shadow_coverage
	);
	ALBEDO *= mix(vec3(1.0), cloud_shadow_tint, cloud_shadow * cloud_shadow_strength);
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
