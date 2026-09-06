shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, ambient_light_disabled, specular_disabled;

// Transparent everywhere by default. The light pass below reads Godot's
// directional shadow-map attenuation and writes opacity only into occluded
// pixels, so ambient light can never wash the whole terrain with this layer.
uniform vec4 shadow_tint : source_color = vec4(0.018, 0.032, 0.060, 0.68);

void fragment() {
	ALBEDO = shadow_tint.rgb;
	ALPHA = 0.0;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT = vec3(0.0);
	SPECULAR_LIGHT = vec3(0.0);
	float shadow_amount = 1.0 - ATTENUATION;
	ALPHA = max(ALPHA, shadow_amount * shadow_tint.a);
}
