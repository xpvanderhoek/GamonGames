shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // Get angle from center (0 = top, goes clockwise)
    vec2 centered = UV - vec2(0.5);
    float angle = atan(centered.x, centered.y); // range: -PI to PI
    float normalized = fract((angle / (2.0 * PI)) + 0.5 + 0.11); // range: 0 to 1

    // Discard pixels beyond current progress
    if (normalized > progress) {
        discard;
    }

    COLOR = texture(TEXTURE, UV) * COLOR;
}