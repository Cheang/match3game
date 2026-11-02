shader_type canvas_item;

uniform vec4 target_color_1 : source_color; // Highlight (#ffffff)
uniform vec4 target_color_2 : source_color; // Light Base (#ffff00)
uniform vec4 target_color_3 : source_color; // Base Fill (#ff0000)
uniform vec4 target_color_4 : source_color; // Shade Base (#0000ff)
uniform vec4 target_color_5 : source_color; // Deep Shade (#00ff00)

const float TOLERANCE = 0.08;

bool match_color(vec3 pixel, vec3 target) {
	return distance(pixel, target) < TOLERANCE;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	
	if (tex.a < 0.01) {
		COLOR = tex;
	}
	// Color 1: Pure White (#ffffff) -> Highlight
	else if (match_color(tex.rgb, vec3(1.0, 1.0, 1.0))) {
		COLOR = vec4(target_color_1.rgb, tex.a * target_color_1.a);
	}
	// Color 2: Pure Yellow (#ffff00) -> Light Base
	else if (match_color(tex.rgb, vec3(1.0, 1.0, 0.0))) {
		COLOR = vec4(target_color_2.rgb, tex.a * target_color_2.a);
	}
	// Color 3: Pure Red (#ff0000) -> Base Fill
	else if (match_color(tex.rgb, vec3(1.0, 0.0, 0.0))) {
		COLOR = vec4(target_color_3.rgb, tex.a * target_color_3.a);
	}
	// Color 4: Pure Blue (#0000ff) -> Shade Base
	else if (match_color(tex.rgb, vec3(0.0, 0.0, 1.0))) {
		COLOR = vec4(target_color_4.rgb, tex.a * target_color_4.a);
	}
	// Color 5: Pure Green (#00ff00) -> Deep Shade
	else if (match_color(tex.rgb, vec3(0.0, 1.0, 0.0))) {
		COLOR = vec4(target_color_5.rgb, tex.a * target_color_5.a);
	}
	// Untouched frame or unkeyed pixels
	else {
		COLOR = tex;
	}
}
