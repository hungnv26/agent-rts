extends Node

# Headless smoke test: starts a campaign world (or a skirmish with the Hollow) straight
# into a match, lets it run for a number of frames, then quits. Any script error shows
# in the log.
#   godot --headless --path . res://tests/smoke/Smoke.tscn -- --world=basin --frames=300
# Optional: --time-scale=60 (run the clock fast, to reach the Hollow's waves and the night),
# --objective=survive:5 (override the world's objective), --difficulty=2.0.

const MatchSettings = preload("res://source/data-model/MatchSettings.gd")

var _frames = 240
var _elapsed_frames = 0
var _match = null


func _ready():
	var world_id = "landing"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world="):
			world_id = arg.substr(8)
		elif arg.begins_with("--frames="):
			_frames = int(arg.substr(9))
	var index = Campaign.index_of(world_id)
	assert(index >= 0, "unknown world " + world_id)
	var settings = Campaign.build_match_settings(index)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--time-scale="):
			Engine.time_scale = float(arg.substr(13))
		elif arg.begins_with("--objective="):  # e.g. --objective=survive:5
			var parts = arg.substr(12).split(":")
			settings.objective = {"type": parts[0], "amount": int(parts[1]) if parts.size() > 1 else 0}
		elif arg.begins_with("--difficulty="):
			settings.difficulty = float(arg.substr(13))
	MatchSignals.hollow_wave_started.connect(
		func(_player, size): print("smoke: hollow wave of ", size)
	)
	MatchSignals.night_started.connect(func(): print("smoke: night"))
	MatchSignals.day_started.connect(func(): print("smoke: day"))
	MatchSignals.objective_completed.connect(func(): print("smoke: objective completed"))
	MatchSignals.match_finished_with_victory.connect(func(): print("smoke: victory"))
	MatchSignals.match_finished_with_defeat.connect(func(): print("smoke: defeat"))
	var map = load(Campaign.world(index)["map"]).instantiate()
	_match = load("res://source/match/Match.tscn").instantiate()
	_match.settings = settings
	_match.map = map
	add_child(_match)
	print("smoke: world ", world_id, " started with ", settings.players.size(), " players")


func _process(_delta):
	_elapsed_frames += 1
	if _elapsed_frames == 120 and _match != null:
		var counts = {}
		for unit in get_tree().get_nodes_in_group("units"):
			counts[unit.type] = counts.get(unit.type, 0) + 1
		print("smoke: units after 120 frames ", counts)
	if _elapsed_frames >= _frames:
		print("smoke: done")
		get_tree().quit()
