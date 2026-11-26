shader_type canvas_item;

uniform int rarity_tier : hint_range(0, 6) = 0;
uniform bool use_custom_colors = false;

uniform vec4 target_color_1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 target_color_2 : source_color = vec4(0.7804, 0.8627, 0.8157, 1.0);
uniform vec4 target_color_3 : source_color = vec4(0.6078, 0.6706, 0.6980, 1.0);
uniform vec4 target_color_4 : source_color = vec4(0.4980, 0.4392, 0.5412, 1.0);
uniform vec4 target_color_5 : source_color = vec4(0.4118, 0.3098, 0.3843, 1.0);

const float TOLERANCE = 0.08;

bool match_color(vec3 pixel, vec3 target) {
	return distance(pixel, target) < TOLERANCE;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a < 0.01) {
		COLOR = tex;
	} else {
		vec3 c1 = target_color_1.rgb;
		vec3 c2 = target_color_2.rgb;
		vec3 c3 = target_color_3.rgb;
		vec3 c4 = target_color_4.rgb;
		vec3 c5 = target_color_5.rgb;

		if (!use_custom_colors && rarity_tier != 6) {
			if (rarity_tier == 1) {
				c1 = vec3(0.9843, 1.0, 0.5255);
				c2 = vec3(0.5686, 0.8588, 0.4118);
				c3 = vec3(0.1176, 0.7373, 0.4510);
				c4 = vec3(0.1373, 0.5647, 0.3882);
				c5 = vec3(0.0863, 0.3529, 0.2980);
			} else if (rarity_tier == 2) {
				c1 = vec3(1.0, 1.0, 1.0);
				c2 = vec3(0.5608, 0.8275, 1.0);
				c3 = vec3(0.3020, 0.6078, 0.9020);
				c4 = vec3(0.3020, 0.3961, 0.7059);
				c5 = vec3(0.2824, 0.2902, 0.4667);
			} else if (rarity_tier == 3) {
				c1 = vec3(1.0, 1.0, 1.0);
				c2 = vec3(0.9176, 0.6784, 0.9294);
				c3 = vec3(0.6588, 0.5176, 0.9529);
				c4 = vec3(0.5647, 0.3686, 0.6627);
				c5 = vec3(0.4196, 0.2431, 0.4588);
			} else if (rarity_tier == 4) {
				c1 = vec3(1.0, 1.0, 1.0);
				c2 = vec3(0.9843, 1.0, 0.5255);
				c3 = vec3(0.9765, 0.7608, 0.1686);
				c4 = vec3(0.9686, 0.5882, 0.0902);
				c5 = vec3(0.2980, 0.2431, 0.1412);
			} else if (rarity_tier == 5) {
				c1 = vec3(0.9765, 0.7608, 0.1686);
				c2 = vec3(0.9843, 0.4196, 0.1137);
				c3 = vec3(0.9098, 0.2314, 0.2314);
				c4 = vec3(0.6824, 0.1373, 0.2039);
				c5 = vec3(0.4784, 0.1882, 0.2706);
			} else {
				c1 = vec3(1.0, 1.0, 1.0);
				c2 = vec3(0.7804, 0.8627, 0.8157);
				c3 = vec3(0.6078, 0.6706, 0.6980);
				c4 = vec3(0.4980, 0.4392, 0.5412);
				c5 = vec3(0.4118, 0.3098, 0.3843);
			}
		}

		if (match_color(tex.rgb, vec3(1.0, 1.0, 1.0))) {
			COLOR = vec4(c1, tex.a);
		} else if (match_color(tex.rgb, vec3(1.0, 1.0, 0.0))) {
			COLOR = vec4(c2, tex.a);
		} else if (match_color(tex.rgb, vec3(1.0, 0.0, 0.0))) {
			COLOR = vec4(c3, tex.a);
		} else if (match_color(tex.rgb, vec3(0.0, 0.0, 1.0))) {
			COLOR = vec4(c4, tex.a);
		} else if (match_color(tex.rgb, vec3(0.0, 1.0, 0.0))) {
			COLOR = vec4(c5, tex.a);
		} else {
			COLOR = tex;
		}
	}
}
