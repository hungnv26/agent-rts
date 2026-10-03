extends "res://source/match/Match.gd"

# The agent world: a single-player Open RTS match with no combat, AI or economy.
# Buildings are capabilities, units are AI agents, and all agent movement comes from the
# adapter's world feed (WorldClient). The player watches, inspects, deploys missions and
# answers Human Approval requests.

const AgentScene = preload("res://source/agent/units/Agent.tscn")
const BuildingScene = preload("res://source/agent/units/Building.tscn")
const WorldClientScript = preload("res://source/agent/WorldClient.gd")
const AgentHUDScript = preload("res://source/agent/hud/AgentHUD.gd")

const CENTER = Vector3(16, 0, 16)
const KENNEY = "res://assets/models/kenney-spacekit/"
const BUILDINGS = [
	{
		"id": "command_centre",
		"label": "Command Centre",
		"pos": Vector3(16, 0, 16),
		"model": "res://source/match/units/structure-geometries/CommandCenter.tscn",
		"size": 3.6,
	},
	{
		"id": "research_lab",
		"label": "Research Lab",
		"pos": Vector3(6.5, 0, 6.5),
		"model": KENNEY + "satelliteDish_large.glb",
		"size": 3.0,
	},
	{
		"id": "code_factory",
		"label": "Code Factory",
		"pos": Vector3(25.5, 0, 6.5),
		"model": KENNEY + "hangar_largeA.glb",
		"size": 3.4,
	},
	{
		"id": "knowledge_library",
		"label": "Knowledge Library",
		"pos": Vector3(6.5, 0, 25.5),
		"model": KENNEY + "hangar_roundGlass.glb",
		"size": 3.2,
	},
	{
		"id": "human_approval",
		"label": "Human Approval",
		"pos": Vector3(25.5, 0, 25.5),
		"model": KENNEY + "gate_complex.glb",
		"size": 3.2,
	},
]
const SPOTS = {
	"rally_point": {"label": "Rally Point", "pos": Vector3(16, 0, 6.0), "color": Color(1.0, 0.82, 0.35)},
	"repair_bay": {"label": "Repair Bay", "pos": Vector3(16, 0, 26.5), "color": Color(1.0, 0.35, 0.35)},
}
const ROSTER = [
	{"id": "researcher", "name": "Researcher", "color": Color(0.35, 0.8, 1.0)},
	{"id": "coder", "name": "Coder", "color": Color(1.0, 0.6, 0.25)},
	{"id": "analyst", "name": "Analyst", "color": Color(0.55, 0.95, 0.5)},
	{"id": "reviewer", "name": "Reviewer", "color": Color(0.85, 0.55, 1.0)},
]
const SPOT_SLOTS = [Vector3(-1.1, 0, -0.5), Vector3(1.1, 0, -0.5), Vector3(-1.1, 0, 0.7), Vector3(1.1, 0, 0.7)]
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


func _ready():
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
		building.position = b["pos"]
		human.add_child(building)
		_buildings[b["id"]] = building
	for r in ROSTER:
		var agent = AgentScene.instantiate()
		agent.agent_id = r["id"]
		agent.display_name = r["name"]
		agent.role_color = r["color"]
		agent.resolve_target = _target_for
		agent.state_applied.connect(_on_agent_state_applied)
		agent.position = _target_for("command_centre", r["id"])
		human.add_child(agent)
		_agents[r["id"]] = agent
	super()
	_build_spots()
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
	_hud.set_connection(false)
	MatchSignals.unit_selected.connect(_on_unit_selected)
	_setup_capture()


func _process(_delta):
	# Buildings glow while an agent is working inside.
	for b in _buildings.values():
		for agent in _agents.values():
			b.set_occupant(
				agent.agent_id,
				agent.state == "working" and agent.location == b.building_id and not agent.is_moving()
			)


# Where an agent stands at a location. Each agent has a fixed slot so they never stack.
func _target_for(location, agent_id):
	var idx = 0
	for i in ROSTER.size():
		if ROSTER[i]["id"] == agent_id:
			idx = i
	if SPOTS.has(location):
		return SPOTS[location]["pos"] + SPOT_SLOTS[idx]
	var b = _building_def(location)
	if b == null:
		return CENTER
	if location == "command_centre":
		var angle = PI * 0.25 + idx * PI * 0.5
		return b["pos"] + Vector3(cos(angle), 0, sin(angle)) * 3.4
	var dir = (CENTER - b["pos"]).normalized()
	var door = b["pos"] + dir * 3.0
	var perp = Vector3(-dir.z, 0, dir.x)
	return door + perp * (idx - 1.5) * 0.95


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
		"agent.state":
			_apply_agent(msg["agent"], false)
		"task.upsert":
			_hud.set_task(msg["task"])
		"mission.upsert":
			_hud.set_mission(msg["mission"])
		"approval.upsert":
			_hud.set_approval(msg["approval"])
		"resource.update":
			_hud.set_resources(msg["resources"])
		"log":
			_hud.add_log(msg["line"])


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


func _build_spots():
	for id in SPOTS:
		var spot = SPOTS[id]
		var disc = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 2.0
		mesh.bottom_radius = 2.0
		mesh.height = 0.02
		disc.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(spot["color"], 0.05)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		disc.material_override = mat
		disc.position = spot["pos"] + Vector3(0, 0.02, 0)
		add_child(disc)
		var ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 1.92
		torus.outer_radius = 2.05
		ring.mesh = torus
		var ring_mat = mat.duplicate()
		ring_mat.albedo_color = Color(spot["color"], 0.7)
		ring.material_override = ring_mat
		ring.scale = Vector3(1, 0.05, 1)
		ring.position = spot["pos"] + Vector3(0, 0.03, 0)
		add_child(ring)
		var l = Label3D.new()
		l.text = spot["label"]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0008
		l.font_size = 24
		l.outline_size = 8
		l.modulate = spot["color"]
		l.outline_modulate = Color(0.04, 0.05, 0.09, 0.9)
		l.position = spot["pos"] + Vector3(0, 0.3, -2.2)
		add_child(l)


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
