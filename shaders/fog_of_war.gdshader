shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_prepass_alpha;
// Godot implementation of the mask-driven displaced-mesh approach:
// https://tekblueprint.org/ru/blog/dev/gamedev-fog-of-war/
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform float world_size = 104.0;
uniform vec3 cloud_color : source_color = vec3(0.58, 0.67, 0.71);
uniform vec3 sun_direction = vec3(-0.5, 0.8, -0.3);
uniform float fog_height = 4.6;
varying vec2 map_uv;
varying float lighting;
varying float billow;
float height_at(vec2 p) {
	vec2 uv = p / world_size + 0.5;
	float history = texture(sight_mask, uv).g;
	vec2 drift = TIME * vec2(0.004, 0.002);
	float broad = texture(cloud_noise, p * 0.016 + drift).r;
	float detail = texture(cloud_noise, p * 0.045 - drift * 0.6).r;
	float top = fog_height + (broad - 0.45) * 2.0 + detail * 0.3;
	return mix(top, -0.5, smoothstep(0.0, 0.96, history));
}
void vertex() {
	vec2 p = VERTEX.xz;
	map_uv = p / world_size + 0.5;
	VERTEX.y = height_at(p);
	float step_size = 0.4;
	vec3 normal = normalize(vec3(height_at(p-vec2(step_size,0.0))-height_at(p+vec2(step_size,0.0)),
		2.0*step_size, height_at(p-vec2(0.0,step_size))-height_at(p+vec2(0.0,step_size))));
	lighting = 0.62 + max(dot(normal, normalize(sun_direction)), 0.0) * 0.42;
	billow = texture(cloud_noise, p * 0.035 + TIME * vec2(0.003, -0.001)).r;
}
void fragment() {
	float known = texture(sight_mask, map_uv).g;
	float opacity = 1.0 - smoothstep(0.12, 0.94, known);
	if (opacity < 0.005) discard;
	ALBEDO = cloud_color * lighting * mix(0.9, 1.08, billow);
	ALPHA = opacity;
}
