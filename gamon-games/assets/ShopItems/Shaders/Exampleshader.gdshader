shader_type canvas_item;
render_mode blend_mix;

uniform vec4 glow_color_inner : source_color = vec4(1.0, 0.5, 0.2, 1.0);
uniform vec4 glow_color_outer : source_color = vec4(0.2, 0.0, 0.8, 1.0);
uniform float glow_intensity : hint_range(0.0, 8.0) = 3.0;
uniform float glow_radius : hint_range(1.0, 60.0) = 18.0;

uniform float pulse_speed : hint_range(0.0, 10.0) = 1.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.25;
uniform float animation_speed : hint_range(0.0, 10.0) = 3.0;

uniform vec4 particle_color_young : source_color = vec4(1.0, 1.0, 0.6, 1.0);
uniform vec4 particle_color_old : source_color = vec4(0.8, 0.1, 0.9, 1.0);
uniform float particle_count : hint_range(0.0, 1000.0) = 50.0;
uniform float particle_orbit : hint_range(0.0, 1.0) = 0.5;
uniform float sparkle_intensity : hint_range(0.0, 2.0) = 0.6;

uniform float distortion_strength : hint_range(0.0, 5.0) = 1.5;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 0.8;

float hash(float n) { return fract(sin(n) * 420.69); }

float get_alpha(sampler2D tex, vec2 uv) {
    return (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        ? 0.0 : texture(tex, uv).a;
}

float ring_glow(sampler2D tex, vec2 uv, vec2 px, float radius, int steps) {
    float acc = 0.0, inv = 1.0 / float(steps);
    for (int i = 0; i < steps; i++) {
        float angle = float(i) * 6.28318 * inv;
        acc += get_alpha(tex, uv + vec2(cos(angle), sin(angle)) * radius * px);
    }
    return acc * inv;
}

float star4(vec2 d, float size) {
    float h = max(0.0, 1.0 - abs(d.x) / size) * max(0.0, 1.0 - abs(d.y) / (size * 0.1));
    float v = max(0.0, 1.0 - abs(d.y) / size) * max(0.0, 1.0 - abs(d.x) / (size * 0.1));
    return clamp(h + v, 0.0, 1.0);
}

void vertex() {
    float pad = 150.0;
    VERTEX += (UV - 0.5) * pad;
}

void fragment() {
    vec2 px = TEXTURE_PIXEL_SIZE;
    vec2 pad_uv = (UV - 0.5) * (1.0 + 150.0 * px.x) + 0.5;

    bool in_bounds = pad_uv.x >= 0.0 && pad_uv.x <= 1.0 && pad_uv.y >= 0.0 && pad_uv.y <= 1.0;
    vec4 tex = in_bounds ? texture(TEXTURE, pad_uv) : vec4(0.0);
    
	// dit is om de sliders iets meer manageble te maken
    float actual_distortion = distortion_strength * 0.01;
    float actual_aberration = chromatic_aberration * 0.01;
    
    vec2 center = pad_uv - 0.5;
    float dist_from_center = length(center);
    
    vec2 wave_offset = vec2(
        sin(pad_uv.y * 20.0 + TIME * animation_speed),
        cos(pad_uv.x * 20.0 + TIME * animation_speed)
    ) * actual_distortion * smoothstep(0.1, 0.5, dist_from_center);
    
    vec2 distorted_uv = pad_uv + wave_offset;
    vec2 distorted_center = center + wave_offset;

    float not_sprite = 1.0 - tex.a;
    float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;

    vec2 uv_r = distorted_uv + vec2(actual_aberration, 0.0);
    vec2 uv_g = distorted_uv;
    vec2 uv_b = distorted_uv - vec2(actual_aberration, 0.0);

    float r1_r = ring_glow(TEXTURE, uv_r, px, glow_radius * 0.25, 8);
    float r2_r = ring_glow(TEXTURE, uv_r, px, glow_radius * 0.60, 12);
    float r3_r = ring_glow(TEXTURE, uv_r, px, glow_radius, 16);
    float glow_r = (r1_r * 0.55 + r2_r * 0.30 + r3_r * 0.15);

    float r1_g = ring_glow(TEXTURE, uv_g, px, glow_radius * 0.25, 8);
    float r2_g = ring_glow(TEXTURE, uv_g, px, glow_radius * 0.60, 12);
    float r3_g = ring_glow(TEXTURE, uv_g, px, glow_radius, 16);
    float glow_g = (r1_g * 0.55 + r2_g * 0.30 + r3_g * 0.15);

    float r1_b = ring_glow(TEXTURE, uv_b, px, glow_radius * 0.25, 8);
    float r2_b = ring_glow(TEXTURE, uv_b, px, glow_radius * 0.60, 12);
    float r3_b = ring_glow(TEXTURE, uv_b, px, glow_radius, 16);
    float glow_b = (r1_b * 0.55 + r2_b * 0.30 + r3_b * 0.15);

    vec3 glow_split = vec3(glow_r, glow_g, glow_b);
    float glow_avg = (glow_r + glow_g + glow_b) / 3.0;

    float glow_total = glow_avg * glow_intensity * pulse * not_sprite;
    glow_total *= sin(distorted_uv.y * 10.0 + TIME * animation_speed) * 0.08 + 0.92;

    float glow_t = (r2_g * 0.5 + r3_g) / max(r1_g + r2_g + r3_g, 0.0001);
    float glow_a = mix(glow_color_inner.a, glow_color_outer.a, glow_t);
    
    vec3 base_glow_rgb = mix(glow_color_inner.rgb, glow_color_outer.rgb, glow_t);
    vec3 glow_rgb = base_glow_rgb * glow_split * glow_intensity * pulse * not_sprite * glow_a;

    // De particles
    vec3 particle_rgb = vec3(0.0);
    float particle_a = 0.0;

    for (float i = 0.0; i < particle_count; i++) {
        float seed = hash(i * 15.23);
        float seed2 = hash(i * 47.17);
        float seed3 = hash(i * 83.61);
        float time = TIME * animation_speed * (0.12 + seed * 0.18) + hash(i * 73.81) * 12.0;
        float life = fract(time);
        float fade = sin(life * 4.20); 

        vec2 rise_pos = vec2(seed - 0.5, 0.46 - life);
        float oa = seed2 * 6.28318 + life * (2.0 + seed3 * 3.0);
        float or_ = 0.15 + seed * 0.35 + sin(life * 6.28318) * 0.05;
        vec2 pos = mix(rise_pos, vec2(cos(oa), sin(oa)) * or_, particle_orbit);
        
        vec2 delta = distorted_center - pos;

        float p = smoothstep(0.2, 0.8, 0.003 / max(length(delta), 0.0001)) * fade;
        float sp = star4(delta, 0.012 + seed * 0.008) * smoothstep(0.35, 0.5, fade) * sparkle_intensity * fade;
        vec4 pcol = mix(particle_color_young, particle_color_old, 1.0 - fade);

        float contrib = (p * 2.5 + sp * 1.5) * not_sprite;
        particle_rgb += pcol.rgb * pcol.a * contrib;
        particle_a += pcol.a * (p + sp * 0.5) * not_sprite;
    }

    particle_rgb = clamp(particle_rgb, 0.0, 3.0);
    particle_a = clamp(particle_a, 0.0, 1.0);

    // het samen brengen
    vec3 col = mix(glow_rgb + particle_rgb, tex.rgb, tex.a);
    float alpha = max(glow_total * glow_a + particle_a, tex.a);

    if (alpha < 0.01) discard;
    COLOR = vec4(col, alpha);
}