shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;

varying vec2 flow_uv;

void vertex() {
	flow_uv = COLOR.rg;
}

void fragment() {
	float streak = sin(flow_uv.x * 42.0 + sin(flow_uv.x * 13.0)) * 0.5 + 0.5;
	float flow = sin(flow_uv.y * 52.0 - TIME * 5.0 + flow_uv.x * 3.0) * 0.5 + 0.5;
	float lip = 1.0 - smoothstep(0.0, 0.055, flow_uv.y);
	float fade = 1.0 - smoothstep(0.35, 1.0, flow_uv.y);
	ALBEDO = mix(vec3(0.045, 0.22, 0.19), vec3(0.48, 0.61, 0.55), streak * 0.3 + lip * 0.55);
	ALPHA = (0.38 + streak * 0.18 + flow * 0.08 + lip * 0.25) * fade;
	ROUGHNESS = 0.75;
}
