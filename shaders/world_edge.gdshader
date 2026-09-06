shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

varying vec3 world_pos;
varying vec2 layer_data;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	layer_data = COLOR.rg;
}

void fragment() {
	float depth = layer_data.x * 12.0;
	float waviness = sin(world_pos.x * 0.37 + world_pos.z * 0.51) * 0.35;
	float stratum = floor((world_pos.y + waviness) * 2.3);
	float band = hash3(vec3(floor(world_pos.x * 0.14), stratum, floor(world_pos.z * 0.14)));
	float grain = hash3(floor(world_pos * vec3(9.0, 13.0, 9.0)));
	vec3 rock = mix(vec3(0.105, 0.115, 0.12), vec3(0.17, 0.165, 0.145), band);
	rock *= mix(0.88, 1.1, grain);
	float soil = (1.0 - smoothstep(0.12, 0.75, depth)) * (1.0 - layer_data.y);
	rock = mix(rock, vec3(0.17, 0.105, 0.052), soil);
	float fissure = smoothstep(0.035, 0.09, abs(sin((world_pos.y + waviness) * 7.2)));
	rock *= mix(0.65, 1.0, fissure);
	// Local depth haze: no full-screen/volumetric fog and no change to the map.
	float abyss = smoothstep(4.0, 11.6, depth);
	ALBEDO = mix(rock, vec3(0.001, 0.002, 0.003), abyss);
	ROUGHNESS = 1.0;
}
