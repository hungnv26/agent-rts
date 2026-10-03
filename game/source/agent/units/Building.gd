extends "res://source/match/units/Structure.gd"

# A capability in the agent world (Research Lab, Code Factory, ...). Placed by AgentMatch.

var building_id = ""
var label = ""
var model_path = ""
var model_size = 3.0  # footprint (largest horizontal extent) the model is fitted to

var _occupants = {}
var _label3d: Label3D
var _activity_light: OmniLight3D


func _ready():
	if model_path != "":
		var model = load(model_path).instantiate()
		find_child("Geometry").add_child(model)
		_fit_model(model)
	await super()
	_label3d = Label3D.new()
	_label3d.text = label
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.no_depth_test = true
	_label3d.fixed_size = true
	_label3d.pixel_size = 0.0009
	_label3d.font_size = 30
	_label3d.outline_size = 10
	_label3d.modulate = Color(0.92, 0.95, 1.0)
	_label3d.outline_modulate = Color(0.05, 0.07, 0.12, 0.9)
	_label3d.position = Vector3(0, 2.6, 0)
	add_child(_label3d)
	_activity_light = OmniLight3D.new()
	_activity_light.position = Vector3(0, 1.5, 0)
	_activity_light.omni_range = 4.5
	_activity_light.light_energy = 0.0
	_activity_light.light_color = Color(0.45, 0.85, 1.0)
	add_child(_activity_light)


# The building glows while at least one agent works inside it.
func set_occupant(agent_id, working):
	if working:
		_occupants[agent_id] = true
	else:
		_occupants.erase(agent_id)


func _process(delta):
	if _activity_light == null:
		return
	var target = 0.0
	if not _occupants.is_empty():
		target = 1.6 + 0.6 * sin(Time.get_ticks_msec() / 250.0)
	_activity_light.light_energy = lerpf(_activity_light.light_energy, target, clampf(delta * 6.0, 0.0, 1.0))
	if _label3d != null:
		_label3d.modulate = Color(0.6, 0.95, 1.0) if not _occupants.is_empty() else Color(0.92, 0.95, 1.0)


# Kenney models have arbitrary origins and sizes: centre the model on the building and
# scale it so its footprint matches model_size.
func _fit_model(model: Node3D):
	var box = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var rel = Transform3D.IDENTITY
		var n = mi
		while n != model:
			rel = n.transform * rel
			n = n.get_parent()
		var aabb = rel * mi.mesh.get_aabb()
		box = aabb if box == null else box.merge(aabb)
	if box == null:
		return
	var extent = max(box.size.x, box.size.z)
	var s = model_size / extent if extent > 0.001 else 1.0
	model.scale = Vector3.ONE * s
	var c = box.get_center()
	model.position = Vector3(-c.x * s, -box.position.y * s, -c.z * s)


func _setup_default_properties_from_constants():
	sight_range = 10.0
	hp = 20
	hp_max = 20
