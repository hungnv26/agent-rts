extends Node3D

# Everything that makes the base feel alive but carries no game logic: coloured ground
# zones, data conduits from the Command Centre, the Rally Point and Repair Bay pads,
# scattered props and a rocket landmark, ships circling overhead, work beams from agents
# to their building, mission bursts, and bloom lighting. Built procedurally from the
# building layout in AgentMatch. Nothing here has collision or affects navigation.

const Fx = preload("res://source/agent/Fx.gd")
const HAZARD_SHADER = preload("res://source/agent/hazard.gdshader")
const CONDUIT_SHADER = preload("res://source/agent/conduit.gdshader")
const K = "res://assets/models/kenney-spacekit/"

var buildings = {}  # id -> {"pos": Vector3, "accent": Color, "size": float}
var spots = {}  # id -> {"pos": Vector3, "color": Color, "label": String}
var center = Vector3(16, 0, 16)
var play_size = Vector2(32, 32)
var ui_scale = 1.0

var _conduits = {}  # location -> ShaderMaterial
var _route_activity = {}  # location -> smoothed 0..1
var _ground_mat: ShaderMaterial
var _rally_beacons = []
var _repair = {}
var _ships = []
var _beams = {}  # agent_id -> MeshInstance3D
var _rng = RandomNumberGenerator.new()


func build(ground_material: ShaderMaterial):
	_rng.seed = 20261004
	_ground_mat = ground_material
	_build_conduits()
	_build_rally_point()
	_build_repair_bay()
	_build_props()
	_build_rocket(Vector3(-5.0, 0, 8.0))
	_build_comms_tower(Vector3(-5.0, 0, 17.5))
	_build_ships()
	_update_zones({})


# Called every frame by AgentMatch with the live agent nodes.
func update_world(agents: Array, delta: float):
	var now = Time.get_ticks_msec() / 1000.0
	var wanted = {}
	var waiting = false
	var errored = false
	for a in agents:
		if a.state in ["idle", "complete"]:
			continue
		wanted[a.location] = 1.0
		waiting = waiting or a.state == "waiting"
		errored = errored or a.state == "error"
		_update_beam(a)
	for a in agents:
		if a.state in ["idle", "complete"] and _beams.has(a.agent_id):
			_beams[a.agent_id].visible = false
	for loc in _conduits:
		var cur = _route_activity.get(loc, 0.0)
		cur = lerpf(cur, wanted.get(loc, 0.0), clampf(delta * 2.5, 0.0, 1.0))
		_route_activity[loc] = cur
		_conduits[loc].set_shader_parameter("active", cur)
	for i in _rally_beacons.size():
		var m = _rally_beacons[i].material_override as StandardMaterial3D
		var phase = sin(now * (5.0 if waiting else 1.5) + i * PI * 0.5)
		m.emission_energy_multiplier = (4.0 if waiting else 1.2) * (0.5 + 0.5 * phase)
	_repair["hazard"].set_shader_parameter("alert", 1.0 if errored else 0.0)
	_repair["siren"].rotation.y += delta * (6.0 if errored else 0.0)
	_repair["light"].light_energy = (2.5 + 1.5 * sin(now * 10.0)) if errored else 0.0
	_animate_ships(delta, now)
	_update_zones(_route_activity)


func burst(color: Color):
	var p = GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 2.2
	p.one_shot = true
	p.explosiveness = 0.9
	var pm = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	var grad = Gradient.new()
	grad.set_color(0, Color(color, 1.0))
	grad.set_color(1, Color(color.lightened(0.5), 0.0))
	var gt = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var mesh = SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	var mat = Fx.emissive(Color.WHITE, 5.0)
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.position = center + Vector3(0, 2.5, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- building


func _update_zones(activity: Dictionary):
	if _ground_mat == null:
		return
	var zones = []
	var colors = []
	for id in buildings:
		var b = buildings[id]
		zones.append(Vector4(b.pos.x, b.pos.z, b.size * 1.35, 0.7 + 1.6 * activity.get(id, 0.0)))
		colors.append(Vector4(b.accent.r, b.accent.g, b.accent.b, 1.0))
	for id in spots:
		var s = spots[id]
		zones.append(Vector4(s.pos.x, s.pos.z, 3.0, 0.5 + 1.6 * activity.get(id, 0.0)))
		colors.append(Vector4(s.color.r, s.color.g, s.color.b, 1.0))
	while zones.size() < 8:
		zones.append(Vector4.ZERO)
		colors.append(Vector4.ZERO)
	_ground_mat.set_shader_parameter("zones", zones.slice(0, 8))
	_ground_mat.set_shader_parameter("zone_colors", colors.slice(0, 8))
	_ground_mat.set_shader_parameter("zone_count", min(8, buildings.size() + spots.size()))


func _build_conduits():
	var targets = {}
	for id in buildings:
		if id != "command_centre":
			targets[id] = buildings[id]
	for id in spots:
		targets[id] = {"pos": spots[id].pos, "accent": spots[id].color, "size": 2.6}
	var start_r = buildings["command_centre"].size * 0.75
	for id in targets:
		var t = targets[id]
		var dir = (t.pos - center).normalized()
		var a = center + dir * start_r
		var b = t.pos - dir * (t.size * 0.75)
		var length = a.distance_to(b)
		var plane = PlaneMesh.new()
		plane.size = Vector2(0.9, length)
		var mat = ShaderMaterial.new()
		mat.shader = CONDUIT_SHADER
		mat.set_shader_parameter("color", t.accent)
		mat.set_shader_parameter("length_units", length)
		mat.set_shader_parameter("direction", -1.0)
		var mi = MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mid = (a + b) * 0.5 + Vector3(0, 0.025, 0)
		mi.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mid)
		add_child(mi)
		_conduits[id] = mat
		_route_activity[id] = 0.0


func _build_rally_point():
	var s = spots["rally_point"]
	var pad = Fx.disc(2.1, 0.1, Fx.metal(Color(0.14, 0.16, 0.22), 0.8, 0.4), 8)
	pad.position = s.pos + Vector3(0, 0.05, 0)
	pad.rotation.y = PI / 8.0
	add_child(pad)
	var rim = Fx.torus(1.95, 2.05, Fx.emissive(s.color, 1.2), 0.04)
	rim.position = s.pos + Vector3(0, 0.11, 0)
	add_child(rim)
	# landing "H"-style chevrons
	for side in [-1, 1]:
		var bar = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.18, 0.02, 1.6)
		bar.mesh = bm
		bar.material_override = Fx.emissive(s.color, 0.8)
		bar.position = s.pos + Vector3(side * 0.6, 0.12, 0)
		add_child(bar)
	var cross = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = Vector3(1.2, 0.02, 0.18)
	cross.mesh = cm
	cross.material_override = Fx.emissive(s.color, 0.8)
	cross.position = s.pos + Vector3(0, 0.12, 0)
	add_child(cross)
	for i in 4:
		var ang = PI * 0.25 + i * PI * 0.5
		var post = Fx.disc(0.08, 0.6, Fx.metal(Color(0.3, 0.32, 0.38)), 8)
		post.position = s.pos + Vector3(cos(ang), 0, sin(ang)) * 2.3 + Vector3(0, 0.3, 0)
		add_child(post)
		var bulb = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		bulb.mesh = sm
		bulb.material_override = Fx.emissive(s.color, 1.0)
		bulb.position = post.position + Vector3(0, 0.38, 0)
		add_child(bulb)
		_rally_beacons.append(bulb)
	var l = Fx.label(self, s.label, 26, s.color, ui_scale)
	l.position = s.pos + Vector3(0, 1.4, -2.4)


func _build_repair_bay():
	var s = spots["repair_bay"]
	var hazard = ShaderMaterial.new()
	hazard.shader = HAZARD_SHADER
	var pad = Fx.disc(2.2, 0.1, hazard, 8)
	pad.position = s.pos + Vector3(0, 0.05, 0)
	pad.rotation.y = PI / 8.0
	add_child(pad)
	var inner = Fx.disc(1.75, 0.12, Fx.metal(Color(0.13, 0.13, 0.16), 0.7, 0.5), 8)
	inner.position = s.pos + Vector3(0, 0.06, 0)
	inner.rotation.y = PI / 8.0
	add_child(inner)
	_repair["hazard"] = hazard
	_prop(K + "machine_barrelLarge.glb", s.pos + Vector3(-2.9, 0, 0.6), 1.1, 0.4)
	_prop(K + "barrels.glb", s.pos + Vector3(2.8, 0, 0.9), 1.0, -0.6)
	_prop(K + "machine_generator.glb", s.pos + Vector3(2.7, 0, -1.4), 1.1, 1.2)
	var mast = Fx.disc(0.07, 1.4, Fx.metal(Color(0.3, 0.3, 0.34)), 8)
	mast.position = s.pos + Vector3(-2.2, 0.7, -1.9)
	add_child(mast)
	var siren = Node3D.new()
	siren.position = mast.position + Vector3(0, 0.85, 0)
	add_child(siren)
	var dome = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.3
	dome.mesh = sm
	dome.material_override = Fx.emissive(Color(1.0, 0.55, 0.1), 2.5)
	siren.add_child(dome)
	var blade = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.7, 0.05, 0.08)
	blade.mesh = bm
	blade.material_override = Fx.emissive(Color(1.0, 0.75, 0.2), 4.0)
	siren.add_child(blade)
	_repair["siren"] = siren
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.omni_range = 6.0
	light.light_energy = 0.0
	light.position = siren.position
	add_child(light)
	_repair["light"] = light
	var l = Fx.label(self, s.label, 26, s.color, ui_scale)
	l.position = s.pos + Vector3(0, 1.4, -2.5)


func _prop(path: String, pos: Vector3, size: float, rot := 0.0, height := 0.0, tint = null) -> Node3D:
	var p = Fx.fitted(path, size, height)
	p.position = pos
	p.rotation.y = rot
	if tint != null:
		for mi in p.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = tint
	add_child(p)
	return p


func _clear_of_layout(p: Vector3, margin: float) -> bool:
	for id in buildings:
		if p.distance_to(buildings[id].pos) < buildings[id].size * 0.9 + margin:
			return false
	for id in spots:
		if p.distance_to(spots[id].pos) < 2.6 + margin:
			return false
	# keep conduits and agent routes clear
	for id in buildings:
		if id != "command_centre" and _dist_to_segment(p, center, buildings[id].pos) < 1.4 + margin:
			return false
	for id in spots:
		if _dist_to_segment(p, center, spots[id].pos) < 1.4 + margin:
			return false
	return true


static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab = b - a
	var t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _build_props():
	var wasteland = [
		["rocks_smallA", 0.8, 1.8], ["rocks_smallB", 0.8, 1.8], ["rock", 0.8, 2.0],
		["rock_largeA", 1.8, 3.4], ["rock_largeB", 1.8, 3.4], ["meteor", 1.2, 2.6],
		["meteor_half", 1.2, 2.4], ["crater", 1.8, 3.2], ["craterLarge", 3.0, 5.0],
		["rock_crystals", 1.0, 2.0], ["rock_crystalsLargeA", 1.4, 2.4], ["rock_crystalsLargeB", 1.4, 2.4],
	]
	# Wasteland around the base.
	var placed = 0
	var tries = 0
	while placed < 110 and tries < 2000:
		tries += 1
		var p = Vector3(_rng.randf_range(-16, 48), 0, _rng.randf_range(-14, 46))
		if p.x > -1.5 and p.x < 33.5 and p.z > -1.5 and p.z < 33.5:
			continue
		if p.distance_to(Vector3(-5.0, 0, 8.0)) < 4.0 or p.distance_to(Vector3(-5.0, 0, 17.5)) < 3.8:
			continue
		var pick = wasteland[_rng.randi() % wasteland.size()]
		# Kenney rocks are salmon-pink; recolour to cold basalt so the base stays the focus.
		var tint = _crystal_mat(pick[0]) if pick[0].begins_with("rock_crystals") else _rock_mat()
		_prop(K + pick[0] + ".glb", p, _rng.randf_range(pick[1], pick[2]), _rng.randf() * TAU, 0.0, tint)
		placed += 1
	# Glowing crystal clusters (sci-fi accents) near the base edge.
	for i in 14:
		var side = i % 4
		var t = _rng.randf_range(2, 30)
		var off = _rng.randf_range(1.5, 4.5)
		var p = [Vector3(t, 0, -off), Vector3(t, 0, 32 + off), Vector3(-off, 0, t), Vector3(32 + off, 0, t)][side]
		var hue = [Color(0.4, 0.8, 1.0), Color(0.75, 0.5, 1.0), Color(0.4, 1.0, 0.7)][i % 3]
		var crystal = _prop(K + ["rock_crystals", "rock_crystalsLargeA", "rock_crystalsLargeB"][i % 3] + ".glb", p, _rng.randf_range(1.2, 2.2), _rng.randf() * TAU, 0.0, Fx.emissive(hue, 1.6))
		var glow = OmniLight3D.new()
		glow.light_color = hue
		glow.omni_range = 3.0
		glow.light_energy = 0.9
		glow.position = Vector3(0, 0.8, 0)
		crystal.add_child(glow)
	# Base furniture: corner turrets, cargo and machines along the inner edge.
	for c in [Vector3(1.6, 0, 1.6), Vector3(30.4, 0, 1.6), Vector3(1.6, 0, 30.4), Vector3(30.4, 0, 30.4)]:
		_prop(K + "turret_double.glb", c, 1.4, (center - c).angle_to(Vector3.FORWARD))
	var furniture = ["barrels", "barrel", "machine_barrel", "machine_generator", "machine_wireless", "satelliteDish"]
	placed = 0
	tries = 0
	while placed < 22 and tries < 1500:
		tries += 1
		var edge = _rng.randi() % 4
		var t = _rng.randf_range(3, 29)
		var inset = _rng.randf_range(0.8, 2.6)
		var p = [Vector3(t, 0, inset), Vector3(t, 0, 32 - inset), Vector3(inset, 0, t), Vector3(32 - inset, 0, t)][edge]
		if not _clear_of_layout(p, 0.8):
			continue
		_prop(K + furniture[_rng.randi() % furniture.size()] + ".glb", p, _rng.randf_range(0.8, 1.4), _rng.randf() * TAU)
		placed += 1
	# Comms gear next to the Research Lab.
	if buildings.has("research_lab"):
		var rl = buildings["research_lab"].pos
		_prop(K + "machine_wirelessCable.glb", rl + Vector3(-3.0, 0, 1.4), 1.2, 0.8)
		_prop(K + "satelliteDish_detailed.glb", rl + Vector3(-3.4, 0, -1.8), 1.6, 2.2)


func _build_rocket(pos: Vector3):
	var pad = Fx.disc(2.6, 0.18, Fx.metal(Color(0.18, 0.2, 0.25), 0.8, 0.4), 8)
	pad.position = pos + Vector3(0, 0.09, 0)
	add_child(pad)
	add_child(_ring_at(pos, 2.45, 2.6, Color(1.0, 0.45, 0.2), 1.5))
	var y = 0.18
	for part in ["rocket_baseA", "rocket_fuelA", "rocket_sidesA", "rocket_fuelB", "rocket_topA"]:
		var p = Fx.fitted(K + part + ".glb", 1.7)
		p.position = pos + Vector3(0, y, 0)
		add_child(p)
		y += p.get_meta("height", 1.0)
	var fins = Fx.fitted(K + "rocket_finsA.glb", 2.4)
	fins.position = pos + Vector3(0, 0.18, 0)
	add_child(fins)
	for side in [-1, 1]:
		var post = Fx.disc(0.09, y * 0.8, Fx.metal(Color(0.35, 0.37, 0.42)), 8)
		post.position = pos + Vector3(side * 1.6, y * 0.4, -0.6)
		add_child(post)
		var tip = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		tip.mesh = sm
		tip.material_override = Fx.emissive(Color(1.0, 0.3, 0.2), 3.0)
		tip.position = post.position + Vector3(0, y * 0.4 + 0.1, 0)
		add_child(tip)
	var l = Fx.label(self, "Launch Pad", 22, Color(1.0, 0.7, 0.5), ui_scale)
	l.position = pos + Vector3(0, y + 0.6, 0)


func _build_comms_tower(pos: Vector3):
	var dish = _prop(K + "satelliteDish_large.glb", pos, 3.2, 0.6)
	_prop(K + "machine_wireless.glb", pos + Vector3(2.2, 0, 1.6), 1.2, 0.0)
	_prop(K + "machine_generatorLarge.glb", pos + Vector3(-1.8, 0, 2.2), 1.6, 1.0)
	dish.set_meta("spin", true)
	_ships.append({"node": dish, "kind": "dish"})
	add_child(_ring_at(pos, 2.2, 2.32, Color(0.45, 0.8, 1.0), 1.2))


func _ring_at(pos: Vector3, inner: float, outer: float, color: Color, energy: float) -> MeshInstance3D:
	var r = Fx.torus(inner, outer, Fx.emissive(color, energy), 0.04)
	r.position = pos + Vector3(0, 0.2, 0)
	return r


func _build_ships():
	var defs = [
		["craft_speederA", 12.0, 7.0, 0.22, 0.0],
		["craft_speederB", 17.0, 8.5, -0.15, 2.0],
		["craft_racer", 21.0, 10.0, 0.11, 4.0],
	]
	for d in defs:
		var ship = Fx.fitted(K + d[0] + ".glb", 1.6)
		add_child(ship)
		var light = OmniLight3D.new()
		light.light_color = Color(0.5, 0.8, 1.0)
		light.omni_range = 2.5
		light.light_energy = 1.2
		light.position = Vector3(0, -0.2, 0)
		ship.add_child(light)
		_ships.append({"node": ship, "kind": "orbit", "radius": d[1], "height": d[2], "speed": d[3], "phase": d[4]})
	var cargo = Fx.fitted(K + "craft_cargoA.glb", 2.6)
	add_child(cargo)
	_ships.append({"node": cargo, "kind": "cargo", "speed": 3.2, "height": 11.0, "t": 0.0})


func _animate_ships(delta: float, now: float):
	for s in _ships:
		var n: Node3D = s.node
		match s.kind:
			"orbit":
				var a = s.phase + now * s.speed
				var p = center + Vector3(cos(a) * s.radius, s.height + sin(now * 0.7 + s.phase) * 0.4, sin(a) * s.radius)
				var fwd = Vector3(-sin(a), 0, cos(a)) * signf(s.speed)
				n.position = p
				n.basis = Basis.looking_at(fwd, Vector3.UP).rotated(fwd, -0.35 * signf(s.speed))
			"cargo":
				s.t += delta * s.speed
				var span = 70.0
				var x = fmod(s.t, span) - 19.0
				n.position = Vector3(x, s.height, 9.0 + sin(s.t * 0.05) * 2.0)
				n.basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
			"dish":
				n.rotation.y += delta * 0.25


var _rock_material: StandardMaterial3D


func _rock_mat() -> StandardMaterial3D:
	if _rock_material == null:
		_rock_material = Fx.metal(Color(0.2, 0.22, 0.27), 0.1, 0.9)
	return _rock_material


func _crystal_mat(_name: String) -> StandardMaterial3D:
	var hues = [Color(0.4, 0.8, 1.0), Color(0.75, 0.5, 1.0), Color(0.4, 1.0, 0.7)]
	return Fx.emissive(hues[_rng.randi() % hues.size()], 1.4)


# A thin animated beam between a working agent and its building.
func _update_beam(a):
	var target = null
	if a.state == "working" and not a.is_moving() and buildings.has(a.location):
		target = buildings[a.location].pos + Vector3(0, 1.4, 0)
	if not _beams.has(a.agent_id):
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.06, 0.06, 1.0)
		mi.mesh = box
		mi.material_override = Fx.additive(a.role_color, 0.7)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_beams[a.agent_id] = mi
	var beam: MeshInstance3D = _beams[a.agent_id]
	beam.visible = target != null
	if target == null:
		return
	var from = a.global_position + Vector3(0, 0.7, 0)
	var dir = target - from
	var length = dir.length()
	if length < 0.1:
		beam.visible = false
		return
	beam.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP).scaled_local(Vector3(1, 1, length)), from + dir * 0.5)
	var m = beam.material_override as StandardMaterial3D
	m.albedo_color.a = 0.35 + 0.35 * abs(sin(Time.get_ticks_msec() / 160.0))


func apply_glow(env_node: WorldEnvironment, sun: DirectionalLight3D):
	if env_node != null and env_node.environment != null:
		var env = env_node.environment.duplicate()
		env.glow_enabled = true
		env.glow_intensity = 0.9
		env.glow_strength = 1.1
		env.glow_bloom = 0.06
		env.glow_hdr_threshold = 0.85
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		env.ambient_light_energy = 0.55
		env.fog_enabled = false
		env_node.environment = env
	if sun != null:
		sun.light_energy = 0.85
		sun.light_color = Color(0.85, 0.9, 1.0)
		sun.shadow_enabled = true
