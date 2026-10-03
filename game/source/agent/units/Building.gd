extends "res://source/match/units/Structure.gd"

# A capability in the agent world (Research Lab, Code Factory, ...). Placed by AgentMatch.
# Sits on a hex pad whose rim glows in the building's accent colour; brightens and runs its
# signature animation while agents work inside, and flashes when it needs attention.

const Fx = preload("res://source/agent/Fx.gd")

var building_id = ""
var label = ""
var model_path = ""
var model_size = 3.0  # footprint (largest horizontal extent) the model is fitted to
var accent = Color(0.4, 0.75, 1.0)

var activity = 0.0  # smoothed 0..1, from occupants
var alert = false  # e.g. Human Approval has a pending request

var _occupants = {}
var _label3d: Label3D
var _pivot: Node3D
var _rim_mat: StandardMaterial3D
var _light: OmniLight3D
var _fx = {}
var _pulse_t = -1.0


func _ready():
	if model_path != "":
		_pivot = Fx.fitted(model_path, model_size)
		_pivot.position.y = 0.14
		find_child("Geometry").add_child(_pivot)
	await super()
	_build_pad()
	_build_signature()
	var ui_scale = _match.ui_scale if "ui_scale" in _match else 1.0
	_label3d = Fx.label(self, label, 26, Color(0.92, 0.95, 1.0), ui_scale, 0.0008)
	_label3d.position = Vector3(0, max(2.6, (_pivot.get_meta("height", 2.0) if _pivot else 2.0) + 0.9), 0)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.6, 0)
	_light.omni_range = 5.5
	_light.light_energy = 0.0
	_light.light_color = accent
	add_child(_light)


# The building glows while at least one agent works inside it.
func set_occupant(agent_id, working):
	if working:
		_occupants[agent_id] = true
	else:
		_occupants.erase(agent_id)


# A one-off expanding ring (mission started / finished at the Command Centre).
func pulse():
	_pulse_t = 0.0


func _process(delta):
	if _light == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	var target = 1.0 if not _occupants.is_empty() else 0.0
	activity = lerpf(activity, target, clampf(delta * 3.0, 0.0, 1.0))
	var flash = 0.5 + 0.5 * sin(now * 6.0) if alert else 0.0
	_light.light_energy = activity * (1.4 + 0.5 * sin(now * 4.0)) + flash * 2.0
	_light.light_color = Color(1.0, 0.6, 0.2) if alert else accent
	_rim_mat.emission_energy_multiplier = 0.8 + activity * 3.5 + flash * 4.0
	_rim_mat.emission = Color(1.0, 0.55, 0.15) if alert else accent
	_label3d.modulate = accent.lightened(0.45) if activity > 0.5 or alert else Color(0.9, 0.93, 1.0)
	_animate_signature(delta, now)
	_animate_pulse(delta)


func _build_pad():
	var r = model_size * 0.72
	var pad = Fx.disc(r, 0.14, Fx.metal(Color(0.16, 0.19, 0.26), 0.8, 0.35), 6)
	pad.position.y = 0.07
	pad.rotation.y = PI / 6.0
	add_child(pad)
	var inner = Fx.disc(r * 0.84, 0.16, Fx.metal(Color(0.1, 0.12, 0.17), 0.6, 0.5), 6)
	inner.position.y = 0.08
	inner.rotation.y = PI / 6.0
	add_child(inner)
	_rim_mat = Fx.emissive(accent, 1.0)
	var rim = Fx.torus(r * 0.93, r * 1.0, _rim_mat, 0.05)
	rim.position.y = 0.15
	add_child(rim)


func _build_signature():
	match building_id:
		"command_centre":
			for i in 2:
				var mat = Fx.additive(accent, 0.55)
				var ring = Fx.torus(2.3 + i * 0.5, 2.4 + i * 0.5, mat, 0.02)
				ring.position.y = 2.4 + i * 0.35
				add_child(ring)
				_fx["ring%d" % i] = ring
			var wave_mat = Fx.additive(accent, 0.0)
			var wave = Fx.torus(0.95, 1.0, wave_mat, 0.02)
			wave.position.y = 0.2
			wave.visible = false
			add_child(wave)
			_fx["wave"] = wave
		"code_factory":
			var sparks = GPUParticles3D.new()
			sparks.amount = 48
			sparks.lifetime = 0.7
			sparks.emitting = false
			var pm = ParticleProcessMaterial.new()
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 55.0
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 4.5
			pm.gravity = Vector3(0, -9.0, 0)
			pm.scale_min = 0.6
			pm.scale_max = 1.2
			sparks.process_material = pm
			var spark_mesh = SphereMesh.new()
			spark_mesh.radius = 0.035
			spark_mesh.height = 0.07
			spark_mesh.material = Fx.emissive(Color(1.0, 0.6, 0.2), 6.0)
			sparks.draw_pass_1 = spark_mesh
			sparks.position = Vector3(0, 1.2, 0)
			add_child(sparks)
			_fx["sparks"] = sparks
		"knowledge_library":
			var beam_mat = Fx.additive(accent, 0.0)
			var beam = Fx.disc(0.45, 9.0, beam_mat, 24)
			beam.position.y = 4.5
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(beam)
			_fx["beam"] = beam
		"human_approval":
			var bulb = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.44
			bulb.mesh = sm
			bulb.material_override = Fx.emissive(Color(1.0, 0.55, 0.15), 0.5)
			bulb.position = Vector3(0, (_pivot.get_meta("height", 2.0) if _pivot else 2.0) + 0.35, 0)
			add_child(bulb)
			_fx["bulb"] = bulb


func _animate_signature(delta, now):
	match building_id:
		"research_lab":
			if _pivot:
				_pivot.rotation.y += delta * (0.2 + 1.6 * activity)
		"command_centre":
			_fx["ring0"].rotation.y += delta * 0.6
			_fx["ring1"].rotation.y -= delta * 0.35
			var busy = _match_busy()
			for k in ["ring0", "ring1"]:
				var m = _fx[k].material_override as StandardMaterial3D
				m.albedo_color.a = 0.25 + 0.35 * busy + 0.1 * sin(now * 2.0)
		"code_factory":
			_fx["sparks"].emitting = activity > 0.4
		"knowledge_library":
			var m = _fx["beam"].material_override as StandardMaterial3D
			m.albedo_color.a = activity * (0.16 + 0.08 * sin(now * 5.0))
			_fx["beam"].visible = activity > 0.02
		"human_approval":
			var m = _fx["bulb"].material_override as StandardMaterial3D
			m.emission_energy_multiplier = 0.4 + (6.0 * (0.5 + 0.5 * sin(now * 7.0)) if alert else 0.0)


func _match_busy():
	return 1.0 if "mission_running" in _match and _match.mission_running else 0.0


func _animate_pulse(delta):
	if not _fx.has("wave") or _pulse_t < 0.0:
		return
	_pulse_t += delta
	var t = _pulse_t / 1.8
	var wave = _fx["wave"]
	wave.visible = t < 1.0
	if t >= 1.0:
		_pulse_t = -1.0
		return
	var s = 1.0 + t * 16.0
	wave.scale = Vector3(s, 0.02, s)
	(wave.material_override as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - t)


func set_pulse_color(color: Color):
	if _fx.has("wave"):
		(_fx["wave"].material_override as StandardMaterial3D).albedo_color = Color(color, 0.0)


func _setup_default_properties_from_constants():
	sight_range = 10.0
	hp = 20
	hp_max = 20
