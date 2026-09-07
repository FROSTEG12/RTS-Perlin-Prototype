shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D billow_noise : repeat_enable, filter_linear_mipmap;
uniform float intensity = 0.0;
uniform vec3 fog_color = vec3(0.36, 0.39, 0.43);
uniform vec3 unit_position;
uniform float vision_radius = 4.0;
uniform float vision_feather = 3.2;
uniform float map_half_extent = 52.0;
uniform vec2 wind_direction = vec2(0.8, 0.4);

void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 endpoint = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 surface = endpoint.xyz / endpoint.w;
	// Parallel orthographic rays, not a perspective ray from the camera origin.
	vec3 toward_camera = normalize(INV_VIEW_MATRIX[2].xyz);
	float bottom = max(surface.y, -0.35);
	float top = 3.8;
	float thickness = max(top - bottom, 0.0);
	vec3 base = surface + toward_camera * ((bottom - surface.y) / toward_camera.y);
	float ds = thickness / (20.0 * toward_camera.y);
	float optical_depth = 0.0;
	float shade_sum = 0.0;
	// Ground-space reveal remains attached to the unit at every zoom/pan.
	vec3 ground = surface - toward_camera * (surface.y / toward_camera.y);
	float reveal = smoothstep(vision_radius, vision_radius + vision_feather, distance(ground.xz, unit_position.xz));
	vec2 drift = wind_direction * TIME * 0.0018;
	for (int i = 0; i < 20; i++) {
		vec3 p = base + toward_camera * ((float(i) + 0.5) * ds);
		float broad = texture(billow_noise, p.xz * 0.034 + drift + p.y * vec2(0.013, -0.009)).r;
		float detail = texture(billow_noise, p.xz * 0.092 - drift * 0.65 + p.y * vec2(-0.021, 0.017)).r;
		float top_height = 1.3 + broad * 2.5;
		float envelope = 1.0 - smoothstep(0.6, top_height, p.y);
		float banks = smoothstep(0.27, 0.73, broad * 0.8 + detail * 0.2);
		float map_mask = 1.0 - smoothstep(map_half_extent - 0.3, map_half_extent + 3.0, max(abs(p.x), abs(p.z)));
		float density = (0.08 + banks * 0.62) * envelope * map_mask * intensity * reveal;
		optical_depth += density * ds;
		shade_sum += density * ds * mix(0.80, 1.12, detail);
	}
	ALBEDO = fog_color * shade_sum / max(optical_depth, 0.00001);
	ALPHA = 1.0 - exp(-optical_depth);
}
