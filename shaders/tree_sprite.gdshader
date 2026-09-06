shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D tree_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float foliage_saturation : hint_range(0.0, 1.0) = 0.62;
uniform float foliage_brightness : hint_range(0.0, 1.5) = 0.82;
varying float tree_tint;

void vertex() {
	// 4 x 4 authored wind frames. Each tree starts at a different phase.
	float frame = mod(floor(TIME * 16.0 + INSTANCE_CUSTOM.x * 16.0), 16.0);
	UV = (UV + vec2(mod(frame, 4.0), floor(frame / 4.0))) / 4.0;
	tree_tint = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec4 foliage = texture(tree_atlas, UV);
	// The atlas includes a black, baked ground shadow. Reject that mask so
	// only the scene light casts a moving shadow. Original PNGs stay intact.
	float colored_pixel = smoothstep(0.001, 0.004, max(foliage.r, max(foliage.g, foliage.b)));
	float luminance = dot(foliage.rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(luminance), foliage.rgb, foliage_saturation) * foliage_brightness * tree_tint;
	ALPHA = foliage.a * colored_pixel;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 1.0;
	// The image already contains local shading. A canopy-facing normal keeps
	// scene illumination independent of the orientation of its flat card.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
