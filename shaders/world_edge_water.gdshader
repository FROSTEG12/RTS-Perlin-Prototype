// Source noise: frepiso/CaptainProton42, MIT (assets/waterfall/LICENSE).
shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;
#include "res://shaders/cloud_common.gdshaderinc"
#include "res://shaders/water_edge_common.gdshaderinc"
#include "res://shaders/world_edge_mist.gdshaderinc"
uniform sampler2D map_depth_texture : filter_linear, repeat_disable;
uniform float map_world_size = 104.0;
uniform vec2 cloud_shadow_offset = vec2(0.0);
uniform vec2 cloud_wind_direction = vec2(0.91, 0.41);
uniform float cloud_shadow_scale = 0.085;
uniform float cloud_shadow_speed = 0.18;
uniform float cloud_shadow_coverage = 0.64;
uniform float cloud_shadow_strength = 0.68;
uniform vec3 cloud_shadow_tint : source_color = vec3(0.31, 0.40, 0.45);
uniform float contact_depth_strength = 0.18;
varying vec3 world_pos;
varying vec3 surface_normal;
void vertex() {
	// Corner copies use the SAME position field, never a face-specific normal.
	vec2 outward = waterfall_outward(UV2, map_world_size * 0.5);
	VERTEX.xz += outward * waterfall_wave(UV2, UV.y, TIME);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surface_normal = NORMAL;
}
void fragment() {
	vec3 flow = edge_flow(UV2, UV.y, TIME);
	float depth = texture(map_depth_texture, UV2 / map_world_size + vec2(0.5)).b * 2.6;
	float falling = smoothstep(0.28, 2.0, UV.y);
	vec3 water = edge_water_color(depth, flow);
	float cloud = projected_cloud_density(UV2 + cloud_shadow_offset, TIME, cloud_wind_direction,
		cloud_shadow_scale, cloud_shadow_speed, cloud_shadow_coverage);
	water *= mix(vec3(1.0), cloud_shadow_tint, cloud * cloud_shadow_strength);
	// A thin film at the crest becomes aerated downstream, not stripes at the seam.
	float foam = flow.z * mix(0.30, 0.60, falling) + overflow_crest_foam(UV2, UV.y, TIME);
	water *= 1.0 - contact_depth_strength * falling * (1.0 - foam);
	ALBEDO = mix(water, edge_foam_color, foam);
	EMISSION = edge_foam_color * foam * 0.08;
	vec3 across = normalize(vec3(abs(surface_normal.z), 0.001, abs(surface_normal.x)));
	float eps = 0.025;
	vec2 tangent = normalize(vec2(-surface_normal.z, surface_normal.x) + vec2(0.00001));
	float across_slope = (waterfall_wave(UV2 + tangent * eps, UV.y, TIME) - waterfall_wave(UV2 - tangent * eps, UV.y, TIME)) / (2.0 * eps);
	float down_slope = (waterfall_wave(UV2, UV.y + eps, TIME) - waterfall_wave(UV2, UV.y - eps, TIME)) / (2.0 * eps);
	vec3 n = normalize(surface_normal - vec3(tangent.x, 0.0, tangent.y) * across_slope
		+ vec3(0.0, down_slope, 0.0) * falling + across * (flow.y - 0.5) * 0.04 * falling);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(0.36, 0.65, falling);
	SPECULAR = 0.48;
	FOG = edge_mist(world_pos, normalize(INV_VIEW_MATRIX[2].xyz));
}
