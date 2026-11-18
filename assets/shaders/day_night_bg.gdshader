shader_type canvas_item;

uniform sampler2D night_texture : source_color, filter_nearest;
uniform float night_progress : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_softness : hint_range(0.05, 0.5) = 0.25;

void fragment() {
	vec4 day_col = texture(TEXTURE, UV);
	vec4 night_col = texture(night_texture, UV);

	// Sweep twilight smoothly from top of the sky downward as night falls
	float local_t = clamp(night_progress * (1.0 + sweep_softness) - UV.y * sweep_softness, 0.0, 1.0);
	local_t = smoothstep(0.0, 1.0, local_t);

	vec3 blended = mix(day_col.rgb, night_col.rgb, local_t);
	vec3 dusk_tint = vec3(0.411765, 0.309804, 0.384314); // #694f62 twilight plum
	blended = mix(blended, dusk_tint, sin(local_t * PI) * 0.15);

	COLOR = vec4(blended, mix(day_col.a, night_col.a, local_t));
}
