shader_type canvas_item;

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.5) = 0.18;
uniform float noise_scale : hint_range(1.0, 32.0) = 8.0;
uniform float time = 0.0;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float _rand(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float _value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = _rand(i);
	float b = _rand(i + vec2(1.0, 0.0));
	float c = _rand(i + vec2(0.0, 1.0));
	float d = _rand(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float n = _value_noise((UV + vec2(time * 0.08, time * 0.06)) * noise_scale);
	float inv = 1.0 - dissolve;
	float edge = smoothstep(inv - edge_width, inv, n);
	float alpha = 1.0 - smoothstep(inv, inv + edge_width, n);
	vec3 color = mix(base.rgb, edge_color.rgb, edge);
	COLOR = vec4(color, base.a * alpha);
}
