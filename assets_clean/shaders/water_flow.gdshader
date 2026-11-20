shader_type canvas_item;

uniform vec2 flow_direction = vec2(1.0, 0.35);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.25;
uniform float shimmer_strength : hint_range(0.0, 0.2) = 0.03;

void fragment() {
	vec4 base_col = texture(TEXTURE, UV) * COLOR;
	float phase = dot(SCREEN_UV * 20.0, normalize(flow_direction)) + TIME * (1.2 + flow_speed * 2.0);
	float wave = sin(phase);
	vec3 delta = vec3(wave * shimmer_strength * 0.4, wave * shimmer_strength * 0.7, wave * shimmer_strength);
	COLOR = vec4(clamp(base_col.rgb + delta, vec3(0.0), vec3(1.0)), base_col.a);
}
