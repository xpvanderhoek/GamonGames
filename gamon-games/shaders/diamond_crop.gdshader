shader_type canvas_item;

void fragment() {
	vec2 d = abs(UV - vec2(0.5, 0.5));
	if (d.x + d.y > 0.5) {
		COLOR.a = 0.0;
	}
}
