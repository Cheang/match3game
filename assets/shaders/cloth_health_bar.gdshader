shader_type canvas_item;
render_mode blend_mix;

// Health progress from 0.0 (empty) to 1.0 (full)
uniform float progress : hint_range(0.0, 1.0) = 1.0;

// Cloth wave animation settings
uniform float wave_amplitude : hint_range(0.0, 25.0) = 6.0;        // Max horizontal wiggle of the end edge (pixels)
uniform float wave_frequency : hint_range(1.0, 30.0) = 15.0;       // Number of folds along the vertical edge
uniform float wave_speed : hint_range(0.5, 20.0) = 6.0;            // Speed of the fluttering cloth
uniform float flutter_depth : hint_range(4.0, 80.0) = 32.0;        // How deep into the cloth the wind ripples extend (pixels)
uniform float vertical_flutter : hint_range(0.0, 6.0) = 1.5;       // Vertical ripple displacement near edge (pixels)
uniform float fold_shading : hint_range(0.0, 0.4) = 0.12;          // Highlight/shadow depth on cloth folds
uniform bool pixel_art_snap = true;                                // Snap displacements to whole pixels for crisp pixel art

void fragment() {
	if (progress <= 0.001) {
		discard;
	}

	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	float px_x = UV.x * tex_size.x;

	// Scale wave amplitude when near empty so wave doesn't invert past 0
	float amp = wave_amplitude * clamp(progress * 8.0, 0.0, 1.0);

	// Multi-frequency wave for organic cloth flapping
	float t = TIME * wave_speed;
	float y_norm = UV.y * wave_frequency;
	float wave = sin(y_norm + t) * 0.72 + sin(y_norm * 2.1 - t * 1.3 + 0.8) * 0.28;

	// Trailing edge cutoff position in pixels
	float edge_px = progress * tex_size.x + wave * amp;
	edge_px = clamp(edge_px, 0.0, tex_size.x - 3.0);

	if (pixel_art_snap) {
		edge_px = floor(edge_px + 0.5);
	}

	// Any pixel beyond the trailing edge is cut off
	if (px_x > edge_px) {
		discard;
	}

	// Proximity to the waving end: 1.0 right at the edge, 0.0 further left
	float dist_from_edge = edge_px - px_x;
	float flutter_factor = clamp(1.0 - dist_from_edge / flutter_depth, 0.0, 1.0);
	flutter_factor = flutter_factor * flutter_factor; // quadratic ease for natural drape

	// Vertical wave ripple traveling through the fabric towards the edge
	float v_disp = cos(y_norm * 1.4 + t * 1.1 + (px_x - edge_px) * 0.1) * vertical_flutter * flutter_factor;
	if (pixel_art_snap) {
		v_disp = floor(v_disp + 0.5);
	}

	vec2 sample_uv = UV;
	sample_uv.y = clamp(sample_uv.y + (v_disp / tex_size.y), 0.0, 1.0);

	vec4 col = texture(TEXTURE, sample_uv);
	if (col.a <= 0.01) {
		discard;
	}

	// 3D fold highlights & shadows
	if (fold_shading > 0.0 && flutter_factor > 0.01) {
		float fold = sin(y_norm * 1.2 + t + (px_x - edge_px) * 0.15);
		col.rgb += vec3(fold * fold_shading * flutter_factor);
	}

	COLOR = col;
}
