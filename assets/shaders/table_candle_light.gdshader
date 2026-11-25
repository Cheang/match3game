shader_type canvas_item;

uniform vec2 light_pos_uv = vec2(0.177, 0.049);
uniform float light_strength : hint_range(0.0, 2.5) = 1.0;
uniform float light_contrast : hint_range(0.0, 2.0) = 1.0;
uniform float flicker : hint_range(0.5, 1.5) = 1.0;
uniform float pixel_snap : hint_range(1.0, 8.0) = 2.0;

uniform float ring_inner_radius : hint_range(40.0, 400.0) = 152.0;
uniform float ring_mid_radius : hint_range(120.0, 700.0) = 392.0;
uniform float ring_outer_radius : hint_range(250.0, 1100.0) = 650.0;

uniform float inner_flicker_px : hint_range(0.0, 120.0) = 40.0;
uniform float mid_flicker_px : hint_range(0.0, 160.0) = 75.0;
uniform float outer_flicker_px : hint_range(0.0, 200.0) = 90.0;

uniform bool allow_hot_highlight = false;

uniform vec4 palette_deep : source_color = vec4(0.270588, 0.160784, 0.247059, 1.0);
uniform vec4 palette_dark : source_color = vec4(0.431373, 0.152941, 0.152941, 1.0);
uniform vec4 palette_mid : source_color = vec4(0.619608, 0.270588, 0.223529, 1.0);
uniform vec4 palette_bright : source_color = vec4(0.803922, 0.407843, 0.239216, 1.0);
uniform vec4 palette_hot : source_color = vec4(0.901961, 0.564706, 0.305882, 1.0);

int classify_palette(vec3 rgb) {
	vec3 d0 = rgb - palette_deep.rgb;
	vec3 d1 = rgb - palette_dark.rgb;
	vec3 d2 = rgb - palette_mid.rgb;
	vec3 d3 = rgb - palette_bright.rgb;

	float best_dist = dot(d0, d0);
	int best_idx = 0;

	float dist1 = dot(d1, d1);
	if (dist1 < best_dist) {
		best_dist = dist1;
		best_idx = 1;
	}
	float dist2 = dot(d2, d2);
	if (dist2 < best_dist) {
		best_dist = dist2;
		best_idx = 2;
	}
	float dist3 = dot(d3, d3);
	if (dist3 < best_dist) {
		best_idx = 3;
	}
	return best_idx;
}

vec3 palette_color(int idx) {
	if (idx <= 0) return palette_deep.rgb;
	if (idx == 1) return palette_dark.rgb;
	if (idx == 2) return palette_mid.rgb;
	if (idx == 3) return palette_bright.rgb;
	return palette_hot.rgb;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.05) {
		COLOR = tex;
	} else {
		int base_idx = classify_palette(tex.rgb);

		float snap = max(1.0, pixel_snap);
		vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 px_pos = floor(UV * tex_size / snap) * snap + 0.5 * snap;
		vec2 light_px = floor(light_pos_uv * tex_size / snap) * snap + 0.5 * snap;
		float dist_px = length(px_pos - light_px);

		float strength = max(0.0, light_strength);
		float f_delta = flicker - 1.0;

		int shift = -2;
		if (strength > 0.001) {
			float r_inner = max(0.0, (ring_inner_radius + f_delta * inner_flicker_px) * strength);
			float r_mid = max(r_inner, (ring_mid_radius + f_delta * mid_flicker_px) * strength);
			float r_outer = max(r_mid, (ring_outer_radius + f_delta * outer_flicker_px) * strength);

			if (dist_px <= r_inner) {
				shift = 1;
			} else if (dist_px <= r_mid) {
				shift = 0;
			} else if (dist_px <= r_outer) {
				shift = -1;
			}
		}

		int idx = 0;
		if (base_idx != 0) {
			int max_idx = (allow_hot_highlight || strength >= 1.35) ? 4 : 3;
			idx = clamp(base_idx + shift, 1, max_idx);
		}

		vec3 stepped = palette_color(idx);
		vec3 out_rgb = stepped;
		if (light_contrast <= 1.0) {
			out_rgb = mix(tex.rgb, stepped, clamp(light_contrast, 0.0, 1.0));
		} else {
			float extra = clamp(light_contrast - 1.0, 0.0, 1.0);
			if (base_idx == 0) {
				out_rgb = mix(stepped, stepped * 0.75, extra * 0.5);
			} else if (shift == 1) {
				out_rgb = clamp(stepped * (1.0 + extra * 0.24) + vec3(0.05, 0.025, 0.0) * extra, 0.0, 1.0);
			} else if (shift == 0) {
				out_rgb = clamp(stepped * (1.0 + extra * 0.06), 0.0, 1.0);
			} else if (shift == -1) {
				out_rgb = mix(stepped, palette_deep.rgb, extra * 0.45);
			} else {
				out_rgb = mix(stepped, palette_deep.rgb * 0.72, extra * 0.70);
			}
		}

		COLOR = vec4(out_rgb, tex.a);
	}
}
