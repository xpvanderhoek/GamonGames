shader_type canvas_item;

uniform float density : hint_range(0.0, 1.0) = 0.55;
uniform float speed : hint_range(0.0, 2.0) = 0.3;
uniform vec4 fog_color : source_color = vec4(0.6, 0.65, 0.7, 1.0);


float fog_noise(vec2 uv, float t) {
    float n = 0.0;
    n += sin(uv.x * 3.1 + t * 0.7) * cos(uv.y * 2.4 - t * 0.5);
    n += sin(uv.x * 5.7 - t * 1.1) * sin(uv.y * 4.3 + t * 0.8) * 0.5;
    n += cos(uv.x * 8.2 + t * 0.4) * cos(uv.y * 7.1 - t * 0.6) * 0.25;
    return (n + 1.75) / 3.5;
}

void fragment() {
    float t = TIME * speed;
    float noise = fog_noise(UV * 4.0, t);
    float alpha = noise * density;
    // Soft edge fade so fog doesn't hard-clip at polygon edges
    float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    alpha *= smoothstep(0.0, 0.12, edge);
    COLOR = vec4(fog_color.rgb, alpha);
}
