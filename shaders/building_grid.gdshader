shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(.45,.8,1.,1.);
uniform vec2 footprint = vec2(4.,6.);
uniform vec2 map_min = vec2(-52.);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz; }
void fragment() {
	vec2 local = (UV-.5)*20.;
	vec2 cell = world_pos.xz-map_min;
	vec2 distance_to_line = abs(fract(cell-.5)-.5);
	vec2 aa = max(fwidth(cell),vec2(.001));
	vec2 line = 1.-smoothstep(vec2(.015),vec2(.015)+aa,distance_to_line);
	float grid = max(line.x,line.y);
	vec2 edge = abs(local)-footprint*.5;
	float d = max(edge.x,edge.y);
	float inside = 1.-smoothstep(-.02,.03,d);
	float outline = 1.-smoothstep(.025,.07,abs(d));
	float fade = 1.-smoothstep(6.,10.,length(local));
	ALBEDO = mix(vec3(.65,.78,.83),tint.rgb,max(inside,outline));
	ALPHA = max(grid*.22*fade, max(inside*.12,outline*.85));
}
