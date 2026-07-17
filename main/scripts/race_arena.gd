extends Control

signal closed
signal race_requested(beast_index: int, ticket_type: String, stake: int, aid_id: String, event_id: String)
signal history_requested
signal replay_completed(event_id: String)

const RaceReplayScript = preload("res://scripts/race_replay.gd")

var game
var event: Dictionary = {}
var event_id: String = ""
var selected_beast: int = 0
var selected_ticket: String = "独胜"
var selected_aid: String = ""
var mode: String = "pre"
var start_locked: bool = false

var top_status: Label
var schedule_box: VBoxContainer
var public_info: Label
var arena_grid: GridContainer
var beast_buttons: Array[Button] = []
var detail_title: Label
var detail_body: Label
var aid_box: HBoxContainer
var ticket_box: HBoxContainer
var bet_spin: SpinBox
var cost_label: Label
var start_button: Button
var center_host: VBoxContainer
var left_panel: Control
var right_panel: Control
var decision_panel: Control
var replay: Control
var result_label: Label
var history_button: Button
var close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open(game_state) -> void:
	game = game_state
	event = game.current_race_event()
	event_id = str(event.get("event_id", ""))
	selected_beast = 0
	selected_ticket = "独胜"
	selected_aid = ""
	mode = "pre"
	start_locked = false
	_rebuild()
	visible = true


func close() -> void:
	if mode == "race":
		return
	visible = false
	closed.emit()


func _unhandled_key_input(input_event: InputEvent) -> void:
	if visible and input_event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	beast_buttons.clear()
	replay = null


func _rebuild() -> void:
	_clear()
	var backdrop := ColorRect.new()
	backdrop.color = Color("071d25")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := PanelContainer.new()
	top.custom_minimum_size.y = 58
	top.add_theme_stylebox_override("panel", _panel_style(Color("143740"), Color("6c9796"), 12))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)
	var title := _label("逐风赛场", 26, Color("f3d77e"))
	title.custom_minimum_size.x = 190
	top_row.add_child(title)
	top_status = _label("", 17, Color("bfe4dc"))
	top_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_status)
	history_button = _button("赛事历史", _request_history, Vector2(105, 42))
	top_row.add_child(history_button)
	close_button = _button("返回岛上", close, Vector2(105, 42))
	top_row.add_child(close_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)
	left_panel = _side_panel(Vector2(205, 0))
	body.add_child(left_panel)
	var left_box := VBoxContainer.new()
	left_box.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_box)
	left_box.add_child(_label("今日赛程", 19, Color("f1d687")))
	schedule_box = VBoxContainer.new()
	left_box.add_child(schedule_box)
	left_box.add_child(HSeparator.new())
	left_box.add_child(_label("公开消息", 19, Color("f1d687")))
	public_info = _label("", 14, Color("a9c7c4"))
	public_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(public_info)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _panel_style(Color("103940"), Color("d7bd68"), 14))
	body.add_child(center_panel)
	center_host = VBoxContainer.new()
	center_host.add_theme_constant_override("separation", 8)
	center_panel.add_child(center_host)

	right_panel = _side_panel(Vector2(225, 0))
	body.add_child(right_panel)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_box)
	detail_title = _label("选中逐风兽", 20, Color("f1d687"))
	right_box.add_child(detail_title)
	detail_body = _label("", 14, Color("c6dad6"))
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(detail_body)

	decision_panel = PanelContainer.new()
	decision_panel.custom_minimum_size.y = 142
	decision_panel.add_theme_stylebox_override("panel", _panel_style(Color("153841"), Color("6b9798"), 12))
	root.add_child(decision_panel)
	_build_pre_state()


func _build_pre_state() -> void:
	top_status.text = "%s · %s · %s · %s" % [str(event.get("name", "今日赛事")), str(event.get("weather", game.weather)), str(event.get("wind", game.wind_direction)), str(event.get("course_note", "等待鸣钟"))]
	for row in game.race_schedule_rows():
		var color := Color("f2d77e") if bool(row.get("active", false)) else Color("91aaa8")
		schedule_box.add_child(_label("%s  %s" % [str(row.get("name", "赛事")), str(row.get("status", "预告"))], 14, color))
	if event.is_empty():
		center_host.add_child(_center_message("本时段没有开放赛事。你可以查看赛程与历史，或返回岛上等待下一次鸣钟。"))
		public_info.text = "查看赛场不消耗金贝，也不推进潮刻。"
		_build_disabled_decision()
		return
	var public_lines: Array[String] = [str(event.get("course_note", "")), "票池显示岛民选择，不是系统推荐。点击中央赛兽后，右侧会同步它的优势、风险、近况与预计返还。"]
	var named_tickets: Array = event.get("named_tickets", [])
	if not named_tickets.is_empty():
		var ticket_lines: Array[String] = []
		for raw_ticket in named_tickets.slice(0, mini(3, named_tickets.size())):
			var ticket: Dictionary = raw_ticket
			ticket_lines.append("%s：%s%s（%d金贝）" % [str(ticket.get("name", "看台来客")), str(ticket.get("ticket", "独胜")), str(ticket.get("beast_name", "逐风兽")), int(ticket.get("stake", 0))])
		public_lines.append("看台公开票据\n%s" % "\n".join(ticket_lines))
	public_info.text = "\n\n".join(public_lines)
	var arena_title := _label("检录区 · 直接点击八匹逐风兽", 18, Color("f1d687"))
	arena_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_host.add_child(arena_title)
	arena_grid = GridContainer.new()
	arena_grid.columns = 4
	arena_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_grid.add_theme_constant_override("h_separation", 8)
	arena_grid.add_theme_constant_override("v_separation", 8)
	center_host.add_child(arena_grid)
	for index in range(game.RACE_BEASTS.size()):
		var beast: Dictionary = game.RACE_BEASTS[index]
		var roster: Dictionary = event.get("roster", [])[index]
		var button := Button.new()
		button.text = "%d\n%s\n%s\n%s" % [index + 1, str(beast["name"]), str(roster.get("condition", "状态平稳")), _trait_line(beast)]
		button.custom_minimum_size = Vector2(132, 112)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_select_beast.bind(index))
		arena_grid.add_child(button)
		beast_buttons.append(button)
	_build_decision_bar()
	_refresh_selection()


func _build_disabled_decision() -> void:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	decision_panel.add_child(box)
	box.add_child(_label("赛前查看处于暂停状态；离开不会扣款或推进时间。", 17, Color("b7ceca")))


func _build_decision_bar() -> void:
	var decision := VBoxContainer.new()
	decision.add_theme_constant_override("separation", 7)
	decision_panel.add_child(decision)
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	decision.add_child(pick_row)
	ticket_box = HBoxContainer.new()
	for ticket in game.ticket_types():
		ticket_box.add_child(_choice_button(str(ticket), _select_ticket.bind(str(ticket))))
	pick_row.add_child(ticket_box)
	aid_box = HBoxContainer.new()
	aid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aid_box.add_child(_choice_button("公开信息 · 免费", _select_aid.bind("")))
	for aid_id in game.race_aids_available():
		var aid: Dictionary = game.RACE_AIDS[aid_id]
		aid_box.add_child(_choice_button("%s %d" % [str(aid["name"]), int(aid["fee"])], _select_aid.bind(aid_id)))
	pick_row.add_child(aid_box)

	var pay_row := HBoxContainer.new()
	pay_row.add_theme_constant_override("separation", 10)
	decision.add_child(pay_row)
	bet_spin = SpinBox.new()
	bet_spin.min_value = 10
	bet_spin.max_value = maxi(10, game.race_bet_cap())
	bet_spin.step = 10
	bet_spin.value = mini(20, maxi(10, game.race_bet_cap()))
	bet_spin.custom_minimum_size.x = 105
	bet_spin.value_changed.connect(_refresh_cost.unbind(1))
	pay_row.add_child(bet_spin)
	cost_label = _label("", 15, Color("f1d687"))
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay_row.add_child(cost_label)
	start_button = _button("开始赛马", _request_start, Vector2(145, 44))
	pay_row.add_child(start_button)


func _choice_button(text_value: String, action: Callable) -> Button:
	var button := _button(text_value, action, Vector2(0, 34))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	return button


func _select_beast(index: int) -> void:
	selected_beast = clampi(index, 0, game.RACE_BEASTS.size() - 1)
	_refresh_selection()


func _select_ticket(ticket: String) -> void:
	selected_ticket = ticket
	_refresh_selection()


func _select_aid(aid_id: String) -> void:
	selected_aid = aid_id
	_refresh_selection()


func _refresh_selection() -> void:
	if event.is_empty():
		return
	for index in range(beast_buttons.size()):
		beast_buttons[index].modulate = Color("fff1a8") if index == selected_beast else Color.WHITE
	var beast: Dictionary = game.RACE_BEASTS[selected_beast]
	var roster: Dictionary = event["roster"][selected_beast]
	var aid_info: Dictionary = game.race_aid_info(selected_aid, selected_beast, event_id)
	detail_title.text = "%d · %s" % [selected_beast + 1, str(beast["name"])]
	detail_body.text = "%s\n\n优势：%s\n风险：%s\n近况：%s\n\n独胜 %.2f倍\n入席 %.2f倍\n\n研读：%s\n%s" % [
		str(roster.get("condition", "状态平稳")), _strength_text(beast), _risk_text(beast),
		game.race_beast_history_text(str(beast["id"])),
		game.race_event_odds(event, selected_beast, "独胜"), game.race_event_odds(event, selected_beast, "入席"),
		str(aid_info.get("name", "公开信息")), str(aid_info.get("insight", "本场不使用造物。"))
	]
	_refresh_cost()


func _refresh_cost() -> void:
	if cost_label == null or event.is_empty():
		return
	var aid_info: Dictionary = game.race_aid_info(selected_aid, selected_beast, event_id)
	var aid_fee := int(aid_info.get("fee", 0))
	var stake := 10 if game.free_race_ticket > 0 else int(bet_spin.value)
	var odds: float = float(game.race_event_odds(event, selected_beast, selected_ticket))
	var total := aid_fee if game.free_race_ticket > 0 else aid_fee + stake
	cost_label.text = "%s · %s · 票面%d · 研读%d · 总支出%d · 预计返还%d · 固定1潮刻" % [str(game.RACE_BEASTS[selected_beast]["name"]), selected_ticket, stake, aid_fee, total, int(round(stake * odds))]
	start_button.disabled = start_locked or (game.free_race_ticket <= 0 and game.cash < total)
	start_button.text = "金贝不足" if game.free_race_ticket <= 0 and game.cash < total else "开始赛马"


func _request_start() -> void:
	if start_locked or event.is_empty():
		return
	start_locked = true
	start_button.disabled = true
	start_button.text = "正在封盘…"
	race_requested.emit(selected_beast, selected_ticket, int(bet_spin.value), selected_aid, event_id)


func _request_history() -> void:
	if mode == "race":
		return
	history_requested.emit()


func show_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		start_locked = false
		start_button.disabled = false
		start_button.text = "开始赛马"
		cost_label.text = str(result.get("text", "赛事未能开始。"))
		return
	mode = "race"
	history_button.disabled = true
	close_button.disabled = true
	for child in center_host.get_children():
		center_host.remove_child(child)
		child.queue_free()
	left_panel.modulate = Color("ffffff55")
	right_panel.modulate = Color("ffffff55")
	for child in decision_panel.get_children():
		decision_panel.remove_child(child)
		child.queue_free()
	top_status.text = "%s · 正式比赛 · 所选%s" % [str(result.get("event_name", "逐风赛事")), str(game.RACE_BEASTS[selected_beast]["name"])]
	replay = RaceReplayScript.new()
	replay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_host.add_child(replay)
	replay.setup(result, selected_beast)
	replay.replay_finished.connect(_finish_view.bind(result), CONNECT_ONE_SHOT)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	decision_panel.add_child(controls)
	controls.add_child(_button("1倍", _set_replay_speed.bind(result, 1.0, false), Vector2(82, 42)))
	controls.add_child(_button("2倍", _set_replay_speed.bind(result, 2.0, false), Vector2(82, 42)))
	controls.add_child(_button("降低动态", _set_replay_speed.bind(result, 2.0, true), Vector2(110, 42)))
	controls.add_child(_button("重看", replay.replay, Vector2(82, 42)))
	controls.add_child(_button("跳到冲线", replay.skip, Vector2(120, 42)))
	result_label = _label("比赛进行中：演出不会改变已经锁定的排名、派彩或时间。", 16, Color("f1d687"))
	result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(result_label)


func _set_replay_speed(result: Dictionary, speed: float, reduced: bool = false) -> void:
	if replay == null:
		return
	replay.setup(result, selected_beast, speed, reduced)


func _finish_view(result: Dictionary) -> void:
	mode = "finish"
	history_button.disabled = false
	close_button.disabled = false
	replay_completed.emit(str(result.get("event_id", event_id)))
	left_panel.modulate = Color.WHITE
	right_panel.modulate = Color.WHITE
	top_status.text = "%s · 冲线复盘 · %s夺魁" % [str(result.get("event_name", "逐风赛事")), str(result.get("results", [{}])[0].get("name", "逐风兽"))]
	var ranking: Array[String] = []
	for index in range(result.get("results", []).size()):
		ranking.append("%d. %s" % [index + 1, str(result["results"][index]["name"])])
	public_info.text = "完整排名\n%s" % "  ".join(ranking)
	detail_title.text = "判断与结果"
	var selected_stage := "冲刺"
	var worst_rank := 0
	for raw_stage in result.get("stage_reports", []):
		if int(raw_stage.get("selected_rank", 0)) > worst_rank:
			worst_rank = int(raw_stage.get("selected_rank", 0))
			selected_stage = str(raw_stage.get("stage", "冲刺"))
	detail_body.text = "%s最终第%d。\n赛前赔率 %.2f → 封盘 %.2f。\n主要失位段：%s（阶段第%d）。\n\n票面%d · 派彩%d · 本场%+d · 当前%d金贝" % [
		str(game.RACE_BEASTS[selected_beast]["name"]), int(result.get("place", 0)), float(result.get("current_odds", 1.0)), float(result.get("final_odds", 1.0)), selected_stage, worst_rank,
		int(result.get("stake", 0)), int(result.get("payout", 0)), int(result.get("net_cash", 0)), int(result.get("cash_after", game.cash))
	]
	if result_label != null:
		result_label.text = "%s · 当前%d金贝 · 赛果已结算一次" % ["命中祝胜券" if bool(result.get("won", false)) else "未命中祝胜券", int(result.get("cash_after", game.cash))]


func _trait_line(beast: Dictionary) -> String:
	return "速%d 耐%d / 爆%d 稳%d" % [int(beast["speed"]), int(beast["stamina"]), int(beast["burst"]), int(beast["stability"])]


func _strength_text(beast: Dictionary) -> String:
	var stats := [{"name": "速度", "value": int(beast["speed"])}, {"name": "耐力", "value": int(beast["stamina"])}, {"name": "爆发", "value": int(beast["burst"])}, {"name": "稳定", "value": int(beast["stability"])}]
	stats.sort_custom(func(a, b): return int(a["value"]) > int(b["value"]))
	return "%s%d、%s%d" % [str(stats[0]["name"]), int(stats[0]["value"]), str(stats[1]["name"]), int(stats[1]["value"])]


func _risk_text(beast: Dictionary) -> String:
	var stats := [{"name": "速度", "value": int(beast["speed"])}, {"name": "耐力", "value": int(beast["stamina"])}, {"name": "爆发", "value": int(beast["burst"])}, {"name": "稳定", "value": int(beast["stability"])}]
	stats.sort_custom(func(a, b): return int(a["value"]) < int(b["value"]))
	return "%s%d，遇到对应赛段可能失位" % [str(stats[0]["name"]), int(stats[0]["value"])]


func _center_message(text_value: String) -> Label:
	var label := _label(text_value, 20, Color("c5d7d3"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return label


func _side_panel(minimum: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _panel_style(Color("102a32"), Color("52777b"), 12))
	return panel


func _label(text_value: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, action: Callable, minimum: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	return button


func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
