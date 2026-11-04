shader_type canvas_item;
render_mode blend_mix;

// Glint appearance
uniform vec4 glint_color : source_color = vec4(0.9, 0.96, 1.0, 1.0);
uniform float glint_intensity : hint_range(0.0, 3.0) = 1.4;
uniform float glint_width : hint_range(0.02, 0.35) = 0.10;
uniform float glint_angle : hint_range(-60.0, 60.0) = 35.0; // In degrees

// Timing
uniform float cycle_duration : hint_range(0.5, 10.0) = 3.0; // Total cycle in seconds
uniform float sweep_duration : hint_range(0.2, 3.0) = 0.9;  // Sweep duration in seconds

// Extra polish
uniform bool dual_beam = true;                              // Secondary trailing glint beam
uniform float secondary_offset : hint_range(0.02, 0.2) = 0.08;
uniform float secondary_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float ambient_metallic : hint_range(0.0, 0.4) = 0.08; // Base metal luster

varying float v_quad_u;

void vertex() {
	v_quad_u = (UV.x > 0.0001) ? 1.0 : 0.0;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a <= 0.01) {
		discard;
	}

	// Diagonal tilt offset based on Y position
	float rad = radians(glint_angle);
	float tilt = (UV.y - 0.5) * 0.4 * tan(rad);
	float beam_pos = v_quad_u + tilt;

	// Sweep timing
	float cycle_t = mod(TIME, cycle_duration);
	float beam_val = 0.0;

	if (cycle_t < sweep_duration) {
		float t_norm = cycle_t / sweep_duration;
		// Ease sweep from off-left (-0.3) to off-right (1.3)
		float beam_center = mix(-0.3, 1.3, t_norm);

		// Primary glint
		float dist1 = abs(beam_pos - beam_center);
		float beam1 = smoothstep(glint_width, 0.0, dist1);
		beam1 = pow(beam1, 2.0);
		beam_val += beam1;

		// Dual secondary trailing beam
		if (dual_beam) {
			float dist2 = abs(beam_pos - (beam_center - secondary_offset));
			float beam2 = smoothstep(glint_width * 0.6, 0.0, dist2);
			beam2 = pow(beam2, 2.5) * secondary_intensity;
			beam_val += beam2;
		}
	}

	// Ambient subtle metallic shimmer across the surface
	float ambient = ambient_metallic * (0.8 + 0.2 * sin(v_quad_u * 25.0 + TIME * 2.5));

	// Apply specular highlight to armor
	float total = beam_val * glint_intensity + ambient;
	if (total > 0.001) {
		vec3 highlight = glint_color.rgb * total;
		col.rgb += highlight * col.a;
	}

	COLOR = col;
}
