shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D grass_texture : repeat_enable, filter_nearest;
uniform float texture_scale = 0.095;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 grass = texture(grass_texture, world_position.xz * texture_scale).rgb;
	ALBEDO = grass;
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
