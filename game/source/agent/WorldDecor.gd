extends Node3D

# Static ground markings on the Martian surface: dirt roads from the Command Centre to each
# building and spot (a road darkens slightly while an agent uses it), a painted Rally Point
# (agents waiting on others) and a striped Repair Bay (agents whose step failed).
# No lights, no animation. No collision, no navigation.

const Fx = preload("res://source/agent/Fx.gd")
const HAZARD_SHADER = preload("res://source/agent/hazard.gdshader")
const ROAD_SHADER = preload("res://source/agent/road.gdshader")

var buildings = {}  # id -> {"pos": Vector3, "accent": Color, "size": float}
var spots = {}  # id -> {"pos": Vector3, "color": Color, "label": String}
var center = Vector3(16, 0, 16)
var ui_scale = 1.0

var _roads = {}  # location -> ShaderMaterial
var _use = {}  # location -> smoothed 0..1


func clear():
	for child in get_children():
		child.queue_free()
	_roads.clear()
	_use.clear()


func build():
	_build_roads()
	_build_rally_point()
	_build_repair_bay()


# Called every frame by AgentMatch with the live agents (or replay ghosts).
func update_world(agents: Array, delta: float):
	var wanted = {}
	for a in agents:
		if not a.state in ["idle", "complete"]:
			wanted[a.location] = 1.0
	for loc in _roads:
		var cur = lerpf(_use.get(loc, 0.0), wanted.get(loc, 0.0), clampf(delta * 2.0, 0.0, 1.0))
		_use[loc] = cur
		_roads[loc].set_shader_parameter("in_use", cur)


func _build_roads():
	var targets = {}
	for id in buildings:
		if id != "command_centre":
			targets[id] = buildings[id].pos
	for id in spots:
		targets[id] = spots[id].pos
	for id in targets:
		var to = targets[id]
		var dir = (to - center).normalized()
		var a = center + dir * 2.2
		var b = to - dir * 1.6
		var plane = PlaneMesh.new()
		plane.size = Vector2(1.5, a.distance_to(b))
		var mat = ShaderMaterial.new()
		mat.shader = ROAD_SHADER
		var mi = MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b) * 0.5 + Vector3(0, 0.015, 0))
		add_child(mi)
		_roads[id] = mat
		_use[id] = 0.0


func _build_rally_point():
	var s = spots["rally_point"]
	var paint = StandardMaterial3D.new()
	paint.albedo_color = Color(0.93, 0.78, 0.32, 0.75)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.roughness = 1.0
	var ring = Fx.torus(1.85, 2.05, paint, 0.01)
	ring.position = s.pos + Vector3(0, 0.02, 0)
	add_child(ring)
	var l = Fx.label(self, s.label, 22, Color(1.0, 0.9, 0.6), ui_scale)
	l.position = s.pos + Vector3(0, 0.8, -2.3)


func _build_repair_bay():
	var s = spots["repair_bay"]
	var hazard = ShaderMaterial.new()
	hazard.shader = HAZARD_SHADER
	var pad = Fx.disc(2.1, 0.04, hazard, 8)
	pad.position = s.pos + Vector3(0, 0.02, 0)
	pad.rotation.y = PI / 8.0
	add_child(pad)
	var inner = StandardMaterial3D.new()
	inner.albedo_color = Color(0.55, 0.42, 0.38)
	inner.roughness = 1.0
	var core = Fx.disc(1.7, 0.05, inner, 8)
	core.position = s.pos + Vector3(0, 0.025, 0)
	core.rotation.y = PI / 8.0
	add_child(core)
	var l = Fx.label(self, s.label, 22, Color(1.0, 0.7, 0.6), ui_scale)
	l.position = s.pos + Vector3(0, 0.8, -2.4)
