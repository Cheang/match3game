shader_type canvas_item;

uniform float banner_height = 448.0;
uniform float wave_amplitude : hint_range(0.0, 12.0) = 2.0;
uniform float wave_frequency : hint_range(0.5, 10.0) = 2.775;
uniform float wave_speed : hint_range(0.2, 10.0) = 1.5;
uniform float fold_shading : hint_range(0.0, 0.25) = 0.037;
uniform bool pixel_art_snap = false;

uniform float top_shadow_height : hint_range(0.0, 48.0) = 14.0;
uniform float top_shadow_strength : hint_range(0.0, 1.0) = 0.72;
uniform vec4 top_shadow_color : source_color = vec4(0.35, 0.14, 0.22, 1.0);
uniform int top_shadow_bands : hint_range(0, 8) = 4;

void fragment() {
	float y_norm = clamp(UV.y, 0.0, 1.0);
	if (pixel_art_snap && banner_height > 0.0) {
		y_norm = floor(y_norm * banner_height) / banner_height;
	}
	float pin_factor = smoothstep(0.0, 0.16, y_norm) * (0.45 + 0.55 * y_norm);

	float t = TIME * wave_speed;
	float phase = y_norm * wave_frequency * 3.14159265;
	float wave = sin(phase - t) * 0.72 + sin(phase * 1.9 - t * 1.35 + 0.7) * 0.28;
	float dx = wave * wave_amplitude * pin_factor;
	if (pixel_art_snap) {
		dx = floor(dx + 0.5);
	}

	vec2 sample_uv = vec2(UV.x - dx * TEXTURE_PIXEL_SIZE.x, UV.y);
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0) {
		discard;
	}

	vec4 col = texture(TEXTURE, sample_uv);
	if (col.a <= 0.001) {
		discard;
	}

	float fold = cos(phase - t) * pin_factor;
	col.rgb += vec3(fold * fold_shading) * col.a;

	if (top_shadow_height > 0.0 && top_shadow_strength > 0.0) {
		float y_px = UV.y * banner_height;
		float raw_shadow = clamp(1.0 - (y_px / top_shadow_height), 0.0, 1.0);
		if (raw_shadow > 0.0) {
			float shadow_curve = raw_shadow * raw_shadow * 0.4 + raw_shadow * 0.6;
			if (top_shadow_bands > 0) {
				shadow_curve = ceil(shadow_curve * float(top_shadow_bands)) / float(top_shadow_bands);
			}
			float shadow_amount = shadow_curve * top_shadow_strength;
			col.rgb = mix(col.rgb, col.rgb * top_shadow_color.rgb, shadow_amount);
		}
	}

	COLOR = col;
}
