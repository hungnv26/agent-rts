extends "res://source/match/units/Unit.gd"

# One AI agent. The adapter decides *what* the agent is doing; this node decides *how it
# looks*: it walks between locations, shows a status badge, and paces fast state changes
# so every step stays readable (an agent that finishes a task in 200 ms still visibly
# walks to the building and back).

signal state_applied(agent)

const Moving = preload("res://source/match/units/actions/Moving.gd")
const Fx = preload("res://source/agent/Fx.gd")

const MIN_DWELL_S = 1.2  # stay at least this long after arriving before walking on
const MAX_TRAVEL_WAIT_S = 9.0  # don't let a stuck walk block the queue forever
const MAX_QUEUE = 4

const STATE_STYLE = {
	"idle": {"text": "IDLE", "color": Color(0.72, 0.76, 0.82)},
	"thinking": {"text": "THINKING", "color": Color(0.75, 0.62, 1.0)},
	"working": {"text": "WORKING", "color": Color(0.35, 0.85, 1.0)},
	"waiting": {"text": "WAITING", "color": Color(1.0, 0.82, 0.35)},
	"approval": {"text": "NEEDS APPROVAL", "color": Color(1.0, 0.55, 0.2)},
	"error": {"text": "ERROR", "color": Color(1.0, 0.35, 0.35)},
	"complete": {"text": "DONE", "color": Color(0.4, 0.95, 0.55)},
}

var agent_id = ""
var display_name = ""
var role_color = Color.WHITE
# Callable(location_id: String, agent_id: String) -> Vector3
var resolve_target: Callable

var data = {}  # last applied agent dict from the adapter
var state = "idle"
var location = "command_centre"

var _queue = []
var _moving = false
var _move_started_at = -100.0
var _arrived_at = -100.0
var _badge: Label3D
var _name_label: Label3D
var _thinking_ring: MeshInstance3D
var _geometry: Node3D
var _geometry_base_y = 0.0
var _ring_mat: StandardMaterial3D


func _ready():
	await super()
	_geometry = find_child("Geometry")
	_geometry_base_y = _geometry.position.y
	_name_label = _make_label(26, Vector3(0, 1.1, 0))
	_name_label.offset = Vector2(0, 40)
	_name_label.text = display_name
	_name_label.modulate = role_color.lightened(0.25)
	_badge = _make_label(20, Vector3(0, 1.1, 0))
	_thinking_ring = _make_thinking_ring()
	_ring_mat = Fx.additive(role_color, 0.35)
	var ring = Fx.torus(0.55, 0.7, _ring_mat, 0.03)
	ring.position.y = 0.05
	add_child(ring)
	_render_badge()


func push_state(agent_dict):
	_queue.append(agent_dict)
	# Too far behind: drop intermediate steps, keep the two most recent.
	while _queue.size() > MAX_QUEUE:
		_queue.remove_at(0)


func snap_to(agent_dict):
	_queue.clear()
	_apply(agent_dict, false)
	global_position = resolve_target.call(location, agent_id)


func is_moving():
	return _moving


func _process(delta):
	var now = Time.get_ticks_msec() / 1000.0
	var still_moving = action != null and action is Moving
	if _moving and not still_moving:
		_arrived_at = now
	_moving = still_moving

	if not _queue.is_empty():
		var next = _queue[0]
		if next.get("location", location) == location:
			_queue.remove_at(0)
			_apply(next, false)
		elif (
			(not _moving and now - _arrived_at >= MIN_DWELL_S)
			or (_moving and now - _move_started_at > MAX_TRAVEL_WAIT_S)
			or _queue.size() >= MAX_QUEUE
		):
			_queue.remove_at(0)
			_apply(next, true)
			_move_started_at = now

	_animate(delta, now)


func _apply(agent_dict, walk):
	data = agent_dict
	state = agent_dict.get("state", "idle")
	var new_location = agent_dict.get("location", location)
	var changed = new_location != location
	location = new_location
	if walk and changed and resolve_target.is_valid():
		action = Moving.new(resolve_target.call(location, agent_id))
		_moving = true
	_render_badge()
	state_applied.emit(self)


func _render_badge():
	if _badge == null:
		return
	var style = STATE_STYLE.get(state, STATE_STYLE["idle"])
	var text = style["text"]
	var progress = data.get("progress")
	if state == "working" and progress != null:
		text += "  %d%%" % int(round(float(progress) * 100.0))
	if _moving:
		text = "> " + text
	_badge.text = text
	_badge.modulate = style["color"]


func _animate(delta, now):
	if _geometry == null:
		return
	var bob = 0.0
	if state == "working" and not _moving:
		bob = 0.08 * abs(sin(now * 6.0))
	_geometry.position.y = lerpf(_geometry.position.y, _geometry_base_y + bob, clampf(delta * 12.0, 0.0, 1.0))
	var ring_alpha = 0.3
	if state == "working" and not _moving:
		ring_alpha = 0.55 + 0.3 * sin(now * 6.0)
	elif state == "error":
		ring_alpha = 0.4 + 0.4 * abs(sin(now * 5.0))
	_ring_mat.albedo_color = Color(Color(1.0, 0.3, 0.3) if state == "error" else role_color, ring_alpha)
	_thinking_ring.visible = state == "thinking"
	if _thinking_ring.visible:
		_thinking_ring.rotation.y = now * 3.0
	if state == "error" or state == "approval":
		_badge.modulate.a = 0.55 + 0.45 * abs(sin(now * 4.0))
	elif _badge != null:
		_badge.modulate.a = 1.0
	_render_badge_moving_prefix()


func _render_badge_moving_prefix():
	if _badge == null:
		return
	var has_prefix = _badge.text.begins_with("> ")
	if has_prefix != _moving:
		_render_badge()


func _make_label(font_size, pos):
	var ui_scale = _match.ui_scale if "ui_scale" in _match else 1.0
	var l = Fx.label(self, "", font_size, Color.WHITE, ui_scale, 0.0008)
	l.position = pos
	return l


func _make_thinking_ring():
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.68
	ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.62, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.position = Vector3(0, 0.9, 0)
	ring.visible = false
	add_child(ring)
	return ring


func _setup_color():
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = role_color
	mat.metallic = 0.6
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		find_child("Geometry"), MATERIAL_ALBEDO_TO_REPLACE, MATERIAL_ALBEDO_TO_REPLACE_EPSILON, mat
	)


func _setup_default_properties_from_constants():
	sight_range = 6.0
	hp = 10
	hp_max = 10
