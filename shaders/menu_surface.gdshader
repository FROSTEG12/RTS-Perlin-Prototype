shader_type canvas_item;
// A very fine, static mineral/linen grain; no screen sampling or blur pass.
void fragment() {
	vec4 surface = COLOR;
	float grain = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	surface.rgb += (grain - 0.5) * 0.035;
	COLOR = surface;
}
