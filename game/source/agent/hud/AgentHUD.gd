extends Control

# Mission HUD, built in code: top bar (mission, resources, connection), agent roster,
# command bar, log feed, Human Approval dialog and mission results panel.

signal mission_requested(title)
signal mission_cancel_requested
signal approval_resolved(id, approved)
signal agent_focus_requested(agent_id)
signal replay_requested(mission_id)
signal replay_pause_toggled
signal replay_speed_cycled
signal replay_stop_requested
signal setting_changed(key, value)

const ROLE_COLORS = {
	"commander": Color(0.85, 0.93, 1.0),
	"scout": Color(1.0, 0.88, 0.3),
	"writer": Color(1.0, 0.5, 0.75),
	"researcher": Color(0.35, 0.8, 1.0),
	"coder": Color(1.0, 0.6, 0.25),
	"analyst": Color(0.55, 0.95, 0.5),
	"reviewer": Color(0.85, 0.55, 1.0),
	"approval": Color(1.0, 0.6, 0.2),
}

const BG = Color(0.06, 0.08, 0.13, 0.86)
const BG_SOLID = Color(0.07, 0.09, 0.15, 0.97)
const BORDER = Color(0.35, 0.55, 0.85, 0.35)
const TEXT = Color(0.9, 0.93, 0.98)
const MUTED = Color(0.6, 0.66, 0.76)
const ACCENT = Color(0.4, 0.75, 1.0)
const STATE_STYLE = preload("res://source/agent/units/Agent.gd").STATE_STYLE

var _mission_label: Label
var _mission_status: Label
var _tokens_label: Label
var _tokens_bar: ProgressBar
var _cost_label: Label
var _conn_label: Label
var _mc_button: Button
var _roster: VBoxContainer
var _cards = {}
var _input: LineEdit
var _deploy: Button
var _abort: Button
var _log_box: VBoxContainer
var _approval_panel: PanelContainer
var _approval_text: Label
var _approval_id = ""
var _result_panel: PanelContainer
var _result_title: Label
var _result_text: RichTextLabel

var _mc_url = ""
var _replay_panel: PanelContainer
var _replay_title: Label
var _replay_time: Label
var _replay_caption: Label
var _replay_pause: Button
var _replay_speed: Button
var _replay_report: Button
var _timeline: Control
var _deferred_result = null  # mission whose report waits for the replay to finish
var replay_active = false
var _settings_panel: PanelContainer
var _chip_groups = {}  # key -> [{button, value}]
var _zoom_slider: HSlider
var _zoom_value: Label
var _syncing_zoom = false
var settings_ref = null
var camera_ref = null
var _mission = null
var _approvals = {}
var _agents = {}
var _tasks = {}
var _selected_agent = ""
var _source = ""


func _ready():
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_roster()
	_build_command_bar()
	_build_log()
	_build_approval()
	_build_result()
	_build_replay()
	_build_settings()


# ---------- public API (driven by AgentMatch) ----------


# The layout is designed for a 1080p-tall window; on bigger screens the whole HUD is
# drawn scaled instead of shrinking to a strip of tiny text.
func set_ui_scale(s: float):
	set_anchors_preset(PRESET_TOP_LEFT)
	position = Vector2.ZERO
	scale = Vector2(s, s)
	size = get_viewport_rect().size / s


func set_connection(online, source = ""):
	if source != "":
		_source = source
	if online:
		_conn_label.text = "● %s" % (_source.to_upper() if _source != "" else "ONLINE")
		_conn_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.55))
	else:
		_conn_label.text = "● ADAPTER OFFLINE"
		_conn_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_deploy.disabled = not online


func apply_snapshot(world):
	_source = world.get("source", "")
	_mc_url = world.get("links", {}).get("missionControl", "") if world.get("links", {}).get("missionControl") != null else ""
	_mc_button.visible = _mc_url != ""
	_approvals.clear()
	set_mission(world.get("mission"))
	_tasks.clear()
	for t in world.get("tasks", []):
		_tasks[t["id"]] = t
	_render_mission_status()
	for a in world.get("agents", []):
		set_agent(a)
	for ap in world.get("approvals", []):
		set_approval(ap)
	set_resources(world.get("resources", {}))
	for child in _log_box.get_children():
		child.queue_free()
	var log_lines = world.get("log", [])
	for i in range(max(0, log_lines.size() - 6), log_lines.size()):
		add_log(log_lines[i])


func set_agent(a):
	_agents[a["id"]] = a
	if not _cards.has(a["id"]):
		_cards[a["id"]] = _make_card(a)
	var card = _cards[a["id"]]
	var style = STATE_STYLE.get(a.get("state", "idle"), STATE_STYLE["idle"])
	var st = style["text"]
	if a.get("state") == "working" and a.get("progress") != null:
		st += "  %d%%" % int(round(float(a["progress"]) * 100.0))
	card.state.text = st
	card.state.add_theme_color_override("font_color", style["color"])
	var task = a.get("taskTitle")
	card.task.text = task if task != null and task != "" else "—"
	var detail = a.get("detail")
	card.detail.text = detail if detail != null else ""
	card.detail.visible = card.detail.text != ""


func set_task(t):
	_tasks[t["id"]] = t
	_render_mission_status()


func set_mission(m):
	var prev_status = _mission.get("status", "") if _mission != null else ""
	var prev_id = _mission.get("id", "") if _mission != null else ""
	if m != null and m.get("id", "") != prev_id:
		_tasks.clear()
		_result_panel.visible = false
	_mission = m
	_render_mission_status()
	if m == null:
		return
	var status = m.get("status", "")
	var terminal = status in ["completed", "failed", "cancelled"]
	if terminal and (status != prev_status or m.get("id", "") != prev_id):
		_show_result(m)


func _render_mission_status():
	var m = _mission
	if m == null:
		_mission_label.text = "No active mission"
		_mission_status.text = "Type a mission below and press Deploy"
		_abort.visible = false
		return
	_mission_label.text = m.get("title", "")
	var status = m.get("status", "")
	var mission_tasks = _tasks.values().filter(func(t): return t.get("missionId", "") == m.get("id", ""))
	var done = mission_tasks.filter(func(t): return t.get("status") == "done").size()
	if mission_tasks.is_empty():
		_mission_status.text = status.to_upper()
	else:
		_mission_status.text = "%s · %d/%d tasks done" % [status.to_upper(), done, mission_tasks.size()]
	_abort.visible = status == "planning" or status == "running"


func set_approval(ap):
	_approvals[ap["id"]] = ap
	_refresh_approval()


func set_resources(r):
	var used = int(r.get("tokensUsed", 0))
	var budget = r.get("tokenBudget")
	if budget != null and float(budget) > 0:
		_tokens_label.text = "Tokens %s / %s" % [_fmt_int(used), _fmt_int(int(budget))]
		_tokens_bar.max_value = float(budget)
		_tokens_bar.value = min(used, float(budget))
		_tokens_bar.visible = true
	else:
		_tokens_label.text = "Tokens %s" % _fmt_int(used)
		_tokens_bar.visible = false
	var cost = float(r.get("costUsd", 0.0))
	var cost_budget = r.get("costBudgetUsd")
	if cost_budget != null and float(cost_budget) > 0:
		_cost_label.text = "Cost $%.4f / $%.2f" % [cost, float(cost_budget)]
	else:
		_cost_label.text = "Cost $%.4f" % cost


func add_log(line):
	var l = Label.new()
	var who = line.get("agentId")
	l.text = ("[%s] " % who.capitalize() if who != null else "") + str(line.get("text", ""))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13)
	var color = MUTED
	match line.get("level", "info"):
		"warn":
			color = Color(1.0, 0.8, 0.4)
		"error":
			color = Color(1.0, 0.45, 0.45)
	l.add_theme_color_override("font_color", color)
	_log_box.add_child(l)
	while _log_box.get_child_count() > 6:
		var old = _log_box.get_child(0)
		_log_box.remove_child(old)
		old.queue_free()


func select_agent(agent_id):
	_selected_agent = agent_id
	for id in _cards:
		var sb = _cards[id].panel.get_theme_stylebox("panel") as StyleBoxFlat
		sb.border_color = ACCENT if id == agent_id else BORDER
		sb.set_border_width_all(2 if id == agent_id else 1)


func open_approval_if_pending():
	_refresh_approval()
	return _approval_panel.visible


# ---------- building ----------


func _panel(bg = BG):
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = MOUSE_FILTER_STOP
	return p


func _label(text, size = 15, color = TEXT):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text, primary = false):
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(96, 36)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.45, 0.85) if primary else Color(0.16, 0.2, 0.3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	b.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.bg_color = sb.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var dis = sb.duplicate()
	dis.bg_color = Color(0.15, 0.17, 0.22)
	b.add_theme_stylebox_override("disabled", dis)
	b.focus_mode = FOCUS_NONE
	return b


func _build_top_bar():
	var p = _panel()
	p.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	p.offset_left = 16
	p.offset_right = -16
	p.offset_top = 12
	add_child(p)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	p.add_child(row)
	var brand = _label("AGENT RTS", 18, ACCENT)
	row.add_child(brand)
	var mission = VBoxContainer.new()
	mission.size_flags_horizontal = SIZE_EXPAND_FILL
	mission.add_theme_constant_override("separation", 0)
	_mission_label = _label("No active mission", 17)
	_mission_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mission_status = _label("", 13, MUTED)
	mission.add_child(_mission_label)
	mission.add_child(_mission_status)
	row.add_child(mission)
	var res = VBoxContainer.new()
	res.add_theme_constant_override("separation", 2)
	res.custom_minimum_size = Vector2(230, 0)
	_tokens_label = _label("Tokens 0", 14)
	_tokens_bar = ProgressBar.new()
	_tokens_bar.show_percentage = false
	_tokens_bar.custom_minimum_size = Vector2(220, 6)
	res.add_child(_tokens_label)
	res.add_child(_tokens_bar)
	row.add_child(res)
	_cost_label = _label("Cost $0.0000", 14)
	row.add_child(_cost_label)
	_conn_label = _label("● CONNECTING", 14, MUTED)
	row.add_child(_conn_label)
	_mc_button = _button("Mission Control ↗")
	_mc_button.visible = false
	_mc_button.pressed.connect(func(): OS.shell_open(_mc_url))
	row.add_child(_mc_button)
	var gear = _button("Settings")
	gear.pressed.connect(_toggle_settings)
	row.add_child(gear)


func _build_roster():
	var p = _panel()
	p.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	p.offset_left = -330
	p.offset_right = -16
	p.offset_top = 92
	add_child(p)
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 8)
	p.add_child(_roster)
	_roster.add_child(_label("AGENTS", 13, MUTED))


func _make_card(a):
	var card = _panel(Color(0.1, 0.13, 0.2, 0.9))
	card.custom_minimum_size = Vector2(290, 0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	card.add_child(v)
	var head = HBoxContainer.new()
	var swatch = ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.size_flags_vertical = SIZE_SHRINK_CENTER
	swatch.color = _role_color(a.get("role", ""))
	head.add_child(swatch)
	var name_l = _label("  " + a.get("name", a["id"]), 16)
	name_l.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(name_l)
	var state = _label("", 13)
	head.add_child(state)
	v.add_child(head)
	var task = _label("—", 13, TEXT.darkened(0.1))
	task.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	task.custom_minimum_size = Vector2(260, 0)
	v.add_child(task)
	var detail = _label("", 12, MUTED)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.custom_minimum_size = Vector2(260, 0)
	v.add_child(detail)
	var id = a["id"]
	card.gui_input.connect(
		func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				agent_focus_requested.emit(id)
	)
	card.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_roster.add_child(card)
	return {"panel": card, "state": state, "task": task, "detail": detail}


func _build_command_bar():
	var p = _panel()
	p.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	p.offset_left = -380
	p.offset_right = 380
	p.offset_top = -72
	p.offset_bottom = -16
	add_child(p)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Give your agents a mission…  e.g. Research the Australian EV market"
	_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_input.add_theme_font_size_override("font_size", 16)
	_input.custom_minimum_size = Vector2(0, 36)
	_input.text_submitted.connect(func(_t): _on_deploy())
	row.add_child(_input)
	_deploy = _button("Deploy", true)
	_deploy.pressed.connect(_on_deploy)
	row.add_child(_deploy)
	_abort = _button("Abort")
	_abort.visible = false
	_abort.pressed.connect(func(): mission_cancel_requested.emit())
	row.add_child(_abort)


func _build_log():
	var p = _panel(Color(0.06, 0.08, 0.13, 0.7))
	p.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	p.offset_left = 16
	p.offset_right = 430
	p.offset_top = -392
	p.offset_bottom = -232
	p.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(p)
	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", 2)
	_log_box.alignment = BoxContainer.ALIGNMENT_END
	p.add_child(_log_box)


func _build_approval():
	_approval_panel = _panel(BG_SOLID)
	# Top centre, under the mission bar, so the base (and the Reviewer walking to Human
	# Approval) stays visible.
	_approval_panel.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_approval_panel.offset_left = -270
	_approval_panel.offset_right = 270
	_approval_panel.offset_top = 92
	_approval_panel.offset_bottom = 250
	_approval_panel.visible = false
	(_approval_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(1.0, 0.55, 0.2)
	(_approval_panel.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	add_child(_approval_panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_approval_panel.add_child(v)
	v.add_child(_label("HUMAN APPROVAL REQUIRED", 14, Color(1.0, 0.65, 0.3)))
	_approval_text = _label("", 17)
	_approval_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_approval_text.custom_minimum_size = Vector2(480, 0)
	v.add_child(_approval_text)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	var reject = _button("Reject")
	reject.pressed.connect(func(): _resolve(false))
	var approve = _button("Approve", true)
	approve.pressed.connect(func(): _resolve(true))
	row.add_child(reject)
	row.add_child(approve)
	v.add_child(row)


func _build_result():
	_result_panel = _panel(BG_SOLID)
	_result_panel.set_anchors_and_offsets_preset(PRESET_CENTER)
	_result_panel.offset_left = -360
	_result_panel.offset_right = 360
	_result_panel.offset_top = -250
	_result_panel.offset_bottom = 250
	_result_panel.visible = false
	add_child(_result_panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_result_panel.add_child(v)
	_result_title = _label("", 18, ACCENT)
	v.add_child(_result_title)
	_result_text = RichTextLabel.new()
	_result_text.bbcode_enabled = true
	_result_text.size_flags_vertical = SIZE_EXPAND_FILL
	_result_text.selection_enabled = true
	_result_text.meta_underlined = true
	_result_text.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	_result_text.add_theme_font_size_override("normal_font_size", 15)
	_result_text.add_theme_font_size_override("bold_font_size", 16)
	v.add_child(_result_text)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	var mc = _button("Open in Mission Control")
	mc.pressed.connect(func(): OS.shell_open(_mission_link()))
	mc.visible = false
	_result_panel.set_meta("mc_button", mc)
	var copy = _button("Copy")
	copy.pressed.connect(func(): DisplayServer.clipboard_set(_mission.get("result", "") if _mission else ""))
	var close = _button("Close", true)
	close.pressed.connect(func(): _result_panel.visible = false)
	var replay = _button("▶ Replay")
	replay.pressed.connect(_on_replay_pressed)
	row.add_child(replay)
	row.add_child(mc)
	row.add_child(copy)
	row.add_child(close)
	v.add_child(row)


# ---------- behaviour ----------


func _mission_link():
	if _mission != null and _mission.get("link") != null and _mission.get("link") != "":
		return _mission["link"]
	return _mc_url + "/tasks"


func _on_deploy():
	var title = _input.text.strip_edges()
	if title == "" or _deploy.disabled:
		return
	_input.text = ""
	_input.release_focus()
	_result_panel.visible = false
	mission_requested.emit(title)


func _resolve(approved):
	if _approval_id == "":
		return
	approval_resolved.emit(_approval_id, approved)
	_approval_panel.visible = false


func _refresh_approval():
	var pending = null
	for ap in _approvals.values():
		if ap.get("status") == "pending":
			pending = ap
	if pending == null:
		_approval_panel.visible = false
		_approval_id = ""
		return
	_approval_id = pending["id"]
	var who = pending.get("agentId")
	_approval_text.text = (
		"%s asks: %s" % [who.capitalize() if who != null else "An agent", pending.get("summary", "")]
	)
	_approval_panel.visible = true


func _show_result(m):
	var status = m.get("status", "")
	_result_title.text = {
		"completed": "MISSION COMPLETE", "failed": "MISSION FAILED", "cancelled": "MISSION CANCELLED"
	}.get(status, status.to_upper())
	var body = m.get("result")
	if body == null or body == "":
		body = "No result was produced."
	_result_text.text = _markdown_to_bbcode(body)
	(_result_panel.get_meta("mc_button") as Button).visible = _mc_url != ""
	if replay_active:
		_deferred_result = m
		_replay_report.visible = true
		return
	_result_panel.visible = status != "cancelled"


static func _markdown_to_bbcode(md: String) -> String:
	var out = []
	for raw in md.split("\n"):
		var line = raw.replace("[", "[lb]")
		var stripped = line.strip_edges()
		if stripped.begins_with("#"):
			out.append("[b]%s[/b]" % stripped.lstrip("# "))
			continue
		if stripped.begins_with("- ") or stripped.begins_with("* "):
			line = "  • " + stripped.substr(2)
		var re = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
		line = re.sub(line, "[b]$1[/b]", true)
		# [text](https://...) -> clickable link; ![alt](file) -> its alt text
		var link_re = RegEx.create_from_string("!?\\[lb\\](.+?)\\]\\((https?://[^)\\s]+)\\)")
		line = link_re.sub(line, "[url=$2]$1[/url]", true)
		var img_re = RegEx.create_from_string("!\\[lb\\](.*?)\\]\\([^)]*\\)")
		line = img_re.sub(line, "($1)", true)
		out.append(line)
	return "\n".join(out)


func _role_color(role):
	if ROLE_COLORS.has(role):
		return ROLE_COLORS[role]
	return {
		"researcher": Color(0.35, 0.8, 1.0),
		"coder": Color(1.0, 0.6, 0.25),
		"analyst": Color(0.55, 0.95, 0.5),
		"reviewer": Color(0.85, 0.55, 1.0),
	}.get(role, Color.WHITE)


static func _fmt_int(n: int) -> String:
	var s = str(n)
	var out = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out



# ---------- mission replay ----------


# Timeline strip: elapsed fill, a marker per step (agent colour) and the playhead.
class Timeline:
	extends Control
	var progress = 0.0
	var markers = []  # [{x: 0..1, color}]

	func _draw():
		var r = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(0, size.y * 0.35, size.x, size.y * 0.3), Color(0.16, 0.2, 0.3))
		draw_rect(Rect2(0, size.y * 0.35, size.x * progress, size.y * 0.3), Color(0.4, 0.75, 1.0, 0.85))
		for m in markers:
			var x = clampf(m["x"], 0.0, 1.0) * r.size.x
			draw_rect(Rect2(x - 2, 0, 4, size.y), m["color"])
		var px = progress * r.size.x
		draw_circle(Vector2(px, size.y * 0.5), size.y * 0.42, Color.WHITE)


func _build_replay():
	_replay_panel = _panel(Color(0.05, 0.07, 0.12, 0.92))
	_replay_panel.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_replay_panel.offset_left = -430
	_replay_panel.offset_right = 430
	_replay_panel.offset_top = -196
	_replay_panel.offset_bottom = -84
	(_replay_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = ACCENT
	_replay_panel.visible = false
	add_child(_replay_panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_replay_panel.add_child(v)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_label("▶ REPLAY", 14, ACCENT))
	_replay_title = _label("", 15)
	_replay_title.size_flags_horizontal = SIZE_EXPAND_FILL
	_replay_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_replay_title.custom_minimum_size = Vector2(200, 0)
	head.add_child(_replay_title)
	_replay_time = _label("", 14, MUTED)
	head.add_child(_replay_time)
	_replay_pause = _button("Pause")
	_replay_pause.custom_minimum_size = Vector2(80, 30)
	_replay_pause.pressed.connect(func(): replay_pause_toggled.emit())
	head.add_child(_replay_pause)
	_replay_speed = _button("×1")
	_replay_speed.custom_minimum_size = Vector2(64, 30)
	_replay_speed.pressed.connect(func(): replay_speed_cycled.emit())
	head.add_child(_replay_speed)
	_replay_report = _button("View report", true)
	_replay_report.custom_minimum_size = Vector2(110, 30)
	_replay_report.visible = false
	_replay_report.pressed.connect(_show_deferred_result)
	head.add_child(_replay_report)
	var stop = _button("Close")
	stop.custom_minimum_size = Vector2(72, 30)
	stop.pressed.connect(func(): replay_stop_requested.emit())
	head.add_child(stop)
	_timeline = Timeline.new()
	_timeline.custom_minimum_size = Vector2(0, 18)
	v.add_child(_timeline)
	_replay_caption = _label("", 14, TEXT.darkened(0.05))
	_replay_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_replay_caption.custom_minimum_size = Vector2(800, 0)
	v.add_child(_replay_caption)


func _on_replay_pressed():
	if _mission != null:
		replay_requested.emit(_mission.get("id", ""))


func begin_replay(title: String, duration_ms: float, markers: Array):
	replay_active = true
	if _deferred_result == null and _result_panel.visible and _mission != null:
		_deferred_result = _mission  # bring the report back when the replay ends
	_result_panel.visible = false
	_replay_title.text = title
	_replay_caption.text = "Replaying the mission…"
	_replay_report.visible = _deferred_result != null
	_replay_pause.text = "Pause"
	var ms = []
	for m in markers:
		ms.append({"x": m["t"] / duration_ms, "color": ROLE_COLORS.get(m.get("agent_id", ""), ACCENT)})
	_timeline.markers = ms
	_timeline.progress = 0.0
	_timeline.queue_redraw()
	_replay_panel.visible = true


func update_replay(clock_ms: float, duration_ms: float, speed: float, playing: bool):
	_timeline.progress = clampf(clock_ms / duration_ms, 0.0, 1.0)
	_timeline.queue_redraw()
	_replay_time.text = "%s / %s" % [_fmt_ms(clock_ms), _fmt_ms(duration_ms)]
	_replay_speed.text = "×%d" % int(round(speed)) if speed >= 1.0 else "×%.1f" % speed
	_replay_pause.text = "Pause" if playing else "Play"


func replay_caption(line: Dictionary):
	var who = line.get("agentId")
	_replay_caption.text = ("%s: " % who.capitalize() if who != null else "") + str(line.get("text", ""))
	var color = TEXT
	match line.get("level", "info"):
		"warn":
			color = Color(1.0, 0.8, 0.4)
		"error":
			color = Color(1.0, 0.5, 0.5)
	_replay_caption.add_theme_color_override("font_color", color)


# Called when the replay ends or is closed; shows the report if it was waiting.
func end_replay():
	replay_active = false
	_replay_panel.visible = false
	_show_deferred_result()


# The report a finished mission produced waits behind its replay.
func defer_next_result():
	replay_active = true


func cancel_deferred():
	replay_active = false
	_show_deferred_result()


func _show_deferred_result():
	if _deferred_result == null:
		return
	var m = _deferred_result
	_deferred_result = null
	_replay_report.visible = false
	_result_panel.visible = m.get("status", "") != "cancelled"


static func _fmt_ms(ms: float) -> String:
	var s = int(ms / 1000.0)
	return "%d:%02d" % [s / 60, s % 60]



# ---------- settings ----------


func _build_settings():
	const Settings = preload("res://source/agent/Settings.gd")
	_settings_panel = _panel(BG_SOLID)
	_settings_panel.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_settings_panel.offset_left = -560
	_settings_panel.offset_right = -16
	_settings_panel.offset_top = 92
	_settings_panel.grow_horizontal = GROW_DIRECTION_BEGIN  # widen leftwards, never off-screen
	_settings_panel.visible = false
	add_child(_settings_panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(v)
	var head = HBoxContainer.new()
	var title = _label("SETTINGS", 14, MUTED)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(title)
	var close = _button("Close")
	close.custom_minimum_size = Vector2(72, 30)
	close.pressed.connect(func(): _settings_panel.visible = false)
	head.add_child(close)
	v.add_child(head)
	_chip_row(v, "Display", "fullscreen", [["Window", false], ["Fullscreen", true]])
	var sizes = []
	for sz in Settings.WINDOW_SIZES:
		sizes.append(["%d×%d" % [sz.x, sz.y], sz])
	_chip_row(v, "Window size", "window_size", sizes)
	var scales = []
	for r in Settings.RENDER_SCALES:
		scales.append(["%d%%" % int(round(r * 100.0)), r])
	_chip_row(v, "3D resolution", "render_scale", scales)
	_chip_row(v, "Anti-aliasing", "msaa", [["Off", 0], ["2×", 1], ["4×", 2]])
	_chip_row(v, "Text & panels", "ui_size", [["Small", 0.8], ["Normal", 1.0], ["Large", 1.25], ["X-Large", 1.5]])
	var zoom_row = HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 10)
	var zl = _label("Map zoom", 15)
	zl.custom_minimum_size = Vector2(130, 0)
	zoom_row.add_child(zl)
	_zoom_slider = HSlider.new()
	# Slider reads "closer" to the right: value = ZOOM_MAX + ZOOM_MIN - camera size.
	_zoom_slider.min_value = Settings.ZOOM_MIN
	_zoom_slider.max_value = Settings.ZOOM_MAX
	_zoom_slider.step = 1.0
	_zoom_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_zoom_slider.custom_minimum_size = Vector2(220, 24)
	_zoom_slider.value_changed.connect(
		func(val):
			if not _syncing_zoom:
				setting_changed.emit("zoom", Settings.ZOOM_MAX + Settings.ZOOM_MIN - val)
	)
	zoom_row.add_child(_zoom_slider)
	var fit = _button("Fit map")
	fit.custom_minimum_size = Vector2(84, 30)
	fit.pressed.connect(func(): setting_changed.emit("zoom", Settings.ZOOM_DEFAULT))
	zoom_row.add_child(fit)
	v.add_child(zoom_row)
	v.add_child(_label("Lower 3D resolution runs faster on large screens; text stays sharp.", 12, MUTED))


func _chip_row(parent: Control, title: String, key: String, options: Array):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l = _label(title, 15)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	_chip_groups[key] = []
	for opt in options:
		var b = _button(opt[0])
		b.custom_minimum_size = Vector2(0, 30)
		b.toggle_mode = true
		var value = opt[1]
		b.pressed.connect(func(): setting_changed.emit(key, value))
		row.add_child(b)
		_chip_groups[key].append({"button": b, "value": value})
	parent.add_child(row)


func _toggle_settings():
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible and settings_ref != null and camera_ref != null:
		show_settings(settings_ref, camera_ref.size)


# Highlight the active option of each setting and sync the zoom slider.
func show_settings(settings, camera_size: float):
	const Settings = preload("res://source/agent/Settings.gd")
	var current = {
		"fullscreen": settings.fullscreen,
		"window_size": settings.window_size,
		"render_scale": settings.render_scale,
		"msaa": settings.msaa,
		"ui_size": settings.ui_size,
	}
	for key in _chip_groups:
		for chip in _chip_groups[key]:
			var on = _same(chip["value"], current[key])
			chip["button"].set_pressed_no_signal(on)
			var sb = (chip["button"].get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
			sb.bg_color = Color(0.2, 0.45, 0.85) if on else Color(0.16, 0.2, 0.3)
			chip["button"].add_theme_stylebox_override("normal", sb)
			chip["button"].add_theme_stylebox_override("pressed", sb)
		if key == "window_size":
			for chip in _chip_groups[key]:
				chip["button"].disabled = settings.fullscreen
	_syncing_zoom = true
	_zoom_slider.value = Settings.ZOOM_MAX + Settings.ZOOM_MIN - camera_size
	_syncing_zoom = false


static func _same(a, b) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return absf(float(a) - float(b)) < 0.001
	return a == b
