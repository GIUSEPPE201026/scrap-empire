shader_type spatial;
render_mode cull_back;
uniform vec4 paint_color : source_color = vec4(0.2, 0.6, 0.55, 1.0);
uniform vec4 rust_color : source_color = vec4(0.28, 0.12, 0.065, 1.0);
uniform float wear = 0.35;
uniform sampler2D detail_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying highp vec3 part_position;
varying vec3 part_normal;

float grain(vec3 point) {
	return fract(sin(dot(point, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float patches(vec3 point) {
	vec3 cell = floor(point);
	vec3 blend = smoothstep(vec3(0.0), vec3(1.0), fract(point));
	float front = mix(mix(grain(cell), grain(cell + vec3(1, 0, 0)), blend.x),
		mix(grain(cell + vec3(0, 1, 0)), grain(cell + vec3(1, 1, 0)), blend.x), blend.y);
	float back = mix(mix(grain(cell + vec3(0, 0, 1)), grain(cell + vec3(1, 0, 1)), blend.x),
		mix(grain(cell + vec3(0, 1, 1)), grain(cell + vec3(1, 1, 1)), blend.x), blend.y);
	return mix(front, back, blend.z);
}

void vertex() {
	part_position = VERTEX;
	part_normal = NORMAL;
}

void fragment() {
	float broad = patches(part_position * 2.2);
	float worn = smoothstep(1.0 - wear - 0.08, 1.0 - wear + 0.08, broad);
	vec3 weights = abs(part_normal);
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 detail = texture(detail_map, part_position.yz * 1.4).rgb * weights.x +
		texture(detail_map, part_position.xz * 1.4).rgb * weights.y +
		texture(detail_map, part_position.xy * 1.4).rgb * weights.z;
	ALBEDO = mix(paint_color.rgb, rust_color.rgb, worn * 0.55) * mix(vec3(0.9), detail * 1.08, 0.7);
	ROUGHNESS = mix(0.57, 0.94, worn);
	METALLIC = mix(0.28, 0.05, worn);
}
