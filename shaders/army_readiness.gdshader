shader_type canvas_item;

uniform bool desaturated = false;

void fragment() {
	// Change readiness presentation only; preserve the portrait's real alpha.
	if (desaturated) {
		float gray = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));
		COLOR.rgb = vec3(gray);
	}
}
