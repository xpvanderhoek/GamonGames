shader_type canvas_item;

uniform int mode : hint_range(0, 3) = 0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    vec4 color = texture(screen_texture, SCREEN_UV);
    vec3 rgb = color.rgb;

    if (mode == 1) {
        // Protanopia
        float r = rgb.r * 0.56667 + rgb.g * 0.43333 + rgb.b * 0.0;
        float g = rgb.r * 0.55833 + rgb.g * 0.44167 + rgb.b * 0.0;
        float b = rgb.r * 0.0     + rgb.g * 0.24167 + rgb.b * 0.75833;
        rgb = vec3(r, g, b);
    } else if (mode == 2) {
        // Deuteranopia
        float r = rgb.r * 0.625   + rgb.g * 0.375   + rgb.b * 0.0;
        float g = rgb.r * 0.7     + rgb.g * 0.3     + rgb.b * 0.0;
        float b = rgb.r * 0.0     + rgb.g * 0.3     + rgb.b * 0.7;
        rgb = vec3(r, g, b);
    } else if (mode == 3) {
        // Tritanopia
        float r = rgb.r * 0.95    + rgb.g * 0.05    + rgb.b * 0.0;
        float g = rgb.r * 0.0     + rgb.g * 0.43333 + rgb.b * 0.56667;
        float b = rgb.r * 0.0     + rgb.g * 0.475   + rgb.b * 0.525;
        rgb = vec3(r, g, b);
    }

    COLOR = vec4(rgb, color.a);
}
