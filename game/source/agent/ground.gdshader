shader_type spatial;
render_mode unshaded;

// Mission-control ground: dark slate with a 1 m grid, a brighter 4 m grid, and a soft
// glow over the playable area (0..play_size).

uniform vec3 base_color : source_color = vec3(0.055, 0.075, 0.115);
uniform vec3 line_color : source_color = vec3(0.22, 0.36, 0.55);
uniform vec2 play_size = vec2(32.0, 32.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p, float spacing, float width) {
	vec2 g = abs(fract(p / spacing - 0.5) - 0.5) * spacing;
	vec2 fw = fwidth(p);
	vec2 l = 1.0 - smoothstep(vec2(0.0), fw * width, g);
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 c = play_size * 0.5;
	float inside = step(0.0, p.x) * step(0.0, p.y) * step(p.x, play_size.x) * step(p.y, play_size.y);
	float glow = 1.0 - smoothstep(0.0, length(c) * 1.1, length(p - c));
	vec3 col = base_color * (0.55 + 0.45 * inside) + vec3(0.02, 0.035, 0.06) * glow;
	float minor = grid(p, 1.0, 1.0) * 0.18;
	float major = grid(p, 4.0, 1.5) * 0.45;
	col = mix(col, line_color, max(minor, major) * (0.35 + 0.65 * inside));
	ALBEDO = col;
}
