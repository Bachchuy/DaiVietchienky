shader_type canvas_item;

uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV) * COLOR;
	float m = clamp(flash_modifier, 0.0, 1.0);
	COLOR = vec4(mix(tex_color.rgb, flash_color.rgb, m), tex_color.a);
}
