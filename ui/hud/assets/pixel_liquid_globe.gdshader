shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 col_highlight : source_color = vec4(0.976, 0.761, 0.169, 1.0); // #F9C22B
uniform vec4 col_base : source_color = vec4(0.910, 0.231, 0.231, 1.0);      // #E83B3B
uniform vec4 col_shadow : source_color = vec4(0.478, 0.188, 0.271, 1.0);    // #7A3045

uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.025;
uniform float wave_frequency : hint_range(0.0, 30.0) = 14.0;
uniform float wave_speed : hint_range(0.0, 15.0) = 3.5;
uniform float time_offset = 0.0;
uniform float pixel_grid_size = 64.0;
uniform float radius : hint_range(0.3, 0.5) = 0.4765; // ~30.5 pixels

// Specks (bubbles / illuminated particles rising through liquid)
uniform bool enable_specks = true;
uniform float speck_rise_speed : hint_range(0.05, 2.0) = 0.28;
uniform vec4 col_speck : source_color = vec4(0.0); // If alpha <= 0.0, uses base in shadow and highlight in base

void fragment() {
	// Snap UV to pixel grid (sample pixel center)
	vec2 pixel_uv = (floor(UV * pixel_grid_size) + vec2(0.5)) / pixel_grid_size;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(pixel_uv, center);

	// Circular mask
	if (dist > radius) {
		discard;
	}

	// Completely empty condition
	if (fill_amount <= 0.0) {
		discard;
	}

	// Fill level in UV space (y = 0 top, y = 1 bottom)
	float y_top = center.y - radius;
	float y_bottom = center.y + radius;
	float target_y = mix(y_bottom, y_top, clamp(fill_amount, 0.0, 1.0));

	// Wave sloshing (attenuated when nearly empty or nearly full)
	float edge_attenuation = smoothstep(0.0, 0.08, fill_amount) * smoothstep(1.0, 0.92, fill_amount);
	float t = TIME * wave_speed + time_offset;
	float wave = (sin(pixel_uv.x * wave_frequency + t) * wave_amplitude +
	              cos(pixel_uv.x * wave_frequency * 1.6 - t * 0.75) * (wave_amplitude * 0.4)) * edge_attenuation;

	float surface_y = target_y + wave;

	// Above the liquid surface
	if (pixel_uv.y < surface_y) {
		discard;
	}

	float depth_from_surface = pixel_uv.y - surface_y;
	float crest_thickness = 2.0 / pixel_grid_size;

	// 1. Surface Crest (Highlight)
	if (depth_from_surface <= crest_thickness) {
		COLOR = col_highlight;
	} else {
		// 2. Rounded Bottom Shadow (concentric upward-offset bowl crescent, moves with waves)
		float fill_scale = clamp(fill_amount * 1.35, 0.2, 1.0);
		float shadow_offset = radius * 0.36 * fill_scale;
		vec2 shadow_c = center - vec2(0.0, shadow_offset);

		// Shadow sloshes and sways along with the wave motion
		float shadow_t = t * 0.85 + 0.4;
		float shadow_wave = (sin(pixel_uv.x * wave_frequency + shadow_t) * wave_amplitude * 0.75 +
		                     cos(pixel_uv.x * wave_frequency * 1.4 - shadow_t * 0.7) * (wave_amplitude * 0.35)) * edge_attenuation;

		shadow_c.x -= wave * 0.8;
		shadow_c.y += shadow_wave * 0.8;

		float shadow_dist = distance(pixel_uv, shadow_c);
		// Geometric crescent intersection: tapers smoothly to zero along the sides
		float shadow_inner_r = sqrt(radius * radius + shadow_offset * shadow_offset);

		bool is_in_shadow = (shadow_dist >= shadow_inner_r);

		// 3. Rising Specks (Bubbles / floating illuminated motes)
		bool is_speck = false;
		if (enable_specks && fill_amount > 0.05) {
			vec2 p_grid = floor(pixel_uv * pixel_grid_size);

			// 10 seeds distributed across BOTH left and right sides of the globe (-0.62 to +0.55 relative to radius)
			const float seed_rel_x[10] = float[](-0.62, -0.45, -0.28, -0.12, 0.05, 0.22, 0.38, 0.55, -0.35, 0.42);
			const float seed_speed[10] = float[](1.0, 1.25, 0.92, 1.15, 0.88, 1.28, 0.95, 1.08, 1.18, 0.85);
			const float seed_sway[10]  = float[](1.8, -2.2, 1.5, -1.8, 2.0, -1.4, 1.9, -1.6, -1.5, 1.7);
			const float seed_phase[10] = float[](0.12, 0.47, 0.81, 0.28, 0.63, 0.93, 0.36, 0.72, 0.55, 0.18);

			for (int i = 0; i < 10; i++) {
				float p = fract((TIME * speck_rise_speed + seed_phase[i]) * seed_speed[i]);
				// Specks rise from bottom to surface of liquid
				float part_v = mix(y_bottom, surface_y + crest_thickness, p);
				float sway = sin(p * 6.283185 * 2.0 + float(i) * 1.7) * seed_sway[i];
				float part_u = center.x + (seed_rel_x[i] * radius) + (sway / pixel_grid_size);

				float bubble_grid_x = round(part_u * pixel_grid_size);
				float bubble_grid_y = round(part_v * pixel_grid_size);

				if (abs(p_grid.x - bubble_grid_x) < 0.5 && abs(p_grid.y - bubble_grid_y) < 0.5) {
					if (pixel_uv.y > surface_y + crest_thickness && dist < radius - (2.5 / pixel_grid_size)) {
						is_speck = true;
						break;
					}
				}
			}
		}

		if (is_speck) {
			// Specks are a lighter step: in shadow they use base, in base they use highlight
			COLOR = col_speck.a > 0.01 ? col_speck : (is_in_shadow ? col_base : col_highlight);
		} else {
			COLOR = is_in_shadow ? col_shadow : col_base;
		}
	}
}
