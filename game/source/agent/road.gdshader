shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// A packed-dirt track on the Martian sand: darker centre, soft edges, tyre ruts.
// `in_use` (0..1) darkens it a little while an agent travels or works at its end.

uniform vec3 dirt : source_color = vec3(0.62, 0.42, 0.36);
uniform float in_use = 0.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float body = 1.0 - smoothstep(0.55, 1.0, across);
	float ruts = (1.0 - smoothstep(0.0, 0.12, abs(across - 0.45))) * 0.35;
	float ends = smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.92, 1.0, UV.y));
	ALBEDO = dirt * (1.0 - ruts * 0.25 - in_use * 0.12);
	ROUGHNESS = 1.0;
	ALPHA = body * ends * (0.55 + 0.25 * in_use);
}
