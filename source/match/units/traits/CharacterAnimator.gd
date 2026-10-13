extends Node

# Plays a Quaternius character's animations from what its unit is doing: Idle when standing,
# Walk or Run when the unit moves (Run at or above `run_speed`), an attack loop while the
# unit is firing, and Death as a short-lived corpse when the unit dies. Attach under any unit
# whose Geometry holds an animated model; it removes itself when there is no AnimationPlayer.

const ROLES = {
	"idle": ["Idle", "Flying_Idle"],
	"walk": ["Walk", "Fast_Flying"],
	"run": ["Run", "Fast_Flying"],
	"attack": ["Shoot_Small", "Run_Gun_Shoot", "Punch", "Headbutt", "Weapon"],
	"death": ["Death"],
}
const CORPSE_SECONDS = 1.8
const MOVING_THRESHOLD = 0.2  # world units per second

@export var run_speed = 3.0

var _anim: AnimationPlayer = null
var _geometry: Node3D = null
var _names = {}
var _current = ""
var _last_position = null

@onready var _unit = get_parent()


func _ready():
	_geometry = _unit.find_child("Geometry")
	var players = _geometry.find_children("*", "AnimationPlayer", true, false) if _geometry else []
	if players.is_empty():
		queue_free()
		return
	_anim = players[0]
	var available = {}
	for full in _anim.get_animation_list():
		available[full.get_slice("|", full.get_slice_count("|") - 1)] = full
	for role in ROLES:
		for short in ROLES[role]:
			if available.has(short):
				_names[role] = available[short]
				break
	for role in ["idle", "walk", "run", "attack"]:
		if _names.has(role):
			_anim.get_animation(_names[role]).loop_mode = Animation.LOOP_LINEAR
	_unit.tree_exiting.connect(_on_unit_tree_exiting)
	_play("idle")


func _physics_process(delta):
	var position = _unit.global_position
	if _last_position == null:
		_last_position = position
		return
	var speed = position.distance_to(_last_position) / max(delta, 0.0001)
	_last_position = position
	var role = "idle"
	if speed > MOVING_THRESHOLD:
		role = "run" if _unit.movement_speed >= run_speed else "walk"
	elif _unit.get_meta("next_attack_availability_time", 0) > Time.get_ticks_msec():
		role = "attack"
	_play(role)


func _play(role):
	var anim_name = _names.get(role, _names.get("idle", ""))
	if anim_name != "" and anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, 0.2)


# Leave a copy of the model behind, playing Death, when the unit was killed.
func _on_unit_tree_exiting():
	if not _names.has("death") or _unit.hp != 0 or not is_instance_valid(_geometry):
		return
	var a_match = _unit.find_parent("Match")
	if a_match == null:
		return
	var corpse = _geometry.duplicate()
	var corpse_transform = _geometry.global_transform
	a_match.add_child.call_deferred(corpse)
	_start_corpse.call_deferred(corpse, corpse_transform, a_match)


func _start_corpse(corpse, corpse_transform, a_match):
	if not is_instance_valid(corpse) or not corpse.is_inside_tree():
		return
	corpse.global_transform = corpse_transform
	var players = corpse.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		players[0].play(_names["death"])
	a_match.get_tree().create_timer(CORPSE_SECONDS).timeout.connect(corpse.queue_free)
