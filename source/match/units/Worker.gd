extends "res://source/match/units/Unit.gd"

var resource_a = 0
var resource_b = 0
var resources_max = null


func _ready():
	await super()
	# The astronaut model carries a pistol; Engineers mine and build, they don't fight.
	for pistol in find_child("Geometry").find_children("Pistol", "", true, false):
		pistol.visible = false


func is_full():
	assert(resource_a + resource_b <= resources_max, "worker capacity was exceeded somehow")
	return resource_a + resource_b == resources_max
