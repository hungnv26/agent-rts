extends "res://source/match/Match.gd"

# The agent world: a single-player Open RTS match with no combat, AI or economy.
# Buildings are capabilities, units are AI agents, and all agent movement comes from the
# adapter's world feed (WorldClient). The player watches, inspects, deploys missions and
# answers Human Approval requests.

const AgentScene = preload("res://source/agent/units/Agent.tscn")
const BuildingScene = preload("res://source/agent/units/Building.tscn")
const WorldClientScript = preload("res://source/agent/WorldClient.gd")
const AgentHUDScript = preload("res://source/agent/hud/AgentHUD.gd")
const WorldDecorScript = preload("res://source/agent/WorldDecor.gd")
const ReplayPlayerScript = preload("res://source/agent/replay/ReplayPlayer.gd")
const Fx = preload("res://source/agent/Fx.gd")

const CENTER = Vector3(16, 0, 16)
const KENNEY = "res://assets/models/kenney-spacekit/"
const BUILDINGS = [
	{
		"id": "command_centre",
		"label": "Command Centre",
		"pos": Vector3(16, 0, 16),
		"model": "res://source/match/units/structure-geometries/CommandCenter.tscn",
		"size": 4.2,
		"accent": Color(0.4, 0.8, 1.0),
	},
	{
		"id": "research_lab",
		"label": "Research Lab",
		"pos": Vector3(6.5, 0, 6.5),
		"model": KENNEY + "satelliteDish_large.glb",
		"size": 3.6,
		"accent": Color(0.35, 0.75, 1.0),
	},
	{
		"id": "code_factory",
		"label": "Code Factory",
		"pos": Vector3(25.5, 0, 6.5),
		"model": KENNEY + "hangar_largeA.glb",
		"size": 3.8,
		"accent": Color(1.0, 0.6, 0.25),
	},
	{
		"id": "knowledge_library",
		"label": "Knowledge Library",
		"pos": Vector3(6.5, 0, 25.5),
		"model": KENNEY + "hangar_roundGlass.glb",
		"size": 3.6,
		"accent": Color(0.45, 0.95, 0.6),
	},
	{
		"id": "human_approval",
		"label": "Human Approval",
		"pos": Vector3(25.5, 0, 25.5),
		"model": KENNEY + "gate_complex.glb",
		"size": 3.6,
		"accent": Color(0.85, 0.55, 1.0),
	},
]
const SPOTS = {
	"rally_point": {"label": "Rally Point", "pos": Vector3(16, 0, 6.0), "color": Color(1.0, 0.82, 0.35)},
	"repair_bay": {"label": "Repair Bay", "pos": Vector3(16, 0, 26.5), "color": Color(1.0, 0.35, 0.35)},
}
# Every unit is a real Hermes agent (the Commander is the orchestrator itself), each its
# own vehicle.
const ROSTER = [
	{"id": "commander", "name": "Commander", "color": Color(0.85, 0.93, 1.0), "model": KENNEY + "craft_cargoA.glb", "size": 2.2},
	{"id": "researcher", "name": "Researcher", "color": Color(0.35, 0.8, 1.0), "model": KENNEY + "rover.glb", "size": 1.6},
	{"id": "scout", "name": "Scout", "color": Color(1.0, 0.88, 0.3), "model": KENNEY + "craft_speederA.glb", "size": 1.6},
	{"id": "analyst", "name": "Analyst", "color": Color(0.55, 0.95, 0.5), "model": KENNEY + "craft_miner.glb", "size": 1.7},
	{"id": "coder", "name": "Coder", "color": Color(1.0, 0.6, 0.25), "model": KENNEY + "craft_speederD.glb", "size": 1.6},
	{"id": "writer", "name": "Writer", "color": Color(1.0, 0.5, 0.75), "model": KENNEY + "craft_speederB.glb", "size": 1.6},
	{"id": "reviewer", "name": "Reviewer", "color": Color(0.85, 0.55, 1.0), "model": KENNEY + "craft_racer.glb", "size": 1.7},
]
const RTS_ONLY_NODES = [
	"Players/Human/StructurePlacementHandler",
	"Players/Human/UnitActionsController",
	"Players/Human/VoiceNarratorController",
	"Players/Human/UnitVoicesController",
	"HUD/MarginContainer2",
	"HUD/MarginContainer3",
	"Handlers/MatchEndHandler",
]

var _agents = {}
var _buildings = {}
var _client = null
var _hud = null
var _first_snapshot = true
var _decor = null
var _pending_approvals = {}
var _mission_id = ""
var ui_scale = 1.0
var mission_running = false
var _mission_status = ""
var _replay = null
var _replaying = false
var _replay_wait_id = ""


func _ready():
	ui_scale = _compute_ui_scale()
	for path in RTS_ONLY_NODES:
		var node = get_node_or_null(path)
		if node != null:
			node.queue_free()
	var human = $Players/Human
	for b in BUILDINGS:
		var building = BuildingScene.instantiate()
		building.building_id = b["id"]
		building.label = b["label"]
		building.model_path = b["model"]
		building.model_size = b["size"]
		building.accent = b["accent"]
		building.position = b["pos"]
		human.add_child(building)
		_buildings[b["id"]] = building
	for r in ROSTER:
		var agent = AgentScene.instantiate()
		agent.agent_id = r["id"]
		agent.display_name = r["name"]
		agent.role_color = r["color"]
		agent.model_path = r["model"]
		agent.model_size = r["size"]
		agent.resolve_target = _target_for
		agent.state_applied.connect(_on_agent_state_applied)
		agent.position = _target_for("command_centre", r["id"])
		human.add_child(agent)
		_agents[r["id"]] = agent
	super()
	_decor = WorldDecorScript.new()
	_decor.center = CENTER
	_decor.ui_scale = ui_scale
	for b in BUILDINGS:
		_decor.buildings[b["id"]] = {"pos": b["pos"], "accent": b["accent"], "size": b["size"]}
	for id in SPOTS:
		_decor.spots[id] = {"pos": SPOTS[id]["pos"], "color": SPOTS[id]["color"], "label": SPOTS[id]["label"]}
	add_child(_decor)
	_decor.build(map.find_child("Terrain").mesh.material)
	_decor.apply_glow($WorldEnvironment, $DirectionalLight3D)
	_replay = ReplayPlayerScript.new()
	add_child(_replay)
	_hud = AgentHUDScript.new()
	$HUD.add_child(_hud)
	_client = WorldClientScript.new()
	add_child(_client)
	_client.connection_changed.connect(func(online): _hud.set_connection(online))
	_client.message_received.connect(_on_message)
	_hud.mission_requested.connect(func(title): _client.send_command({"type": "mission.create", "title": title}))
	_hud.mission_cancel_requested.connect(func(): _client.send_command({"type": "mission.cancel"}))
	_hud.approval_resolved.connect(
		func(id, approved): _client.send_command({"type": "approval.resolve", "id": id, "approved": approved})
	)
	_hud.agent_focus_requested.connect(_focus_agent)
	_hud.replay_requested.connect(_request_replay)
	_hud.replay_pause_toggled.connect(func(): _replay.toggle_pause())
	_hud.replay_speed_cycled.connect(func(): _replay.cycle_speed())
	_hud.replay_stop_requested.connect(_end_replay)
	_replay.caption.connect(func(line): _hud.replay_caption(line))
	_replay.progressed.connect(
		func(clock, total): _hud.update_replay(clock, total, _replay.effective_speed(), _replay.playing)
	)
	_replay.finished.connect(_end_replay)
	_hud.set_connection(false)
	MatchSignals.unit_selected.connect(_on_unit_selected)
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale.call_deferred()
	_setup_capture()


func _process(delta):
	# During a replay the ghosts drive the world's reactions instead of the real agents.
	var actors = _replay.ghosts.values() if _replaying else _agents.values()
	# Buildings glow while an agent is working inside.
	for b in _buildings.values():
		for agent in actors:
			b.set_occupant(
				agent.agent_id,
				agent.state == "working" and agent.location == b.building_id and not agent.is_moving()
			)
	_buildings["human_approval"].alert = _replay.approval_pending if _replaying else not _pending_approvals.is_empty()
	if _decor != null:
		_decor.update_world(actors, delta)



# HUD and labels are designed for a 1080p-tall window; scale them up on 4K/5K screens.
func _compute_ui_scale():
	var h = get_viewport().get_visible_rect().size.y
	return clampf(h / 1080.0, 1.0, 3.0)


func _apply_ui_scale():
	ui_scale = _compute_ui_scale()
	if _hud != null:
		_hud.set_ui_scale(ui_scale)
	var minimap = get_node_or_null("HUD/MarginContainer")
	if minimap != null:
		minimap.pivot_offset = Vector2(0, minimap.size.y)
		minimap.scale = Vector2(ui_scale, ui_scale)
	for l in get_tree().get_nodes_in_group(Fx.LABEL_GROUP):
		l.pixel_size = l.get_meta("base_px", 0.0008) * ui_scale


# Where an agent stands at a location. Each agent has a fixed slot so they never stack.
func _target_for(location, agent_id):
	var idx = 0
	for i in ROSTER.size():
		if ROSTER[i]["id"] == agent_id:
			idx = i
	var n = ROSTER.size()
	if SPOTS.has(location):
		var a = TAU * idx / n
		return SPOTS[location]["pos"] + Vector3(cos(a), 0, sin(a)) * 1.6
	var b = _building_def(location)
	if b == null:
		return CENTER
	if location == "command_centre":
		var angle = PI * 0.5 + TAU * idx / n
		return b["pos"] + Vector3(cos(angle), 0, sin(angle)) * 4.1
	var dir = (CENTER - b["pos"]).normalized()
	var door = b["pos"] + dir * 3.3
	var perp = Vector3(-dir.z, 0, dir.x)
	return door + perp * (idx - (n - 1) * 0.5) * 0.85


func _building_def(id):
	for b in BUILDINGS:
		if b["id"] == id:
			return b
	return null


func _on_message(msg):
	match msg.get("type", ""):
		"snapshot":
			var world = msg["world"]
			_hud.apply_snapshot(world)
			_hud.set_connection(true, world.get("source", ""))
			for a in world.get("agents", []):
				_apply_agent(a, _first_snapshot)
			_first_snapshot = false
			_pending_approvals.clear()
			for ap in world.get("approvals", []):
				if ap.get("status") == "pending":
					_pending_approvals[ap["id"]] = true
			var m = world.get("mission")
			if m != null:
				_mission_id = m.get("id", "")
				mission_running = m.get("status") in ["planning", "running"]
		"agent.state":
			_apply_agent(msg["agent"], false)
		"task.upsert":
			_hud.set_task(msg["task"])
		"mission.upsert":
			var m = msg["mission"]
			var status = m.get("status", "")
			var finished_now = status in ["completed", "failed"] and (
				status != _mission_status or m.get("id", "") != _mission_id
			)
			if finished_now:
				# Play a replay of the mission first; the report opens after it.
				_hud.defer_next_result()
				_replay_wait_id = m.get("id", "")
				get_tree().create_timer(2.5).timeout.connect(_request_replay.bind(_replay_wait_id))
			_hud.set_mission(m)
			_on_mission_fx(m)
			_mission_status = status
		"replay":
			_on_replay(msg.get("replay"))
		"approval.upsert":
			_hud.set_approval(msg["approval"])
			var ap = msg["approval"]
			if ap.get("status") == "pending":
				_pending_approvals[ap["id"]] = true
			else:
				_pending_approvals.erase(ap["id"])
		"resource.update":
			_hud.set_resources(msg["resources"])
		"log":
			_hud.add_log(msg["line"])


# Mission start/end shows up on the Command Centre: a pulse, plus a burst on success.
func _on_mission_fx(m):
	if m == null:
		return
	var cc = _buildings["command_centre"]
	var status = m.get("status", "")
	var is_new = m.get("id", "") != _mission_id
	_mission_id = m.get("id", "")
	if is_new:
		_pending_approvals.clear()
		if _replaying and (status == "planning" or status == "running"):
			_end_replay()
	mission_running = status == "planning" or status == "running"
	if is_new and mission_running:
		cc.set_pulse_color(Color(0.4, 0.8, 1.0))
		cc.pulse()
	elif status == "completed":
		cc.set_pulse_color(Color(0.4, 1.0, 0.55))
		cc.pulse()
		_decor.burst(Color(0.45, 1.0, 0.6))
	elif status == "failed":
		cc.set_pulse_color(Color(1.0, 0.35, 0.3))
		cc.pulse()


func _request_replay(mission_id):
	if mission_running or _replaying:
		_hud.cancel_deferred()
		return
	_replay_wait_id = mission_id
	_client.send_command({"type": "replay.request", "missionId": mission_id})
	# If the adapter has nothing (or is gone), don't keep the report waiting.
	get_tree().create_timer(3.0).timeout.connect(
		func():
			if _replay_wait_id == mission_id and not _replaying:
				_replay_wait_id = ""
				_hud.cancel_deferred()
	)


func _on_replay(replay):
	var wanted = _replay_wait_id
	_replay_wait_id = ""
	if replay == null or replay.get("events", []).is_empty() or mission_running or _replaying:
		_hud.cancel_deferred()
		return
	if wanted != "" and replay.get("mission", {}).get("id", "") != wanted:
		_hud.cancel_deferred()
		return
	_replaying = true
	for agent in _agents.values():
		agent.set_hidden(true)
	_replay.start(replay, ROSTER, self, _target_for, ui_scale)
	_hud.begin_replay(replay["mission"].get("title", ""), _replay.duration_ms, _replay.markers)


func _end_replay():
	if not _replaying:
		return
	var completed = _replay.mission.get("status", "") == "completed"
	_replay.stop()
	_replaying = false
	for agent in _agents.values():
		agent.set_hidden(false)
	_hud.end_replay()
	if completed:
		var cc = _buildings["command_centre"]
		cc.set_pulse_color(Color(0.4, 1.0, 0.55))
		cc.pulse()


func _apply_agent(a, snap):
	var agent = _agents.get(a.get("id", ""))
	if agent == null:
		return
	if snap:
		agent.snap_to(a)
	else:
		agent.push_state(a)


# Roster cards follow what the 3D agent is showing, not the raw (possibly queued) feed.
func _on_agent_state_applied(agent):
	if _hud != null and not agent.data.is_empty():
		_hud.set_agent(agent.data)


func _on_unit_selected(unit):
	if "agent_id" in unit:
		_hud.select_agent(unit.agent_id)
	elif "building_id" in unit and unit.building_id == "human_approval":
		_hud.open_approval_if_pending()


func _focus_agent(agent_id):
	var agent = _agents.get(agent_id)
	if agent == null:
		return
	MatchSignals.deselect_all_units.emit()
	agent.find_child("Selection").select()
	_camera.set_position_safely(agent.global_position)


# Dev aid: --capture-dir=DIR --capture-at=5,12,20 [--quit-after-capture]
# saves viewport screenshots at those seconds (used for automated visual checks).
func _setup_capture():
	var dir = ""
	var times = []
	var quit_after = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			dir = arg.substr(14)
		elif arg.begins_with("--capture-at="):
			for t in arg.substr(13).split(","):
				times.append(float(t))
		elif arg == "--quit-after-capture":
			quit_after = true
	if dir == "" or times.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	for t in times:
		get_tree().create_timer(t, true, false, true).timeout.connect(
			func():
				var img = get_viewport().get_texture().get_image()
				img.save_png("%s/shot_%03d.png" % [dir, int(t)])
				if quit_after and t == times.max():
					get_tree().quit()
		)
