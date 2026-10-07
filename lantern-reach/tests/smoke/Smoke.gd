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
var _screenshot = ""  # --screenshot=PATH saves the viewport at --shot-frame=N (default 150)
var _shot_frame = 150
var _camera_size = 0.0  # --camera-size=N zooms the camera (bigger = further out)
var _camera_at = ""  # --camera-at=hollow centres the camera on the first Hollow nest
var _walk = ""  # --walk=+z|-z sends the Engineers walking towards (+z) or away from the camera
var _spawn = []  # --spawn=Trooper,MechForge spawns those scenes next to the player's base
var _select = ""  # --select=Worker selects the first such unit before the screenshot (shows its menu)
var _sheet = ""  # --sheet=DIR spawns one of everything and saves a close-up of each to DIR
const SHEET = [
	["Worker", 4.5], ["Drone", 4.5], ["Trooper", 4.5], ["Tank", 4.5], ["Helicopter", 4.5],
	["CommandCenter", 8.0], ["MechForge", 7.0], ["VehicleFactory", 7.0], ["AircraftFactory", 7.0],
	["SolarArray", 6.0], ["AntiGroundTurret", 5.0], ["AntiAirTurret", 5.0],
	["HollowMote", 4.0], ["HollowBrute", 4.5], ["HollowWasp", 4.0], ["HollowNest", 8.0],
]
const SHEET_FIRST_FRAME = 60
const SHEET_FRAMES_PER_ITEM = 10


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
		elif arg.begins_with("--screenshot="):
			_screenshot = arg.substr(13)
		elif arg.begins_with("--shot-frame="):
			_shot_frame = int(arg.substr(13))
		elif arg.begins_with("--camera-size="):
			_camera_size = float(arg.substr(14))
		elif arg == "--reveal":  # no fog of war, for looking at the map
			settings.visibility = settings.Visibility.FULL
		elif arg.begins_with("--camera-at="):
			_camera_at = arg.substr(12)
		elif arg.begins_with("--walk"):
			_walk = arg.substr(7) if arg.length() > 7 else "+z"
		elif arg.begins_with("--spawn="):
			_spawn = arg.substr(8).split(",")
		elif arg.begins_with("--select="):
			_select = arg.substr(9)
		elif arg.begins_with("--sheet="):
			_sheet = arg.substr(8)
			settings.visibility = settings.Visibility.FULL
			_frames = max(_frames, SHEET_FIRST_FRAME + SHEET_FRAMES_PER_ITEM * (SHEET.size() + 1))
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


func _debug_actions():
	var human = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_script().resource_path.ends_with("Human.gd"):
			human = player
	var pivot = _human_pivot()
	if _walk != "":
		var step = Vector3(0, 0, 3 if _walk == "+z" else -3)
		for unit in get_tree().get_nodes_in_group("controlled_units"):
			if unit.type == "Worker":
				unit.action = load("res://source/match/units/actions/Moving.gd").new(
					unit.global_position + step
				)
	var i = 0
	for scene_name in _spawn:
		var unit = load("res://source/match/units/" + scene_name + ".tscn").instantiate()
		var at = pivot + Vector3(-6 + 4 * i, 0, 5)
		MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), at), human)
		if unit.has_method("is_under_construction") and unit.is_under_construction():
			unit.construct(1.0)
		i += 1


# One of everything on a grid south-east of the base, 10 units apart.
func _spawn_sheet():
	var human = null
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_script().resource_path.ends_with("Human.gd"):
			human = player
	for i in range(SHEET.size()):
		var scene_name = SHEET[i][0]
		var unit = load("res://source/match/units/" + scene_name + ".tscn").instantiate()
		var at = Vector3(8 + 10 * (i % 4), 0, 16 + 10 * (i / 4))
		unit.set_meta("sheet_index", i)
		MatchSignals.setup_and_spawn_unit.emit(unit, Transform3D(Basis(), at), human)
		if unit.has_method("is_under_construction") and unit.is_under_construction():
			unit.construct(1.0)


func _sheet_step():
	var step = _elapsed_frames - SHEET_FIRST_FRAME
	var i = step / SHEET_FRAMES_PER_ITEM
	var phase = step % SHEET_FRAMES_PER_ITEM
	if i >= SHEET.size():
		return
	var target = null
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.get_meta("sheet_index", -1) == i:
			target = unit
	if target == null:
		return
	var camera = _match.find_child("IsometricCamera3D")
	if phase == 0:
		camera.set_size_safely(SHEET[i][1])
		camera.set_position_safely(target.global_position)
	elif phase == 6:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_sheet + "/" + SHEET[i][0] + ".png")
		print("smoke: sheet ", SHEET[i][0])


func _human_pivot():
	var pivot = Vector3.ZERO
	var n = 0
	for unit in get_tree().get_nodes_in_group("controlled_units"):
		pivot += unit.global_position
		n += 1
	return pivot / max(1, n)


func _process(_delta):
	_elapsed_frames += 1
	if _elapsed_frames == 120 and _match != null:
		var counts = {}
		for unit in get_tree().get_nodes_in_group("units"):
			counts[unit.type] = counts.get(unit.type, 0) + 1
		print("smoke: units after 120 frames ", counts)
	if _elapsed_frames == 2 and _match != null:
		var camera = _match.find_child("IsometricCamera3D")
		camera.screen_margin_for_movement = -1  # no edge scrolling: the test mouse sits at (0, 0)
		if _camera_size > 0.0:
			camera.set_size_safely(_camera_size)
		camera.set_position_safely(_human_pivot())
	if _elapsed_frames == 10 and _match != null:
		_debug_actions()
		if _sheet != "":
			_spawn_sheet()
	if _sheet != "" and _elapsed_frames >= SHEET_FIRST_FRAME:
		_sheet_step()
	if _elapsed_frames == _shot_frame - 10 and _select != "":
		for unit in get_tree().get_nodes_in_group("controlled_units"):
			if unit.type == _select:
				unit.find_child("Selection").select()
				break
	if _elapsed_frames == _shot_frame - 2 and _camera_at != "":  # a unit type, e.g. Worker
		for unit in get_tree().get_nodes_in_group("units"):
			if unit.type == _camera_at:
				_match.find_child("IsometricCamera3D").set_position_safely(unit.global_position)
				break
	if _elapsed_frames == _shot_frame and _screenshot != "":
		await RenderingServer.frame_post_draw
		var image = get_viewport().get_texture().get_image()
		image.save_png(_screenshot)
		print("smoke: screenshot saved to ", _screenshot)
	if _elapsed_frames >= _frames:
		print("smoke: done")
		get_tree().quit()
