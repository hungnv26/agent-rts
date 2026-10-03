shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// A data conduit on the ground: faint rails with dashes flowing along it.
// `active` (0..1) brightens it and speeds the flow while an agent uses this route.

uniform vec4 color : source_color = vec4(0.4, 0.75, 1.0, 1.0);
uniform float active = 0.0;
uniform float length_units = 10.0;
uniform float direction = 1.0;

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.1, 0.9, across);
	float rails = smoothstep(0.78, 0.86, across) * (1.0 - smoothstep(0.92, 1.0, across));
	float t = UV.y * length_units * 0.9;
	float speed = mix(0.5, 2.6, active);
	float dash = smoothstep(0.55, 0.75, fract(t - direction * TIME * speed)) * (1.0 - smoothstep(0.85, 1.0, fract(t - direction * TIME * speed)));
	// Fade both ends so conduits melt into the pads.
	float ends = smoothstep(0.0, 0.06, UV.y) * (1.0 - smoothstep(0.94, 1.0, UV.y));
	float a = (core * (0.05 + 0.08 * active) + dash * core * (0.10 + 0.55 * active) + rails * (0.12 + 0.3 * active)) * ends;
	ALBEDO = color.rgb * 1.6;
	ALPHA = clamp(a, 0.0, 1.0);
}
