extends "res://source/match/units/Structure.gd"

# A Hollow nest: a crystal outcrop the swarm grew into. It has no production queue; the
# Hollow player spawns waves next to it. Burn out every nest and the Hollow is gone.

const CRYSTAL_ALBEDO = Color(0.4687, 0.944, 0.7938)  # Kenney's crystal material
const CRYSTAL_ALBEDO_EPSILON = 0.05
const PULSE_SPEED = 1.3

var _glow = null
var _pad = null
var _t = 0.0


func _ready():
	await super()
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.45, 0.2, 0.75)
	_glow.emission_enabled = true
	_glow.emission = Color(0.6, 0.2, 1.0)
	_glow.emission_energy_multiplier = 1.2
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		find_child("Geometry"), CRYSTAL_ALBEDO, CRYSTAL_ALBEDO_EPSILON, _glow
	)
	_pad = _make_pad()
	find_child("Geometry").add_child(_pad)


func _process(delta):
	_t += delta
	if _glow != null:
		_glow.emission_energy_multiplier = 0.9 + 0.5 * sin(_t * PULSE_SPEED)


func _make_pad():
	var mesh = CylinderMesh.new()
	mesh.top_radius = 2.3
	mesh.bottom_radius = 2.3
	mesh.height = 0.04
	mesh.radial_segments = 24
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.05, 0.25, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	var pad = MeshInstance3D.new()
	pad.mesh = mesh
	pad.material_override = material
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.position = Vector3(0, 0.02, 0)
	return pad
