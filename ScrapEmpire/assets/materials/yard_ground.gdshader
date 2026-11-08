shader_type spatial;
render_mode cull_disabled;
uniform sampler2D sand_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying highp vec3 ground_position;

float hash_ground(highp vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float ground_noise(highp vec2 point) {
	highp vec2 cell = floor(point);
	highp vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	return mix(mix(hash_ground(cell), hash_ground(cell + vec2(1, 0)), blend.x),
		mix(hash_ground(cell + vec2(0, 1)), hash_ground(cell + vec2(1, 1)), blend.x), blend.y);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	highp vec2 point = ground_position.xz;
	highp float drift = 0.5 + 0.5 * sin(point.x * 0.12 + sin(point.y * 0.09) * 1.7);
	highp float variation = drift * 0.85 + ground_noise(point * 0.65) * 0.15;
	vec3 soil = mix(vec3(0.53, 0.38, 0.24), vec3(0.61, 0.46, 0.31), variation);
	float track = (1.0 - smoothstep(0.18, 0.32, abs(abs(point.x) - 1.1)));
	track *= 0.55 + 0.45 * smoothstep(0.25, 0.4, fract(point.y * 4.5));
	soil *= 1.0 - track * 0.13;
	vec3 detail = texture(sand_detail, point * 0.65).rgb;
	ALBEDO = soil * mix(vec3(0.95), detail * 1.12, 0.65);
	ROUGHNESS = 0.96;
}
