shader_type canvas_item;

uniform float light_strength : hint_range(0.0, 2.5) = 1.0;
uniform float flicker : hint_range(0.5, 1.5) = 1.0;
uniform float pixel_snap : hint_range(1.0, 8.0) = 2.0;
uniform vec2 rect_size = vec2(520.0, 520.0);

uniform float inner_radius : hint_range(8.0, 100.0) = 32.0;
uniform float mid_radius : hint_range(16.0, 120.0) = 58.0;
uniform float outer_radius : hint_range(24.0, 260.0) = 86.0;

uniform vec4 inner_color : source_color = vec4(0.984314, 1.0, 0.52549, 0.34);
uniform vec4 mid_color : source_color = vec4(0.976471, 0.760784, 0.168627, 0.22);
uniform vec4 outer_color : source_color = vec4(0.984314, 0.419608, 0.113725, 0.09);

void fragment() {
	float strength = max(0.0, light_strength);
	if (strength <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		float snap = max(1.0, pixel_snap);
		vec2 snapped_pos = floor(UV * rect_size / snap) * snap + 0.5 * snap;
		float dist = length(snapped_pos - rect_size * 0.5);

		float rad_scale = clamp(strength, 0.0, 2.5);
		float alpha_scale = clamp(strength, 0.0, 1.6);
		float f_delta = flicker - 1.0;
		float r_in = max(2.0, (inner_radius + f_delta * 16.0) * rad_scale);
		float r_mid = max(r_in + 2.0, (mid_radius + f_delta * 26.0) * rad_scale);
		float r_out = max(r_mid + 2.0, (outer_radius + f_delta * 34.0) * rad_scale);

		if (dist <= r_in) {
			vec4 col = inner_color;
			col.a = min(col.a * alpha_scale, 0.85);
			COLOR = col;
		} else if (dist <= r_mid) {
			vec4 col = mid_color;
			col.a = min(col.a * alpha_scale, 0.85);
			COLOR = col;
		} else if (dist <= r_out) {
			vec4 col = outer_color;
			col.a = min(col.a * alpha_scale, 0.85);
			COLOR = col;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
