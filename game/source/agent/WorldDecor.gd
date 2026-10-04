extends Node3D

# World visuals that each reflect real state: ground zones that brighten with activity,
# data conduits that light up while an agent uses the route, the Rally Point (agents
# waiting) and Repair Bay (agents in error) pads, work beams from agents to their building
# and the mission-complete burst. Nothing purely decorative. No collision, no navigation.

const Fx = preload("res://source/agent/Fx.gd")
const HAZARD_SHADER = preload("res://source/agent/hazard.gdshader")
const CONDUIT_SHADER = preload("res://source/agent/conduit.gdshader")

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
var _beams = {}  # agent_id -> MeshInstance3D


func build(ground_material: ShaderMaterial):
	_ground_mat = ground_material
	_build_conduits()
	_build_rally_point()
	_build_repair_bay()
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
		env.glow_intensity = 0.6
		env.glow_strength = 0.9
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
