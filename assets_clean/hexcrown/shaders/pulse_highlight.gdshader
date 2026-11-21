shader_type canvas_item;

// Set by VisualsCoordinator at runtime — no hardcoded colours.
uniform vec4 highlight_color : source_color = vec4(0.2, 0.9, 1.0, 0.7);
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a < 0.05) { discard; }

	vec2 center_uv = UV - vec2(0.5, 0.5);
	
	float line_width = 0.035;
	float line_length = 0.25;
	
	float iso_y = center_uv.y * 1.5;
	
	bool h_line = abs(iso_y) < line_width && abs(center_uv.x) < line_length;
	bool v_line = abs(center_uv.x) < line_width && abs(iso_y) < line_length;
	
	bool center_gap = abs(center_uv.x) < 0.06 && abs(iso_y) < 0.06;
	
	if ((!h_line && !v_line) || center_gap) {
		discard;
	}
	
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed);
	
	COLOR = vec4(highlight_color.rgb, highlight_color.a * pulse);
}
