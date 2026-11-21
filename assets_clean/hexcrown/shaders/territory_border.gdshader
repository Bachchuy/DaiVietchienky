shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.2, 0.6, 1.0, 0.95);
uniform float line_thickness : hint_range(0.5, 4.0) = 1.2;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    vec2 ps = TEXTURE_PIXEL_SIZE * line_thickness;

    float a_up    = texture(TEXTURE, UV + vec2(0.0, -ps.y)).a;
    float a_down  = texture(TEXTURE, UV + vec2(0.0,  ps.y)).a;
    float a_left  = texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a;
    float a_right = texture(TEXTURE, UV + vec2( ps.x, 0.0)).a;
    float a_ur    = texture(TEXTURE, UV + vec2( ps.x, -ps.y)).a;
    float a_ul    = texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a;
    float a_dr    = texture(TEXTURE, UV + vec2( ps.x,  ps.y)).a;
    float a_dl    = texture(TEXTURE, UV + vec2(-ps.x,  ps.y)).a;

    bool is_inside = tex_color.a > 0.05;
    bool is_near_outside = (a_up < 0.1 || a_down < 0.1 || a_left < 0.1 || a_right < 0.1 || a_ur < 0.1 || a_ul < 0.1 || a_dr < 0.1 || a_dl < 0.1);

    if (is_inside && is_near_outside) {
        float pulse = 0.08 * sin(TIME * 4.5) + 0.92;
        COLOR = vec4(border_color.rgb * pulse, border_color.a);
    } else {
        COLOR = vec4(0.0);
    }
}
