extends "res://source/match/players/Player.gd"

# The Hollow: a player that never builds or mines. It starts with nests (one on its own
# spawn point, the rest on spawn points nobody took) and sends waves of creatures from
# them at the other players. Waves grow with every wave, with the match's difficulty, and
# at night. When the last nest is gone the waves stop; when the last creature is gone the
# Hollow is out of the match.

const HollowNestScene = preload("res://source/match/units/HollowNest.tscn")
const HollowMoteScene = preload("res://source/match/units/HollowMote.tscn")
const HollowBruteScene = preload("res://source/match/units/HollowBrute.tscn")
const HollowWaspScene = preload("res://source/match/units/HollowWasp.tscn")
const AutoAttackingBattlegroup = preload(
	"res://source/match/players/simple-clairvoyant-ai/AutoAttackingBattlegroup.gd"
)

const FIRST_WAVE_DELAY_S = 150.0
const WAVE_INTERVAL_S = 100.0
const MIN_WAVE_INTERVAL_S = 45.0
const INTERVAL_DECAY = 0.92  # every wave comes this much sooner than the last
const NIGHT_MULTIPLIER = 1.6
const MAX_WAVE_SIZE = 24
const EXTRA_NEST_SPACING = 9.0

@export var nests = 1
@export var difficulty = 1.0

var _nests = []
var _wave = 0
var _interval = WAVE_INTERVAL_S
var _night = false
var _timer = null

@onready var _match = find_parent("Match")


func _ready():
	color = Constants.Player.HOLLOW_COLOR
	MatchSignals.night_started.connect(func(): _night = true)
	MatchSignals.day_started.connect(func(): _night = false)


# Called by Match instead of the usual Lantern Core + Engineers.
func spawn_initial_units(spawn_transform):
	if "hollow_nests" in _match.settings and _match.settings.hollow_nests > 0:
		nests = _match.settings.hollow_nests
	if "difficulty" in _match.settings:
		difficulty = _match.settings.difficulty
	var transforms = [spawn_transform]
	for free in _match.get_free_spawn_transforms():
		if transforms.size() >= nests:
			break
		transforms.append(free)
	var i = 0
	while transforms.size() < nests:
		var base = transforms[i % transforms.size()]
		transforms.append(base.translated(Vector3(EXTRA_NEST_SPACING, 0, 0) * (1 + i / 4)))
		i += 1
	for t in transforms:
		var nest = HollowNestScene.instantiate()
		_match._setup_and_spawn_unit(nest, t, self, false)
		_nests.append(nest)
		nest.tree_exited.connect(_on_nest_died.bind(nest))
		_spawn_creature(HollowMoteScene, t.origin)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_wave_timer)
	add_child(_timer)
	_timer.start(FIRST_WAVE_DELAY_S / max(0.25, difficulty))


func _living_nests():
	return _nests.filter(func(nest): return is_instance_valid(nest) and nest.is_inside_tree())


func _on_nest_died(nest):
	_nests.erase(nest)


func _on_wave_timer():
	var living = _living_nests()
	if living.is_empty():
		return
	_wave += 1
	var size = int(round((2 + _wave) * difficulty * (NIGHT_MULTIPLIER if _night else 1.0)))
	size = clampi(size, 2, MAX_WAVE_SIZE)
	var composition = []
	var brutes = int(_wave / 2) if _wave >= 2 else 0
	var wasps = max(0, _wave - 2)
	for _i in range(min(brutes, size / 3)):
		composition.append(HollowBruteScene)
	for _i in range(min(wasps, size / 3)):
		composition.append(HollowWaspScene)
	while composition.size() < size:
		composition.append(HollowMoteScene)
	var targets = get_tree().get_nodes_in_group("players").filter(
		func(player): return player != self and not player.get_script() == get_script()
	)
	if targets.is_empty():
		return
	var battlegroup = AutoAttackingBattlegroup.new(composition.size(), targets)
	add_child(battlegroup)
	for i in range(composition.size()):
		var nest = living[i % living.size()]
		var creature = _spawn_creature(composition[i], nest.global_position)
		battlegroup.attach_unit(creature)
	MatchSignals.hollow_wave_started.emit(self, composition.size())
	_interval = max(MIN_WAVE_INTERVAL_S, _interval * INTERVAL_DECAY)
	_timer.start(_interval / max(0.25, difficulty))


func _spawn_creature(scene, around: Vector3):
	var creature = scene.instantiate()
	var offset = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * 3.0
	var t = Transform3D(Basis(), around + offset)
	MatchSignals.setup_and_spawn_unit.emit(creature, t, self)
	return creature
