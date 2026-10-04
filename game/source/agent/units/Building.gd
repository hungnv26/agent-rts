extends "res://source/match/units/Structure.gd"

# A capability in the agent world (Research Lab, Code Factory, ...). Placed by AgentMatch.
# Kept plain on purpose: the model, its name, and a status line saying who is working
# inside (or that it needs you, for Human Approval). No lights, no effects.

const Fx = preload("res://source/agent/Fx.gd")

var building_id = ""
var label = ""
var model_path = ""
var model_size = 3.0  # footprint (largest horizontal extent) the model is fitted to
var accent = Color(0.4, 0.75, 1.0)

var alert = false:  # e.g. Human Approval has a pending request
	set(value):
		if alert != value:
			alert = value
			_render_status()

var _occupants = {}  # agent_id -> display name
var _label3d: Label3D
var _status3d: Label3D
var _pivot: Node3D


func _ready():
	if model_path != "":
		_pivot = Fx.fitted(model_path, model_size)
		find_child("Geometry").add_child(_pivot)
	await super()
	var ui_scale = _match.label_scale if "label_scale" in _match else 1.0
	var top = max(2.4, (_pivot.get_meta("height", 2.0) if _pivot else 2.0) + 0.7)
	_label3d = Fx.label(self, label, 26, Color(1.0, 0.97, 0.92), ui_scale)
	_label3d.position = Vector3(0, top, 0)
	_status3d = Fx.label(self, "", 19, accent.lightened(0.2), ui_scale)
	_status3d.position = Vector3(0, top, 0)
	_status3d.offset = Vector2(0, -30)
	_render_status()


func set_occupant(agent_id, working, display_name = ""):
	var changed = false
	if working and not _occupants.has(agent_id):
		_occupants[agent_id] = display_name if display_name != "" else str(agent_id).capitalize()
		changed = true
	elif not working and _occupants.has(agent_id):
		_occupants.erase(agent_id)
		changed = true
	if changed:
		_render_status()


func is_busy():
	return not _occupants.is_empty()


func _render_status():
	if _status3d == null:
		return
	if alert:
		_status3d.text = "Waiting for you"
		_status3d.modulate = Color(1.0, 0.62, 0.25)
	elif not _occupants.is_empty():
		_status3d.text = "%s working" % ", ".join(_occupants.values())
		_status3d.modulate = accent.lightened(0.25)
	else:
		_status3d.text = ""


func _setup_default_properties_from_constants():
	sight_range = 10.0
	hp = 20
	hp_max = 20
