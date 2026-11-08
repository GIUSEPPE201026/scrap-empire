shader_type spatial;
render_mode cull_disabled;
uniform vec4 flag_color : source_color = vec4(0.9, 0.6, 0.15, 1.0);
void vertex() {
	float freedom = clamp(VERTEX.x + 0.75, 0.0, 1.5);
	VERTEX.z += sin(VERTEX.x * 5.0 - TIME * 3.0) * freedom * 0.12;
}
void fragment() {
	ALBEDO = flag_color.rgb;
	ROUGHNESS = 0.95;
}
