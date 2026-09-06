shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "res://shaders/world_edge_mist.gdshaderinc"
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
}
void fragment() {
	vec4 haze = edge_mist(world_pos, normalize(INV_VIEW_MATRIX[2].xyz));
	ALBEDO = mix(mist_color * 0.82, haze.rgb, haze.a);
}
