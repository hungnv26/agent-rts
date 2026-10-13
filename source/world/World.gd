extends Node3D

# The world a match is played on: the terrain's baked texture set on the map's ground (and a
# backdrop of the same ground beyond the map's edge), the terrain's light, scenery around the
# map, and the day cycle. Reads `terrain` from the match settings (Terrains.PRESETS keys).

const Terrains = preload("res://source/world/Terrains.gd")
const SceneryScript = preload("res://source/world/Scenery.gd")
const TERRAIN_SHADER = preload("res://source/world/terrain.gdshader")

const BACKDROP_SIZE = 420.0
const NIGHT_SUN_ENERGY = 0.22
const NIGHT_AMBIENT_ENERGY = 0.18
const NIGHT_TINT = Color(0.55, 0.65, 1.0)
const LIGHT_LERP_SPEED = 0.35  # per second

var terrain_id = "grassland"

var _time = 0.0
var _night = false
var _sun_target_energy = 1.0
var _sun_target_color = Color.WHITE
var _ambient_target_energy = 0.4
var _ambient_target_color = Color.WHITE
var _preset = {}
var _env = null
var _sun = null
var _scenery = null

@onready var _match = find_parent("Match")


func _ready():
	if not _match.is_node_ready():
		await _match.ready
	terrain_id = _match.settings.terrain if "terrain" in _match.settings else "grassland"
	_preset = Terrains.get_preset(terrain_id)
	_apply_ground()
	_apply_light()
	_scenery = SceneryScript.new()
	_scenery.map_size = max(_match.map.size.x, _match.map.size.y)
	add_child(_scenery)
	_scenery.build(terrain_id)
	_time = Constants.Match.DayCycle.DAY_LENGTH_S * 0.1  # start mid-morning


func is_day():
	return not _night


func day_fraction():
	return _time / Constants.Match.DayCycle.DAY_LENGTH_S


func _process(delta):
	var day_length = Constants.Match.DayCycle.DAY_LENGTH_S
	_time = fmod(_time + delta, day_length)
	var night_now = _time > day_length * (1.0 - Constants.Match.DayCycle.NIGHT_FRACTION)
	if night_now != _night:
		_night = night_now
		_set_light_targets()
		_scale_sight_ranges()
		if _night:
			MatchSignals.night_started.emit()
		else:
			MatchSignals.day_started.emit()
	if _sun != null:
		var k = clampf(delta * LIGHT_LERP_SPEED * 4.0, 0.0, 1.0)
		_sun.light_energy = lerpf(_sun.light_energy, _sun_target_energy, k)
		_sun.light_color = _sun.light_color.lerp(_sun_target_color, k)
		_env.ambient_light_energy = lerpf(_env.ambient_light_energy, _ambient_target_energy, k)
		_env.ambient_light_color = _env.ambient_light_color.lerp(_ambient_target_color, k)


func _apply_ground():
	var terrain_mesh = _match.map.find_child("Terrain").mesh
	var material = ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	Terrains.apply_to_material(material, terrain_id)
	terrain_mesh.material = material
	var backdrop_mesh = PlaneMesh.new()
	backdrop_mesh.size = Vector2(BACKDROP_SIZE, BACKDROP_SIZE)
	backdrop_mesh.material = material
	var backdrop = MeshInstance3D.new()
	backdrop.mesh = backdrop_mesh
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.position = Vector3(_match.map.size.x * 0.5, -0.02, _match.map.size.y * 0.5)
	add_child(backdrop)


func _apply_light():
	var env_node = _match.get_node_or_null("WorldEnvironment")
	_sun = _match.get_node_or_null("DirectionalLight3D")
	if env_node == null or _sun == null:
		return
	env_node.environment = env_node.environment.duplicate()
	_env = env_node.environment
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.fog_enabled = false
	_env.volumetric_fog_enabled = false
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.0
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.1
	_env.adjustment_contrast = 1.05
	_env.glow_enabled = true
	_env.glow_intensity = 0.3
	_env.glow_hdr_threshold = 1.3
	_sun.light_angular_distance = 1.5
	_sun.shadow_blur = 1.2
	_set_light_targets()
	_sun.light_energy = _sun_target_energy
	_sun.light_color = _sun_target_color
	_env.ambient_light_energy = _ambient_target_energy
	_env.ambient_light_color = _ambient_target_color


func _set_light_targets():
	if _night:
		_sun_target_energy = NIGHT_SUN_ENERGY
		_sun_target_color = NIGHT_TINT
		_ambient_target_energy = NIGHT_AMBIENT_ENERGY
		_ambient_target_color = NIGHT_TINT
	else:
		_sun_target_energy = _preset["sun_energy"]
		_sun_target_color = _preset["sun"]
		_ambient_target_energy = _preset["ambient_energy"]
		_ambient_target_color = _preset["ambient"]


# At night every unit sees less far (Scout Drones excepted: they see in the dark).
func _scale_sight_ranges():
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.sight_range == null or unit.type == "Drone":
			continue
		if not unit.has_meta("day_sight_range"):
			unit.set_meta("day_sight_range", unit.sight_range)
		var day_range = unit.get_meta("day_sight_range")
		unit.sight_range = (
			day_range * Constants.Match.DayCycle.NIGHT_SIGHT_FACTOR if _night else day_range
		)
