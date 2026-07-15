extends Node2D

const GameStateScript = preload("res://scripts/game_state.gd")
const MarkerScript = preload("res://scripts/interactable.gd")
const PokerTableScript = preload("res://scripts/poker_table.gd")
const WealthChartScript = preload("res://scripts/wealth_chart.gd")
const IslandPanorama = preload("res://assets/art/island_panorama_v1.png")
const SynthesisCollectionAtlas = preload("res://assets/art/synthesis_collection_atlas_v1.png")
const RaceBanner = preload("res://assets/art/race_banner_v1.png")
const ShopMaterialAtlas = preload("res://assets/art/shop_material_atlas_v1.png")

const COLLECTION_OUTPUTS := ["mud", "charcoal", "fog", "pottery", "tool", "sail", "salted_fish", "calm_incense", "wind_bell"]
const MATERIAL_ITEMS := ["water", "earth", "fire", "wood", "wind", "stone", "fish", "fruit", "salt", "metal", "cloth", "paper", "flower"]
const COLLECTION_DESCRIPTIONS := {
	"mud": "水与土安静结合后的第一种稳定造物。",
	"charcoal": "木在火中留下的凝练热量。",
	"fog": "被风托住、暂时不肯落下的水。",
	"pottery": "泥经历火之后获得了可以长久保存的形状。",
	"tool": "木提供握持，金提供改变世界的锋面。",
	"sail": "布接住风，第一次把方向变成力量。",
	"salted_fish": "海获与盐共同换来的耐储食物。",
	"calm_incense": "炭托起花香，让纷乱慢慢沉静。",
	"wind_bell": "金属替无形的风留下了声音。"
}

@onready var player: CharacterBody2D = $Player
@onready var markers_root: Node2D = $Markers
@onready var ui_layer: CanvasLayer = $UILayer

var game
var markers: Array[Node2D] = []
var marker_by_id := {}
var nearest_marker: Node2D
var synthesis_left_id: String = ""
var synthesis_right_id: String = ""
var discovered_areas := {"漂流湾": true}
var current_area := "漂流湾"

var ui_root: Control
var hud_label: Label
var inventory_button: Button
var prompt_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer: Timer
var modal_overlay: ColorRect
var modal_title: Label
var modal_body: VBoxContainer
var poker_table: Control
var synthesis_left_library: GridContainer
var synthesis_right_library: GridContainer
var synthesis_stage: PanelContainer

var race_beast_option: OptionButton
var race_ticket_option: OptionButton
var race_aid_option: OptionButton
var race_bet_spin: SpinBox
var race_preview_label: Label


func _ready() -> void:
	game = GameStateScript.new()
	game.changed.connect(_refresh_hud)
	game.notice.connect(_show_toast)
	_build_markers()
	_build_ui()
	player.interact_requested.connect(_interact)
	player.inventory_requested.connect(_open_collection)
	_refresh_hud()
	# Optional local visual-QA entry points.
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("preview-poker") or user_args.has("preview-rules"):
		game.begin_poker_session(80)
		game.start_poker_hand()
		if user_args.has("preview-poker"):
			game.poker_action("call")
			poker_table.animations_enabled = false
		poker_table.open("界面预览")
		player.controls_enabled = false
		if user_args.has("preview-rules"):
			poker_table._show_rules()
	elif user_args.has("preview-collection"):
		_open_collection()
	elif user_args.has("preview-shop"):
		_open_shop()


func _process(_delta: float) -> void:
	_update_area_discovery()
	_update_nearest_marker()
	var milo = marker_by_id.get("milo")
	if milo != null:
		milo.visible = game.poker_completed or game.phase_name() == "夜晚"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and poker_table != null and poker_table.visible:
		poker_table.request_close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and modal_overlay.visible:
		_close_modal()
		get_viewport().set_input_as_handled()


func _build_markers() -> void:
	_add_marker("bed", "漂流小屋", Vector2(95, 205), Color("9ecae1"))
	_add_marker("fish", "浅滩采集", Vector2(190, 465), Color("6bd6e8"))
	_add_marker("basin", "造化盆", Vector2(405, 330), Color("e7c85d"))
	_add_marker("granny", "榕奶奶", Vector2(515, 250), Color("f3a6b9"))
	_add_marker("shop", "杂货铺", Vector2(710, 335), Color("f2b366"))
	_add_marker("shopkeeper", "铺主阿拓", Vector2(790, 255), Color("e49f5a"))
	_add_marker("tea", "命运牌会", Vector2(930, 335), Color("b38ee6"))
	_add_marker("old_joe", "老乔", Vector2(1010, 255), Color("c3a3ed"))
	_add_marker("news", "岛报栏", Vector2(1120, 405), Color("f4e1a1"))
	_add_marker("mia", "米娅", Vector2(1100, 285), Color("ffcf70"))
	_add_marker("tower", "万象塔", Vector2(1050, 205), Color("d9eef2"))
	_add_marker("race", "逐风竞速", Vector2(1340, 335), Color("7ee0a2"))
	_add_marker("aqiu", "阿葵", Vector2(1590, 305), Color("93e0ba"))
	_add_marker("milo", "米洛", Vector2(1710, 245), Color("95b9ff"))


func _add_marker(id_value: String, label_value: String, position_value: Vector2, color_value: Color) -> void:
	var marker = MarkerScript.new()
	marker.position = position_value
	marker.setup(id_value, label_value, color_value)
	markers_root.add_child(marker)
	markers.append(marker)
	marker_by_id[id_value] = marker


func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 16
	ui_root.theme = theme
	ui_layer.add_child(ui_root)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 20
	top_panel.offset_top = 15
	top_panel.offset_right = -20
	top_panel.offset_bottom = 74
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color("18323bea"), Color("6b9298")))
	ui_root.add_child(top_panel)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_row)
	hud_label = Label.new()
	hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 16)
	top_row.add_child(hud_label)
	var collection_button := _make_button("造化盆", _open_synthesis)
	collection_button.custom_minimum_size.x = 104
	top_row.add_child(collection_button)
	var wealth_button := _make_button("财富轨迹", _open_wealth)
	wealth_button.custom_minimum_size.x = 104
	top_row.add_child(wealth_button)
	var map_button := _make_button("地图", _open_map)
	map_button.custom_minimum_size.x = 74
	top_row.add_child(map_button)
	inventory_button = _make_button("万物图鉴", _open_collection)
	inventory_button.custom_minimum_size.x = 102
	top_row.add_child(inventory_button)

	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_panel.offset_left = -420
	bottom_panel.offset_top = -68
	bottom_panel.offset_right = 420
	bottom_panel.offset_bottom = -18
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(Color("18323be8"), Color("6b9298")))
	ui_root.add_child(bottom_panel)
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 17)
	bottom_panel.add_child(prompt_label)

	toast_panel = PanelContainer.new()
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_left = -310
	toast_panel.offset_top = -120
	toast_panel.offset_right = 310
	toast_panel.offset_bottom = -80
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color("2b454bea"), Color("9ab4a7")))
	toast_panel.visible = false
	ui_root.add_child(toast_panel)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color("f7edbd"))
	toast_panel.add_child(toast_label)
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.wait_time = 4.5
	toast_timer.timeout.connect(_hide_toast)
	ui_root.add_child(toast_timer)

	modal_overlay = ColorRect.new()
	modal_overlay.color = Color(0.025, 0.055, 0.075, 0.78)
	modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_overlay.visible = false
	ui_root.add_child(modal_overlay)

	var modal_panel := PanelContainer.new()
	modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	modal_panel.offset_left = -395
	modal_panel.offset_top = -290
	modal_panel.offset_right = 395
	modal_panel.offset_bottom = 290
	modal_panel.add_theme_stylebox_override("panel", _panel_style(Color("203946"), Color("80aeba")))
	modal_overlay.add_child(modal_panel)

	var modal_column := VBoxContainer.new()
	modal_column.add_theme_constant_override("separation", 12)
	modal_panel.add_child(modal_column)
	var title_row := HBoxContainer.new()
	modal_column.add_child(title_row)
	modal_title = Label.new()
	modal_title.add_theme_font_size_override("font_size", 25)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(modal_title)
	title_row.add_child(_make_button("关闭 Esc", _close_modal))
	modal_column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_column.add_child(scroll)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 10)
	scroll.add_child(modal_body)

	poker_table = PokerTableScript.new()
	poker_table.setup(game)
	poker_table.closed.connect(_on_poker_table_closed)
	ui_root.add_child(poker_table)


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _make_button(text_value: String, action: Callable, disabled_value: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 38)
	button.disabled = disabled_value
	button.add_theme_color_override("font_color", Color("f5f7ed"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("819196"))
	button.add_theme_stylebox_override("normal", _button_style(Color("29444d"), Color("66858c")))
	button.add_theme_stylebox_override("hover", _button_style(Color("365963"), Color("96b9b3")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1f353d"), Color("e2ce82")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("24363b"), Color("40565a")))
	button.pressed.connect(action)
	return button


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _make_text(text_value: String, color_value: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color_value)
	return label


func _art_banner(texture: Texture2D, height: float = 180.0) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size.y = height
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _collection_art(item_id: String, size_value: float = 150.0, discovered_value: bool = true) -> TextureRect:
	var index := COLLECTION_OUTPUTS.find(item_id)
	var atlas := AtlasTexture.new()
	atlas.atlas = SynthesisCollectionAtlas
	var tile_width := float(SynthesisCollectionAtlas.get_width()) / 3.0
	var tile_height := float(SynthesisCollectionAtlas.get_height()) / 3.0
	var column := index % 3
	var row := index / 3
	atlas.region = Rect2(column * tile_width, row * tile_height, tile_width, tile_height)
	var art := TextureRect.new()
	art.texture = atlas
	art.custom_minimum_size = Vector2(size_value, size_value)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color.WHITE if discovered_value else Color("22353ad9")
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _item_art(item_id: String, size_value: float = 150.0, discovered_value: bool = true) -> TextureRect:
	if COLLECTION_OUTPUTS.has(item_id):
		return _collection_art(item_id, size_value, discovered_value)
	var index := MATERIAL_ITEMS.find(item_id)
	var atlas := AtlasTexture.new()
	atlas.atlas = ShopMaterialAtlas
	var tile_width := float(ShopMaterialAtlas.get_width()) / 4.0
	var tile_height := float(ShopMaterialAtlas.get_height()) / 4.0
	var safe_index := maxi(0, index)
	atlas.region = Rect2((safe_index % 4) * tile_width, (safe_index / 4) * tile_height, tile_width, tile_height)
	var art := TextureRect.new()
	art.texture = atlas
	art.custom_minimum_size = Vector2(size_value, size_value)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color.WHITE if discovered_value else Color("22353ad9")
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _refresh_hud() -> void:
	if hud_label == null:
		return
	var coin_text := "金贝 %d" % game.cash
	if game.locked_principal > 0:
		coin_text = "金贝总计 %d · 可用 %d · 活动中 %d" % [game.account_wealth(), game.cash, game.locked_principal]
	hud_label.text = "第%d天 · %s %d/16 · %s · %s\n%s · %s · 建议留存 %d金贝" % [
		game.day, game.phase_name(), game.tide, game.weather, current_area,
		coin_text, game.wealth_title(), game.suggested_reserve()
	]
	inventory_button.text = "万物 %d" % game.discovered_item_ids().size()


func _update_area_discovery() -> void:
	var next_area := "漂流湾"
	if player.global_position.x >= 1200:
		next_area = "逐风海岸"
	elif player.global_position.x >= 600:
		next_area = "椰影街"
	if next_area != current_area:
		current_area = next_area
		_refresh_hud()
		if not discovered_areas.has(next_area):
			discovered_areas[next_area] = true
			_show_toast("发现新区域：%s。现在可从地图快速移动。" % next_area)


func _update_nearest_marker() -> void:
	if modal_overlay.visible:
		prompt_label.text = "正在查看界面 · Esc 关闭"
		return
	var best_distance := INF
	var candidate: Node2D
	for marker in markers:
		if not marker.visible:
			continue
		var distance := player.global_position.distance_to(marker.global_position)
		marker.set_proximity(distance)
		if distance <= marker.interaction_radius and distance < best_distance:
			best_distance = distance
			candidate = marker
	nearest_marker = candidate
	for marker in markers:
		marker.set_highlighted(marker == nearest_marker)
	if nearest_marker == null:
		prompt_label.text = "%s · WASD / 方向键移动 · I / Tab 背包" % current_area
	else:
		prompt_label.text = "按 E：%s" % nearest_marker.display_name


func _interact() -> void:
	if modal_overlay.visible:
		return
	if nearest_marker == null:
		_show_toast("再靠近一个地点或人物试试。")
		return
	match nearest_marker.interaction_id:
		"bed": _open_bed()
		"fish": _do_fish()
		"basin": _open_synthesis()
		"granny": _open_granny()
		"shop", "shopkeeper": _open_shop()
		"tea", "old_joe": _open_poker()
		"news": _open_news()
		"mia": _open_mia()
		"tower": _open_tower()
		"race": _open_race()
		"aqiu": _open_aqiu()
		"milo": _open_milo()


func _open_modal(title_value: String) -> void:
	modal_title.text = title_value
	for child in modal_body.get_children():
		modal_body.remove_child(child)
		child.queue_free()
	modal_overlay.visible = true
	player.controls_enabled = false


func _close_modal() -> void:
	modal_overlay.visible = false
	player.controls_enabled = true


func _show_toast(text_value: String) -> void:
	if toast_label != null:
		toast_label.text = text_value
		toast_panel.visible = true
		toast_timer.start()


func _hide_toast() -> void:
	if toast_panel != null:
		toast_panel.visible = false


func _show_result(title_value: String, text_value: String, return_action: Callable = Callable()) -> void:
	_open_modal(title_value)
	modal_body.add_child(_make_text(text_value, Color("fff2b0")))
	if return_action.is_valid():
		modal_body.add_child(_make_button("继续", return_action))


func _open_inventory() -> void:
	_open_collection()


func _open_collection() -> void:
	_open_modal("万物图鉴")
	var discovered_count: int = game.discovered_item_ids().size()
	modal_body.add_child(_make_text("永久万物 %d / %d · 发现后可以无限参与合成，也不会因委托或竞速而消失。" % [discovered_count, game.ITEMS.size()], Color("f2d984")))
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 20
	progress.show_percentage = false
	progress.value = float(discovered_count) / float(game.ITEMS.size()) * 100.0
	progress.add_theme_stylebox_override("background", _progress_style(Color("173039"), Color("526f73")))
	progress.add_theme_stylebox_override("fill", _progress_style(Color("b3954f"), Color("f0d27e")))
	modal_body.add_child(progress)
	modal_body.add_child(_make_text("账户凭证：逐风免费体验券 %d · 实验折扣 %d次" % [game.free_race_ticket, game.synthesis_discount_uses], Color("9fdcc1")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	var all_ids: Array[String] = []
	for raw_id in game.ITEMS.keys():
		all_ids.append(str(raw_id))
	all_ids.sort_custom(func(a: String, b: String):
		var tier_a := int(game.ITEMS[a]["tier"])
		var tier_b := int(game.ITEMS[b]["tier"])
		if tier_a != tier_b:
			return tier_a < tier_b
		return game.item_name(a) < game.item_name(b)
	)
	for item_id in all_ids:
		var known: bool = game.is_discovered(item_id)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(230, 270)
		panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), Color("b99e5d") if known else Color("41565a")))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)
		box.add_child(_item_art(item_id, 145.0, known))
		var name_label := _make_text(game.item_name(item_id) if known else "尚未发现", Color("f1d68b") if known else Color("7d9294"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 19)
		box.add_child(name_label)
		var aid_text := " · 逐风辅助" if game.RACE_AIDS.has(item_id) else ""
		var detail_text := "%s · %s · %d阶%s\n%s" % [game.item_name(item_id), str(game.ITEMS[item_id]["category"]), int(game.ITEMS[item_id]["tier"]), aid_text, game.item_description(item_id)] if known else "继续观察世界、学习知识或尝试新组合"
		var detail := _make_text(detail_text, Color("bfd6d2") if known else Color("718487"))
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(detail)
		grid.add_child(panel)
	modal_body.add_child(_make_button("前往造化盆继续发现", _open_synthesis))


func _open_wealth() -> void:
	_open_modal("财富轨迹")
	var history: Array = game.wealth_history_for_chart()
	var first_point: Dictionary = history[0]
	var last_point: Dictionary = history[history.size() - 1]
	var start_value := int(first_point.get("net_worth", 0))
	var current_value := int(last_point.get("net_worth", 0))
	var peak_value := current_value
	for raw_point in history:
		if raw_point is Dictionary:
			peak_value = maxi(peak_value, int(raw_point.get("net_worth", 0)))
	var net_change := current_value - start_value

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.add_child(_wealth_stat("当前净资产", "%d金贝" % current_value, Color("8ee0b1")))
	stats.add_child(_wealth_stat("从上岛至今", "%s%d金贝" % ["+" if net_change >= 0 else "", net_change], Color("8ee0b1") if net_change >= 0 else Color("eea099")))
	stats.add_child(_wealth_stat("历史最高", "%d金贝" % peak_value, Color("f0d27e")))
	modal_body.add_child(stats)

	modal_body.add_child(_make_text("净资产 = 当前金贝 + 活动中金贝。永久万物、知识和凭证不折算为现金。曲线记录每次结算后的真实变化。", Color("a9c9ca")))
	var chart = WealthChartScript.new()
	chart.setup(history)
	modal_body.add_child(chart)

	var milestone: Dictionary = game.next_wealth_milestone()
	if bool(milestone.get("complete", false)):
		modal_body.add_child(_make_text("已达到最高财富头衔：岛之名流。接下来可以把财富转化为收藏、住宅与岛上影响力。", Color("f2d984")))
	else:
		modal_body.add_child(_make_text("下一头衔：%s · 再积累%d金贝" % [str(milestone["title"]), int(milestone["remaining"])], Color("f2d984")))
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 22
		progress.show_percentage = false
		progress.value = float(milestone.get("progress", 0.0)) * 100.0
		progress.add_theme_stylebox_override("background", _progress_style(Color("173039"), Color("526f73")))
		progress.add_theme_stylebox_override("fill", _progress_style(Color("4fa982"), Color("7ed5aa")))
		modal_body.add_child(progress)

	modal_body.add_child(_make_text("最近变化", Color("f0d27e")))
	var first_recent := maxi(0, history.size() - 6)
	for index in range(history.size() - 1, first_recent - 1, -1):
		var point: Dictionary = history[index]
		var previous_value := int(history[index - 1].get("net_worth", 0)) if index > 0 else int(point.get("net_worth", 0))
		var delta := int(point.get("net_worth", 0)) - previous_value
		var delta_text := "±0" if delta == 0 else ("+%d" % delta if delta > 0 else "%d" % delta)
		modal_body.add_child(_make_text("第%d天 %d/16 · %s　净资产%s金贝 → %d" % [
			int(point.get("day", 1)), int(point.get("tide", 1)), str(point.get("reason", "结算")),
			delta_text, int(point.get("net_worth", 0))
		], Color("c7dcda")))


func _wealth_stat(title_text: String, value_text: String, value_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), Color("55777b")))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := _make_text(title_text, Color("9db9ba"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var value := _make_text(value_text, value_color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 22)
	box.add_child(value)
	return panel


func _progress_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _open_synthesis() -> void:
	_open_modal("万物合成 · 造化盆")
	modal_body.add_child(_make_text("永久万物 %d · 配方造物 %d / %d · 新组合只支付实验费，万物本身永远保留。" % [game.discovered_item_ids().size(), game.discovered_recipe_count(), game.RECIPES.size()], Color("ffe7a6")))
	var experiment_row := HBoxContainer.new()
	experiment_row.add_theme_constant_override("separation", 10)
	experiment_row.add_child(_synthesis_library("left"))
	experiment_row.add_child(_synthesis_center_stage())
	experiment_row.add_child(_synthesis_library("right"))
	modal_body.add_child(experiment_row)
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_make_text("最近实验 · 每个不同组合永久记录，左右交换视为同一组", Color("bde9f2")))
	if game.recent_synthesis_pairs.is_empty():
		modal_body.add_child(_make_text("还没有实验记录。先从左右图鉴各选一个万物。", Color("8da7a9")))
	for pair_key in game.recent_synthesis_pairs:
		var record: Dictionary = game.attempted_pairs.get(pair_key, {})
		var result_text: String = game.item_name(str(record.get("output", ""))) if bool(record.get("success", false)) else "无稳定结果"
		modal_body.add_child(_make_text("%s + %s → %s · 首次实验%d金贝" % [
			game.item_name(str(record.get("left_id", ""))), game.item_name(str(record.get("right_id", ""))),
			result_text, int(record.get("cost_paid", 0))
		], Color("9fdcc1") if bool(record.get("success", false)) else Color("c9aaa3")))


func _synthesis_library(side: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 220
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("6f9693")))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var side_name := "左侧万物" if side == "left" else "右侧万物"
	var title := _make_text(side_name, Color("f0d27e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	box.add_child(_make_text("与另一侧读取同一份永久图鉴", Color("8fb0ae")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	if side == "left":
		synthesis_left_library = grid
	else:
		synthesis_right_library = grid
	for item_id in game.discovered_item_ids():
		var selected: bool = synthesis_left_id == item_id if side == "left" else synthesis_right_id == item_id
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(90, 116)
		card.add_theme_stylebox_override("panel", _panel_style(Color("203f45"), Color("efcf73") if selected else Color("52787a")))
		var card_box := VBoxContainer.new()
		card_box.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(card_box)
		card_box.add_child(_item_art(item_id, 54.0))
		var choose := _make_button(("✓ " if selected else "") + game.item_name(item_id), _select_synthesis_item.bind(side, item_id))
		choose.tooltip_text = game.item_description(item_id)
		card_box.add_child(choose)
		grid.add_child(card)
	box.add_child(grid)
	return panel


func _synthesis_center_stage() -> PanelContainer:
	synthesis_stage = PanelContainer.new()
	synthesis_stage.custom_minimum_size.x = 260
	synthesis_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	synthesis_stage.add_theme_stylebox_override("panel", _panel_style(Color("254f49"), Color("d9bd63")))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	synthesis_stage.add_child(box)
	var title := _make_text("造化盆", Color("ffe49a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var pair := HBoxContainer.new()
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", 8)
	pair.add_child(_synthesis_selected_item(synthesis_left_id, "左侧"))
	var plus := _make_text("＋", Color("f0d27e"))
	plus.add_theme_font_size_override("font_size", 24)
	pair.add_child(plus)
	pair.add_child(_synthesis_selected_item(synthesis_right_id, "右侧"))
	box.add_child(pair)
	var ready := not synthesis_left_id.is_empty() and not synthesis_right_id.is_empty()
	var cost: int = game.synthesis_cost(synthesis_left_id, synthesis_right_id) if ready else 0
	var prior: Dictionary = game.synthesis_attempt_record(synthesis_left_id, synthesis_right_id) if ready else {}
	var status_text := "从左右图鉴各选一个万物"
	if ready and not prior.is_empty():
		status_text = "这个组合已经记录 · 再次查看 0金贝"
	elif ready:
		status_text = "新组合实验费 %d金贝%s" % [cost, " · 已应用半价" if game.synthesis_discount_uses > 0 else ""]
	var status := _make_text(status_text, Color("9fe0ba") if ready else Color("9bb5bc"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	box.add_child(_make_text("当前%d金贝 · 折扣剩余%d次" % [game.cash, game.synthesis_discount_uses], Color("d9e8df")))
	var disabled: bool = not ready or (prior.is_empty() and game.cash < cost)
	box.add_child(_make_button("查看记录 · 0金贝" if not prior.is_empty() else "开始实验 · %d金贝" % cost, _submit_synthesis, disabled))
	box.add_child(_make_button("清空两侧", _clear_synthesis, not ready))
	return synthesis_stage


func _synthesis_selected_item(item_id: String, placeholder: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 92
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	if item_id.is_empty():
		var empty := ColorRect.new()
		empty.color = Color("173039")
		empty.custom_minimum_size = Vector2(78, 78)
		box.add_child(empty)
		box.add_child(_make_text(placeholder, Color("82999a")))
	else:
		box.add_child(_item_art(item_id, 78.0))
		var name_label := _make_text(game.item_name(item_id), Color("f3d77f"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
	return box


func _select_synthesis_item(side: String, item_id: String) -> void:
	if side == "left":
		synthesis_left_id = item_id
	else:
		synthesis_right_id = item_id
	_open_synthesis()


func _clear_synthesis() -> void:
	synthesis_left_id = ""
	synthesis_right_id = ""
	_open_synthesis()


func _submit_synthesis() -> void:
	var result: Dictionary = game.synthesize_pair(synthesis_left_id, synthesis_right_id)
	_show_synthesis_result(result)


func _show_synthesis_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_show_result("实验未开始", str(result.get("text", "无法开始实验。")), _open_synthesis)
		return
	if not bool(result.get("success", false)):
		_open_modal("实验记录 · %s" % str(result.get("failure_title", "无稳定结果")))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("352d31"), Color("b46f6b")))
		var box := VBoxContainer.new()
		panel.add_child(box)
		var title := _make_text(str(result.get("failure_title", "结构未成")), Color("f0aaa0"))
		title.add_theme_font_size_override("font_size", 23)
		box.add_child(title)
		box.add_child(_make_text("%s + %s" % [game.item_name(str(result.get("left_id", ""))), game.item_name(str(result.get("right_id", "")))], Color("d6c3c0")))
		box.add_child(_make_text(str(result.get("failure_reason", "两者没有形成稳定万物。")), Color("f1e4d8")))
		box.add_child(_make_text("研究提示：%s" % str(result.get("suggestion", "替换一侧再试。")), Color("f0cf7e")))
		box.add_child(_make_text("本次支付%d金贝 · 两个万物永久保留 · 此组合以后免费查看" % int(result.get("cost_paid", 0)), Color("8ee0b1")))
		modal_body.add_child(panel)
		var actions := HBoxContainer.new()
		actions.add_child(_make_button("重新尝试", _open_synthesis))
		actions.add_child(_make_button("查看万物图鉴", _open_collection))
		modal_body.add_child(actions)
		return

	var output_id := str(result["output"])
	var first_discovery := bool(result.get("first_discovery", false))
	_open_modal("首次发现！" if first_discovery else "已知发现")
	var reveal := HBoxContainer.new()
	reveal.add_theme_constant_override("separation", 18)
	reveal.add_child(_collection_art(output_id, 230.0, true))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _make_text(game.item_name(output_id), Color("f3d77f"))
	title.add_theme_font_size_override("font_size", 30)
	copy.add_child(title)
	copy.add_child(_make_text("永久加入万物图鉴" if first_discovery else "这个发现已经永久记录", Color("8ee0b1")))
	copy.add_child(_make_text(game.item_description(output_id), Color("d7e8e4")))
	copy.add_child(_make_text("%s · %d阶万物 · 本次支付%d金贝" % [str(result.get("category", "造物")), int(result.get("tier", game.ITEMS[output_id]["tier"])), int(result.get("cost_paid", 0))], Color("adc9c7")))
	copy.add_child(_make_text("收藏进度 %d / %d" % [int(result.get("collection_count", 0)), int(result.get("collection_total", game.RECIPES.size()))], Color("f0cf7e")))
	copy.add_child(_make_text("新增可尝试组合：%d" % int(result.get("new_opportunities", game.count_untried_visible_pairs())), Color("a9d9d1")))
	if game.RACE_AIDS.has(output_id):
		copy.add_child(_make_text("逐风用途：%s · 每场部署费%d金贝" % [str(game.RACE_AIDS[output_id]["description"]), int(game.RACE_AIDS[output_id]["fee"])], Color("9fe0ba")))
	reveal.add_child(copy)
	modal_body.add_child(reveal)
	var actions := HBoxContainer.new()
	actions.add_child(_make_button("继续合成", _open_synthesis))
	actions.add_child(_make_button("查看万物图鉴", _open_collection))
	if game.RACE_AIDS.has(output_id):
		actions.add_child(_make_button("用于逐风竞速", _open_race))
	modal_body.add_child(actions)


func _open_shop() -> void:
	_open_modal("椰影杂货铺")
	var intro := PanelContainer.new()
	intro.add_theme_stylebox_override("panel", _panel_style(Color("183b41"), Color("c39b58")))
	var intro_row := HBoxContainer.new()
	intro_row.add_theme_constant_override("separation", 16)
	intro.add_child(intro_row)
	intro_row.add_child(_item_art("paper", 112.0))
	var intro_copy := VBoxContainer.new()
	intro_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var welcome := _make_text("阿拓的知识铺", Color("f4dc96"))
	welcome.add_theme_font_size_override("font_size", 23)
	intro_copy.add_child(welcome)
	intro_copy.add_child(_make_text("这里提供一次性永久知识、配方方向线索和实验折扣。每个万物一旦发现，就会永久留在图鉴中。", Color("c9e5df")))
	intro_copy.add_child(_make_text("当前%d金贝 · 永久万物%d种 · 实验折扣%d次" % [game.cash, game.discovered_item_ids().size(), game.synthesis_discount_uses], Color("f0d27e")))
	intro_copy.add_child(_make_text("“我卖的是别人走过的路。学会以后，那条路就归你了。”——阿拓", Color("eab77f")))
	intro_row.add_child(intro_copy)
	modal_body.add_child(intro)
	var purchase_title := _make_text("永久知识与研究服务", Color("ffe7a6"))
	purchase_title.add_theme_font_size_override("font_size", 20)
	modal_body.add_child(purchase_title)
	var purchase_grid := GridContainer.new()
	purchase_grid.columns = 2
	purchase_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	purchase_grid.add_theme_constant_override("h_separation", 10)
	purchase_grid.add_theme_constant_override("v_separation", 10)
	for raw_offer in game.shop_offers():
		var offer: Dictionary = raw_offer
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(340, 250)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("c09d5a") if bool(offer["available"]) else Color("526568")))
		var card_box := VBoxContainer.new()
		card_box.alignment = BoxContainer.ALIGNMENT_CENTER
		card_box.add_theme_constant_override("separation", 5)
		card.add_child(card_box)
		card_box.add_child(_item_art(str(offer["art"]), 112.0))
		var name_label := _make_text(str(offer["name"]), Color("f4efd8"))
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(name_label)
		var description := _make_text(str(offer["description"]), Color("bcd8d3"))
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(description)
		var price_label := _make_text("%d金贝 · %s" % [int(offer["price"]), str(offer["state_text"])], Color("efc978"))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_box.add_child(price_label)
		var disabled: bool = not bool(offer["available"]) or game.cash < int(offer["price"])
		card_box.add_child(_make_button("学习" if str(offer["type"]) == "knowledge" else "购买服务", _buy_shop_offer.bind(str(offer["id"])), disabled))
		purchase_grid.add_child(card)
	modal_body.add_child(purchase_grid)
	if not game.last_shop_hint.is_empty():
		modal_body.add_child(_make_text("最近线索：%s" % game.last_shop_hint, Color("f0d27e")))
	modal_body.add_child(_make_text("普通查看和购买不消耗潮刻。永久知识不会因日期或财富变化失效。", Color("9bb5bc")))


func _buy_shop_offer(offer_id: String) -> void:
	var result: Dictionary = game.buy_shop_offer(offer_id)
	_show_toast(str(result.get("text", "服务未能交付。")))
	_open_shop()


func _do_fish() -> void:
	var result: Dictionary = game.fish_once()
	var title := "浅滩采集 · 消耗1潮刻" if bool(result.get("ok", false)) else "浅滩今日已采尽"
	_show_result(title, str(result["text"]))


func _open_bed() -> void:
	_open_modal("漂流小屋")
	modal_body.add_child(_make_text("休息会直接结束今天，进入次日清晨；浅滩观察次数、天气与赛事随之刷新。"))
	modal_body.add_child(_make_button("睡到明天", _sleep))


func _sleep() -> void:
	game.sleep_to_next_day()
	_show_result("新的一天", "第%d天清晨。今日天气：%s。" % [game.day, game.weather])


func _open_granny() -> void:
	_open_modal("榕奶奶 · %s" % game.relationship_state("granny"))
	modal_body.add_child(_make_text("“把两个已经认识的万物放到盆的两边。它们不会消失，留下的是你对关系的理解。”", Color("ffd4df")))
	modal_body.add_child(_make_text("她建议先让水与土相遇。第一次基础实验需要2金贝，谈话不消耗潮刻。"))
	modal_body.add_child(_make_button("使用造化盆", _open_synthesis))


func _open_aqiu() -> void:
	var result: Dictionary = game.turn_in_aqiu_request()
	_open_modal("阿葵 · %s" % game.relationship_state("aqiu"))
	modal_body.add_child(_make_text(str(result["text"]), Color("c5f5d8")))
	if not game.aqiu_request_done:
		modal_body.add_child(_make_button("去造化盆", _travel_to.bind("漂流湾")))
	else:
		modal_body.add_child(_make_text("赛事情报：云鳍今天的状态值得留意。"))


func _open_mia() -> void:
	_open_modal("米娅 · %s" % game.relationship_state("mia"))
	modal_body.add_child(_make_text("“岛报只讲公开信息，最终下注还得你自己判断。”", Color("ffe4a5")))
	modal_body.add_child(_make_text("今日天气：%s。云鳍与雾步的场地适性较高；白浪速度突出但稳定性偏低。" % game.weather))
	modal_body.add_child(_make_button("查看岛报", _open_news))


func _open_milo() -> void:
	_open_modal("米洛 · %s" % game.relationship_state("milo"))
	if game.poker_completed:
		modal_body.add_child(_make_text("“听说你在老乔那桌坐过了。输赢不稀奇，能把本金和现金分开看才像个岛民。”", Color("c7d8ff")))
	else:
		modal_body.add_child(_make_text("米洛通常只在夜晚出现。他让你先去牌桌见识一次。"))


func _open_news() -> void:
	_open_modal("《万物岛报》")
	modal_body.add_child(_make_text("第%d日 · %s天 · 公开赛事观察" % [game.day, game.weather], Color("ffe7a6")))
	for index in range(game.RACE_BEASTS.size()):
		var beast: Dictionary = game.RACE_BEASTS[index]
		modal_body.add_child(_make_text("%s：速度%d / 耐力%d / 爆发%d / 稳定%d · 独胜参考 %.2f" % [
			str(beast["name"]), int(beast["speed"]), int(beast["stamina"]), int(beast["burst"]), int(beast["stability"]), game.race_odds(index, "独胜")
		]))


func _open_tower() -> void:
	_open_modal("万象塔")
	modal_body.add_child(_art_banner(IslandPanorama, 210.0))
	var count: int = int(game.discovered_recipe_count())
	modal_body.add_child(_make_text("塔身会回应你真正理解并留下的造物。当前图鉴：%d / %d。" % [count, game.RECIPES.size()], Color("d8f4f8")))
	var floors := [
		{"need": 1, "name": "潮纹廊", "reward": "记录第一种稳定造物"},
		{"need": 3, "name": "造物回廊", "reward": "开放组合关系陈列"},
		{"need": 6, "name": "风贝台", "reward": "开放岛民需求与稀有线索"},
		{"need": 9, "name": "塔心观象室", "reward": "进入下一阶段的万物研究"}
	]
	for raw_floor in floors:
		var floor: Dictionary = raw_floor
		var unlocked: bool = count >= int(floor["need"])
		var prefix := "✓ 已点亮" if unlocked else "◇ 尚需%d种" % (int(floor["need"]) - count)
		modal_body.add_child(_make_text("%s　%s · %s" % [prefix, str(floor["name"]), str(floor["reward"])], Color("f0d27e") if unlocked else Color("82989a")))
	modal_body.add_child(_make_button("查看万物图鉴", _open_collection))
	modal_body.add_child(_make_button("前往造化盆", _open_synthesis))


func _open_poker(message: String = "") -> void:
	_open_modal("命运牌会 · 选择桌级")
	modal_body.add_child(_make_text("桌级提高会同步提高本局上限、基础投入和NPC带来的钱包。高桌不是单纯放大按钮，而是让财富跃升与输光风险同时变得明显。", Color("d5e8e4")))
	modal_body.add_child(_make_text("当前持有%d金贝 · 财富头衔：%s" % [game.cash, game.wealth_title()], Color("f0d27e")))
	for raw_tier in game.poker_tiers():
		var tier: Dictionary = raw_tier
		var buy_in := int(tier["buy_in"])
		var requirement := int(tier["wealth_required"])
		var available: bool = bool(game.can_enter_poker_tier(buy_in))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("b79959") if available else Color("46585b")))
		var row := HBoxContainer.new()
		panel.add_child(row)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_child(_make_text("%s · 上限%d金贝 · 基础投入%d/%d" % [str(tier["name"]), buy_in, int(tier["small_blind"]), int(tier["big_blind"])], Color("f2d984") if available else Color("91a1a3")))
		copy.add_child(_make_text("%s%s" % [str(tier["description"]), " · 需财富%d" % requirement if requirement > 0 else ""], Color("b9cfcd")))
		row.add_child(copy)
		row.add_child(_make_button("入席" if available else "尚未开放", _enter_poker_tier.bind(buy_in, message), not available))
		modal_body.add_child(panel)


func _enter_poker_tier(buy_in: int, message: String = "") -> void:
	modal_overlay.visible = false
	game.begin_poker_session(buy_in)
	poker_table.open(message)
	player.controls_enabled = false


func _on_poker_table_closed() -> void:
	game.end_poker_session()
	player.controls_enabled = true
	_refresh_hud()


func _open_race() -> void:
	_open_modal("逐风竞速 · 八兽四段")
	modal_body.add_child(_art_banner(RaceBanner, 190.0))
	modal_body.add_child(_make_text("每场依次经过起步、巡航、地形和冲刺四段。已发现造物可以在下注前提供额外情报；每场最多部署一个、只支付部署费、造物永久保留且不会暗改赛果。", Color("c9f6d8")))
	race_beast_option = OptionButton.new()
	for beast in game.RACE_BEASTS:
		race_beast_option.add_item(str(beast["name"]))
	race_beast_option.item_selected.connect(_update_race_preview)
	modal_body.add_child(_labeled_control("选择逐风兽", race_beast_option))

	race_ticket_option = OptionButton.new()
	for ticket_type in game.ticket_types():
		race_ticket_option.add_item(ticket_type)
	race_ticket_option.item_selected.connect(_update_race_preview)
	modal_body.add_child(_labeled_control("祝胜券类型", race_ticket_option))

	race_aid_option = OptionButton.new()
	race_aid_option.add_item("不使用造物")
	race_aid_option.set_item_metadata(0, "")
	for aid_id in game.race_aids_available():
		var aid: Dictionary = game.RACE_AIDS[aid_id]
		race_aid_option.add_item("%s · %d金贝" % [str(aid["name"]), int(aid["fee"])])
		race_aid_option.set_item_metadata(race_aid_option.item_count - 1, aid_id)
	race_aid_option.item_selected.connect(_update_race_preview)
	modal_body.add_child(_labeled_control("赛前造物", race_aid_option))

	race_bet_spin = SpinBox.new()
	race_bet_spin.min_value = 10
	race_bet_spin.max_value = maxi(10, game.race_bet_cap())
	race_bet_spin.step = 10
	race_bet_spin.value = mini(20, maxi(10, game.race_bet_cap()))
	modal_body.add_child(_labeled_control("下注金贝", race_bet_spin))
	race_preview_label = _make_text("")
	modal_body.add_child(race_preview_label)
	modal_body.add_child(_make_button("开始比赛", _run_race, game.free_race_ticket <= 0 and game.cash < 10))
	_update_race_preview(0)


func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _make_text(label_text)
	label.custom_minimum_size.x = 150
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _update_race_preview(_selected_index: int) -> void:
	if race_beast_option == null or race_ticket_option == null or race_aid_option == null or race_preview_label == null:
		return
	var beast_index := race_beast_option.selected
	var ticket_type := race_ticket_option.get_item_text(race_ticket_option.selected)
	var beast: Dictionary = game.RACE_BEASTS[beast_index]
	var aid_id := str(race_aid_option.get_item_metadata(race_aid_option.selected))
	var aid_info: Dictionary = game.race_aid_info(aid_id, beast_index)
	var free_text := "本场优先使用免费体验券（固定10金贝票面）" if game.free_race_ticket > 0 else "正式下注"
	race_preview_label.text = "%s · 速度%d / 耐力%d / 爆发%d / 稳定%d\n%s · 当前参考赔率 %.2f · 本场最多投入%d金贝\n%s：%s" % [
		str(beast["name"]), int(beast["speed"]), int(beast["stamina"]), int(beast["burst"]), int(beast["stability"]),
		free_text, game.race_odds(beast_index, ticket_type), game.race_bet_cap(game.cash - int(aid_info.get("fee", 0))),
		str(aid_info.get("name", "公开信息")), str(aid_info.get("insight", "本场不部署造物。"))
	]


func _run_race() -> void:
	var beast_index := race_beast_option.selected
	var ticket_type := race_ticket_option.get_item_text(race_ticket_option.selected)
	var aid_id := str(race_aid_option.get_item_metadata(race_aid_option.selected))
	var result: Dictionary = game.run_race(beast_index, ticket_type, int(race_bet_spin.value), aid_id)
	_open_modal("逐风竞速 · 结算")
	modal_body.add_child(_art_banner(RaceBanner, 160.0))
	modal_body.add_child(_make_text(str(result.get("text", "赛事未能开始。")), Color("fff2b0")))
	if bool(result.get("ok", false)):
		modal_body.add_child(_make_text("赛前造物：%s · 部署费%d金贝\n%s" % [str(result.get("aid_name", "不使用造物")), int(result.get("aid_fee", 0)), str(result.get("aid_insight", ""))], Color("9fe0ba")))
		modal_body.add_child(_make_text("票面%d金贝 · 赔率%.2f · 派彩%d金贝 · 本场净变化%+d金贝 · 当前%d金贝" % [int(result.get("stake", 0)), float(result.get("odds", 1.0)), int(result.get("payout", 0)), int(result.get("net_cash", 0)), int(result.get("cash_after", game.cash))], Color("f0d27e")))
		modal_body.add_child(_make_text("四段赛程回放", Color("f0d27e")))
		var stages := HBoxContainer.new()
		stages.add_theme_constant_override("separation", 8)
		for raw_stage in result.get("stage_reports", []):
			var stage: Dictionary = raw_stage
			var stage_panel := PanelContainer.new()
			stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stage_panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("5f8286")))
			var stage_copy := VBoxContainer.new()
			stage_panel.add_child(stage_copy)
			var stage_name := _make_text(str(stage["stage"]), Color("f0d27e"))
			stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stage_copy.add_child(stage_name)
			var leader := _make_text("领先：%s" % str(stage["leader"]), Color("c9dcda"))
			leader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stage_copy.add_child(leader)
			var selected := _make_text("所选第%d" % int(stage["selected_rank"]), Color("8ee0b1") if int(stage["selected_rank"]) <= 3 else Color("e4a29a"))
			selected.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stage_copy.add_child(selected)
			stages.add_child(stage_panel)
		modal_body.add_child(stages)
		var ranking: Array[String] = []
		for index in range(result["results"].size()):
			ranking.append("%d. %s" % [index + 1, str(result["results"][index]["name"])])
		modal_body.add_child(_make_text("完整排名\n%s" % "\n".join(ranking)))
		modal_body.add_child(_make_button("再看一场", _open_race))


func _open_map() -> void:
	_open_modal("岛屿地图")
	modal_body.add_child(_art_banner(IslandPanorama, 230.0))
	modal_body.add_child(_make_text("走到区域后即可永久发现。已发现区域之间快速移动不消耗潮刻。", Color("bde9f2")))
	for area_name in ["漂流湾", "椰影街", "逐风海岸"]:
		var unlocked := discovered_areas.has(area_name)
		modal_body.add_child(_make_button(("前往 " if unlocked else "尚未发现 ") + area_name, _travel_to.bind(area_name), not unlocked))


func _travel_to(area_name: String) -> void:
	var positions := {
		"漂流湾": Vector2(320, 360),
		"椰影街": Vector2(900, 360),
		"逐风海岸": Vector2(1450, 360)
	}
	if not discovered_areas.has(area_name) or not positions.has(area_name):
		return
	player.global_position = positions[area_name]
	current_area = area_name
	_close_modal()
	_show_toast("已快速前往%s；未消耗潮刻。" % area_name)
