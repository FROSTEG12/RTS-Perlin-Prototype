shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
#include "res://shaders/world_edge_mist.gdshaderinc"
uniform sampler2D rock_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D soil_texture : source_color, filter_nearest_mipmap, repeat_enable;
varying vec3 world_pos;
varying vec2 layer_data;
varying float waterfall_occlusion;
uniform float waterfall_shadow_strength = 0.46;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
	layer_data = COLOR.rg;
	waterfall_occlusion = COLOR.b;
}
void fragment() {
	// Match grass texel scale. Continuous coordinates wrap the four corners.
	vec2 rock_uv = vec2(world_pos.x + world_pos.z, -world_pos.y) * 0.095;
	vec3 rock = texture(rock_texture, rock_uv).rgb;
	float depth = layer_data.x * 12.0;
	float soil = (1.0 - smoothstep(0.04, 0.40, depth)) * (1.0 - layer_data.y);
	vec3 earth = texture(soil_texture, rock_uv).rgb * vec3(0.68, 0.56, 0.40);
	ALBEDO = mix(rock, earth, soil);
	// Static contact occlusion on the actual rock; unaffected by sun direction.
	float contact = waterfall_occlusion * smoothstep(0.18, 0.85, -world_pos.y);
	ALBEDO *= 1.0 - waterfall_shadow_strength * contact;
	ROUGHNESS = 1.0;
	FOG = edge_mist(world_pos, normalize(INV_VIEW_MATRIX[2].xyz));
}
