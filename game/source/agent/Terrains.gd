extends RefCounted

# Terrain themes: ground shader parameters plus light colour. Ids match the adapter's
# TERRAINS list (adapter/src/layout.ts).

const ORDER = ["grassland", "sahara", "arctic", "beach", "canyon", "mars", "moon", "venus", "europa", "titan"]

const PRESETS = {
	# ---- Earth ----
	"grassland": {
		"name": "Grassland", "group": "Earth",
		"a": Color(0.42, 0.62, 0.30), "b": Color(0.52, 0.68, 0.33), "c": Color(0.36, 0.52, 0.26),
		"patch_scale": 0.07, "patch_amount": 0.5, "grain": 0.22,
		"road": Color(0.55, 0.45, 0.32),
		"sun": Color(1.0, 0.97, 0.9), "sun_energy": 0.9, "ambient": Color(0.85, 0.92, 1.0), "ambient_energy": 0.5,
	},
	"sahara": {
		"name": "Sahara Desert", "group": "Earth",
		"a": Color(0.90, 0.74, 0.50), "b": Color(0.85, 0.68, 0.43), "c": Color(0.74, 0.56, 0.33),
		"patch_scale": 0.05, "patch_amount": 0.45, "grain": 0.12, "dunes": 0.55,
		"road": Color(0.62, 0.47, 0.30),
		"sun": Color(1.0, 0.94, 0.82), "sun_energy": 0.85, "ambient": Color(1.0, 0.93, 0.82), "ambient_energy": 0.4,
	},
	"arctic": {
		"name": "Arctic Ice", "group": "Earth",
		"a": Color(0.86, 0.91, 0.97), "b": Color(0.76, 0.84, 0.93), "c": Color(0.60, 0.72, 0.86),
		"patch_scale": 0.06, "patch_amount": 0.5, "grain": 0.06, "cracks": 0.35,
		"road": Color(0.56, 0.62, 0.72),
		"sun": Color(0.95, 0.97, 1.0), "sun_energy": 0.8, "ambient": Color(0.85, 0.92, 1.0), "ambient_energy": 0.4,
	},
	"beach": {
		"name": "Tropical Beach", "group": "Earth",
		"a": Color(0.92, 0.84, 0.64), "b": Color(0.86, 0.77, 0.57), "c": Color(0.78, 0.69, 0.52),
		"patch_scale": 0.09, "patch_amount": 0.45, "grain": 0.16, "dunes": 0.2,
		"road": Color(0.64, 0.54, 0.40),
		"sun": Color(1.0, 0.97, 0.88), "sun_energy": 0.85, "ambient": Color(0.88, 0.95, 1.0), "ambient_energy": 0.45,
	},
	"canyon": {
		"name": "Grand Canyon", "group": "Earth",
		"a": Color(0.78, 0.45, 0.30), "b": Color(0.85, 0.55, 0.36), "c": Color(0.62, 0.33, 0.22),
		"patch_scale": 0.06, "patch_amount": 0.4, "grain": 0.18, "strata": 0.6,
		"road": Color(0.60, 0.40, 0.30),
		"sun": Color(1.0, 0.9, 0.78), "sun_energy": 0.9, "ambient": Color(1.0, 0.88, 0.8), "ambient_energy": 0.5,
	},
	# ---- Other worlds ----
	"mars": {
		"name": "Mars", "group": "Planets",
		"a": Color(0.96, 0.75, 0.65), "b": Color(0.93, 0.71, 0.61), "c": Color(0.85, 0.62, 0.53),
		"patch_scale": 0.06, "patch_amount": 0.3, "grain": 0.03,
		"metallic": 1.0, "roughness": 1.0,
		"road": Color(0.62, 0.42, 0.36),
		"sun": Color(1.0, 1.0, 1.0), "sun_energy": 1.0, "ambient": Color(1.0, 1.0, 1.0), "ambient_energy": 1.0,
	},
	"moon": {
		"name": "The Moon", "group": "Planets",
		"a": Color(0.62, 0.62, 0.62), "b": Color(0.54, 0.54, 0.55), "c": Color(0.75, 0.75, 0.75),
		"patch_scale": 0.05, "patch_amount": 0.5, "grain": 0.2, "craters": 0.9,
		"road": Color(0.36, 0.36, 0.37),
		"sun": Color(1.0, 1.0, 1.0), "sun_energy": 1.0, "ambient": Color(0.75, 0.78, 0.85), "ambient_energy": 0.35,
	},
	"venus": {
		"name": "Venus", "group": "Planets",
		"a": Color(0.76, 0.62, 0.38), "b": Color(0.68, 0.53, 0.32), "c": Color(0.55, 0.42, 0.26),
		"patch_scale": 0.05, "patch_amount": 0.55, "grain": 0.2, "cracks": 0.3,
		"road": Color(0.50, 0.40, 0.26),
		"sun": Color(1.0, 0.85, 0.55), "sun_energy": 0.85, "ambient": Color(1.0, 0.85, 0.6), "ambient_energy": 0.5,
	},
	"europa": {
		"name": "Europa", "group": "Planets",
		"a": Color(0.86, 0.90, 0.95), "b": Color(0.78, 0.83, 0.90), "c": Color(0.62, 0.44, 0.36),
		"patch_scale": 0.06, "patch_amount": 0.5, "grain": 0.08, "cracks": 0.75,
		"road": Color(0.56, 0.60, 0.70),
		"sun": Color(0.9, 0.94, 1.0), "sun_energy": 0.8, "ambient": Color(0.78, 0.86, 1.0), "ambient_energy": 0.45,
	},
	"titan": {
		"name": "Titan", "group": "Planets",
		"a": Color(0.66, 0.48, 0.28), "b": Color(0.58, 0.40, 0.22), "c": Color(0.45, 0.30, 0.18),
		"patch_scale": 0.05, "patch_amount": 0.6, "grain": 0.14, "dunes": 0.35,
		"road": Color(0.44, 0.32, 0.20),
		"sun": Color(1.0, 0.75, 0.45), "sun_energy": 0.75, "ambient": Color(1.0, 0.78, 0.52), "ambient_energy": 0.55,
	},
}


static func get_preset(id: String) -> Dictionary:
	return PRESETS.get(id, PRESETS["mars"])


static func apply_to_material(mat: ShaderMaterial, id: String):
	var t = get_preset(id)
	mat.set_shader_parameter("color_a", t["a"])
	mat.set_shader_parameter("color_b", t["b"])
	mat.set_shader_parameter("color_c", t["c"])
	mat.set_shader_parameter("patch_scale", t.get("patch_scale", 0.06))
	mat.set_shader_parameter("patch_amount", t.get("patch_amount", 0.4))
	mat.set_shader_parameter("grain", t.get("grain", 0.12))
	mat.set_shader_parameter("dunes", t.get("dunes", 0.0))
	mat.set_shader_parameter("strata", t.get("strata", 0.0))
	mat.set_shader_parameter("craters", t.get("craters", 0.0))
	mat.set_shader_parameter("cracks", t.get("cracks", 0.0))
	mat.set_shader_parameter("metallic_value", t.get("metallic", 0.0))
	mat.set_shader_parameter("roughness_value", t.get("roughness", 1.0))
