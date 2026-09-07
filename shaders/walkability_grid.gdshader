shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D walkability : filter_nearest, repeat_disable;
uniform float map_size = 104.0;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 grid = world_xz + vec2(map_size * 0.5);
	float blocked = texture(walkability, grid / map_size).r;
	vec2 edge = min(fract(grid), 1.0 - fract(grid));
	vec2 width = max(fwidth(grid) * 0.8, vec2(0.013));
	float line = 1.0 - smoothstep(0.0, 1.0, min(edge.x / width.x, edge.y / width.y));
	ALBEDO = mix(vec3(0.33, 0.9, 0.36), vec3(1.0, 0.25, 0.18), blocked);
	ALPHA = mix(0.015, 0.065, blocked) + line * 0.62;
}
