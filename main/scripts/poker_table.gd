extends Control
class_name OraclePokerTable

signal closed

const CardScript = preload("res://scripts/oracle_card.gd")
const PokerNpcAvatarScript = preload("res://scripts/poker_npc_avatar.gd")
const OracleTableBackdrop = preload("res://assets/art/oracle_table_backdrop_v1.png")

var game
var built: bool = false
var header_stage: Label
var header_pot: Label
var header_cash: Label
var leave_button: Button
var left_box: VBoxContainer
var center_stage: Control
var opponent_slots: Array[Control] = []
var board_slot: Control
var player_slot: Control
var speech_layer: Control
var speech_slots: Array[Control] = []
var right_box: VBoxContainer
var right_scroll: ScrollContainer
var footer_box: HBoxContainer
var rules_overlay: ColorRect
var records_overlay: ColorRect
var records_body: VBoxContainer
var footer_message: String = ""
var animation_busy: bool = false
var animations_enabled: bool = true
var thinking_index: int = -1
var action_overrides: Array[String] = ["", "", "", "", ""]
var speech_bubbles: Array[String] = ["", "", "", "", ""]
var animation_visible_community_count: int = -1
var last_visible_community_count: int = 0
var motion_layer: Control
var presentation_generation: int = 0
var active_presentation_tween: Tween
var animation_speed_scale: float = 1.0
var reduced_motion: bool = false
var dealt_card_counts: Array[int] = [2, 2, 2, 2, 2, 2]


func setup(game_state) -> void:
	game = game_state
	if is_node_ready():
		_ensure_built()
		_refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_built()
	visible = false


func _exit_tree() -> void:
	presentation_generation += 1
	if active_presentation_tween != null and active_presentation_tween.is_valid():
		active_presentation_tween.kill()
	active_presentation_tween = null


func open(message: String = "") -> void:
	_ensure_built()
	footer_message = message
	visible = true
	_refresh()


func request_close() -> void:
	if animation_busy:
		return
	if records_overlay != null and records_overlay.visible:
		_hide_records()
		return
	if rules_overlay != null and rules_overlay.visible:
		_hide_rules()
		return
	if _hand_is_active():
		footer_message = "本手尚未结束。请先退契，或继续完成定命。"
		_refresh()
		return
	visible = false
	closed.emit()


func _ensure_built() -> void:
	if built:
		return
	built = true
	_build_shell()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("0c1c24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	# 给桌面宠物留出安全区，避免右栏文字和按钮被覆盖。
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var header := PanelContainer.new()
	header.custom_minimum_size.y = 58
	header.add_theme_stylebox_override("panel", _panel_style(Color("19333b"), Color("668e93"), 10))
	page.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header.add_child(header_row)
	var title := _label("命运牌会 · 椰影茶摊", 23, Color("f4e3a1"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	header_stage = _label("", 18, Color("d5eeec"))
	header_row.add_child(header_stage)
	header_pot = _label("", 18, Color("f1c87a"))
	header_row.add_child(header_pot)
	header_cash = _label("", 18, Color("9ee1b8"))
	header_row.add_child(header_cash)
	header_row.add_child(_button("牌局记录", _show_records))
	header_row.add_child(_button("规则查询", _show_rules))
	leave_button = _button("返回岛上", _header_leave)
	header_row.add_child(leave_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	page.add_child(content)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 205
	left_panel.add_theme_stylebox_override("panel", _panel_style(Color("142a32"), Color("3f6269"), 9))
	content.add_child(left_panel)
	var left_scroll := ScrollContainer.new()
	left_panel.add_child(left_scroll)
	left_box = VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left_box)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _panel_style(Color("152f32"), Color("8d8060"), 14, 5, 5))
	content.add_child(center_panel)
	var center_stack := Control.new()
	center_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_stack.custom_minimum_size = Vector2(620, 480)
	center_panel.add_child(center_stack)
	var table_art := TextureRect.new()
	table_art.texture = OracleTableBackdrop
	table_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	table_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	table_art.modulate = Color(0.78, 0.85, 0.82, 0.54)
	table_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_stack.add_child(table_art)
	var table_shade := ColorRect.new()
	table_shade.color = Color(0.02, 0.08, 0.09, 0.34)
	table_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_stack.add_child(table_shade)
	center_stage = Control.new()
	center_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_stack.add_child(center_stage)
	_build_fixed_table_stage()

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size.x = 235
	right_panel.add_theme_stylebox_override("panel", _panel_style(Color("142a32"), Color("3f6269"), 9))
	content.add_child(right_panel)
	right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_panel.add_child(right_scroll)
	right_box = VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 8)
	right_scroll.add_child(right_box)

	var footer := PanelContainer.new()
	footer.custom_minimum_size.y = 84
	footer.add_theme_stylebox_override("panel", _panel_style(Color("19333b"), Color("668e93"), 10))
	page.add_child(footer)
	footer_box = HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_box.add_theme_constant_override("separation", 8)
	footer.add_child(footer_box)

	_build_rules_overlay()
	_build_records_overlay()


func _build_rules_overlay() -> void:
	rules_overlay = ColorRect.new()
	rules_overlay.color = Color(0.02, 0.05, 0.07, 0.92)
	rules_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rules_overlay.visible = false
	add_child(rules_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -450
	panel.offset_top = -320
	panel.offset_right = 450
	panel.offset_bottom = 320
	panel.add_theme_stylebox_override("panel", _panel_style(Color("17323a"), Color("d0bf78"), 13))
	rules_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _label("命运牌会规则", 25, Color("f6e5a5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(_button("关闭规则", _hide_rules))
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	body.add_child(_wrapped("牌堆共48张：水牌24张、火牌24张。每类有6个势阶，每种“类别＋势阶”有4张完全相同的牌。水火不是花色，四张同类不会自动成为高命象。", 16, Color("d9eeeb")))
	body.add_child(_section("水火六阶"))
	body.add_child(_wrapped("水：1水滴 · 2雨幕 · 3溪流 · 4湖泊 · 5江河 · 6海洋\n火：1火星 · 2烛火 · 3炉火 · 4篝火 · 5烈焰 · 6天火", 16, Color("c9e5e8")))
	body.add_child(_section("如何形成命象"))
	body.add_child(_wrapped("你必须使用自己的两张隐藏命牌，再从五张公共天象牌中选择两张，组成四张牌的最高命象。天象按初兆2张、交汇2张、定命1张公开。", 16, Color("f2dca0")))
	body.add_child(_section("命象从高到低"))
	for index in range(game.ORACLE_PATTERN_NAMES.size() - 1, -1, -1):
		body.add_child(_wrapped("%d. %s　%s" % [index + 1, game.ORACLE_PATTERN_NAMES[index], game.ORACLE_PATTERN_RULES[index]], 15, Color("f4f1df") if index < 7 else Color("f3ca75")))
	body.add_child(_section("行动与平局"))
	body.add_child(_wrapped("静观：无人增加投入时不花金贝。跟契：补足本轮所需金贝。加契：提高本轮投入。退契：放弃本手和已经投入底池的金贝。全部投入：投入本局剩余额度。同级先比较核心势阶与总势，仍完全相同则平分；水与火本身不打破平局。", 16, Color("d9eeeb")))
	body.add_child(_wrapped("每手司契位、大小盲和首位行动者在玩家与五名岛民的六席中轮换。跟契只补齐该席本轮尚欠金额；加契后，所有尚未补齐者必须依次响应，本轮闭合后才公开下一阶段天象。已退契或已全部投入者不再行动。", 15, Color("f2dca0")))
	body.add_child(_wrapped("你退契后，其余仍在场者会按真实投入继续完成各轮并公开最终命象；已退契者只显示未参与最终比较。全投按投入层形成主池与边池，无人跟注的金额退还。普通局服务费为可争夺底池的2%，封顶1个大盲；教学局免费。", 15, Color("d9eeeb")))
	body.add_child(_section("诈唬原则"))
	body.add_child(_wrapped("公开天象只展示可能性。你可以利用看似支持轮转、既济或升势的天象施压，但规则窗口不会显示对手命牌、精确胜率或最佳行动。", 16, Color("f2dca0")))


func _build_records_overlay() -> void:
	records_overlay = ColorRect.new()
	records_overlay.color = Color(0.02, 0.05, 0.07, 0.92)
	records_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	records_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	records_overlay.visible = false
	add_child(records_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_top = -310
	panel.offset_right = 440
	panel.offset_bottom = 310
	panel.add_theme_stylebox_override("panel", _panel_style(Color("17323a"), Color("79aeb2"), 13))
	records_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := _label("命运牌会 · 牌局记录", 25, Color("f6e5a5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(_button("关闭记录", _hide_records))
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	records_body = VBoxContainer.new()
	records_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records_body.add_theme_constant_override("separation", 8)
	scroll.add_child(records_body)


func _refresh() -> void:
	if game == null or not built:
		return
	_clear(left_box)
	_clear(right_box)
	_clear(footer_box)
	var has_hand: bool = not game.poker.is_empty()
	var active: bool = _hand_is_active() or animation_busy
	header_stage.text = "阶段：%s" % (game.poker_stage_name() if has_hand else "等待入席")
	var session_tier: Dictionary = game.poker_tier_for_buy_in(int(game.poker_session_buy_in))
	header_pot.text = "底池 %d金贝" % int(game.poker.get("pot", 0)) if has_hand else "基础投入 %d / %d金贝" % [int(session_tier["small_blind"]), int(session_tier["big_blind"])]
	var currency_label := "教学额度" if game.poker_session_tutorial and not game.poker_tutorial_settled else "持有"
	header_cash.text = "%s%d金贝 · 本局已投入%d/%d" % [currency_label, game.poker_player_available(), _player_invested(), _player_limit()] if active else "%s %d金贝" % [currency_label, game.poker_player_available() if game.poker_session_active else game.cash]
	leave_button.text = "众人思考中" if animation_busy else ("退契离桌" if active else "返回岛上")
	leave_button.disabled = animation_busy
	_build_left_panel()
	_refresh_table_stage()
	_build_right_panel()
	_build_footer()


func _build_left_panel() -> void:
	left_box.add_child(_section("本桌财富榜"))
	left_box.add_child(_wrapped("相对本次入席时的累计盈亏", 12, Color("91aaad")))
	var entries: Array = game.poker_wealth_leaderboard()
	var max_abs := 1
	for entry in entries:
		max_abs = maxi(max_abs, abs(int(entry["net"])))
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var net := int(entry["net"])
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var heading := HBoxContainer.new()
		var name := "%d  %s" % [index + 1, str(entry["name"])]
		var name_label := _label(name, 13, Color("f4e3a1") if str(entry["id"]) == "player" else Color("d7e5e2"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(name_label)
		var net_color := Color("7ee0a4") if net > 0 else (Color("ee8e86") if net < 0 else Color("a8bcbc"))
		heading.add_child(_label(_signed_amount(net) + "金贝", 13, net_color))
		row.add_child(heading)
		row.add_child(_wealth_bar(net, max_abs))
		row.add_child(_label("现有%d · 入席%d" % [int(entry["current"]), int(entry["start"])], 10, Color("879fa0")))
		left_box.add_child(row)
	if entries.is_empty():
		left_box.add_child(_wrapped("入席后显示本桌财富变化。", 13, Color("91aaad")))


func _wealth_bar(net: int, max_abs: int) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size.y = 12
	var background := ColorRect.new()
	background.color = Color("0b2026")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(background)
	var center := ColorRect.new()
	center.color = Color("70898a")
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 1.0
	center.offset_left = -1.0
	center.offset_right = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(center)
	if net != 0:
		var fill := ColorRect.new()
		fill.color = Color("62c990") if net > 0 else Color("df746d")
		var ratio := clampf(float(abs(net)) / float(max_abs), 0.06, 1.0) * 0.48
		if net > 0:
			fill.anchor_left = 0.5
			fill.anchor_right = 0.5 + ratio
		else:
			fill.anchor_left = 0.5 - ratio
			fill.anchor_right = 0.5
		fill.anchor_bottom = 1.0
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill)
	return bar


func _build_fixed_table_stage() -> void:
	# The table is a fixed stage. Seats and the board keep their geometry while
	# their contents update, so dialogue and settlement text can never reflow it.
	board_slot = _stage_slot(center_stage, Rect2(0.205, 0.355, 0.590, 0.340), "BoardSlot")
	var opponent_rects := [
		Rect2(0.010, 0.010, 0.315, 0.345),
		Rect2(0.342, 0.010, 0.316, 0.345),
		Rect2(0.675, 0.010, 0.315, 0.345),
		Rect2(0.010, 0.360, 0.185, 0.345),
		Rect2(0.805, 0.360, 0.185, 0.345),
	]
	for index in range(opponent_rects.size()):
		opponent_slots.append(_stage_slot(center_stage, opponent_rects[index], "OpponentSlot%d" % index))
	player_slot = _stage_slot(center_stage, Rect2(0.100, 0.715, 0.800, 0.275), "PlayerSlot")

	speech_layer = Control.new()
	speech_layer.name = "SpeechOverlay"
	speech_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speech_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_layer.z_index = 20
	center_stage.add_child(speech_layer)
	var speech_rects := [
		Rect2(0.015, 0.255, 0.300, 0.085),
		Rect2(0.350, 0.255, 0.300, 0.085),
		Rect2(0.685, 0.255, 0.300, 0.085),
		Rect2(0.145, 0.430, 0.260, 0.125),
		Rect2(0.595, 0.430, 0.260, 0.125),
	]
	for index in range(speech_rects.size()):
		var speech_slot := _stage_slot(speech_layer, speech_rects[index], "SpeechSlot%d" % index)
		speech_slot.visible = false
		speech_slots.append(speech_slot)
	motion_layer = Control.new()
	motion_layer.name = "TableMotionLayer"
	motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_layer.clip_contents = true
	motion_layer.z_index = 40
	center_stage.add_child(motion_layer)


func _stage_slot(parent: Control, normalized_rect: Rect2, slot_name: String) -> Control:
	var slot := Control.new()
	slot.name = slot_name
	slot.anchor_left = normalized_rect.position.x
	slot.anchor_top = normalized_rect.position.y
	slot.anchor_right = normalized_rect.end.x
	slot.anchor_bottom = normalized_rect.end.y
	slot.offset_left = 0.0
	slot.offset_top = 0.0
	slot.offset_right = 0.0
	slot.offset_bottom = 0.0
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	return slot


func _replace_stage_slot(slot: Control, content: Control) -> void:
	_clear(slot)
	slot.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _refresh_table_stage() -> void:
	if center_stage == null:
		return
	for index in range(opponent_slots.size()):
		_replace_stage_slot(opponent_slots[index], _opponent_seat(index, true))
	_replace_stage_slot(board_slot, _board_view())
	_replace_stage_slot(player_slot, _player_seat())
	_refresh_speech_overlays()


func _board_view() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0c292db8"), Color("6f8f79"), 11, 5, 4))
	var board := VBoxContainer.new()
	board.alignment = BoxContainer.ALIGNMENT_CENTER
	board.add_theme_constant_override("separation", 2)
	panel.add_child(board)
	var board_title := "五张天象 · 初兆 2 / 交汇 2 / 定命 1"
	if not game.poker.is_empty():
		board_title = "%s · 底池 %d金贝" % [game.poker_stage_name(), int(game.poker["pot"])]
	var board_label := _label(board_title, 15, Color("f5dd96"))
	board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(board_label)
	var public_row := HBoxContainer.new()
	public_row.alignment = BoxContainer.ALIGNMENT_CENTER
	public_row.add_theme_constant_override("separation", 3)
	var visible_cards: Array = _visible_community_for_view()
	var selected_public: Array = []
	if not game.poker.is_empty() and visible_cards.size() >= 2:
		selected_public = game.oracle_best_reading(game.poker["player_hand"], visible_cards)["public_cards"]
	for index in range(5):
		var card_id := int(game.poker["community"][index]) if not game.poker.is_empty() else -1
		var face_up := index < visible_cards.size()
		var card_control := _card(card_id, face_up, face_up and selected_public.has(card_id), true)
		card_control.custom_minimum_size = Vector2(62, 88)
		public_row.add_child(card_control)
		if animations_enabled and face_up and index >= last_visible_community_count:
			_animate_card_reveal.call_deferred(card_control, float(index - last_visible_community_count) * 0.08)
		if index == 1 or index == 3:
			var divider := VSeparator.new()
			divider.custom_minimum_size.x = 3
			public_row.add_child(divider)
	board.add_child(public_row)
	var phase_hint := _label("初兆　　　　　　交汇　　　　　定命", 11, Color("9cb8b7"))
	phase_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.add_child(phase_hint)
	last_visible_community_count = visible_cards.size()
	return panel


func _refresh_speech_overlays() -> void:
	for index in range(speech_slots.size()):
		var slot := speech_slots[index]
		_clear(slot)
		var line := speech_bubbles[index] if index < speech_bubbles.size() else ""
		slot.visible = not line.is_empty()
		if line.is_empty():
			continue
		var bubble := PanelContainer.new()
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_theme_stylebox_override("panel", _panel_style(Color("f2e7c9f2"), Color("d2a85e"), 8, 7, 4))
		var speech := _wrapped("“%s”" % line, 11, Color("3b342a"))
		speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bubble.add_child(speech)
		slot.add_child(bubble)
		bubble.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _opponent_seat(index: int, compact_layout: bool = false) -> Control:
	var data: Dictionary = game.ORACLE_OPPONENTS[index]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(112, 0) if compact_layout else Vector2(186, 188)
	var present := bool(game.poker_npc_present[index]) if index < game.poker_npc_present.size() else true
	var active := present and (bool(game.poker.get("active", [true, true, true, true, true])[index]) if not game.poker.is_empty() else true)
	var border := Color("f2d77f") if thinking_index == index else (Color(str(data["color"])) if active else Color("48575a"))
	panel.add_theme_stylebox_override("panel", _panel_style(Color("102c32e8"), border, 10, 5 if compact_layout else 8, 4 if compact_layout else 7))
	panel.modulate.a = 1.0 if active else 0.55
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_theme_constant_override("separation", 7)
	box.add_child(portrait_row)
	var portrait_size := 60.0 if compact_layout and index == 0 else (46.0 if compact_layout else 72.0)
	var portrait := _npc_portrait(index, portrait_size)
	portrait_row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _label(str(data["name"]), 13 if compact_layout else 16, Color("f4f1dc"))
	info.add_child(name_label)
	if not compact_layout:
		info.add_child(_label(str(data["style"]), 11, Color("9fc3c1")))
	var default_limit := int(game.poker_session_buy_in)
	var default_stacks := [default_limit, default_limit, default_limit, default_limit, default_limit]
	var stack := int(game.poker.get("opponent_stacks", default_stacks)[index]) if not game.poker.is_empty() else default_limit
	var action := str(game.poker.get("opponent_actions", ["等待", "等待", "等待", "等待", "等待"])[index]) if not game.poker.is_empty() else (str(data["style"]) if present else "输光离桌")
	if index < action_overrides.size() and not action_overrides[index].is_empty():
		action = action_overrides[index]
	if index == 0 and portrait.has_method("play_for_action"):
		portrait.play_for_action(
			action,
			thinking_index == index,
			index < speech_bubbles.size() and not speech_bubbles[index].is_empty()
		)
	var hand_limits: Array = game.poker.get("opponent_hand_limits", default_stacks) if not game.poker.is_empty() else [0, 0, 0, 0, 0]
	var hand_limit := int(hand_limits[index])
	var invested := maxi(0, hand_limit - stack)
	var wallet: int = game.poker_npc_available(index)
	var brought: int = int(game.poker_npc_brought[index]) if index < game.poker_npc_brought.size() else wallet
	var wallet_text := "钱包%d\n可投%d · 已投%d" % [wallet, stack, invested] if compact_layout else "钱包 %d/%d\n可投 %d" % [wallet, brought, stack]
	if game.poker.is_empty() or _view_completed():
		wallet_text = "钱包%d/%d" % [wallet, brought] if present else "钱包归零 · 已离桌"
	var wallet_label := _label(wallet_text, 10 if compact_layout else 12, Color("b9d4d0") if present else Color("879898"))
	info.add_child(wallet_label)
	if not game.poker.is_empty():
		var position_marks: Array[String] = []
		var seat_index := index + 1
		if seat_index == int(game.poker.get("dealer_seat", -1)):
			position_marks.append("司契位")
		if seat_index == int(game.poker.get("small_blind_seat", -1)):
			position_marks.append("小盲")
		if seat_index == int(game.poker.get("big_blind_seat", -1)):
			position_marks.append("大盲")
		if seat_index == int(game.poker.get("current_actor", -1)) and not _view_completed():
			position_marks.append("当前行动")
		if not position_marks.is_empty():
			info.add_child(_label(" · ".join(position_marks), 10, Color("f0cf7b")))
	if not compact_layout and not game.poker.is_empty() and not _view_completed():
		info.add_child(_label("本手已投%d金贝" % invested, 11, Color("a9c9c8")))
	portrait_row.add_child(info)
	box.add_child(_action_badge(action))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 4)
	var revealed_hand := _revealed_opponent_hand(index)
	for card_index in range(2):
		if index + 1 < dealt_card_counts.size() and card_index >= int(dealt_card_counts[index + 1]):
			cards.add_child(_empty_card_space(Vector2(46, 66) if compact_layout else Vector2(58, 82)))
		else:
			var card_id := int(revealed_hand[card_index]) if revealed_hand.size() == 2 else -1
			var card_control := _card(card_id, revealed_hand.size() == 2, false, true)
			if compact_layout:
				card_control.custom_minimum_size = Vector2(46, 66)
			cards.add_child(card_control)
	box.add_child(cards)
	return panel


func _revealed_opponent_hand(index: int) -> Array:
	if game.poker.is_empty() or not _view_completed():
		return []
	var showdown: Array = game.poker.get("showdown", [])
	for entry in showdown:
		if int(entry["index"]) == index:
			return entry["hand"]
	return []


func _final_reading_for(id_value: String) -> Dictionary:
	for raw_entry in game.poker.get("final_readings", []):
		if raw_entry is Dictionary and str(raw_entry.get("id", "")) == id_value:
			return raw_entry
	return {}


func _player_seat() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 116
	panel.add_theme_stylebox_override("panel", _panel_style(Color("173b42"), Color("d0bf78"), 9))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 120
	identity.add_child(_label("你的命牌", 17, Color("f3dc92")))
	var stack := int(game.poker.get("player_stack", 0)) if not game.poker.is_empty() else 0
	identity.add_child(_label("本局上限 %d金贝" % _player_limit(), 14, Color("bcd3d2")))
	identity.add_child(_label("已投入%d · 还能投入%d" % [_player_invested(), stack], 13, Color("9fbdbc")))
	if not game.poker.is_empty():
		var player_marks: Array[String] = []
		if int(game.poker.get("dealer_seat", -1)) == 0:
			player_marks.append("司契位")
		if int(game.poker.get("small_blind_seat", -1)) == 0:
			player_marks.append("小盲")
		if int(game.poker.get("big_blind_seat", -1)) == 0:
			player_marks.append("大盲")
		if int(game.poker.get("current_actor", -1)) == 0 and not _view_completed():
			player_marks.append("轮到你")
		if not player_marks.is_empty():
			identity.add_child(_label(" · ".join(player_marks), 11, Color("f0cf7b")))
	var player_action := str(game.poker.get("player_action", "等待行动")) if not game.poker.is_empty() else "等待入席"
	identity.add_child(_action_badge(player_action))
	row.add_child(identity)
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 8)
	if game.poker.is_empty():
		hand_row.add_child(_card(-1, false))
		hand_row.add_child(_card(-1, false))
	else:
		for card_index in range(2):
			if card_index >= int(dealt_card_counts[0]):
				hand_row.add_child(_empty_card_space(Vector2(82, 116)))
			else:
				hand_row.add_child(_card(int(game.poker["player_hand"][card_index]), true, true))
	row.add_child(hand_row)
	var reading_box := VBoxContainer.new()
	reading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var visible_cards: Array = _visible_community_for_view()
	if not game.poker.is_empty() and _view_completed():
		var final_entry := _final_reading_for("player")
		var final_name := str(final_entry.get("reading_name", ""))
		if not final_name.is_empty():
			var prefix := "★ 赢家 · " if bool(final_entry.get("winner", false)) else "最终命象："
			reading_box.add_child(_label(prefix + final_name, 20, Color("f2ca76")))
			reading_box.add_child(_wrapped(str(final_entry.get("reading_text", "")), 14, Color("d3e4e1")))
		else:
			reading_box.add_child(_label(str(final_entry.get("status", "本手已结束")), 18, Color("b9cecc")))
	elif visible_cards.size() < 2:
		reading_box.add_child(_label("等待初兆", 20, Color("b9cecc")))
		reading_box.add_child(_wrapped("两张天象公开后，系统会标出你当前最高命象。", 14, Color("91abad")))
	else:
		var reading: Dictionary = game.oracle_best_reading(game.poker["player_hand"], visible_cards)
		reading_box.add_child(_label("当前命象：%s" % reading["name"], 20, Color("f2ca76")))
		reading_box.add_child(_wrapped(str(reading["text"]), 14, Color("d3e4e1")))
		reading_box.add_child(_wrapped("采用天象：%s" % game.cards_text(reading["public_cards"]), 13, Color("9fc3c2")))
	row.add_child(reading_box)
	return panel


func _build_right_panel() -> void:
	var completed: bool = _view_completed()
	if completed:
		right_box.add_child(_section("各席最终命象"))
		for raw_entry in game.poker.get("final_readings", []):
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry
			var reading_name := str(entry.get("reading_name", ""))
			var detail := reading_name if not reading_name.is_empty() else str(entry.get("status", "未解契"))
			var marker := "★ " if bool(entry.get("winner", false)) else "· "
			var color := Color("f2ca76") if bool(entry.get("winner", false)) else (Color("d8e7e4") if not reading_name.is_empty() else Color("8fa5a6"))
			right_box.add_child(_wrapped("%s%s：%s" % [marker, str(entry.get("name", "席位")), detail], 14, color))
	else:
		right_box.add_child(_section("你的命象"))
		if game.poker.is_empty() or _visible_community_for_view().size() < 2:
			right_box.add_child(_wrapped("初兆公开后显示当前最高命象。", 14, Color("93abad")))
		else:
			var reading: Dictionary = game.oracle_best_reading(game.poker["player_hand"], _visible_community_for_view())
			right_box.add_child(_label(str(reading["name"]), 23, Color("f2ca76")))
			right_box.add_child(_wrapped(str(reading["text"]), 14, Color("d8e7e4")))
	right_box.add_child(HSeparator.new())
	right_box.add_child(_section("命象阶梯"))
	for index in range(game.ORACLE_PATTERN_NAMES.size() - 1, -1, -1):
		var color := Color("f0cb78") if index >= 6 else Color("b5cdca")
		right_box.add_child(_label("%d  %s" % [index + 1, game.ORACLE_PATTERN_NAMES[index]], 14, color))
	right_box.add_child(_button("查看完整规则与示例", _show_rules))


func _build_footer() -> void:
	var completed: bool = _view_completed()
	if animation_busy:
		var thinker_name := str(game.ORACLE_OPPONENTS[thinking_index]["name"]) if thinking_index >= 0 else "牌桌众人"
		var thinking := _wrapped("◆ %s正在观察天象……每位岛民会依次作出判断。" % thinker_name, 16, Color("f3dd9a"))
		thinking.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		thinking.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer_box.add_child(thinking)
		return
	if not footer_message.is_empty() and not completed:
		var message := _wrapped(footer_message, 14, Color("f3dd9a"))
		message.custom_minimum_size.x = 260
		footer_box.add_child(message)
	if game.poker.is_empty() or completed:
		if completed:
			var settlement: Dictionary = game.poker.get("settlement", {})
			var names: Array = game.poker.get("winner_names", [])
			var winners := "、".join(names) if not names.is_empty() else "未决"
			var current_amount: int = int(game.cash if game.poker_session_tutorial and game.poker_tutorial_settled else game.poker_player_available())
			var summary_text := "%s ｜ 赢家：%s ｜ 本手%s金贝 ｜ 服务费%d ｜ 当前%d金贝" % [
				str(settlement.get("outcome_label", "已结束")), winners,
				_signed_amount(int(settlement.get("net_bank", settlement.get("net_cash", 0)))), int(settlement.get("service_fee", 0)), current_amount
			]
			var result := _wrapped(summary_text, 15, Color("f0cf7e"))
			result.custom_minimum_size.x = 420
			result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			footer_box.add_child(result)
		var session_ended := completed and bool(game.poker.get("session_ended", false))
		if session_ended:
			var end_reason := _wrapped(str(game.poker.get("session_end_reason", "本次牌会结束。")), 14, Color("eea08d"))
			end_reason.custom_minimum_size.x = 270
			footer_box.add_child(end_reason)
		else:
			var tier: Dictionary = game.poker_tier_for_buy_in(int(game.poker_session_buy_in))
			var buy_in := int(tier["buy_in"])
			footer_box.add_child(_button("开始下一手 · %s · 上限%d金贝" % [str(tier["name"]), buy_in], _start_hand, not game.can_enter_poker_tier(buy_in)))
		footer_box.add_child(_button("返回岛上", _header_leave))
		return

	var to_call := int(game.poker.get("to_call", 0))
	var remaining := int(game.poker.get("player_stack", 0))
	var min_raise := int(game.poker.get("min_raise", 2))
	var can_raise := remaining >= to_call + min_raise
	var min_extra := min_raise
	var pot_after_call := int(game.poker.get("pot", 0)) + to_call
	var half_extra := maxi(min_raise, int(round(float(pot_after_call) * 0.5)))
	var full_extra := maxi(min_raise, pot_after_call)
	var min_total := mini(remaining, to_call + min_extra)
	var half_total := mini(remaining, to_call + half_extra)
	var full_total := mini(remaining, to_call + full_extra)
	footer_box.add_child(_button("退契", _act.bind("fold")))
	footer_box.add_child(_button("跟契%d金贝" % to_call if to_call > 0 else "静观", _act.bind("call")))
	footer_box.add_child(_button("加到%d金贝" % min_total, _act.bind("raise", min_extra), not can_raise))
	footer_box.add_child(_button("半池 · 投入%d金贝" % half_total, _act.bind("raise", half_extra), not can_raise))
	footer_box.add_child(_button("满池 · 投入%d金贝" % full_total, _act.bind("raise", full_extra), not can_raise))
	footer_box.add_child(_button("全部投入", _act.bind("all_in")))


func _start_hand() -> void:
	if animation_busy:
		return
	var result: Dictionary = game.start_poker_hand()
	footer_message = str(result["text"])
	last_visible_community_count = 0
	_reset_animation_state()
	if not animations_enabled or not bool(result.get("ok", false)) or not is_inside_tree():
		_refresh()
		return
	var generation := _begin_presentation()
	var final_actions: Array = game.poker.get("opponent_actions", ["等待", "等待", "等待", "等待", "等待"]).duplicate()
	var action_sequence: Array = result.get("npc_action_sequence", [])
	animation_busy = true
	animation_visible_community_count = 0
	dealt_card_counts.fill(0)
	for index in range(5):
		action_overrides[index] = "整理命牌"
	_refresh()
	var small_blind_seat := int(game.poker.get("small_blind_seat", -1))
	var big_blind_seat := int(game.poker.get("big_blind_seat", -1))
	if small_blind_seat >= 0:
		await _animate_shell_transfer(generation, small_blind_seat, int(game.poker.get("small_blind", 1)), true)
	if not _presentation_alive(generation):
		return
	if big_blind_seat >= 0:
		await _animate_shell_transfer(generation, big_blind_seat, int(game.poker.get("big_blind", 2)), true)
	if not _presentation_alive(generation):
		return
	await _animate_initial_deal(generation)
	if not _presentation_alive(generation):
		return
	dealt_card_counts.fill(2)
	_refresh()
	for raw_event in action_sequence:
		var event: Dictionary = raw_event
		var index := int(event.get("npc_index", -1))
		if index < 0 or index >= 5:
			continue
		await _animate_community_to(generation, _community_count_for_stage(str(event.get("stage", "藏命"))))
		if not _presentation_alive(generation):
			return
		thinking_index = index
		action_overrides[index] = "入席中……"
		speech_bubbles[index] = ""
		_refresh()
		await get_tree().create_timer(_animation_duration(0.30 + float(index % 2) * 0.08)).timeout
		if not _presentation_alive(generation):
			return
		thinking_index = -1
		var action_text := str(event.get("action_text", final_actions[index]))
		action_overrides[index] = action_text
		speech_bubbles[index] = _npc_line(index, action_text, false)
		_refresh()
		await _animate_action_effect(generation, index + 1, event)
		if not _presentation_alive(generation):
			return
		await get_tree().create_timer(_animation_duration(0.16)).timeout
		if not _presentation_alive(generation):
			return
	await _animate_community_to(generation, game.poker_visible_community().size())
	if not _presentation_alive(generation):
		return
	if bool(game.poker.get("completed", false)):
		await _animate_settlement(generation)
		if not _presentation_alive(generation):
			return
	animation_busy = false
	animation_visible_community_count = -1
	_reset_animation_state()
	_refresh()


func _act(action: String, raise_amount: int = 0) -> void:
	if animation_busy:
		return
	var visible_before := _visible_community_for_view().size()
	var player_invested_before := _player_invested()
	var previous_actions: Array = game.poker.get("opponent_actions", ["等待", "等待", "等待", "等待", "等待"]).duplicate()
	var result: Dictionary = game.poker_action(action, raise_amount)
	footer_message = "" if bool(result.get("completed", false)) else str(result["text"])
	if not animations_enabled or not bool(result.get("ok", true)) or not is_inside_tree():
		_refresh()
		return
	var generation := _begin_presentation()
	var player_paid := maxi(0, _player_invested() - player_invested_before)
	var final_actions: Array = game.poker.get("opponent_actions", previous_actions).duplicate()
	var action_sequence: Array = result.get("npc_action_sequence", [])
	animation_busy = true
	animation_visible_community_count = visible_before
	for index in range(5):
		action_overrides[index] = str(previous_actions[index]) if index < previous_actions.size() else "等待"
		speech_bubbles[index] = ""
	_refresh()
	if player_paid > 0:
		await _animate_shell_transfer(generation, 0, player_paid, true)
	elif action == "fold":
		await _animate_fold_cards(generation, 0)
	else:
		await _animate_seat_pulse(generation, 0, Color("7fc7bd"))
	if not _presentation_alive(generation):
		return
	for raw_event in action_sequence:
		var event: Dictionary = raw_event
		var index := int(event.get("npc_index", -1))
		if index < 0 or index >= 5:
			continue
		await _animate_community_to(generation, _community_count_for_stage(str(event.get("stage", "藏命"))))
		if not _presentation_alive(generation):
			return
		thinking_index = index
		action_overrides[index] = "思考中……"
		speech_bubbles[index] = ""
		_refresh()
		var action_text := str(event.get("action_text", final_actions[index]))
		await get_tree().create_timer(_animation_duration(_npc_think_delay(index, action_text))).timeout
		if not _presentation_alive(generation):
			return
		thinking_index = -1
		var display_action := "回应加契 · %s" % action_text if int(event.get("action_number", 1)) > 1 else action_text
		action_overrides[index] = display_action
		speech_bubbles[index] = _npc_line(index, display_action, false)
		_refresh()
		await _animate_action_effect(generation, index + 1, event)
		if not _presentation_alive(generation):
			return
		await get_tree().create_timer(_animation_duration(0.16)).timeout
		if not _presentation_alive(generation):
			return
	await _animate_community_to(generation, game.poker_visible_community().size())
	if not _presentation_alive(generation):
		return
	if bool(result.get("completed", false)) or bool(game.poker.get("completed", false)):
		await _animate_settlement(generation)
		if not _presentation_alive(generation):
			return
	animation_busy = false
	animation_visible_community_count = -1
	_reset_animation_state()
	_refresh()


func _begin_presentation() -> int:
	presentation_generation += 1
	if active_presentation_tween != null and active_presentation_tween.is_valid():
		active_presentation_tween.kill()
	active_presentation_tween = null
	if motion_layer != null and is_instance_valid(motion_layer):
		_clear(motion_layer)
	return presentation_generation


func _presentation_alive(generation: int) -> bool:
	return generation == presentation_generation and is_inside_tree() and visible


func _animation_duration(base_duration: float) -> float:
	return base_duration / maxf(0.1, animation_speed_scale)


func _animate_initial_deal(generation: int) -> void:
	if motion_layer == null or game.poker.is_empty():
		return
	var dealer := int(game.poker.get("dealer_seat", 0))
	var order: Array[int] = []
	for offset in range(1, 7):
		order.append(posmod(dealer + offset, 6))
	var proxies: Array[Control] = []
	var duration := _animation_duration(0.24 if not reduced_motion else 0.13)
	var stagger := _animation_duration(0.055 if not reduced_motion else 0.025)
	active_presentation_tween = create_tween().bind_node(self).set_parallel(true)
	var sequence_index := 0
	for round_index in range(2):
		for seat_index in order:
			var card_id := int(game.poker["player_hand"][round_index]) if seat_index == 0 else int(game.poker["opponent_hands"][seat_index - 1][round_index])
			var proxy := _motion_card(card_id, seat_index == 0, _deck_anchor(), Vector2(48, 68))
			proxy.rotation = deg_to_rad(-7.0)
			proxies.append(proxy)
			var delay := float(sequence_index) * stagger
			active_presentation_tween.tween_method(
				_set_motion_arc.bind(proxy, _deck_anchor(), _seat_card_anchor(seat_index, round_index), -34.0 if seat_index <= 2 else 34.0),
				0.0, 1.0, duration
			).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			active_presentation_tween.tween_property(proxy, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
			sequence_index += 1
	await active_presentation_tween.finished
	if not _presentation_alive(generation):
		return
	dealt_card_counts.fill(2)
	_refresh()
	for proxy in proxies:
		if is_instance_valid(proxy):
			proxy.queue_free()


func _animate_community_to(generation: int, requested_count: int) -> void:
	if game.poker.is_empty():
		return
	var available: int = int(game.poker_visible_community().size())
	var target_count := mini(requested_count, available)
	var current_count := maxi(0, animation_visible_community_count)
	while current_count < target_count:
		await _animate_community_card(generation, current_count)
		if not _presentation_alive(generation):
			return
		current_count += 1
		animation_visible_community_count = current_count
		last_visible_community_count = current_count
		_refresh()


func _animate_community_card(generation: int, card_index: int) -> void:
	if motion_layer == null or card_index < 0 or card_index >= 5:
		return
	var card_id := int(game.poker["community"][card_index])
	var proxy := _motion_card(card_id, false, _deck_anchor(), Vector2(62, 88))
	proxy.rotation = deg_to_rad(-6.0 + float(card_index) * 2.0)
	var travel_duration := _animation_duration(0.20 if not reduced_motion else 0.11)
	active_presentation_tween = create_tween().bind_node(self)
	active_presentation_tween.tween_method(
		_set_motion_arc.bind(proxy, _deck_anchor(), _board_card_anchor(card_index), -30.0),
		0.0, 1.0, travel_duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await active_presentation_tween.finished
	if not _presentation_alive(generation):
		return
	if reduced_motion:
		proxy.setup(game, card_id, true, false, true)
		proxy.queue_redraw()
	else:
		active_presentation_tween = create_tween().bind_node(self)
		active_presentation_tween.tween_property(proxy, "scale", Vector2(0.06, 1.0), _animation_duration(0.08)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await active_presentation_tween.finished
		if not _presentation_alive(generation):
			return
		proxy.setup(game, card_id, true, false, true)
		proxy.queue_redraw()
		active_presentation_tween = create_tween().bind_node(self)
		active_presentation_tween.tween_property(proxy, "scale", Vector2.ONE, _animation_duration(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await active_presentation_tween.finished
		if not _presentation_alive(generation):
			return
	await _animate_omen_echo(generation, card_id, _board_card_anchor(card_index))
	if is_instance_valid(proxy):
		proxy.queue_free()


func _animate_omen_echo(generation: int, card_id: int, center_value: Vector2) -> void:
	if motion_layer == null:
		return
	var is_water: bool = int(game.oracle_card_element(card_id)) == 0
	var echo := _label("○" if is_water else "△", 38, Color("72c6d3") if is_water else Color("e58955"))
	echo.name = "WaterOmenEcho" if is_water else "FireOmenEcho"
	echo.size = Vector2(58, 58)
	echo.position = center_value - echo.size * 0.5
	echo.pivot_offset = echo.size * 0.5
	echo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	echo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	echo.scale = Vector2(0.45, 0.45)
	echo.modulate.a = 0.76
	motion_layer.add_child(echo)
	active_presentation_tween = create_tween().bind_node(self).set_parallel(true)
	active_presentation_tween.tween_property(echo, "scale", Vector2(1.45, 1.45), _animation_duration(0.24)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_presentation_tween.tween_property(echo, "modulate:a", 0.0, _animation_duration(0.24))
	await active_presentation_tween.finished
	if not _presentation_alive(generation):
		return
	if is_instance_valid(echo):
		echo.queue_free()


func _animate_action_effect(generation: int, seat_index: int, event: Dictionary) -> void:
	var paid := int(event.get("paid", 0))
	var action := str(event.get("action", ""))
	if paid > 0:
		await _animate_shell_transfer(generation, seat_index, paid, true)
	elif action == "fold" or str(event.get("action_text", "")).contains("退契"):
		await _animate_fold_cards(generation, seat_index)
	else:
		await _animate_seat_pulse(generation, seat_index, Color("78bdb3"))


func _animate_shell_transfer(generation: int, seat_index: int, amount: int, into_pot: bool) -> void:
	if motion_layer == null or amount <= 0:
		return
	if reduced_motion:
		await _animate_seat_pulse(generation, seat_index, Color("e3c66e"))
		return
	var start := _seat_anchor(seat_index) if into_pot else _pot_anchor()
	var finish := _pot_anchor() if into_pot else _seat_anchor(seat_index)
	var token_count := _shell_proxy_count(amount)
	var tokens: Array[Control] = []
	var duration := _animation_duration(0.28)
	var stagger := _animation_duration(0.035)
	active_presentation_tween = create_tween().bind_node(self).set_parallel(true)
	for index in range(token_count):
		var token := _shell_token(amount, index)
		token.position = start - token.size * 0.5 + Vector2(float(index % 3 - 1) * 5.0, float(index / 3) * 4.0)
		tokens.append(token)
		var delay := float(index) * stagger
		var arc := (-30.0 - float(index) * 3.0) if into_pot else (28.0 + float(index) * 3.0)
		active_presentation_tween.tween_method(
			_set_motion_arc.bind(token, start, finish, arc),
			0.0, 1.0, duration
		).set_delay(delay).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		active_presentation_tween.tween_property(token, "modulate:a", 0.0, duration * 0.28).set_delay(delay + duration * 0.72)
	await active_presentation_tween.finished
	if not _presentation_alive(generation):
		return
	for token in tokens:
		if is_instance_valid(token):
			token.queue_free()
	await _animate_seat_pulse(generation, seat_index if not into_pot else -1, Color("e3c66e"))


func _animate_fold_cards(generation: int, seat_index: int) -> void:
	if motion_layer == null:
		return
	var proxies: Array[Control] = []
	var duration := _animation_duration(0.26 if not reduced_motion else 0.13)
	active_presentation_tween = create_tween().bind_node(self).set_parallel(true)
	for card_index in range(2):
		var start := _seat_card_anchor(seat_index, card_index)
		var proxy := _motion_card(-1, false, start, Vector2(46, 66))
		proxies.append(proxy)
		active_presentation_tween.tween_method(
			_set_motion_arc.bind(proxy, start, _discard_anchor(), 26.0 + float(card_index) * 8.0),
			0.0, 1.0, duration
		).set_delay(float(card_index) * _animation_duration(0.035)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		active_presentation_tween.tween_property(proxy, "scale", Vector2(0.52, 0.52), duration)
		active_presentation_tween.tween_property(proxy, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	await active_presentation_tween.finished
	if not _presentation_alive(generation):
		return
	for proxy in proxies:
		if is_instance_valid(proxy):
			proxy.queue_free()


func _animate_seat_pulse(generation: int, seat_index: int, color_value: Color) -> void:
	if motion_layer == null:
		return
	var center_value := _pot_anchor() if seat_index < 0 else _seat_anchor(seat_index)
	var pulse := Label.new()
	pulse.text = "◇"
	pulse.add_theme_font_size_override("font_size", 34)
	pulse.add_theme_color_override("font_color", color_value)
	pulse.size = Vector2(54, 54)
	pulse.position = center_value - pulse.size * 0.5
	pulse.pivot_offset = pulse.size * 0.5
	pulse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pulse.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pulse.scale = Vector2(0.45, 0.45)
	pulse.modulate.a = 0.75
	motion_layer.add_child(pulse)
	active_presentation_tween = create_tween().bind_node(self).set_parallel(true)
	active_presentation_tween.tween_property(pulse, "scale", Vector2(1.30, 1.30), _animation_duration(0.20)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_presentation_tween.tween_property(pulse, "modulate:a", 0.0, _animation_duration(0.20))
	await active_presentation_tween.finished
	if not _presentation_alive(generation):
		return
	if is_instance_valid(pulse):
		pulse.queue_free()


func _animate_settlement(generation: int) -> void:
	await _animate_showdown(generation)
	if not _presentation_alive(generation):
		return
	var settlement: Dictionary = game.poker.get("settlement", {})
	var payouts: Array = settlement.get("payouts", [])
	var refunds: Array = settlement.get("refunds", [])
	for seat_index in range(6):
		var payout := int(payouts[seat_index]) if seat_index < payouts.size() else 0
		var refund := int(refunds[seat_index]) if seat_index < refunds.size() else 0
		if payout + refund <= 0:
			continue
		await _animate_shell_transfer(generation, seat_index, payout + refund, false)
		if not _presentation_alive(generation):
			return
	await get_tree().create_timer(_animation_duration(0.16)).timeout


func _animate_showdown(generation: int) -> void:
	var showdown: Array = game.poker.get("showdown", [])
	if showdown.is_empty() or motion_layer == null:
		return
	var presentation_nodes: Array[Control] = []
	for raw_entry in showdown:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var seat_index := int(entry.get("index", -1)) + 1
		var hand: Array = entry.get("hand", [])
		if seat_index <= 0 or hand.size() != 2:
			continue
		for card_index in range(2):
			var proxy := _motion_card(int(hand[card_index]), true, _seat_card_anchor(seat_index, card_index), Vector2(46, 66))
			proxy.scale = Vector2(0.06, 1.0)
			proxy.modulate.a = 0.35
			presentation_nodes.append(proxy)
			active_presentation_tween = create_tween().bind_node(self).set_parallel(true)
			active_presentation_tween.tween_property(proxy, "scale", Vector2.ONE, _animation_duration(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			active_presentation_tween.tween_property(proxy, "modulate:a", 1.0, _animation_duration(0.12))
			await active_presentation_tween.finished
			if not _presentation_alive(generation):
				return
		var reading: Dictionary = entry.get("reading", {})
		var reading_badge := _label(str(reading.get("name", "命象已定")), 13, Color("f2cf78"))
		reading_badge.size = Vector2(116, 28)
		reading_badge.position = _seat_anchor(seat_index) + Vector2(-58.0, 24.0)
		reading_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reading_badge.modulate.a = 0.0
		motion_layer.add_child(reading_badge)
		presentation_nodes.append(reading_badge)
		active_presentation_tween = create_tween().bind_node(self)
		active_presentation_tween.tween_property(reading_badge, "modulate:a", 1.0, _animation_duration(0.14))
		await active_presentation_tween.finished
		if not _presentation_alive(generation):
			return
		await get_tree().create_timer(_animation_duration(0.08)).timeout
	for node in presentation_nodes:
		if is_instance_valid(node):
			node.queue_free()


func _motion_card(card_id: int, face_up: bool, center_value: Vector2, card_size: Vector2) -> Control:
	var card := _card(card_id, face_up, false, true)
	card.custom_minimum_size = card_size
	card.size = card_size
	card.position = center_value - card_size * 0.5
	card.pivot_offset = card_size * 0.5
	card.modulate.a = 0.92
	card.z_index = 2
	motion_layer.add_child(card)
	return card


func _shell_token(amount: int, index: int) -> Control:
	var token := PanelContainer.new()
	token.name = "ShellToken%d" % index
	token.size = Vector2(24, 24)
	token.custom_minimum_size = token.size
	token.pivot_offset = token.size * 0.5
	token.add_theme_stylebox_override("panel", _panel_style(Color("7a6230"), Color("f0d27b"), 12, 2, 1))
	var glyph := _label("◇", 15, Color("fff0ae"))
	glyph.tooltip_text = "%d金贝" % amount
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	token.add_child(glyph)
	motion_layer.add_child(token)
	return token


func _empty_card_space(card_size: Vector2) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = card_size
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _shell_proxy_count(amount: int) -> int:
	if amount <= 2:
		return 1
	if amount <= 10:
		return 3
	if amount <= 50:
		return 5
	return 7


func _community_count_for_stage(stage_name: String) -> int:
	return int({"藏命": 0, "初兆": 2, "交汇": 4, "定命": 5, "解契": 5}.get(stage_name, 0))


func _seat_anchor(seat_index: int) -> Vector2:
	var slot := player_slot if seat_index == 0 else opponent_slots[clampi(seat_index - 1, 0, opponent_slots.size() - 1)]
	return slot.position + slot.size * Vector2(0.5, 0.64)


func _seat_card_anchor(seat_index: int, card_index: int) -> Vector2:
	var slot := player_slot if seat_index == 0 else opponent_slots[clampi(seat_index - 1, 0, opponent_slots.size() - 1)]
	var spacing := 47.0 if seat_index > 0 else 70.0
	return slot.position + slot.size * Vector2(0.5, 0.82) + Vector2((float(card_index) - 0.5) * spacing, 0.0)


func _board_card_anchor(card_index: int) -> Vector2:
	var card_spacing := 66.0
	return board_slot.position + board_slot.size * Vector2(0.5, 0.54) + Vector2((float(card_index) - 2.0) * card_spacing, 0.0)


func _pot_anchor() -> Vector2:
	return board_slot.position + board_slot.size * Vector2(0.5, 0.78)


func _deck_anchor() -> Vector2:
	return board_slot.position + board_slot.size * Vector2(0.91, 0.46)


func _discard_anchor() -> Vector2:
	return board_slot.position + board_slot.size * Vector2(0.08, 0.48)


func _set_motion_arc(progress_value: float, node: Control, start: Vector2, finish: Vector2, arc_height: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var t := clampf(progress_value, 0.0, 1.0)
	var control_point := (start + finish) * 0.5 + Vector2(0.0, arc_height)
	var center_value := start * ((1.0 - t) * (1.0 - t)) + control_point * (2.0 * (1.0 - t) * t) + finish * (t * t)
	node.position = center_value - node.size * 0.5
	node.rotation = deg_to_rad(lerpf(-6.0 if arc_height < 0.0 else 6.0, 0.0, t))


func _opponent_action_order() -> Array[int]:
	var result: Array[int] = []
	for raw_index in game.poker.get("opponent_action_order", [0, 1, 2, 3, 4]):
		result.append(int(raw_index))
	return result


func _eligible_opponent_animation_order(active_before: Array, stacks_before: Array) -> Array[int]:
	var result: Array[int] = []
	for index in _opponent_action_order():
		if index >= active_before.size() or not bool(active_before[index]):
			continue
		if index >= stacks_before.size() or int(stacks_before[index]) <= 0:
			continue
		result.append(index)
	return result


func _header_leave() -> void:
	if animation_busy:
		return
	if _hand_is_active():
		_act("fold")
		return
	request_close()


func _hand_is_active() -> bool:
	return game != null and not game.poker.is_empty() and not bool(game.poker.get("completed", true))


func _view_completed() -> bool:
	return game != null and not game.poker.is_empty() and bool(game.poker.get("completed", false)) and not animation_busy


func _visible_community_for_view() -> Array:
	if game == null or game.poker.is_empty():
		return []
	var visible: Array = game.poker_visible_community()
	if animation_busy and animation_visible_community_count >= 0:
		return visible.slice(0, mini(animation_visible_community_count, visible.size()))
	return visible


func _reset_animation_state() -> void:
	thinking_index = -1
	for index in range(5):
		action_overrides[index] = ""
		speech_bubbles[index] = ""


func _npc_think_delay(index: int, action: String) -> float:
	var delay := 0.55
	if action.contains("加契") or action.contains("立契") or action.contains("投入"):
		delay += 0.25
	elif action.contains("退契"):
		delay += 0.10
	if game != null and index >= 0 and index < game.ORACLE_OPPONENTS.size():
		var opponent: Dictionary = game.ORACLE_OPPONENTS[index]
		var style_delay := float({"礁石型": 0.16, "海雾型": 0.08}.get(str(opponent.get("style", "")), 0.0))
		delay += style_delay
		if str(opponent.get("name", "")) == "旅人洛沙":
			delay += 0.08
	return delay


func _npc_line(index: int, action: String, thinking: bool) -> String:
	var thinking_lines := [
		"潮声急不得，我再看一眼。",
		"这局值不值得抬价呢？",
		"公开天象和他的投入……",
		"先听完风，再决定去留。",
		"雾里露出的，未必是真相。"
	]
	if thinking:
		return thinking_lines[index]
	var fold_lines := ["这兆不稳，我收手。", "这笔买卖不划算。", "证据不够，我退出。", "该放下时就放下。", "雾太浓，不必追。"]
	var raise_lines := ["潮头到了，添一层。", "好风向，我来抬价！", "概率在变，我加契。", "这一兆值得多押。", "让水再深一点。"]
	var call_lines := ["我跟。", "这点金贝，奉陪。", "先跟上观察。", "不抢风头，跟着看。", "我还在雾里。"]
	var wait_lines := ["静观。", "先不抬价。", "继续记录。", "让天象自己说。", "雾还没散。"]
	var win_lines := ["潮水替我作证。", "这桌的金贝归我了。", "结论已经很清楚。", "承让，命象已定。", "雾散之后，答案在我。"]
	var response_lines := ["我回应。", "这口价，我接。", "收到，重新判断。", "既然抬了，我再选一次。", "雾变了，我回应。"]
	if action.contains("回应加契"):
		return response_lines[index]
	if action.contains("赢得") or action.contains("平分"):
		return win_lines[index]
	if action.contains("退契") or action.contains("离桌"):
		return fold_lines[index]
	if action.contains("加契") or action.contains("立契") or action.contains("投入"):
		return raise_lines[index]
	if action.contains("跟契") or action.contains("小盲") or action.contains("大盲"):
		return call_lines[index]
	return wait_lines[index]


func _player_limit() -> int:
	return int(game.poker.get("buy_in", game.poker_session_buy_in)) if game != null and not game.poker.is_empty() else int(game.poker_session_buy_in if game != null else 80)


func _player_invested() -> int:
	if game == null or game.poker.is_empty():
		return 0
	return maxi(0, _player_limit() - int(game.poker.get("player_stack", 0)))


func _show_rules() -> void:
	if records_overlay != null:
		records_overlay.visible = false
	rules_overlay.visible = true


func _hide_rules() -> void:
	rules_overlay.visible = false


func _show_records() -> void:
	if rules_overlay != null:
		rules_overlay.visible = false
	_rebuild_records()
	records_overlay.visible = true


func _hide_records() -> void:
	records_overlay.visible = false


func _rebuild_records() -> void:
	_clear(records_body)
	records_body.add_child(_wrapped("调试记录文件：%s" % game.oracle_record_file_path(), 13, Color("94b7b8")))
	records_body.add_child(_wrapped("每手都有唯一编号；进行中只显示公开信息，结算后才记录全部命牌、真实赢家和资金变化。", 14, Color("d6e7e4")))
	records_body.add_child(HSeparator.new())
	records_body.add_child(_section("当前牌局"))
	if game.poker.is_empty():
		records_body.add_child(_wrapped("还没有开始牌局。下一手会从开局前持有的金贝开始记录。", 15, Color("9fb8b8")))
	else:
		var hand_id := str(game.poker.get("hand_id", "未编号"))
		var before := int(game.poker.get("cash_before", game.cash))
		records_body.add_child(_wrapped("编号 %s\n阶段 %s · 底池%d金贝\n本局上限%d · 已投入%d · 还能投入%d\n开局前持有%d金贝" % [
			hand_id, game.poker_stage_name(), int(game.poker.get("pot", 0)),
			_player_limit(), _player_invested(), int(game.poker.get("player_stack", 0)), before
		], 15, Color("f1dfa1")))
		var visible_cards: Array = game.poker_visible_community()
		records_body.add_child(_wrapped("你的命牌：%s\n已公开天象：%s" % [
			game.cards_text(game.poker.get("player_hand", [])),
			game.cards_text(visible_cards) if not visible_cards.is_empty() else "尚未公开"
		], 14, Color("c7dfdd")))
		if bool(game.poker.get("completed", false)):
			var settlement: Dictionary = game.poker.get("settlement", {})
			records_body.add_child(_settlement_block(settlement))
		else:
			records_body.add_child(_wrapped("牌局进行中：对手命牌不会在这里显示，也不会提前写入记录。", 13, Color("90aaab")))
		records_body.add_child(_section("本手行动时间线"))
		var action_log: Array = game.poker.get("action_log", [])
		for entry in action_log:
			records_body.add_child(_wrapped("· %s" % str(entry), 13, Color("bfd2d0")))

	records_body.add_child(HSeparator.new())
	records_body.add_child(_section("最近完成的牌局"))
	if game.recent_oracle_records.is_empty():
		records_body.add_child(_wrapped("暂无已完成记录。完成下一手后，结算摘要会保留在这里。", 14, Color("90aaab")))
		return
	for raw_record in game.recent_oracle_records:
		if not raw_record is Dictionary:
			continue
		var record: Dictionary = raw_record
		var settlement: Dictionary = record.get("settlement", {})
		var names: Array = record.get("winner_names", [])
		var winners := "、".join(names) if not names.is_empty() else "未决（玩家退契）"
		var player_reading: Dictionary = record.get("player_reading", {})
		var reading_name := str(player_reading.get("name", "未形成命象"))
		var heading := "%s · %s" % [str(record.get("outcome_label", "已结束")), str(record.get("hand_id", "未编号"))]
		records_body.add_child(_label(heading, 17, Color("f0cf7b")))
		records_body.add_child(_wrapped("赢家：%s · 你的命象：%s\n本桌额度 %d → %d · 本手%s金贝 · 底池赢得%d金贝 · 服务费%d" % [
			winners, reading_name,
			int(settlement.get("player_bank_before", settlement.get("cash_before", 0))), int(settlement.get("player_bank_after", settlement.get("cash_after", 0))),
			_signed_amount(int(settlement.get("net_bank", settlement.get("net_cash", 0)))), int(settlement.get("pot_award", 0)), int(settlement.get("service_fee", 0))
		], 14, Color("d7e5e2")))
		var seat_lines: Array[String] = []
		for raw_seat in record.get("final_readings", []):
			if raw_seat is Dictionary:
				var seat_name := str(raw_seat.get("name", "席位"))
				var seat_reading := str(raw_seat.get("reading_name", ""))
				var seat_status := str(raw_seat.get("status", "未解契"))
				seat_lines.append("%s：%s" % [seat_name, seat_reading if not seat_reading.is_empty() else seat_status])
		if not seat_lines.is_empty():
			records_body.add_child(_wrapped("结算命象：%s" % " · ".join(seat_lines), 12, Color("9fb9b9")))
		var past_log: Array = record.get("action_log", [])
		if not past_log.is_empty():
			records_body.add_child(_wrapped("行动：%s" % " / ".join(past_log), 12, Color("8fa9aa")))
		records_body.add_child(HSeparator.new())


func _settlement_block(settlement: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("1d4144"), Color("a9a368"), 8))
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_label("结算：%s" % str(settlement.get("outcome_label", "已结束")), 18, Color("f2cf78")))
	box.add_child(_wrapped("本桌额度 %d → %d · 本手%s金贝\n未投入额度%d · 底池赢得%d · 未跟注返还%d · 服务费%d" % [
		int(settlement.get("player_bank_before", settlement.get("cash_before", 0))), int(settlement.get("player_bank_after", settlement.get("cash_after", 0))),
		_signed_amount(int(settlement.get("net_bank", settlement.get("net_cash", 0)))), int(settlement.get("remaining_stack", 0)),
		int(settlement.get("pot_award", 0)), int(settlement.get("uncalled_return", 0)), int(settlement.get("service_fee", 0))
	], 14, Color("e4eee9")))
	var pot_lines: Array[String] = []
	for raw_pot in settlement.get("side_pots", []):
		if raw_pot is Dictionary:
			var names: Array[String] = []
			for seat_index in raw_pot.get("winner_seats", []):
				names.append("你" if int(seat_index) == 0 else str(game.ORACLE_OPPONENTS[int(seat_index) - 1]["name"]))
			pot_lines.append("%s %d金贝 → %s" % [str(raw_pot.get("name", "底池")), int(raw_pot.get("amount", 0)), "、".join(names)])
	if not pot_lines.is_empty():
		box.add_child(_wrapped("分池：%s" % "；".join(pot_lines), 12, Color("a9c7c4")))
	return panel


func _signed_amount(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _card(card_id: int, face_up: bool, emphasized: bool = false, compact: bool = false) -> Control:
	var card = CardScript.new()
	card.setup(game, card_id, face_up, emphasized, compact)
	return card


func _npc_portrait(index: int, size_value: float) -> Control:
	var animated_portrait = PokerNpcAvatarScript.new()
	animated_portrait.setup(size_value, index)
	return animated_portrait


func _animate_card_reveal(card: Control, delay: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(card) or not card.is_inside_tree():
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.06, 1.0)
	card.rotation = deg_to_rad(-4.0)
	card.modulate.a = 0.35
	var tween := card.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "rotation", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.18)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _wrapped(text_value: String, font_size: int, color: Color) -> Label:
	var label := _label(text_value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _section(text_value: String) -> Label:
	return _label(text_value, 17, Color("f1d68b"))


func _action_badge(action_text: String) -> Control:
	var background := Color("28464b")
	var border := Color("6f8e91")
	var ink := Color("d7e6e3")
	if action_text.contains("赢得") or action_text.contains("平分"):
		background = Color("554824")
		border = Color("e2c565")
		ink = Color("ffe69a")
	elif action_text.contains("立契") or action_text.contains("加契") or action_text.contains("投入"):
		background = Color("563928")
		border = Color("dd9258")
		ink = Color("ffd0a3")
	elif action_text.contains("跟契") or action_text.contains("小盲") or action_text.contains("大盲"):
		background = Color("244553")
		border = Color("6db1c3")
		ink = Color("ccecf2")
	elif action_text.contains("静观"):
		background = Color("214b48")
		border = Color("68aaa1")
		ink = Color("c9eee7")
	elif action_text.contains("退契") or action_text.contains("未胜") or action_text.contains("离桌"):
		background = Color("3c3e42")
		border = Color("7f858a")
		ink = Color("c5cbcd")
	if action_text.contains("输光"):
		background = Color("552f31")
		border = Color("c97070")
		ink = Color("ffc4bf")
	var badge := PanelContainer.new()
	badge.custom_minimum_size.y = 27
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.add_theme_stylebox_override("panel", _panel_style(background, border, 6, 6, 3))
	var text_label := _label("行动 · %s" % action_text, 12, ink)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(text_label)
	if animations_enabled and animation_busy:
		# Refreshes can replace a badge before the deferred callback executes.
		# Pass the stable instance id so the message queue never retains a freed Object.
		_animate_action_badge.call_deferred(badge.get_instance_id())
	return badge


func _animate_action_badge(badge_instance_id: int) -> void:
	var badge := instance_from_id(badge_instance_id) as Control
	if not is_instance_valid(badge) or not badge.is_inside_tree():
		return
	badge.modulate.a = 0.25
	badge.position.x += 6.0
	var tween := badge.create_tween().set_parallel(true)
	tween.tween_property(badge, "modulate:a", 1.0, 0.18)
	tween.tween_property(badge, "position:x", badge.position.x - 6.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _button(text_value: String, action: Callable, disabled_value: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 36
	button.disabled = disabled_value
	button.add_theme_color_override("font_color", Color("f5f4e8"))
	button.add_theme_color_override("font_disabled_color", Color("718489"))
	button.add_theme_stylebox_override("normal", _button_style(Color("294750"), Color("66898e")))
	button.add_theme_stylebox_override("hover", _button_style(Color("3b6067"), Color("d4c378")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1d353d"), Color("ead486")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("23363b"), Color("3d5155")))
	button.pressed.connect(action)
	return button


func _panel_style(background: Color, border: Color, radius: int, horizontal_margin: int = 12, vertical_margin: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
