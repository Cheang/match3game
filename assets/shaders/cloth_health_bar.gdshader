shader_type canvas_item;
render_mode blend_mix;

// Cloth wave animation settings
uniform float wave_amplitude : hint_range(0.0, 25.0) = 3.5;        // Max horizontal wiggle of the end edge (pixels)
uniform float wave_frequency : hint_range(1.0, 30.0) = 6.0;       // Number of folds along the vertical edge
uniform float wave_speed : hint_range(0.5, 20.0) = 6.0;            // Speed of the fluttering cloth
uniform float flutter_depth : hint_range(4.0, 80.0) = 80.0;        // How deep into the cloth the wind ripples extend (pixels)
uniform float vertical_flutter : hint_range(0.0, 6.0) = 0.0;       // Vertical ripple displacement near edge (pixels)
uniform float fold_shading : hint_range(0.0, 0.4) = 0.065;          // Highlight/shadow depth on cloth folds
uniform bool pixel_art_snap = true;                                // Snap displacements to whole pixels for crisp pixel art

varying float v_quad_u;
varying float v_local_x;

void vertex() {
	v_quad_u = (UV.x > 0.0001) ? 1.0 : 0.0;
	v_local_x = VERTEX.x;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a <= 0.01) {
		discard;
	}

	// Only apply cloth wiggle to the red progress fill (enm-hp-middle.png)
	bool is_red_cloth = (col.r > 0.38 && col.r > col.g * 1.25 && col.r > col.b * 1.25);
	if (!is_red_cloth) {
		COLOR = col;
	} else {
		// Distance in pixels from the right trailing edge of the progress quad
		float safe_u = max(v_quad_u, 0.0001);
		float dist_from_right = (1.0 - v_quad_u) * (v_local_x / safe_u);

		// Wave amplitude scales down if the progress bar is almost empty
		float quad_w = v_local_x / safe_u;
		float amp = wave_amplitude * clamp(quad_w / 24.0, 0.0, 1.0);

		// Multi-frequency wave for organic cloth flapping
		float t = TIME * wave_speed;
		float y_norm = UV.y * wave_frequency;
		float wave = sin(y_norm + t) * 0.72 + sin(y_norm * 2.1 - t * 1.3 + 0.8) * 0.28;

		// Inward wave cut from the quad's right edge
		float wave_cut = (wave * 0.5 + 0.5) * amp;
		if (pixel_art_snap) {
			wave_cut = floor(wave_cut + 0.5);
		}

		if (dist_from_right < wave_cut) {
			discard;
		}

		// Proximity to the waving edge
		float dist_from_wave_edge = dist_from_right - wave_cut;
		float flutter_factor = clamp(1.0 - dist_from_wave_edge / flutter_depth, 0.0, 1.0);
		flutter_factor = flutter_factor * flutter_factor;

		// Vertical fabric ripple traveling through the fabric towards the edge
		float v_disp = cos(y_norm * 1.4 + t * 1.1 + dist_from_wave_edge * 0.1) * vertical_flutter * flutter_factor;
		if (pixel_art_snap) {
			v_disp = floor(v_disp + 0.5);
		}

		vec2 sample_uv = UV;
		sample_uv.y = clamp(sample_uv.y + (v_disp * TEXTURE_PIXEL_SIZE.y), 0.0, 1.0);

		col = texture(TEXTURE, sample_uv);
		if (col.a <= 0.01) {
			discard;
		}

		// 3D fold highlights & shadows
		if (fold_shading > 0.0 && flutter_factor > 0.01) {
			float fold = sin(y_norm * 1.2 + t + dist_from_wave_edge * 0.15);
			col.rgb += vec3(fold * fold_shading * flutter_factor);
		}

		COLOR = col;
	}
}
