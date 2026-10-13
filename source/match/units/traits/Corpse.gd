extends Node3D

# A dead unit's model, left behind by CharacterAnimator: plays the death animation once it
# is in the tree, then frees itself. It owns its whole lifetime because the unit and its
# animator are gone by the time this node is added.

var death_animation = ""
var seconds = 1.8
var resting_transform = Transform3D()


func _ready():
	global_transform = resting_transform
	var players = find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		players[0].play(death_animation)
	get_tree().create_timer(seconds).timeout.connect(queue_free)
