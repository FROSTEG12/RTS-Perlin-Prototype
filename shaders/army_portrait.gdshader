shader_type canvas_item;
varying vec4 portrait_tint;
void vertex() {
	portrait_tint = COLOR;
}
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float inset = max(0.0, (0.09 - UV.y) / 0.18);
	inset = max(inset, max(0.0, (UV.y - 0.90) / 0.20));
	art.a *= step(inset, UV.x) * step(UV.x, 1.0 - inset);
	COLOR = art * portrait_tint;
}
