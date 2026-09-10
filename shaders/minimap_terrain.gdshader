shader_type canvas_item;
render_mode unshaded;
uniform sampler2D wear_texture : filter_linear, repeat_disable;
void fragment() {
	vec4 ground = texture(TEXTURE, UV);
	float wear = smoothstep(0.12, 0.85, texture(wear_texture, UV).r);
	COLOR = vec4(mix(ground.rgb, vec3(0.53, 0.44, 0.30), wear * 0.60), ground.a);
}
