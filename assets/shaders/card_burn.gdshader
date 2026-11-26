shader_type canvas_item;

uniform float burn_progress : hint_range(0.0, 1.0) = 0.0;
uniform float burn_seed = 1.0;
uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;
uniform vec4 card_canvas_rect = vec4(0.0, 0.0, 534.0, 239.0);

varying vec2 v_canvas_pos;

void vertex() {
	v_canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return total;
}

void fragment() {
	vec4 base = COLOR;
	if (base.a <= 0.01) {
		COLOR = base;
	} else if (burn_progress <= 0.001) {
		COLOR = base;
	} else {
		float px = max(pixel_size, 1.0);
		vec2 card_size = max(card_canvas_rect.zw, vec2(1.0));
		vec2 rel_px = floor((v_canvas_pos - card_canvas_rect.xy) / px) * px + vec2(px * 0.5);
		vec2 card_uv = clamp(rel_px / card_size, vec2(0.0), vec2(1.0));

		float n = fbm(card_uv * vec2(9.0, 4.2) + vec2(burn_seed * 13.7, burn_seed * 7.3));
		float bottom_bias = (1.0 - card_uv.y) * 0.44;
		float edge_bias = length((card_uv - vec2(0.5)) * vec2(1.5, 1.6)) * 0.14;
		float thresh = clamp((n * 0.58 + bottom_bias + edge_bias) / 1.12, 0.0, 1.0);

		float edge_width = 0.24;
		float t = burn_progress * (1.0 + edge_width) - thresh;

		if (burn_progress >= 0.999 || t >= edge_width) {
			COLOR = vec4(0.0);
		} else if (t > 0.0) {
			float d = t / edge_width;
			vec3 char_col = vec3(0.180392, 0.133333, 0.184314);
			vec3 crimson_col = vec3(0.619608, 0.156863, 0.207843);
			vec3 orange_col = vec3(0.968627, 0.462745, 0.133333);
			vec3 flame_core = vec3(0.996078, 0.905882, 0.380392);

			vec3 out_rgb = char_col;
			if (d < 0.22) {
				out_rgb = mix(base.rgb * vec3(0.42, 0.28, 0.26), char_col, smoothstep(0.0, 0.22, d));
			} else if (d < 0.50) {
				out_rgb = mix(char_col, crimson_col, smoothstep(0.22, 0.50, d));
			} else if (d < 0.78) {
				out_rgb = mix(crimson_col, orange_col, smoothstep(0.50, 0.78, d));
			} else {
				out_rgb = mix(orange_col, flame_core, smoothstep(0.78, 1.0, d));
			}
			COLOR = vec4(out_rgb, base.a);
		} else {
			COLOR = base;
		}
	}
}
