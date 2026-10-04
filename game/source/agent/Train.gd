extends Node3D

# An elevated monorail loop just inside the base perimeter, with a four-car train doing
# laps and stopping at a small station. Runs faster while a mission is in progress.
# Purely decorative: no collision, no navigation.

const Fx = preload("res://source/agent/Fx.gd")
const K = "res://assets/models/kenney-spacekit/"

const RAIL_HEIGHT = 0.95
const CAR_LENGTH = 1.35
const CAR_GAP = 0.12
const CRUISE = 2.4
const CRUISE_MISSION = 4.2
const STATION_STOP_S = 2.5

var inset = 1.3  # distance from the base edge
var corner_radius = 2.6
var play_size = Vector2(32, 32)
var station_point = Vector3(1.3, 0, 16)
var mission_running = false
var ui_scale = 1.0

var _path: Path3D
var _cars = []  # PathFollow3D
var _head = 0.0
var _speed = 0.0
var _length = 1.0
var _station_offset = 0.0
var _stop_left = 0.0
var _departing = false
var _headlight: SpotLight3D


func build():
	_path = Path3D.new()
	_path.curve = _loop_curve()
	add_child(_path)
	_length = _path.curve.get_baked_length()
	_build_rail()
	_build_supports()
	_build_station()
	_build_train()
	_station_offset = _path.curve.get_closest_offset(station_point + Vector3(0, RAIL_HEIGHT, 0))
	_head = fposmod(_station_offset + _length * 0.5, _length)


func _process(delta):
	if _cars.is_empty():
		return
	var cruise = CRUISE_MISSION if mission_running else CRUISE
	var to_station = fposmod(_station_offset - _head, _length)
	var target = cruise
	if _stop_left > 0.0:
		_stop_left -= delta
		target = 0.0
		if _stop_left <= 0.0:
			_departing = true
	elif not _departing and to_station < 5.0:
		target = max(0.25, cruise * to_station / 5.0)
		if to_station < 0.06:
			_stop_left = STATION_STOP_S
			target = 0.0
	if _departing and to_station > 6.0 and to_station < _length - 1.0:
		_departing = false
	_speed = move_toward(_speed, target, delta * (3.0 if target < _speed else 1.6))
	_head = fposmod(_head + _speed * delta, _length)
	for i in _cars.size():
		_cars[i].progress = fposmod(_head - i * (CAR_LENGTH + CAR_GAP), _length)
	if _headlight:
		_headlight.light_energy = 2.0 + (1.0 if mission_running else 0.0)


func _loop_curve() -> Curve3D:
	var c = Curve3D.new()
	c.bake_interval = 0.15
	var lo = inset
	var hi_x = play_size.x - inset
	var hi_z = play_size.y - inset
	var r = corner_radius
	# Clockwise (seen from above) rounded rectangle; each corner is a quarter arc.
	var corners = [
		[Vector2(hi_x - r, lo + r), -PI * 0.5],
		[Vector2(hi_x - r, hi_z - r), 0.0],
		[Vector2(lo + r, hi_z - r), PI * 0.5],
		[Vector2(lo + r, lo + r), PI],
	]
	for corner in corners:
		var ctr: Vector2 = corner[0]
		var start: float = corner[1]
		for k in 9:
			var a = start + (PI * 0.5) * k / 8.0
			c.add_point(Vector3(ctr.x + cos(a) * r, RAIL_HEIGHT, ctr.y + sin(a) * r))
	c.add_point(c.get_point_position(0))
	return c


func _build_rail():
	var beam = CSGPolygon3D.new()
	beam.polygon = PackedVector2Array([Vector2(-0.2, -0.14), Vector2(0.2, -0.14), Vector2(0.2, 0.1), Vector2(-0.2, 0.1)])
	beam.mode = CSGPolygon3D.MODE_PATH
	beam.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	beam.path_interval = 0.3
	beam.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	beam.path_joined = true
	beam.path_local = false
	beam.material = Fx.metal(Color(0.5, 0.54, 0.62), 0.75, 0.35)
	add_child(beam)
	beam.path_node = beam.get_path_to(_path)
	var strip = CSGPolygon3D.new()
	strip.polygon = PackedVector2Array([Vector2(-0.035, 0.1), Vector2(0.035, 0.1), Vector2(0.035, 0.12), Vector2(-0.035, 0.12)])
	strip.mode = CSGPolygon3D.MODE_PATH
	strip.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	strip.path_interval = 0.3
	strip.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	strip.path_joined = true
	strip.material = Fx.emissive(Color(0.35, 0.75, 1.0), 0.45)
	add_child(strip)
	strip.path_node = strip.get_path_to(_path)


func _build_supports():
	var mat = Fx.metal(Color(0.26, 0.28, 0.34), 0.8, 0.4)
	var foot_mat = Fx.metal(Color(0.16, 0.18, 0.23), 0.7, 0.5)
	var step = 3.0
	var d = 0.0
	while d < _length:
		var p = _path.curve.sample_baked(d)
		var pillar = Fx.disc(0.09, RAIL_HEIGHT - 0.12, mat, 10)
		pillar.position = Vector3(p.x, (RAIL_HEIGHT - 0.12) * 0.5, p.z)
		add_child(pillar)
		var foot = Fx.disc(0.24, 0.08, foot_mat, 12)
		foot.position = Vector3(p.x, 0.04, p.z)
		add_child(foot)
		d += step


func _build_station():
	var platform = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.4, 0.7, 6.4)
	platform.mesh = box
	platform.material_override = Fx.metal(Color(0.42, 0.46, 0.54), 0.6, 0.45)
	platform.position = station_point + Vector3(1.05, 0.35, 0)
	add_child(platform)
	var edge = MeshInstance3D.new()
	var eb = BoxMesh.new()
	eb.size = Vector3(0.06, 0.03, 6.4)
	edge.mesh = eb
	edge.material_override = Fx.emissive(Color(1.0, 0.8, 0.3), 2.0)
	edge.position = station_point + Vector3(0.38, 0.72, 0)
	add_child(edge)
	var canopy = MeshInstance3D.new()
	var cb = BoxMesh.new()
	cb.size = Vector3(1.6, 0.06, 4.0)
	canopy.mesh = cb
	canopy.material_override = Fx.metal(Color(0.55, 0.6, 0.7), 0.7, 0.3)
	canopy.position = station_point + Vector3(1.05, 2.0, 0)
	add_child(canopy)
	for z in [-1.8, 1.8]:
		var post = Fx.disc(0.05, 1.3, Fx.metal(Color(0.35, 0.37, 0.42)), 8)
		post.position = station_point + Vector3(1.6, 1.35, z)
		add_child(post)
	var l = Fx.label(self, "Station", 22, Color(1.0, 0.85, 0.5), ui_scale)
	l.position = station_point + Vector3(1.0, 2.5, 0)


func _build_train():
	var parts = ["monorail_trainFront", "monorail_trainPassenger", "monorail_trainCargo", "monorail_trainEnd"]
	for i in parts.size():
		var follow = PathFollow3D.new()
		follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
		follow.loop = true
		_path.add_child(follow)
		var car = Fx.fitted(K + parts[i] + ".glb", CAR_LENGTH)
		# Align the car's long axis with the direction of travel (-Z of the follower).
		var box = Fx.aabb_of(car.get_child(0))
		if box != null and box.size.x > box.size.z:
			car.rotation.y = PI * 0.5
		car.position.y = 0.1
		follow.add_child(car)
		_cars.append(follow)
	_headlight = SpotLight3D.new()
	_headlight.light_color = Color(1.0, 0.95, 0.8)
	_headlight.spot_range = 7.0
	_headlight.spot_angle = 28.0
	_headlight.position = Vector3(0, 0.4, -CAR_LENGTH * 0.55)
	_cars[0].add_child(_headlight)
	for follow in _cars:
		var glow = OmniLight3D.new()
		glow.light_color = Color(0.45, 0.8, 1.0)
		glow.omni_range = 1.6
		glow.light_energy = 0.8
		glow.position = Vector3(0, 0.5, 0)
		follow.add_child(glow)
