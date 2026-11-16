shader_type canvas_item;

uniform float banner_height = 264.0;
uniform float wave_amplitude : hint_range(0.0, 12.0) = 3.5;
uniform float wave_frequency : hint_range(0.5, 10.0) = 2.6;
uniform float wave_speed : hint_range(0.2, 10.0) = 1.8;
uniform float fold_shading : hint_range(0.0, 0.25) = 0.045;
uniform bool pixel_art_snap = true;

varying float v_norm_y;
varying float v_fold;

void vertex() {
	float y_norm = clamp(VERTEX.y / max(banner_height, 1.0), 0.0, 1.0);
	float pin_factor = pow(y_norm, 1.35);

	float t = TIME * wave_speed;
	float phase = y_norm * wave_frequency * 3.14159265;
	float wave = sin(phase - t) * 0.72 + sin(phase * 1.9 - t * 1.35 + 0.7) * 0.28;
	float dx = wave * wave_amplitude * pin_factor;
	if (pixel_art_snap) {
		dx = floor(dx + 0.5);
	}
	VERTEX.x += dx;

	v_norm_y = y_norm;
	v_fold = cos(phase - t) * pin_factor;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col.rgb += vec3(v_fold * fold_shading) * col.a;
	COLOR = col;
}
