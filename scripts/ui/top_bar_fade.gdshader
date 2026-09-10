shader_type canvas_item;
render_mode unshaded;

// Local pixels keep the fade the same width on standard and ultrawide layouts.
uniform float fade_width = 104.0;
varying vec2 panel_position;

void vertex() {
	panel_position = VERTEX;
}

void fragment() {
	// Applied to the panel's own drawing only, including its border and shadow.
	// Child Controls deliberately do not use their parent's material.
	COLOR.a *= smoothstep(0.0, fade_width, panel_position.x);
}
