shader_type spatial;
render_mode cull_disabled;

// Diagonal hazard stripes for the Repair Bay pad; `alert` makes the yellow glow.

uniform vec3 stripe_a : source_color = vec3(0.95, 0.72, 0.12);
uniform vec3 stripe_b : source_color = vec3(0.06, 0.06, 0.08);
uniform float alert = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = step(0.5, fract((world_pos.x + world_pos.z) * 1.4));
	ALBEDO = mix(stripe_b, stripe_a, s);
	METALLIC = 0.3;
	ROUGHNESS = 0.6;
	EMISSION = stripe_a * s * (0.15 + 1.4 * alert * (0.6 + 0.4 * sin(TIME * 8.0)));
}
