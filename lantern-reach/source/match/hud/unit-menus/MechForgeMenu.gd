extends GridContainer

const TrooperUnit = preload("res://source/match/units/Trooper.tscn")

var unit = null

@onready var _trooper_button = find_child("ProduceTrooperButton")


func _ready():
	var properties = Constants.Match.Units.DEFAULT_PROPERTIES[TrooperUnit.resource_path]
	_trooper_button.tooltip_text = ("{0} - {1}\n{2} HP, {3} DPS\n{4}: {5}, {6}: {7}".format(
		[
			tr("TROOPER"),
			tr("TROOPER_DESCRIPTION"),
			properties["hp_max"],
			properties["attack_damage"] / properties["attack_interval"],
			tr("RESOURCE_A"),
			Constants.Match.Units.PRODUCTION_COSTS[TrooperUnit.resource_path]["resource_a"],
			tr("RESOURCE_B"),
			Constants.Match.Units.PRODUCTION_COSTS[TrooperUnit.resource_path]["resource_b"]
		]
	))


func _on_produce_trooper_button_pressed():
	unit.production_queue.produce(TrooperUnit)
