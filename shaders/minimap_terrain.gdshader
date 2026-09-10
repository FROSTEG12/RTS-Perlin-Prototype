shader_type canvas_item;
render_mode unshaded;
uniform sampler2D wear_texture : filter_linear, repeat_disable;
uniform sampler2D sight_mask : filter_linear, repeat_disable;
uniform sampler2D previous_mask : filter_linear, repeat_disable;
uniform float mask_blend = 1.0;
uniform bool visibility_enabled = false;
void fragment() {
	vec4 ground = texture(TEXTURE, UV);
	float wear = smoothstep(0.12, 0.85, texture(wear_texture, UV).r);
	vec3 terrain = mix(ground.rgb, vec3(0.53,0.44,0.30),wear*0.60);
	if (visibility_enabled) {
		vec2 sight = mix(texture(previous_mask,UV).rg,texture(sight_mask,UV).rg,mask_blend);
		terrain = mix(vec3(0.025,0.04,0.055),terrain*mix(0.74,1.0,sight.r),sight.g);
	}
	COLOR = vec4(terrain,ground.a);
}
