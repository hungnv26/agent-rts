extends "res://source/match/units/Structure.gd"

# Trickles Lumen into its owner's stock while the sun is up (see Constants.Match.Units
# SOLAR_ARRAY_*). The only income that needs no Engineer, so a base can keep building
# after its crystal fields are gone, slowly.

var _timer = null


func _ready():
	await super()
	_timer = Timer.new()
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start(Constants.Match.Units.SOLAR_ARRAY_TICK_S)


func _on_tick():
	if not is_constructed() or not _is_daylight():
		return
	player.add_resources({"resource_a": Constants.Match.Units.SOLAR_ARRAY_LUMEN_PER_TICK})


func _is_daylight():
	var world = _match.find_child("World") if _match != null else null
	if world == null or not world.has_method("is_day"):
		return true
	return world.is_day()
