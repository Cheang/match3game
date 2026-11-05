shader_type canvas_item;

// Magic Armor Shield Shader: Animate the arcane energy shield with pixel-perfect flow,
// breathing pulse, and rotating celestial glints.

// --- Wave Displacement ---
uniform float wave_amplitude : hint_range(0.0, 5.0, 0.1) = 0.8;
uniform float wave_frequency : hint_range(0.0, 20.0, 0.5) = 6.0;
uniform float wave_radial_freq : hint_range(0.0, 30.0, 0.5) = 10.0;
uniform float wave_speed : hint_range(-10.0, 10.0, 0.1) = 3.2;
uniform float wave_bias : hint_range(-1.0, 1.0, 0.05) = 0.0;

// --- Breathing Pulse ---
uniform float pulse_speed : hint_range(0.5, 6.0, 0.1) = 2.6;
uniform float pulse_amount : hint_range(0.0, 0.4, 0.01) = 0.12;

// --- Celestial Glint ---
uniform float glint_speed : hint_range(0.2, 5.0, 0.1) = 1.8;
uniform vec4 tint_glow : source_color = vec4(0.35, 0.88, 1.0, 1.0);

// --- Shield Display Parameters ---
uniform float pixel_grid_size : hint_range(16.0, 128.0, 1.0) = 64.0;
uniform float shield_alpha : hint_range(0.0, 1.0, 0.05) = 1.0;

void fragment() {
	// Snap to pixel grid to keep pixel art authentic and crisp
	vec2 p_uv = (floor(UV * pixel_grid_size) + vec2(0.5)) / pixel_grid_size;
	vec2 center = vec2(0.5, 0.5);
	vec2 dir = p_uv - center;
	float dist = length(dir);
	float angle = atan(dir.y, dir.x);

	// Arcane flow: controllable wave displacement
	float wave = (sin(angle * wave_frequency - TIME * wave_speed + dist * wave_radial_freq) + wave_bias) * (wave_amplitude / pixel_grid_size);
	vec2 sample_uv = p_uv + (dir / max(0.001, dist)) * wave;
	sample_uv = (floor(sample_uv * pixel_grid_size) + vec2(0.5)) / pixel_grid_size;

	vec4 tex = texture(TEXTURE, sample_uv);
	if (tex.a <= 0.01) {
		discard;
	}

	// Breathing energy pulse
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	// Rotating energy glint around the shield circumference
	float rot_glint = sin(angle - TIME * glint_speed);
	rot_glint = pow(max(0.0, rot_glint), 3.5) * 0.4;

	// Enhanced celestial highlights
	vec3 out_rgb = tex.rgb * pulse + tint_glow.rgb * rot_glint;
	float out_a = tex.a * shield_alpha;

	COLOR = vec4(out_rgb, out_a);
}
