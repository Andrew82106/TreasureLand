extends Control

signal closed
signal checkpoint_requested(reason: String)

const FishCatalog = preload("res://scripts/fish_catalog.gd")
const DiveFieldScript = preload("res://scripts/dive_field.gd")

var game
var mode: String = "prep"
var selected_area: String = "sand_shallows"
var selected_catches := {}
var current_sale_preview := {}
var finishing: bool = false
var pause_reasons := {}
var feedback_text: String = ""

var page_root: Control
var dive_field: DiveField
var oxygen_bar: ProgressBar
var oxygen_label: Label
var basket_label: Label
var dive_status_label: Label
var dive_pause_button: Button


func setup(state) -> void:
	game = state


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(true)


func open(initial_mode: String = "prep") -> void:
	visible = true
	finishing = false
	mode = "dive" if game.dive_active else initial_mode
	if mode not in ["prep", "market", "equipment", "catalog", "dive", "result", "sale_preview"]:
		mode = "prep"
	_rebuild()


func request_close() -> void:
	if finishing:
		return
	if mode == "dive" and game.dive_active:
		_finish_dive(false)
		return
	visible = false
	closed.emit()


func set_activity_pause(reason: String, active: bool) -> void:
	if active:
		pause_reasons[reason] = true
	else:
		pause_reasons.erase(reason)
	if dive_field != null and is_instance_valid(dive_field):
		dive_field.set_gameplay_paused(not pause_reasons.is_empty())
	_update_pause_feedback()


func _process(_delta: float) -> void:
	if not visible or mode != "dive" or not game.dive_active:
		return
	if oxygen_bar != null:
		var oxygen := float(game.dive_state.get("oxygen", 0.0))
		var oxygen_max := maxf(1.0, float(game.dive_state.get("oxygen_max", 50.0)))
		oxygen_bar.value = oxygen / oxygen_max * 100.0
		oxygen_label.text = "氧气 %.1f / %.0f秒" % [oxygen, oxygen_max]
		if oxygen <= oxygen_max * 0.10:
			oxygen_label.add_theme_color_override("font_color", Color("ff8d7d"))
		elif oxygen <= oxygen_max * 0.25:
			oxygen_label.add_theme_color_override("font_color", Color("f3cf74"))
		else:
			oxygen_label.add_theme_color_override("font_color", Color("b8eff0"))
	if basket_label != null:
		var caught: Array = game.dive_state.get("captured_indices", [])
		basket_label.text = "鱼篓 %d / %d" % [caught.size(), int(game.dive_state.get("basket_capacity", 4))]


func handle_interact() -> void:
	if visible and mode == "dive" and dive_field != null:
		dive_field.try_capture_nearest()


func _rebuild() -> void:
	dive_field = null
	oxygen_bar = null
	oxygen_label = null
	basket_label = null
	dive_status_label = null
	dive_pause_button = null
	for child in get_children():
		remove_child(child)
		child.queue_free()
	page_root = ColorRect.new()
	page_root.color = Color("071a24")
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	page_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_build_header())
	match mode:
		"market": column.add_child(_build_market())
		"equipment": column.add_child(_build_equipment())
		"catalog": column.add_child(_build_catalog())
		"dive": column.add_child(_build_dive())
		"result": column.add_child(_build_result())
		"sale_preview": column.add_child(_build_sale_preview())
		_: column.add_child(_build_prep())


func _build_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 62
	panel.add_theme_stylebox_override("panel", _panel_style(Color("123440"), Color("6fa5a8"), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title := _label({
		"prep": "海岸潜捕 · 下水准备", "market": "蓝鳍鱼铺 · 供需柜台",
		"equipment": "潜捕工坊 · 长期装备",
		"catalog": "海生图鉴", "dive": "海岸潜捕 · 水下",
		"result": "海岸潜捕 · 上岸结算", "sale_preview": "蓝鳍鱼铺 · 出售确认"
	}.get(mode, "海岸潜捕"), Color("f0d27e"), 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_button("潜捕准备", _show_mode.bind("prep"), mode == "dive", 112))
	row.add_child(_button("鱼铺行情", _show_mode.bind("market"), mode == "dive", 112))
	row.add_child(_button("装备工坊", _show_mode.bind("equipment"), mode == "dive", 112))
	row.add_child(_button("海生图鉴 %d/12" % game.marine_discoveries.size(), _show_mode.bind("catalog"), mode == "dive", 142))
	row.add_child(_button("上浮" if mode == "dive" else "返回岛上", _finish_dive.bind(false) if mode == "dive" else request_close, false, 112))
	return panel


func _build_prep() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	var areas_panel := PanelContainer.new()
	areas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	areas_panel.add_theme_stylebox_override("panel", _panel_style(Color("0e2b35"), Color("4f7d80"), 10))
	var areas_box := VBoxContainer.new()
	areas_box.add_theme_constant_override("separation", 8)
	areas_panel.add_child(areas_box)
	areas_box.add_child(_label("选择水下区域", Color("f0d27e"), 21))
	for area_id in FishCatalog.AREAS.keys():
		areas_box.add_child(_area_card(str(area_id)))
	body.add_child(areas_panel)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size.x = 370
	info_panel.add_theme_stylebox_override("panel", _panel_style(Color("12313a"), Color("6b9292"), 10))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 9)
	info_panel.add_child(info)
	info.add_child(_label("今日海况", Color("f0d27e"), 21))
	info.add_child(_label("%s · %s · %s\n有效鱼群窗口 %d / %d" % [game.phase_name(), game.weather, game.wind_direction, game.fishing_remaining_today(), game.DAILY_FISHING_LIMIT], Color("c7dcda"), 17))
	info.add_child(HSeparator.new())
	info.add_child(_label("当前装备", Color("f0d27e"), 19))
	info.add_child(_label("氧气 %.0f秒\n鱼篓 %d格\n游动效率 ×%.2f\n保鲜延后 %d日" % [float(game.dive_equipment["oxygen"]), int(game.dive_equipment["basket"]), float(game.dive_equipment["swim_speed"]), int(game.dive_equipment["preservation_days"])], Color("b7d5d1"), 16))
	info.add_child(_button("查看与升级装备", _show_mode.bind("equipment"), false, 0))
	info.add_child(HSeparator.new())
	var market_rows: Array = game.fish_market_rows()
	info.add_child(_label("当前高价鱼", Color("f0d27e"), 19))
	for index in range(mini(3, market_rows.size())):
		var market: Dictionary = market_rows[index]
		info.add_child(_label("%s · %d金贝 · 重点需求%d条" % [str(market["name"]), int(market["quote"]), int(market["demand"])], Color("91dfb2"), 15))
	info.add_child(HSeparator.new())
	info.add_child(_label("一次潜捕固定消耗1潮刻；水下现实时间不会叠加世界耗时。氧气归零只会强制上浮，已经入篓的鱼获全部保留。", Color("9eb9b7"), 15))
	if not feedback_text.is_empty():
		info.add_child(_label(feedback_text, Color("f0c77b"), 15))
	body.add_child(info_panel)
	return body


func _area_card(area_id: String) -> PanelContainer:
	var status: Dictionary = game.dive_area_status(area_id)
	var selected := selected_area == area_id
	var unlocked := bool(status.get("unlocked", false))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("173b43") if selected else Color("123039"), Color("e1c263") if selected else Color("4e7477"), 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(_label("%s%s" % ["✓ " if selected else "", str(status.get("name", area_id))], Color("f0d27e") if unlocked else Color("7f9697"), 19))
	copy.add_child(_label(str(status.get("description", "")), Color("b7cfcc") if unlocked else Color("73888a"), 14))
	copy.add_child(_label("能见度 %d%% · 洋流%s · %s" % [int(round(float(status.get("visibility", 0.0)) * 100.0)), str(status.get("current", "")), "可进入" if unlocked else str(status.get("unlock", "尚未开放"))], Color("8fc9c1") if unlocked else Color("708083"), 13))
	row.add_child(copy)
	row.add_child(_button("选择", _select_area.bind(area_id), not unlocked, 76))
	row.add_child(_button("下水抓鱼", _start_dive.bind(area_id), not unlocked or game.fishing_remaining_today() <= 0, 112))
	return panel


func _build_dive() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	var field_panel := PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_panel.add_theme_stylebox_override("panel", _panel_style(Color("0b4050"), Color("6aa8ac"), 8))
	dive_field = DiveFieldScript.new()
	dive_field.setup(game)
	dive_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dive_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dive_field.oxygen_depleted.connect(_finish_dive.bind(true), CONNECT_DEFERRED)
	dive_field.status_changed.connect(_on_dive_status)
	dive_field.set_gameplay_paused(not pause_reasons.is_empty())
	field_panel.add_child(dive_field)
	body.add_child(field_panel)

	var hud_panel := PanelContainer.new()
	hud_panel.custom_minimum_size.x = 310
	hud_panel.add_theme_stylebox_override("panel", _panel_style(Color("102d37"), Color("789a98"), 8))
	var hud := VBoxContainer.new()
	hud.add_theme_constant_override("separation", 10)
	hud_panel.add_child(hud)
	var area_id := str(game.dive_state.get("area_id", "sand_shallows"))
	hud.add_child(_label(FishCatalog.area_name(area_id), Color("f0d27e"), 22))
	oxygen_label = _label("", Color("b8eff0"), 17)
	hud.add_child(oxygen_label)
	oxygen_bar = ProgressBar.new()
	oxygen_bar.show_percentage = false
	oxygen_bar.custom_minimum_size.y = 24
	oxygen_bar.add_theme_stylebox_override("background", _panel_style(Color("17343b"), Color("36565c"), 5))
	oxygen_bar.add_theme_stylebox_override("fill", _panel_style(Color("4ba8b5"), Color("9be0e0"), 5))
	hud.add_child(oxygen_bar)
	basket_label = _label("", Color("f0d27e"), 18)
	hud.add_child(basket_label)
	hud.add_child(_basket_contents())
	hud.add_child(HSeparator.new())
	dive_status_label = _label("WASD/方向键游动，靠近鱼影按E抓取；按住Shift快速游动会更快消耗氧气。", Color("b8cfcb"), 15)
	dive_status_label.custom_minimum_size.y = 100
	hud.add_child(dive_status_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud.add_child(spacer)
	dive_pause_button = _button("继续潜捕" if pause_reasons.has("manual") else "暂停 / 查看说明", _toggle_manual_pause, false, 0)
	hud.add_child(dive_pause_button)
	hud.add_child(_button("主动上浮并结算", _finish_dive.bind(false), false, 0))
	body.add_child(hud_panel)
	return body


func _basket_contents() -> VBoxContainer:
	var box := VBoxContainer.new()
	var candidates: Array = game.dive_state.get("candidates", [])
	for raw_index in game.dive_state.get("captured_indices", []):
		var candidate: Dictionary = candidates[int(raw_index)]
		box.add_child(_label("• %s · %s" % [FishCatalog.species_name(str(candidate["species_id"])), str(candidate["size"])], Color("d8ece7"), 14))
	if box.get_child_count() == 0:
		box.add_child(_label("鱼篓还是空的", Color("738e90"), 14))
	return box


func _build_result() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var result: Dictionary = game.last_dive_result
	content.add_child(_label(str(result.get("text", "本次潜捕已经结束。")), Color("f5dfa0"), 19))
	for raw_catch in result.get("catches", []):
		var catch_record: Dictionary = raw_catch
		var species_id := str(catch_record["species_id"])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _panel_style(Color("12343c"), Color("5d8584"), 7))
		var row := HBoxContainer.new()
		card.add_child(row)
		var color_swatch := ColorRect.new()
		color_swatch.custom_minimum_size = Vector2(70, 54)
		color_swatch.color = FishCatalog.SPECIES[species_id]["color"]
		row.add_child(color_swatch)
		var first: bool = result.get("first_discoveries", []).has(FishCatalog.species_name(species_id))
		var copy := _label("%s%s · %s · %s\n当前估价 %d金贝" % ["★ 新发现　" if first else "", FishCatalog.species_name(species_id), str(catch_record["size"]), game.fish_freshness_state(catch_record), game.fish_catch_value(catch_record)], Color("f0d27e") if first else Color("d2e5e1"), 16)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		content.add_child(card)
	if result.get("catches", []).is_empty():
		content.add_child(_label("这次没有鱼进入鱼篓，但窗口与1潮刻仍已结算。下次可以更早返程或选择白沙浅湾。", Color("a9c0bd"), 16))
	if not result.get("new_records", []).is_empty():
		content.add_child(_label("新尺寸纪录：%s" % "、".join(result["new_records"]), Color("f0d27e"), 18))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var market_button := _button("带鱼获去蓝鳍鱼铺", _show_mode.bind("market"), false, 210)
	market_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(market_button)
	var again := _button("查看下一次鱼群", _show_mode.bind("prep"), game.fishing_remaining_today() <= 0, 190)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(again)
	actions.add_child(_button("返回岛上", request_close, false, 120))
	content.add_child(actions)
	return scroll


func _build_market() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	var quotes_panel := PanelContainer.new()
	quotes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quotes_panel.add_theme_stylebox_override("panel", _panel_style(Color("102e37"), Color("527c7e"), 8))
	var quotes_box := VBoxContainer.new()
	quotes_panel.add_child(quotes_box)
	quotes_box.add_child(_label("当前报价 · %s" % game.phase_name(), Color("f0d27e"), 20))
	quotes_box.add_child(_label("距下一次时段刷新约%.2f潮刻。报价只在边界更新，不会因你阅读或选择而跳动。" % _tides_to_market_refresh(), Color("9ebbb8"), 14))
	var quote_scroll := ScrollContainer.new()
	quote_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quotes_box.add_child(quote_scroll)
	var quote_list := VBoxContainer.new()
	quote_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_scroll.add_child(quote_list)
	for raw_row in game.fish_market_rows():
		var row: Dictionary = raw_row
		quote_list.add_child(_market_row(row))
	body.add_child(quotes_panel)

	var inventory_panel := PanelContainer.new()
	inventory_panel.custom_minimum_size.x = 470
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color("14323a"), Color("6c8f8d"), 8))
	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override("separation", 7)
	inventory_panel.add_child(inventory_box)
	inventory_box.add_child(_label("你的鱼获箱 · %d条 · 估值%d金贝" % [game.fish_catch_inventory.size(), game.fish_inventory_value()], Color("f0d27e"), 20))
	if not feedback_text.is_empty():
		inventory_box.add_child(_label(feedback_text, Color("f0c77b"), 14))
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_box.add_child(inventory_scroll)
	var catch_list := VBoxContainer.new()
	catch_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(catch_list)
	for raw_catch in game.fish_catch_inventory:
		var catch_record: Dictionary = raw_catch
		var catch_id := str(catch_record["catch_id"])
		var check := CheckButton.new()
		check.text = "%s · %s · %s · 参考%d金贝" % [FishCatalog.species_name(str(catch_record["species_id"])), str(catch_record["size"]), game.fish_freshness_state(catch_record), game.fish_catch_value(catch_record)]
		check.button_pressed = bool(selected_catches.get(catch_id, false))
		check.toggled.connect(_toggle_catch.bind(catch_id))
		catch_list.add_child(check)
	if game.fish_catch_inventory.is_empty():
		catch_list.add_child(_label("鱼获箱为空。潜捕上岸后，鱼会先进入这里，不会自动出售。", Color("829b9b"), 15))
	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 8)
	var selected_button := _button("预览已选出售", _preview_selected_sale, selected_catches.is_empty(), 0)
	selected_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_row.add_child(selected_button)
	var all_button := _button("预览全部出售", _preview_all_sale, game.fish_catch_inventory.is_empty(), 0)
	all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_row.add_child(all_button)
	inventory_box.add_child(sell_row)
	inventory_box.add_child(HSeparator.new())
	inventory_box.add_child(_label("今日订单", Color("f0d27e"), 18))
	for raw_order in game.fish_market_orders:
		inventory_box.add_child(_order_row(raw_order))
	body.add_child(inventory_panel)
	return body


func _build_equipment() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("102d36"), Color("6b9292"), 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label("长期装备不会损坏，也不会增加每日3个有效鱼群窗口；它只改善单次潜捕的时间、移动、携带与保存选择。", Color("c7dcda"), 16))
	box.add_child(_label("当前持有 %d金贝。第二次升级会读取已永久发现的万物知识，但不会消耗万物。" % game.cash, Color("f0d27e"), 17))
	if not feedback_text.is_empty():
		box.add_child(_label(feedback_text, Color("f0c77b"), 15))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for raw_row in game.dive_equipment_rows():
		grid.add_child(_equipment_card(raw_row))
	return panel


func _equipment_card(raw_row: Dictionary) -> PanelContainer:
	var row: Dictionary = raw_row
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 215)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color("153640"), Color("d0b967") if not bool(row["maxed"]) else Color("638581"), 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	card.add_child(box)
	box.add_child(_label("%s · %d/%d级" % [str(row["name"]), int(row["level"]), int(row["max_level"])], Color("f0d27e"), 20))
	box.add_child(_label("%s\n当前：%s · %s" % [str(row["description"]), str(row["current_name"]), _equipment_value_text(row, false)], Color("bfd5d1"), 15))
	if bool(row["maxed"]):
		box.add_child(_label("已完成全部升级。", Color("8edcaf"), 16))
		return card
	var requirement := "无知识门槛"
	if not str(row["requirement_id"]).is_empty():
		requirement = "需要发现%s%s" % [str(row["requirement_name"]), " · 已满足" if bool(row["requirement_met"]) else " · 未满足"]
	box.add_child(_label("下一阶：%s · %s\n%s" % [str(row["next_name"]), _equipment_value_text(row, true), requirement], Color("9edfc4") if bool(row["requirement_met"]) else Color("d49b91"), 15))
	var buy := _button("支付%d金贝升级" % int(row["cost"]), _buy_equipment.bind(str(row["slot_id"])), not bool(row["requirement_met"]) or not bool(row["affordable"]), 0)
	box.add_child(buy)
	return card


func _equipment_value_text(row: Dictionary, next_value: bool) -> String:
	var value = row["next_value"] if next_value else row["current_value"]
	if str(row["slot_id"]) == "fins":
		return "游动×%.2f" % float(value)
	if str(row["slot_id"]) == "oxygen":
		return "%.0f秒" % float(value)
	return "%d%s" % [int(value), str(row["unit"])]


func _buy_equipment(slot_id: String) -> void:
	var result: Dictionary = game.buy_dive_equipment_upgrade(slot_id)
	feedback_text = str(result.get("text", "装备升级未完成。"))
	mode = "equipment"
	_rebuild()


func _market_row(row: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("14363d"), Color("456e70"), 6))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var arrow := "↑" if int(row["change"]) > 0 else ("↓" if int(row["change"]) < 0 else "→")
	box.add_child(_label("%s　%d金贝 %s　重点需求%d条　库存%d" % [str(row["name"]), int(row["quote"]), arrow, int(row["demand"]), int(row["stock"])], Color("9ee0b4") if int(row["change"]) >= 0 else Color("e1ad9c"), 15))
	box.add_child(_label("；".join(row["reasons"]), Color("91abaa"), 13))
	return panel


func _order_row(raw_order: Dictionary) -> Control:
	var order: Dictionary = raw_order
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("183740"), Color("587b7b"), 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var species_name := FishCatalog.species_name(str(order["species_id"]))
	var completed := bool(order.get("completed", false))
	var requirements: Array[String] = []
	if not str(order.get("min_size", "")).is_empty():
		requirements.append("至少%s" % str(order["min_size"]))
	if not str(order.get("freshness_required", "")).is_empty():
		requirements.append("%s以上" % str(order["freshness_required"]))
	if requirements.is_empty():
		requirements.append("尺寸与新鲜度不限")
	var npc_id := str(order.get("npc_id", ""))
	var relationship_required := int(order.get("relationship_required", 0))
	var relationship_value := int(game.relationships.get(npc_id, 0))
	var relationship_met := relationship_value >= relationship_required
	var label := _label("%s · %s\n%s：%s ×%d · %s · 每条%d金贝 · 截止%d潮刻%s" % [
		str(order.get("role", "人物订单")), str(order.get("brief", "定向收购")),
		str(order["buyer"]), species_name, int(order["quantity"]), "、".join(requirements),
		int(order["reward_each"]), int(order["deadline_tide"]), " · 已交付" if completed else ""
	], Color("89aaa7") if completed else Color("d1e1dd"), 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button_text := "已交付" if completed else ("关系%d/%d" % [relationship_value, relationship_required] if not relationship_met else "交付")
	row.add_child(_button(button_text, _turn_in_order.bind(str(order["order_id"])), completed or not relationship_met, 94))
	return panel


func _build_sale_preview() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("11313a"), Color("b29a5d"), 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	box.add_child(_label("出售预览在确认前保持不变；确认后鱼获、金贝、库存和重点需求会一次完成结算。", Color("d6e6e1"), 17))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	for raw_line in current_sale_preview.get("lines", []):
		var line: Dictionary = raw_line
		lines.add_child(_label("%s · %s · %s · %s → %d金贝" % [str(line["name"]), str(line["size"]), str(line["freshness"]), str(line["tier"]), int(line["unit_price"])], Color("cde0dc"), 16))
	box.add_child(_label("合计：%d条 · %d金贝" % [int(current_sale_preview.get("count", 0)), int(current_sale_preview.get("total", 0))], Color("f0d27e"), 23))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var confirm := _button("确认出售", _confirm_sale.bind(str(current_sale_preview.get("sale_id", ""))), current_sale_preview.is_empty(), 180)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(confirm)
	var cancel := _button("返回鱼铺", _show_mode.bind("market"), false, 150)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(cancel)
	box.add_child(actions)
	return panel


func _build_catalog() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for species_id in FishCatalog.SPECIES.keys():
		var discovered: bool = game.marine_discoveries.has(species_id)
		var species: Dictionary = FishCatalog.SPECIES[species_id]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 142)
		panel.add_theme_stylebox_override("panel", _panel_style(Color("14343c"), Color("627f7f") if discovered else Color("31494d"), 8))
		var box := VBoxContainer.new()
		panel.add_child(box)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size.y = 34
		swatch.color = species["color"] if discovered else Color("23383d")
		box.add_child(swatch)
		box.add_child(_label(str(species["name"]) if discovered else "未识别鱼影", Color("f0d27e") if discovered else Color("71898b"), 17))
		if discovered:
			var record: Dictionary = game.marine_size_records.get(species_id, {})
			box.add_child(_label("%s · %s · %s\n最大纪录：%s" % [str(species["rarity"]), str(species["behavior"]), "、".join(species["tags"]), str(record.get("size", "尚无"))], Color("b5cdca"), 13))
		else:
			box.add_child(_label("可能栖息于：%s" % "、".join(_area_names(species["habitats"])), Color("6e8587"), 13))
		grid.add_child(panel)
	return scroll


func _area_names(area_ids: Array) -> Array[String]:
	var names: Array[String] = []
	for area_id in area_ids:
		names.append(FishCatalog.area_name(str(area_id)))
	return names


func _select_area(area_id: String) -> void:
	selected_area = area_id
	_rebuild()


func _start_dive(area_id: String) -> void:
	var result: Dictionary = game.begin_dive(area_id)
	if not bool(result.get("ok", false)):
		feedback_text = str(result.get("text", "这次不能下水。"))
		mode = "prep"
		_rebuild()
		return
	checkpoint_requested.emit("海岸潜捕场景已锁定")
	feedback_text = ""
	pause_reasons.clear()
	mode = "dive"
	_rebuild()


func _finish_dive(forced_surface: bool = false) -> void:
	if finishing:
		return
	if not game.dive_active:
		mode = "result"
		_rebuild()
		return
	finishing = true
	game.finish_dive(forced_surface)
	checkpoint_requested.emit("海岸潜捕已结算")
	pause_reasons.clear()
	finishing = false
	mode = "result"
	_rebuild()


func _on_dive_status(text_value: String) -> void:
	if dive_status_label != null and is_instance_valid(dive_status_label):
		dive_status_label.text = text_value


func _toggle_manual_pause() -> void:
	set_activity_pause("manual", not pause_reasons.has("manual"))


func _update_pause_feedback() -> void:
	if dive_status_label != null and is_instance_valid(dive_status_label) and not pause_reasons.is_empty():
		dive_status_label.text = "潜捕已暂停：氧气、鱼群和移动全部冻结。WASD游动，E抓取，Shift快游；继续后不会补算暂停时间。"
	if dive_pause_button != null and is_instance_valid(dive_pause_button):
		dive_pause_button.text = "继续潜捕" if pause_reasons.has("manual") else ("窗口失焦 · 已暂停" if pause_reasons.has("focus") else "暂停 / 查看说明")


func _show_mode(next_mode: String) -> void:
	if mode == "dive":
		return
	mode = next_mode
	_rebuild()


func _toggle_catch(enabled: bool, catch_id: String) -> void:
	if enabled:
		selected_catches[catch_id] = true
	else:
		selected_catches.erase(catch_id)


func _preview_selected_sale() -> void:
	_preview_sale(selected_catches.keys())


func _preview_all_sale() -> void:
	var ids: Array = []
	for raw_catch in game.fish_catch_inventory:
		ids.append(str(raw_catch["catch_id"]))
	_preview_sale(ids)


func _preview_sale(catch_ids: Array) -> void:
	var preview: Dictionary = game.create_fish_sale_preview(catch_ids)
	if not bool(preview.get("ok", false)):
		return
	current_sale_preview = preview
	mode = "sale_preview"
	_rebuild()


func _confirm_sale(sale_id: String) -> void:
	var result: Dictionary = game.confirm_fish_sale(sale_id)
	feedback_text = str(result.get("text", "出售未完成。"))
	selected_catches.clear()
	current_sale_preview.clear()
	mode = "market"
	_rebuild()


func _turn_in_order(order_id: String) -> void:
	var result: Dictionary = game.turn_in_fish_order(order_id)
	feedback_text = str(result.get("text", "订单未能交付。"))
	mode = "market"
	_rebuild()


func _tides_to_market_refresh() -> float:
	var current := float(game.tide - 1) + float(game.tide_progress)
	for boundary in [4.0, 8.0, 12.0, 16.0]:
		if float(boundary) > current + 0.000001:
			return float(boundary) - current
	return 0.0


func _label(text_value: String, color_value: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color_value)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text_value: String, action: Callable, disabled_value: bool, width: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.disabled = disabled_value
	button.custom_minimum_size = Vector2(width, 40)
	button.add_theme_color_override("font_color", Color("f4f1df"))
	button.add_theme_color_override("font_disabled_color", Color("708487"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("294951"), Color("62888a"), 7))
	button.add_theme_stylebox_override("hover", _panel_style(Color("39616a"), Color("a1c1b7"), 7))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("1d353c"), Color("e2c96f"), 7))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("20343a"), Color("3d5357"), 7))
	button.pressed.connect(action, CONNECT_DEFERRED)
	return button


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
