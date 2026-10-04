shader_type spatial;
render_mode unshaded;

// Plain dark ground: a fine grid inside the base, a perimeter line, and coloured zones
// under each building that brighten while it is in use.

uniform vec3 base_color : source_color = vec3(0.05, 0.07, 0.11);
uniform vec3 dust_color : source_color = vec3(0.09, 0.08, 0.09);
uniform vec3 line_color : source_color = vec3(0.22, 0.38, 0.6);
uniform vec2 play_size = vec2(32.0, 32.0);
// xy = centre (world x, z), z = radius, w = intensity
uniform vec4 zones[8];
uniform vec4 zone_colors[8];
uniform int zone_count = 0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
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

	// Soft edge of the playable area (1 unit falloff).
	vec2 d = max(vec2(0.0) - p, p - play_size);
	float outside = clamp(max(d.x, d.y), 0.0, 6.0) / 6.0;
	float inside = 1.0 - smoothstep(0.0, 1.0, max(d.x, d.y));

	vec3 col = mix(base_color, base_color * 0.45, outside);

	// Gentle light pool towards the centre of the base.
	float glow = 1.0 - smoothstep(0.0, length(c) * 1.15, length(p - c));
	col += vec3(0.015, 0.03, 0.055) * glow;

	// Building zones.
	for (int i = 0; i < zone_count; i++) {
		float r = zones[i].z;
		float dist = length(p - zones[i].xy);
		float zone = 1.0 - smoothstep(r * 0.25, r, dist);
		float ring = (1.0 - smoothstep(0.0, 0.08, abs(dist - r * 0.82))) * 0.5;
		col += zone_colors[i].rgb * (zone * 0.10 + ring * 0.25) * zones[i].w;
	}

	// Grid only inside the base; major lines every 4 units.
	float minor = grid(p, 1.0, 1.0) * 0.07;
	float major = grid(p, 4.0, 1.5) * 0.22;
	col = mix(col, line_color, max(minor, major) * inside);

	// Base perimeter line.
	float edge = (1.0 - smoothstep(0.0, 0.12, abs(max(d.x, d.y)))) * 0.8;
	col = mix(col, vec3(0.35, 0.65, 1.0), edge);

	ALBEDO = col;
}
