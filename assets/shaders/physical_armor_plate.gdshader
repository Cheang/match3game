shader_type canvas_item;

// Physical Armor Plate Shader: Metallic glint sweep across the forged steel plate,
// with optional outer rim masking when Magic Armor is layered on top.

uniform float glint_interval : hint_range(1.0, 10.0) = 4.0;
uniform float glint_speed : hint_range(0.2, 3.0) = 1.0;
uniform float glint_width : hint_range(0.04, 0.3) = 0.12;
uniform vec4 glint_color : source_color = vec4(0.92, 0.97, 1.0, 0.55);
uniform float pixel_grid_size : hint_range(16.0, 128.0) = 64.0;
uniform float armor_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float hide_outer_rim : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p_uv = (floor(UV * pixel_grid_size) + vec2(0.5)) / pixel_grid_size;
	vec4 tex = texture(TEXTURE, p_uv);
	if (tex.a <= 0.01) {
		discard;
	}

	// When Magic Armor is stacked on top, mask the outer metal rim so it doesn't peek past the aura
	if (hide_outer_rim > 0.5 && distance(p_uv, vec2(0.5)) > 0.42) {
		discard;
	}

	// Diagonal sweep position (35 degree tilt)
	float beam_coord = p_uv.x + p_uv.y * 0.55;
	float cycle_t = mod(TIME, glint_interval);
	float glint_add = 0.0;

	if (cycle_t < glint_speed) {
		float progress = cycle_t / glint_speed;
		float beam_center = mix(-0.2, 1.7, progress);
		float d = abs(beam_coord - beam_center);
		if (d < glint_width) {
			float intensity = 1.0 - (d / glint_width);
			glint_add = pow(intensity, 2.0) * glint_color.a;
		}
	}

	vec3 out_rgb = tex.rgb + glint_color.rgb * glint_add;
	COLOR = vec4(out_rgb, tex.a * armor_alpha);
}
