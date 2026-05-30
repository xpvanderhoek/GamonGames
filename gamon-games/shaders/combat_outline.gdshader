shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.9, 0.2, 1.0);
uniform float outline_width : hint_range(0.0, 50.0) = 8.0;
uniform float blur_width : hint_range(0.0, 50.0) = 15.0;
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.12;
uniform float blur_threshold : hint_range(0.0, 1.0) = 0.06;
uniform float glow_strength : hint_range(0.0, 3.0) = 0.7;
uniform bool outline_enabled = true;
uniform bool outline_only = false;

void fragment() {
    float alpha = texture(TEXTURE, UV).a;

    float outline = 0.0;
    float blur = 0.0;
    const int MAX_RADIUS = 12;
    float radius = clamp(outline_width, 0.0, float(MAX_RADIUS));
    float blur_radius = clamp(blur_width, 0.0, float(MAX_RADIUS));
    vec2 pixel = TEXTURE_PIXEL_SIZE;

    for (int x = -MAX_RADIUS; x <= MAX_RADIUS; x++) {
        for (int y = -MAX_RADIUS; y <= MAX_RADIUS; y++) {
            vec2 offset = vec2(float(x), float(y));
            float dist = length(offset);
            if (dist <= radius && dist > 0.0) {
                float sample_alpha = texture(TEXTURE, UV + offset * pixel).a;
                float weight = 1.0 - smoothstep(0.0, radius, dist);
                outline = max(outline, sample_alpha * weight);
            }
            if (dist <= blur_radius && dist > 0.0) {
                float sample_alpha_blur = texture(TEXTURE, UV + offset * pixel).a;
                float blur_weight = 1.0 - smoothstep(0.0, blur_radius, dist);
                blur = max(blur, sample_alpha_blur * blur_weight);
            }
        }
    }

    float edge = smoothstep(outline_threshold, 1.0, outline);
    float glow = smoothstep(blur_threshold, 1.0, blur) * glow_strength;
    float inner_mask = 1.0 - smoothstep(0.0, outline_threshold, alpha);

    vec4 sprite_color = texture(TEXTURE, UV) * COLOR;

    if (outline_enabled) {
        if (outline_only) {
            float outline_alpha = (edge + glow) * inner_mask;
            COLOR = vec4(outline_color.rgb, outline_alpha * outline_color.a);
        } else {
            COLOR = mix(outline_color, sprite_color, alpha);
            COLOR.a = max(alpha, (edge + glow) * outline_color.a);
            COLOR.rgb += outline_color.rgb * glow * 0.8;
        }
    } else {
        COLOR = sprite_color;
    }
}
