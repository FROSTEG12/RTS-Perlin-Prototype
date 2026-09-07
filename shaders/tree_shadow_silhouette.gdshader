shader_type spatial;
render_mode cull_disabled, unshaded;

// The visible tree keeps its camera-facing transform. This second
// alpha-tested card is upright and faces the sun's horizontal direction.
// Related billboarding reference (CC0): Joey_Bland, Godot Shaders,
// https://godotshaders.com/shader/spatial-view-depending-directional-billboard/
// The pivot, upright orientation and alpha mask here are project-specific.
uniform sampler2D tree_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 sun_direction = vec3(0.7, -0.6, 0.3);
uniform float low_sun_shortening : hint_range(0.0, 0.5) = 0.28;

void vertex() {
	float frame = mod(floor(TIME * 16.0 + INSTANCE_CUSTOM.x * 16.0), 16.0);
	UV = (UV + vec2(mod(frame, 4.0), floor(frame / 4.0))) / 4.0;
	vec3 right = normalize(vec3(sun_direction.z, 0.0, -sun_direction.x));
	vec3 normal = cross(right, vec3(0.0, 1.0, 0.0));
	// Art-directed caster height, not visual tree scale. Anchored at the stem.
	// Shorten long low-sun shadows by 28%; leave high-sun/noon shadows unchanged.
	float high_sun = smoothstep(0.55, 0.83, abs(normalize(sun_direction).y));
	float height_scale = 1.0 - low_sun_shortening * (1.0 - high_sun);
	VERTEX = right * VERTEX.x + vec3(0.0, VERTEX.y * height_scale, 0.0);
	NORMAL = normal;
}

void fragment() {
	vec4 foliage = texture(tree_atlas, UV);
	// Match the visible card's removal of the atlas's baked black ground shadow.
	float colored_pixel = smoothstep(0.001, 0.004, max(foliage.r, max(foliage.g, foliage.b)));
	ALPHA = foliage.a * colored_pixel;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ALBEDO = vec3(1.0);
}
