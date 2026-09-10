shader_type canvas_item;
render_mode unshaded;
uniform sampler2D wear_texture : filter_linear, repeat_disable;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform bool fog_enabled = false;
void fragment() {
	vec4 ground = texture(TEXTURE, UV);
	float wear = smoothstep(0.12, 0.85, texture(wear_texture, UV).r);
	vec3 terrain = mix(ground.rgb, vec3(0.53, 0.44, 0.30), wear * 0.60);
	if (fog_enabled) {
		vec2 sight = texture(sight_mask, UV).rg;
		vec3 remembered = terrain * mix(0.48, 1.0, sight.r);
		terrain = mix(vec3(0.043, 0.072, 0.097), remembered, smoothstep(0.60,0.98,sight.g));
	}
	COLOR = vec4(terrain, ground.a);
}
