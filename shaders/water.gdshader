shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://shaders/cloud_common.gdshaderinc"

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D map_depth_texture : filter_linear, repeat_disable;
uniform float map_world_size = 104.0;

uniform float max_depth : hint_range(0.1, 10.0, 0.1) = 2.6;
uniform float water_level : hint_range(-2.0, 2.0, 0.01) = -0.16;
uniform float fade_start_depth : hint_range(0.0, 3.0, 0.01) = 0.18;

uniform float sea_height : hint_range(0.0, 0.25) = 0.045;
uniform float sea_choppy : hint_range(0.0, 10.0) = 2.15;
uniform float sea_speed : hint_range(0.0, 5.0) = 0.72;
uniform float sea_freq : hint_range(0.0, 2.0) = 0.20;
uniform int ITER_GEOMETRY = 4;
uniform int ITER_FRAGMENT = 5;
const mat2 octave_m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));

uniform float refraction_strength : hint_range(0.0, 2.0, 0.01) = 0.22;
uniform float refraction_distance_fade : hint_range(0.0, 100.0, 1.0) = 28.0;
uniform float normal_epsilon : hint_range(0.001, 1.0) = 0.072;
uniform float normal_smoothness_dist : hint_range(0.0, 1000.0) = 55.0;
uniform float camera_ortho_size = 22.0;

uniform vec3 underwater_fog_color : source_color = vec3(0.055, 0.23, 0.30);
uniform vec3 base_tint_color : source_color = vec3(0.54, 0.84, 0.87);
uniform vec3 deep_color : source_color = vec3(0.035, 0.27, 0.36);
uniform vec3 water_absorption : source_color = vec3(0.24, 0.10, 0.07);

uniform float roughness : hint_range(0.0, 1.0) = 0.24;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.48;

uniform sampler2D caustics_texture : filter_linear_mipmap, repeat_enable;
uniform float caustics_scale : hint_range(0.1, 10.0, 0.1) = 2.0;
uniform float caustics_speed : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float caustics_intensity : hint_range(0.0, 2.0, 0.1) = 0.16;
uniform float caustics_depth_fade : hint_range(0.0, 1.0, 0.01) = 0.62;

uniform vec3 foam_color : source_color = vec3(0.96, 1.0, 0.98);
uniform vec3 foam_thin_color : source_color = vec3(0.82, 0.96, 0.93);
uniform vec3 shallow_surface_color : source_color = vec3(0.075, 0.39, 0.45);
uniform vec3 deep_surface_color : source_color = vec3(0.025, 0.19, 0.29);
uniform float foam_depth_start : hint_range(0.0, 5.0, 0.01) = 0.48;
uniform float foam_depth_end : hint_range(0.0, 5.0, 0.01) = 0.06;
uniform float foam_noise_scale : hint_range(0.0, 10.0, 0.01) = 3.2;
uniform float foam_noise_speed : hint_range(0.0, 2.0, 0.01) = 0.18;
uniform float foam_cutoff : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float foam_crest_threshold : hint_range(0.0, 1.0, 0.01) = 0.74;
uniform float foam_crest_amount : hint_range(0.0, 10.0, 0.1) = 0.72;
uniform vec3 foam_edge_color : source_color = vec3(0.68, 0.89, 0.87);
uniform vec2 foam_edge_offset = vec2(0.035, 0.035);
uniform float voronoi_scale : hint_range(0.0, 50.0) = 18.0;
uniform float voronoi_strength : hint_range(0.0, 8.0) = 0.72;
uniform vec2 wind_direction = vec2(0.91, 0.41);
uniform float wind_foam_speed : hint_range(0.0, 3.0, 0.01) = 0.08;
uniform float wind_streak_length : hint_range(0.1, 10.0, 0.1) = 0.62;
uniform float wind_streak_density : hint_range(0.1, 20.0, 0.1) = 13.0;
uniform float shore_wave_speed : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float shore_wave_frequency : hint_range(1.0, 40.0, 0.5) = 16.0;
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_shadow_scale : hint_range(0.005, 0.2, 0.001) = 0.095;
uniform float cloud_shadow_speed : hint_range(0.0, 2.0, 0.01) = 0.24;
uniform float cloud_shadow_coverage : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.84;
uniform vec3 cloud_shadow_tint : source_color = vec3(0.22, 0.31, 0.36);

varying vec3 world_vert;
varying float wave_height;
varying vec3 vertex_normal_world;


float hash12(vec2 p) {
	uvec2 q = uvec2(ivec2(p)) * uvec2(1597334677u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334677u;
	return float(n) * (1.0 / 4294967295.0);
}


float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return -1.0 + 2.0 * mix(
		mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0)), u.x), u.y
	);
}


float sea_octave(vec2 uv, float choppy) {
	uv += noise(uv);
	vec2 wv = 1.0 - abs(sin(uv));
	vec2 swv = abs(cos(uv));
	wv = mix(wv, swv, wv);
	return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}


float map(vec3 p, float time) {
	float freq = sea_freq;
	float amp = sea_height;
	float choppy = sea_choppy;
	vec2 uv = p.xz;
	uv.x *= 0.75;
	float h = 0.0;
	for (int i = 0; i < ITER_GEOMETRY; i++) {
		float d = sea_octave((uv + time * sea_speed) * freq, choppy);
		d += sea_octave((uv - time * sea_speed) * freq, choppy);
		h += d * amp;
		uv *= octave_m;
		freq *= 1.9;
		amp *= 0.22;
		choppy = mix(choppy, 1.0, 0.2);
	}
	return p.y - h;
}


float map_detailed(vec3 p, float time) {
	float freq = sea_freq;
	float amp = sea_height;
	float choppy = sea_choppy;
	vec2 uv = p.xz;
	uv.x *= 0.75;
	float h = 0.0;
	for (int i = 0; i < ITER_FRAGMENT; i++) {
		float d = sea_octave((uv + time * sea_speed) * freq, choppy);
		d += sea_octave((uv - time * sea_speed) * freq, choppy);
		h += d * amp;
		uv *= octave_m;
		freq *= 1.9;
		amp *= 0.22;
		choppy = mix(choppy, 1.0, 0.2);
	}
	return p.y - h;
}


vec3 get_normal_detailed(vec3 p, float eps, float time) {
	vec3 n;
	n.y = map_detailed(p, time);
	n.x = map_detailed(vec3(p.x + eps, p.y, p.z), time) - n.y;
	n.z = map_detailed(vec3(p.x, p.y, p.z + eps), time) - n.y;
	n.y = eps;
	return normalize(n);
}


float get_linear_depth(sampler2D depth_texture, vec2 uv, mat4 inverse_projection) {
	float depth = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ndc.z = depth * 2.0 - 1.0;
	#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}


float hash13(vec3 p) {
	uvec3 q = uvec3(ivec3(p)) * uvec3(1597334677u, 3812015801u, 2798796415u);
	uint n = (q.x ^ q.y ^ q.z) * 1597334677u;
	return float(n) * (1.0 / 4294967295.0);
}


vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}


float voronoi(vec2 uv) {
	vec2 n = floor(uv);
	vec2 f = fract(uv);
	float nearest = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 point = hash22(n + g);
			point = 0.5 + 0.5 * sin(TIME * foam_noise_speed + 6.2831 * point);
			vec2 delta = g - f + point;
			nearest = min(nearest, dot(delta, delta));
		}
	}
	return nearest;
}


float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(
			mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z
	);
}


float fbm_voronoi(vec2 uv) {
	float value = 0.0;
	float amplitude = 0.5;
	vec2 shift = vec2(100.0);
	mat2 rotation = mat2(vec2(cos(0.5), sin(0.5)), vec2(-sin(0.5), cos(0.5)));
	for (int i = 0; i < 3; i++) {
		float layer = 1.0 - voronoi(uv);
		value += amplitude * layer * layer;
		uv = rotation * uv * 2.0 + shift;
		amplitude *= 0.5;
	}
	return value;
}


void vertex() {
	vec3 original_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 sample_position = vec3(original_world.x, 0.0, original_world.z);
	wave_height = -map(sample_position, TIME);
	vec2 vertex_map_uv = original_world.xz / map_world_size + vec2(0.5);
	float vertex_shore_depth = texture(map_depth_texture, vertex_map_uv).r;
	// A steep displaced plane intersecting a triangulated beach exposes its
	// tessellation. Let waves gain their full height after leaving the shore.
	float shore_wave_blend = smoothstep(0.004, 0.060, vertex_shore_depth);
	wave_height *= shore_wave_blend;
	VERTEX.y += wave_height;
	world_vert = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float eps = 0.04;
	float center_height = wave_height;
	float height_x = -map(sample_position + vec3(eps, 0.0, 0.0), TIME);
	float height_z = -map(sample_position + vec3(0.0, 0.0, eps), TIME);
	vertex_normal_world = normalize(vec3(center_height - height_x, eps, center_height - height_z));
}


void fragment() {
	vec2 map_uv = world_vert.xz / map_world_size + vec2(0.5);
	float map_depth = texture(map_depth_texture, map_uv).r;
	float dist_to_camera = length(VERTEX);
	float close_zoom_smoothing = clamp(22.0 / max(1.0, camera_ortho_size), 0.72, 2.2);
	float lod_epsilon = max(normal_epsilon * close_zoom_smoothing, dist_to_camera * 0.0007);
	vec3 detailed_normal = get_normal_detailed(world_vert, lod_epsilon, TIME);
	float smooth_factor = clamp((dist_to_camera - normal_smoothness_dist) / 200.0, 0.0, 1.0);
	float micro_detail_amount = clamp(camera_ortho_size / 22.0, 0.42, 1.0);
	vec3 zoom_stable_normal = normalize(mix(vertex_normal_world, detailed_normal, micro_detail_amount));
	vec3 final_normal = mix(zoom_stable_normal, vertex_normal_world, smooth_factor);
	NORMAL = (VIEW_MATRIX * vec4(final_normal, 0.0)).xyz;

	float water_linear_depth = -VERTEX.z;
	float background_linear_depth = get_linear_depth(DEPTH_TEXTURE, SCREEN_UV, INV_PROJECTION_MATRIX);
	float thickness = max(0.0, background_linear_depth - water_linear_depth);

	vec3 view_vertex_normal = (VIEW_MATRIX * vec4(vertex_normal_world, 0.0)).xyz;
	vec2 normal_offset = NORMAL.xy - view_vertex_normal.xy;
	float distance_factor = clamp(refraction_distance_fade / max(0.1, dist_to_camera), 0.0, 1.0);
	float refraction_depth_mask = smoothstep(0.0, max_depth, thickness);
	vec2 refraction_offset = normal_offset * refraction_strength * distance_factor * refraction_depth_mask * 0.05;
	vec2 distorted_uv = SCREEN_UV + refraction_offset;
	float distorted_background_depth = get_linear_depth(DEPTH_TEXTURE, distorted_uv, INV_PROJECTION_MATRIX);
	if (distorted_background_depth < water_linear_depth - 0.001) {
		distorted_uv = SCREEN_UV;
		distorted_background_depth = background_linear_depth;
	}

	vec3 raw_screen_color = texture(SCREEN_TEXTURE, distorted_uv).rgb;
	vec3 screen_color = raw_screen_color;
	// Compatibility rendering can return a nearly black screen sample over an
	// opaque procedural seabed. Preserve the refracted sample but keep a real
	// seabed colour underneath it.
	screen_color = mix(vec3(0.24, 0.38, 0.32), screen_color, 0.62);
	thickness = max(0.0, distorted_background_depth - water_linear_depth);
	// Preserve the real scene intersection before switching to generated
	// bathymetry for stable volume colour. Foam needs this exact contact depth.
	float scene_thickness = thickness;

	// DEPTH_TEXTURE still drives refraction and intersection rejection above.
	// Compatibility depth loses too much precision for a steep orthographic
	// camera, so volume absorption uses the generator's full-float bathymetry.
	// This is the actual vertical water column stored in the blue channel.
	float generated_thickness = texture(map_depth_texture, map_uv).b * max_depth;
	thickness = generated_thickness;
	float fade_range = max(0.001, max_depth - fade_start_depth);
	float depth_ratio = clamp((thickness - fade_start_depth) / fade_range, 0.0, 1.0);
	float seabed_variation = noise(world_vert.xz * 0.11 + vec2(17.0, -23.0));
	depth_ratio = clamp(depth_ratio + seabed_variation * 0.025 * smoothstep(0.08, 0.72, depth_ratio), 0.0, 1.0);
	if (thickness > 0.0) {
		// Anchor caustics directly in world XZ. Reconstructing their position
		// from the screen depth made the pattern swim when the camera moved.
		vec2 caustics_world = world_vert.xz;
		vec2 caustics_rotated = vec2(
			caustics_world.x * 0.82 + caustics_world.y * 0.57,
			-caustics_world.x * 0.57 + caustics_world.y * 0.82
		);
		vec2 caustics_uv1 = caustics_world * caustics_scale;
		caustics_uv1.x += TIME * caustics_speed;
		vec2 caustics_uv2 = caustics_rotated * caustics_scale * 0.71;
		caustics_uv2.y -= TIME * caustics_speed * 0.8;
		float caustics_sample1 = texture(caustics_texture, caustics_uv1).r;
		float caustics_sample2 = texture(caustics_texture, caustics_uv2).r;
		float caustics_value = caustics_sample1 * caustics_sample2;
		float caustics_emergence = smoothstep(0.07, 0.18, thickness);
		float caustics_fade = 1.0 - smoothstep(0.38, 1.05, thickness);
		float caustics_patchiness = mix(0.58, 1.0, noise(world_vert.xz * 0.16 + vec2(9.0, -14.0)) * 0.5 + 0.5);
		screen_color += caustics_value * caustics_intensity * caustics_emergence * caustics_fade * caustics_patchiness;
	}

	vec3 transmittance = exp(-thickness * water_absorption);
	vec3 water_volume_color = mix(base_tint_color, deep_color, depth_ratio);
	vec3 apparent_seabed_color = screen_color * water_volume_color;
	ALBEDO = mix(underwater_fog_color, apparent_seabed_color, transmittance);
	vec3 readable_depth_color = mix(shallow_surface_color, deep_surface_color, depth_ratio);
	ALBEDO = mix(ALBEDO, readable_depth_color, 0.12);
	// At the contact line the water column is optically thin: reveal the wet
	// sand first, then introduce the water tint continuously across the shelf.
	float shore_volume_presence = smoothstep(0.035, 0.16, thickness);
	vec3 submerged_sand = mix(vec3(0.48, 0.38, 0.22), raw_screen_color, 0.30);
	ALBEDO = mix(submerged_sand, ALBEDO, shore_volume_presence);
	float normalized_wave_height = clamp(wave_height / max(0.001, sea_height * 2.45), 0.0, 1.0);
	ALBEDO *= mix(0.88, 1.10, normalized_wave_height);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(ALBEDO, vec3(0.08, 0.40, 0.48), fresnel * 0.24);
	EMISSION = readable_depth_color * 0.018 + vec3(0.02, 0.07, 0.09) * fresnel * 0.08;

	// PBR specular only reveals waves inside the sun reflection. A subtle
	// normal-driven tint keeps their relief readable everywhere and at every
	// orthographic zoom level without flattening the real lighting.
	float slope_readability = smoothstep(0.008, 0.052, length(vertex_normal_world.xz));
	ALBEDO += vec3(0.010, 0.026, 0.032) * slope_readability;
	float cloud_shadow = projected_cloud_density(
		world_vert.xz, TIME, cloud_wind_direction,
		cloud_shadow_scale, cloud_shadow_speed, cloud_shadow_coverage
	);
	ALBEDO *= mix(vec3(1.0), cloud_shadow_tint, cloud_shadow * cloud_shadow_strength);

	vec2 wind = normalize(wind_direction);
	vec2 depth_texel = 1.0 / vec2(textureSize(map_depth_texture, 0));
	float depth_left = texture(map_depth_texture, map_uv - vec2(depth_texel.x, 0.0)).r;
	float depth_right = texture(map_depth_texture, map_uv + vec2(depth_texel.x, 0.0)).r;
	float depth_up = texture(map_depth_texture, map_uv - vec2(0.0, depth_texel.y)).r;
	float depth_down = texture(map_depth_texture, map_uv + vec2(0.0, depth_texel.y)).r;
	vec2 shore_gradient = vec2(depth_right - depth_left, depth_down - depth_up);
	shore_gradient /= max(length(shore_gradient), 0.0001);
	vec2 shore_tangent = vec2(-shore_gradient.y, shore_gradient.x);
	float wind_into_shore = dot(wind, -shore_gradient);
	float wind_exposure = mix(0.12, 1.0, smoothstep(-0.20, 0.72, wind_into_shore));
	float shore_band = 1.0 - smoothstep(0.012, 0.115, map_depth);
	float shore_phase_warp = noise(world_vert.xz * 0.31 - wind * TIME * shore_wave_speed * 0.12) * 0.18;
	float shore_phase = fract(map_depth * shore_wave_frequency + TIME * shore_wave_speed + shore_phase_warp);
	float incoming_front = smoothstep(0.54, 0.70, shore_phase) * (1.0 - smoothstep(0.84, 0.97, shore_phase));
	float shore_breakup = noise(world_vert.xz * 1.85 - wind * TIME * shore_wave_speed * 0.35);
	shore_breakup = smoothstep(0.45, 0.72, shore_breakup * 0.5 + 0.5);
	float activity_noise_a = noise(world_vert.xz * 0.14 - wind * TIME * shore_wave_speed * 0.42);
	float activity_noise_b = noise(world_vert.xz * 0.27 + wind.yx * TIME * shore_wave_speed * 0.19 + vec2(31.7, -12.4));
	float shore_activity = smoothstep(0.52, 0.70, activity_noise_a * 0.35 + activity_noise_b * 0.15 + 0.5);
	float moving_shore_foam = shore_band * incoming_front * wind_exposure * shore_breakup * shore_activity;
	float depth_foam_factor = clamp(moving_shore_foam, 0.0, 1.0);
	// Fine contact foam is fed into the same depth + Voronoi mask as the larger
	// breaking waves. Keeping it separate made it too weak to affect the image.
	float land_depth = texture(map_depth_texture, map_uv).g;
	float contact_distance = max(map_depth, land_depth);
	float contact_width_phase = sin(TIME * 0.28 + noise(world_vert.xz * 0.07) * 1.6) * 0.5 + 0.5;
	float physical_contact_width = mix(0.10, 0.22, contact_width_phase);
	float physical_contact = 1.0 - smoothstep(0.015, physical_contact_width, scene_thickness);
	// The depth buffer also reads zero above dry land. The generated distance is
	// therefore only a broad guard; it no longer decides where the foam line is.
	float generated_coast_guard = 1.0 - smoothstep(0.020, 0.055, contact_distance);
	float contact_level = physical_contact * generated_coast_guard;
	float contact_patch_noise = noise(world_vert.xz * 0.18 + shore_tangent * TIME * 0.018) * 0.5 + 0.5;
	float contact_patchiness = mix(0.56, 0.86, smoothstep(0.34, 0.66, contact_patch_noise));
	float fine_contact_level = contact_level * contact_patchiness;
	float normalized_crest_height = wave_height / max(0.001, sea_height);
	float crest_rise = smoothstep(2.04, 2.14, normalized_crest_height);
	float crest_fall = 1.0 - smoothstep(2.23, 2.34, normalized_crest_height);
	float crest_band = crest_rise * crest_fall;
	float foam_level = clamp(max(depth_foam_factor, fine_contact_level), 0.0, 1.0);
	vec2 flow_uv = world_vert.xz * 0.5 - wind * TIME * foam_noise_speed * 0.18 + shore_tangent * TIME * 0.018;
	vec2 warp = vec2(noise(flow_uv), noise(flow_uv + vec2(5.2, 1.3))) * 0.5;
	vec2 foam_uv = world_vert.xz * foam_noise_scale + warp;
	float emergence_noise = noise3d(vec3(world_vert.xz * 0.5, TIME * 0.2 * foam_noise_speed));
	emergence_noise = smoothstep(0.0, 1.0, emergence_noise * 0.5 + 0.5);
	float effective_emergence = mix(emergence_noise, 1.0, foam_level * 0.72);
	float foam_noise_value = fbm_voronoi(foam_uv) * effective_emergence;
	vec2 foam_shadow_uv = (world_vert.xz + foam_edge_offset) * foam_noise_scale + warp;
	float foam_shadow_value = fbm_voronoi(foam_shadow_uv) * effective_emergence;
	float combined_foam = foam_noise_value + foam_level;
	float combined_shadow = foam_shadow_value + foam_level;
	float foam_mask_primary = foam_level * smoothstep(foam_cutoff + 0.46, foam_cutoff + 0.60, combined_foam);
	float shadow_shape = foam_level * smoothstep(foam_cutoff + 0.46, foam_cutoff + 0.60, combined_shadow);
	float foam_mask_shadow = clamp(shadow_shape - foam_mask_primary, 0.0, 1.0);
	float voronoi_value = 1.0 - sqrt(voronoi(world_vert.xz * voronoi_scale + warp));
	voronoi_value = smoothstep(0.2, 0.8, voronoi_value);
	float bubble_alpha = 1.0 - clamp((1.0 - voronoi_value) * voronoi_strength, 0.0, 1.0);
	float shore_edge_foam = foam_mask_shadow * 0.06;
	float shore_white_foam = clamp(foam_mask_primary * bubble_alpha * 0.92, 0.0, 0.88);
	ALBEDO = mix(ALBEDO, foam_edge_color, shore_edge_foam);
	ALBEDO = mix(ALBEDO, foam_color, shore_white_foam);

	float beach_lace_foam = shore_white_foam * fine_contact_level;

	// Whitecaps have two wind-driven parts: bright breaking caps locked to high
	// crests, and thinner residual foam advected into long streaks downwind.
	float open_water_mask = smoothstep(0.10, 0.28, map_depth);
	vec2 across_wind = vec2(-wind.y, wind.x);
	vec2 wind_space = vec2(dot(world_vert.xz, wind), dot(world_vert.xz, across_wind));
	wind_space.x -= TIME * wind_foam_speed;
	vec2 streak_uv = vec2(
		wind_space.x * 2.6 - TIME * wind_foam_speed,
		wind_space.y * 14.0
	);
	float wind_streak_cells = fbm_voronoi(streak_uv + warp * 0.34);
	wind_streak_cells = smoothstep(0.71, 0.84, wind_streak_cells);
	float streak_breakup = noise(vec2(wind_space.x * 1.55 - TIME * wind_foam_speed * 0.55, wind_space.y * 2.8) + vec2(0.0, 17.3));
	streak_breakup = smoothstep(0.64, 0.80, streak_breakup * 0.5 + 0.5);
	float crest_foam_detail = fbm_voronoi(vec2(wind_space.x * 14.0, wind_space.y * 22.0) + warp * 0.7);
	crest_foam_detail = smoothstep(0.64, 0.79, crest_foam_detail);
	float distance_visibility = clamp(camera_ortho_size / 22.0, 0.82, 1.45);
	float downwind_slope = max(0.0, dot(vertex_normal_world.xz, wind));
	float breaking_slope = smoothstep(0.010, 0.052, downwind_slope);
	float high_wave_gate = smoothstep(0.42, 1.02, normalized_crest_height);
	float breaking_raw = breaking_slope * high_wave_gate * crest_foam_detail * open_water_mask;
	float breaking_caps = smoothstep(0.075, 0.24, breaking_raw) * foam_crest_amount;
	float trailing_wave_zone = smoothstep(0.16, 0.55, normalized_crest_height) * (1.0 - smoothstep(1.90, 2.35, normalized_crest_height));
	float residual_raw = trailing_wave_zone * wind_streak_cells * streak_breakup * open_water_mask;
	float residual_streaks = smoothstep(0.10, 0.31, residual_raw) * 0.38;
	float open_water_foam = clamp((breaking_caps + residual_streaks) * distance_visibility, 0.0, 0.72);
	ALBEDO = mix(ALBEDO, foam_thin_color, clamp(residual_streaks * distance_visibility * 1.18, 0.0, 0.88));
	ALBEDO = mix(ALBEDO, foam_color, breaking_caps * distance_visibility * 1.10);

	// Foam scatters light instead of inheriting the dark water shading. A small
	// emission term keeps it clean and pale outside the sun highlight as well.
	float bright_foam = clamp(shore_white_foam + shore_edge_foam * 0.35 + beach_lace_foam * 0.42 + open_water_foam, 0.0, 1.0);
	EMISSION += mix(foam_thin_color, foam_color, clamp(bright_foam * 1.6, 0.0, 1.0)) * bright_foam * 0.58;

	ROUGHNESS = mix(roughness, 0.8, clamp(foam_mask_primary * bubble_alpha + foam_mask_shadow + open_water_foam, 0.0, 1.0));
	SPECULAR = specular;
	METALLIC = metallic;
}
