shader_type canvas_item;

uniform bool hovering = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    if (hovering) {

        float alpha = tex.a;
        float outline = 0.0;

        vec2 pixel = TEXTURE_PIXEL_SIZE;

        for (int x = -20; x <= 20; x++) {
            for (int y = -20; y <= 20; y++) {

                if (x == 0 && y == 0) {
                    continue;
                }

                vec2 offset = vec2(float(x), float(y)) * pixel;

                outline += texture(TEXTURE, UV + offset).a;
            }
        }

        if (alpha <= 0.0 && outline > 0.0) {
            COLOR = outline_color;
        } else {
            COLOR = tex;
        }

    } else {
        COLOR = tex;
    }
}