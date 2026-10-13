extends "res://source/match/units/Unit.gd"

# A Hollow creature: spawned by a nest, never built. Bites whatever comes close, hunts what
# it can see, and follows its wave's battlegroup to the nearest enemy.

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")


func _ready():
	await super()
	action_changed.connect(_on_action_changed)
	action = WaitingForTargets.new()


func _on_action_changed(new_action):
	if new_action == null:
		action = WaitingForTargets.new()
