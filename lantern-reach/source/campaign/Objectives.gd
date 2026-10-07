extends CanvasLayer

# Shows the match's objective at the top of the screen, tracks it, and tells the match when
# it is done (MatchSignals.objective_completed). Also flashes the Hollow's waves and the turn
# of day and night.

const HollowNest = preload("res://source/match/units/HollowNest.gd")
const Human = preload("res://source/match/players/human/Human.gd")
const NOTICE_SECONDS = 4.0

var _type = "destroy_all"
var _amount = 0
var _elapsed = 0.0
var _harvested = 0
var _last_lumen = null
var _nests_seen = false
var _done = false
var _notice_until = 0.0

@onready var _match = find_parent("Match")
@onready var _label = find_child("ObjectiveLabel")
@onready var _notice = find_child("NoticeLabel")


func _ready():
	if not _match.is_node_ready():
		await _match.ready
	var objective = _match.settings.objective if "objective" in _match.settings else {}
	_type = objective.get("type", "destroy_all")
	_amount = int(objective.get("amount", 0))
	_notice.text = ""
	var human = _human_player()
	if human != null:
		_last_lumen = human.resource_a
		human.changed.connect(_on_human_resources_changed.bind(human))
	MatchSignals.night_started.connect(func(): _show_notice(tr("NIGHT_FALLS")))
	MatchSignals.day_started.connect(func(): _show_notice(tr("DAY_BREAKS")))
	MatchSignals.hollow_wave_started.connect(
		func(_player, size): _show_notice(tr("HOLLOW_WAVE") + " (" + str(size) + ")")
	)
	_refresh()


func _process(delta):
	if _done:
		return
	_elapsed += delta
	if _type == "survive" and _elapsed >= _amount:
		_complete()
	elif _type == "nests":
		var alive = _living_nests()
		if alive > 0:
			_nests_seen = true
		elif _nests_seen:
			_complete()
	if Time.get_ticks_msec() / 1000.0 > _notice_until:
		_notice.text = ""
	_refresh()


func _on_human_resources_changed(human):
	if _last_lumen != null and human.resource_a > _last_lumen:
		_harvested += human.resource_a - _last_lumen
	_last_lumen = human.resource_a
	if _type == "harvest" and _harvested >= _amount and not _done:
		_complete()


func _complete():
	if _done:
		return
	_done = true
	_refresh()
	MatchSignals.objective_completed.emit()


func _refresh():
	var text = Campaign.objective_text({"type": _type, "amount": _amount})
	match _type:
		"survive":
			text = tr("OBJECTIVE_SURVIVE") + "  " + _mmss(max(0, _amount - int(_elapsed)))
		"harvest":
			text = tr("OBJECTIVE_HARVEST") + "  " + str(min(_harvested, _amount)) + " / " + str(_amount)
		"nests":
			text = tr("OBJECTIVE_NESTS") + "  (" + str(_living_nests()) + ")"
	_label.text = text


func _show_notice(text):
	_notice.text = text
	_notice_until = Time.get_ticks_msec() / 1000.0 + NOTICE_SECONDS


func _living_nests():
	return get_tree().get_nodes_in_group("units").filter(func(unit): return unit is HollowNest).size()


func _human_player():
	for player in get_tree().get_nodes_in_group("players"):
		if player is Human:
			return player
	return null


static func _mmss(seconds: int):
	return "%d:%02d" % [seconds / 60, seconds % 60]
