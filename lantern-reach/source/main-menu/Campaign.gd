extends Control

# The campaign page: the ten worlds in order, locked until the one before is relit, with
# each world's briefing. Start builds the world's match settings and goes to the loading
# page like a skirmish does.

const LoadingScene = preload("res://source/main-menu/Loading.tscn")

@onready var _world_list = find_child("WorldList")
@onready var _details = find_child("DetailsLabel")
@onready var _start_button = find_child("StartButton")


func _ready():
	_world_list.clear()
	for i in range(Campaign.world_count()):
		var w = Campaign.world(i)
		var label = "%d. %s" % [i + 1, w["name"]]
		if Campaign.is_completed(i):
			label += "  (" + tr("CAMPAIGN_DONE") + ")"
		_world_list.add_item(label)
		_world_list.set_item_disabled(i, not Campaign.is_unlocked(i))
	var first = 0
	for i in range(Campaign.world_count()):
		if Campaign.is_unlocked(i) and not Campaign.is_completed(i):
			first = i
			break
	_world_list.select(first)
	_on_world_list_item_selected(first)


func _on_world_list_item_selected(index):
	var w = Campaign.world(index)
	var terrain_name = load("res://source/world/Terrains.gd").get_preset(w["terrain"])["name"]
	var enemies = []
	if w["wardens"] > 0:
		enemies.append("%d Warden base%s" % [w["wardens"], "s" if w["wardens"] > 1 else ""])
	if w["nests"] > 0:
		enemies.append("%d Hollow nest%s" % [w["nests"], "s" if w["nests"] > 1 else ""])
	_details.text = (
		"[b]%s[/b]  ·  %s\n[u]Objective:[/u] %s\n[u]Enemies:[/u] %s\n\n%s"
		% [
			w["name"],
			terrain_name,
			Campaign.objective_text(w["objective"]),
			", ".join(enemies) if not enemies.is_empty() else "none",
			w["intro"] if Campaign.is_unlocked(index) else tr("CAMPAIGN_LOCKED"),
		]
	)
	_start_button.disabled = not Campaign.is_unlocked(index)


func _selected_index():
	var selected = _world_list.get_selected_items()
	return selected[0] if not selected.is_empty() else 0


func _on_start_button_pressed():
	var index = _selected_index()
	if not Campaign.is_unlocked(index):
		return
	hide()
	var new_scene = LoadingScene.instantiate()
	new_scene.match_settings = Campaign.build_match_settings(index)
	new_scene.map_path = Campaign.world(index)["map"]
	get_parent().add_child(new_scene)
	get_tree().current_scene = new_scene
	queue_free()


func _on_reset_button_pressed():
	Campaign.reset()
	_ready()


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
