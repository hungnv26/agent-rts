shader_type spatial;

// Ground for every terrain theme (see Terrains.gd). Static: no animation, no emission.
// color_a/b make large soft patches, color_c is the accent used by dunes, rock strata,
// crater rims and ice cracks. Each feature is off at 0.

uniform vec3 color_a : source_color = vec3(0.96, 0.75, 0.65);
uniform vec3 color_b : source_color = vec3(0.92, 0.70, 0.60);
uniform vec3 color_c : source_color = vec3(0.80, 0.55, 0.45);
uniform float patch_scale = 0.08;
uniform float patch_amount = 0.5;
uniform float grain = 0.15;
uniform float dunes = 0.0;
uniform float strata = 0.0;
uniform float craters = 0.0;
uniform float cracks = 0.0;
uniform float metallic_value = 0.0;
uniform float roughness_value = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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

// x: distance to nearest cell point, y: distance to the cell edge, z: cell random
vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash(n + g);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = fbm(p * patch_scale);
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.65, n) * patch_amount * 2.0);

	// Fine grain so the ground doesn't look like flat paint.
	col *= 1.0 + (fbm(p * 1.7) - 0.5) * grain;

	if (dunes > 0.0) {
		float w = fbm(p * 0.06) * 7.0;
		float ridge = pow(0.5 + 0.5 * sin(p.x * 0.32 + p.y * 0.12 + w), 6.0);
		col = mix(col, color_c, ridge * dunes);
	}
	if (strata > 0.0) {
		float band = fract((p.x * 0.6 + p.y) * 0.07 + fbm(p * 0.05) * 1.2);
		float line = smoothstep(0.0, 0.08, band) * (1.0 - smoothstep(0.12, 0.22, band));
		col = mix(col, color_c, line * strata);
		col *= 1.0 - 0.08 * strata * step(0.5, fract(band * 3.0));
	}
	if (craters > 0.0) {
		vec3 v = voronoi(p * 0.16);
		float r = mix(0.18, 0.42, fract(v.z * 7.13));
		float present = step(0.55, v.z);
		float basin = 1.0 - smoothstep(r * 0.6, r, v.x);
		float rim = smoothstep(r * 0.8, r, v.x) * (1.0 - smoothstep(r, r * 1.25, v.x));
		float shade = smoothstep(0.0, r, v.x);  // deeper towards the middle
		col = mix(col, col * mix(0.62, 0.9, shade), basin * present * craters);
		col = mix(col, color_c, rim * present * craters * 0.3);
	}
	if (cracks > 0.0) {
		vec3 v = voronoi(p * 0.22 + vec2(fbm(p * 0.3)) * 0.6);
		float crack = 1.0 - smoothstep(0.0, 0.05, v.y);
		col = mix(col, color_c, crack * cracks);
	}
	ALBEDO = col;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
}
