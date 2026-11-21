shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(0.9, 0.2, 0.2, 1.0);
uniform float swap_amount : hint_range(0.0, 1.0) = 1.0;
uniform float is_selected : hint_range(0.0, 1.0) = 0.0;
uniform vec4 selection_color : source_color = vec4(0.98, 0.85, 0.25, 0.85);

uniform float is_attack_target : hint_range(0.0, 1.0) = 0.0;
uniform vec4 attack_target_color : source_color = vec4(0.95, 0.20, 0.20, 0.85);

uniform float is_heal_target : hint_range(0.0, 1.0) = 0.0;
uniform vec4 heal_target_color : source_color = vec4(0.20, 0.95, 0.35, 0.85);

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec4 final_color = tex_color;

    if (tex_color.a >= 0.05 && swap_amount >= 0.01) {
        vec3 hsv = rgb2hsv(tex_color.rgb);
        vec3 target_hsv = rgb2hsv(target_color.rgb);

        // 1. Primary Tunic / Clothing Swap (Blue range in base pixel art)
        bool is_tunic = (hsv.x >= 0.50 && hsv.x <= 0.70) && (hsv.y >= 0.30) && (hsv.z >= 0.20);

        if (is_tunic) {
            if (target_hsv.y < 0.12) {
                // Low saturation -> White, Grey, or Black team!
                float shade_factor = clamp(hsv.z * 1.2, 0.3, 1.1);
                vec3 desat_rgb = target_color.rgb * shade_factor;
                final_color.rgb = mix(tex_color.rgb, desat_rgb, swap_amount);
            } else {
                // Chromatic team (Red, Blue, Green, Teal, Violet, etc.)
                float new_sat = clamp(max(hsv.y, target_hsv.y * 0.85), 0.40, 1.00);
                float new_val = clamp(hsv.z * (target_hsv.z > 0.4 ? 1.05 : 0.90), 0.25, 1.00);
                vec3 swapped_rgb = hsv2rgb(vec3(target_hsv.x, new_sat, new_val));
                final_color.rgb = mix(tex_color.rgb, swapped_rgb, swap_amount);
            }
        }

        // 2. Red Faction Fix: Dark red cape (hsv.x near 0, value <= 0.60) -> Dark Obsidian Charcoal
        bool is_red_faction = (target_hsv.x <= 0.05 || target_hsv.x >= 0.95) && (target_hsv.y >= 0.5);
        bool is_dark_red_cape = (hsv.x >= 0.94 || hsv.x <= 0.04) && (hsv.y >= 0.50) && (hsv.z <= 0.60);

        if (is_red_faction && is_dark_red_cape) {
            vec3 obsidian_cape = vec3(0.14, 0.14, 0.16) * (hsv.z / 0.60);
            final_color.rgb = mix(final_color.rgb, obsidian_cape, swap_amount);
        }
    }

    // 3. Selection, Attack Target & Heal Target Glow Outline
    float active_highlight = max(max(is_selected, is_attack_target), is_heal_target);
    if (active_highlight > 0.0) {
        vec4 outline_col = selection_color;
        if (is_attack_target > 0.5) {
            outline_col = attack_target_color;
        } else if (is_heal_target > 0.5) {
            outline_col = heal_target_color;
        }
        vec2 ps = TEXTURE_PIXEL_SIZE;
        float alpha_up    = texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
        float alpha_down  = texture(TEXTURE, UV + vec2(0.0,  ps.y)).a;
        float alpha_left  = texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
        float alpha_right = texture(TEXTURE, UV + vec2( ps.x, 0.0)).a;

        bool is_outline_pixel = (tex_color.a < 0.05) && (alpha_up > 0.1 || alpha_down > 0.1 || alpha_left > 0.1 || alpha_right > 0.1);
        float pulse = 0.08 * sin(TIME * 6.0) + 0.08;

        if (is_outline_pixel) {
            vec3 glow_outline = mix(outline_col.rgb, outline_col.rgb * 1.35, pulse * 4.0);
            final_color = vec4(glow_outline, outline_col.a);
        } else if (tex_color.a >= 0.05) {
            final_color.rgb = mix(final_color.rgb, final_color.rgb + vec3(pulse), active_highlight);
        }
    }

    COLOR = final_color;
}
