extends Node2D

@export var title_screen_enabled: bool = true

var title_save_override_enabled: bool = false
var title_save_paths_override: Array[String] = []

const GameStateScript = preload("res://scripts/game_state.gd")
const MarkerScript = preload("res://scripts/interactable.gd")
const PokerTableScript = preload("res://scripts/poker_table.gd")
const SynthesisTableScript = preload("res://scripts/synthesis_table.gd")
const DiveTableScript = preload("res://scripts/dive_table.gd")
const WealthChartScript = preload("res://scripts/wealth_chart.gd")
const RaceReplayScript = preload("res://scripts/race_replay.gd")
const RaceArenaScript = preload("res://scripts/race_arena.gd")
const WorldLayoutScript = preload("res://scripts/world_layout.gd")
const MapOverviewScript = preload("res://scripts/map_overview.gd")
const NpcCatalogScript = preload("res://scripts/npc_catalog.gd")
const PixelCharacterScene = preload("res://scenes/components/pixel_character_animator.tscn")
const IslandGroundMap = preload("res://assets/art/environments/world_map_v2/island_ground_map_v2.png")
const SynthesisCollectionAtlas = preload("res://assets/art/synthesis_collection_atlas_v1.png")
const RaceBanner = preload("res://assets/art/race_banner_v1.png")
const ShopMaterialAtlas = preload("res://assets/art/shop_material_atlas_v1.png")

@onready var player: CharacterBody2D = $Player
@onready var markers_root: Node2D = $Markers
@onready var npc_visuals_root: Node2D = $NPCVisuals
@onready var world_root: Node2D = $World
@onready var world_lighting: WorldLighting = $WorldLighting
@onready var ui_layer: CanvasLayer = $UILayer

var game
var markers: Array[Node2D] = []
var marker_by_id := {}
var npc_visual_by_id := {}
var resident_visual_by_id := {}
var resident_visuals_root: Node2D
var nearest_marker: Node2D
var discovered_areas := {"漂流湾": true}
var current_area := "漂流湾"
var clock_hud_elapsed: float = 0.0
var day_end_notice_day: int = 0
var last_npc_phase: String = ""
var initial_player_position := Vector2.ZERO

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
var synthesis_table: Control
var dive_table: Control
var tutorial_panel: PanelContainer
var tutorial_progress_label: Label
var tutorial_title_label: Label
var tutorial_description_label: Label
var tutorial_target_label: Label
var title_overlay: Control
var title_continue_button: Button
var title_new_button: Button
var title_status_label: Label
var title_latest_save: Dictionary = {}
var title_new_confirm_pending: bool = false
var collection_view: String = "items"
var collection_tier_filter: int = 0
var collection_category_filter: String = "全部"

var race_beast_option: OptionButton
var race_ticket_option: OptionButton
var race_aid_option: OptionButton
var race_bet_spin: SpinBox
var race_preview_label: Label
var race_event_id: String = ""
var race_replay: Control
var race_arena: Control


func _ready() -> void:
	game = GameStateScript.new()
	game.changed.connect(_refresh_hud)
	game.notice.connect(_show_toast)
	game.time_boundary.connect(_on_time_boundary)
	_build_world_collisions()
	_build_markers()
	_build_npc_visuals()
	_apply_npc_schedule()
	_build_ui()
	initial_player_position = player.global_position
	player.interact_requested.connect(_interact)
	player.inventory_requested.connect(_open_collection)
	_refresh_hud()
	# Optional local visual-QA entry points.
	var user_args := OS.get_cmdline_user_args()
	var preview_mode := false
	if user_args.has("preview-poker") or user_args.has("preview-rules"):
		preview_mode = true
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
		preview_mode = true
		_open_collection()
	elif user_args.has("preview-shop"):
		preview_mode = true
		_open_shop()
	elif user_args.has("preview-synthesis"):
		preview_mode = true
		_open_synthesis()
	elif user_args.has("preview-home"):
		preview_mode = true
		_open_home()
	if title_screen_enabled and not preview_mode:
		_build_title_screen()


func _process(delta: float) -> void:
	var title_open: bool = title_overlay != null and title_overlay.visible
	game.set_time_pause("title_screen", title_open, game.TIME_STATE_UI)
	if title_open:
		return
	var dive_activity_open: bool = dive_table != null and dive_table.visible and dive_table.mode == "dive"
	var dive_interface_open: bool = dive_table != null and dive_table.visible and dive_table.mode != "dive"
	var formal_activity_open: bool = (synthesis_table != null and synthesis_table.visible) or (poker_table != null and poker_table.visible) or dive_activity_open
	game.set_time_pause("formal_activity", formal_activity_open, game.TIME_STATE_ACTIVITY)
	var race_interface_open: bool = race_arena != null and race_arena.visible
	game.set_time_pause("interface", (modal_overlay != null and modal_overlay.visible) or dive_interface_open or race_interface_open, game.TIME_STATE_UI)
	if game.advance_world_delta(delta):
		clock_hud_elapsed += delta
		if clock_hud_elapsed >= 0.5:
			clock_hud_elapsed = 0.0
			_refresh_hud()
	if game.day_end_pending and day_end_notice_day != game.day:
		day_end_notice_day = game.day
		_show_toast("夜深了，世界时间已经停驻。回漂流小屋查看结算并休息。")
	_update_area_discovery()
	_update_nearest_marker()
	if last_npc_phase != game.phase_name():
		_apply_npc_schedule()
	if not game.journey_tutorial_actions.has("move") and player.global_position.distance_to(initial_player_position) >= 48.0:
		game.record_journey_tutorial_action("move")


func _notification(what: int) -> void:
	if game == null:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		game.set_time_pause("focus_lost", true, game.TIME_STATE_UI)
		if dive_table != null and dive_table.visible and dive_table.mode == "dive":
			dive_table.set_activity_pause("focus", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		game.set_time_pause("focus_lost", false)
		if dive_table != null:
			dive_table.set_activity_pause("focus", false)


func _unhandled_input(event: InputEvent) -> void:
	if race_arena != null and race_arena.visible and event.is_action_pressed("ui_cancel"):
		race_arena.close()
		get_viewport().set_input_as_handled()
		return
	if title_overlay != null and title_overlay.visible:
		get_viewport().set_input_as_handled()
		return
	if dive_table != null and dive_table.visible:
		if event.is_action_pressed("interact") and dive_table.mode == "dive":
			dive_table.handle_interact()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			dive_table.request_close()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") and synthesis_table != null and synthesis_table.visible:
		synthesis_table.request_close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and poker_table != null and poker_table.visible:
		poker_table.request_close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and modal_overlay.visible:
		_close_modal()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_open_time_menu()
		get_viewport().set_input_as_handled()


func _build_markers() -> void:
	for definition in WorldLayoutScript.MARKERS:
		_add_marker(
			str(definition["id"]),
			str(definition["label"]),
			definition["position"],
			definition["color"]
		)
	for raw_profile in game.ENVIRONMENT_RESIDENTS:
		var profile: Dictionary = raw_profile
		_add_marker(
			str(profile["id"]),
			str(profile["name"]),
			Vector2.ZERO,
			Color(str(profile.get("color", "9bb8b8")))
		)


func _build_npc_visuals() -> void:
	for definition in WorldLayoutScript.NPC_VISUALS:
		var holder := Node2D.new()
		var character_id := str(definition["id"])
		holder.name = character_id
		holder.position = definition["position"]
		var animator: PixelCharacterAnimator = PixelCharacterScene.instantiate()
		animator.atlas_texture = load(str(definition["atlas"]))
		animator.walk_frame_count = 4
		animator.idle_frame_count = 4
		animator.use_placeholder_when_missing = false
		animator.facing = int(definition.get("facing", PixelCharacterAnimator.Facing.DOWN))
		holder.add_child(animator)
		npc_visuals_root.add_child(holder)
		npc_visual_by_id[character_id] = holder
	resident_visuals_root = Node2D.new()
	resident_visuals_root.name = "ResidentVisuals"
	add_child(resident_visuals_root)
	for raw_profile in game.ENVIRONMENT_RESIDENTS:
		var profile: Dictionary = raw_profile
		var holder := Node2D.new()
		var resident_id := str(profile["id"])
		holder.name = resident_id
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([Vector2(-13, 13), Vector2(13, 13), Vector2(9, 18), Vector2(-9, 18)])
		shadow.color = Color("07171b88")
		holder.add_child(shadow)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([Vector2(0, -22), Vector2(13, -4), Vector2(10, 16), Vector2(-10, 16), Vector2(-13, -4)])
		body.color = Color(str(profile.get("color", "9bb8b8")))
		holder.add_child(body)
		var face := Polygon2D.new()
		face.polygon = PackedVector2Array([Vector2(-7, -20), Vector2(7, -20), Vector2(9, -9), Vector2(0, -4), Vector2(-9, -9)])
		face.color = Color("e8c59d")
		holder.add_child(face)
		resident_visuals_root.add_child(holder)
		resident_visual_by_id[resident_id] = holder


func _on_time_boundary(kind: String, _data: Dictionary) -> void:
	if kind in ["phase", "day_end"]:
		_apply_npc_schedule()
	if kind == "phase":
		_show_toast("进入%s：人物日程、鱼市报价与公开活动已经刷新。" % game.phase_name())
	elif kind == "share_close":
		_show_toast("潮汐商会已经收盘；现在只能提交次日开盘订单。")


func _apply_npc_schedule() -> void:
	if game == null:
		return
	last_npc_phase = game.phase_name()
	for npc_id in NpcCatalogScript.core_ids():
		var schedule: Dictionary = game.npc_schedule_entry(npc_id)
		var available := bool(schedule.get("available", false))
		var marker = marker_by_id.get(npc_id)
		if marker != null:
			marker.position = schedule.get("position", marker.position)
			marker.visible = available
		var visual = npc_visual_by_id.get(npc_id)
		if visual != null:
			visual.position = schedule.get("visual_position", schedule.get("position", visual.position))
			visual.visible = available
	for raw_entry in game.environment_resident_entries():
		var entry: Dictionary = raw_entry
		var resident_id := str(entry["id"])
		var available := bool(entry.get("available", false))
		var marker = marker_by_id.get(resident_id)
		if marker != null:
			marker.position = entry.get("position", marker.position)
			marker.visible = available
		var visual = resident_visual_by_id.get(resident_id)
		if visual != null:
			visual.position = entry.get("position", visual.position) + Vector2(-20, 22)
			visual.visible = available


func _build_world_collisions() -> void:
	var collision_root := Node2D.new()
	collision_root.name = "GeneratedCollision"
	world_root.add_child(collision_root)
	for index in range(WorldLayoutScript.BLOCKERS.size()):
		var blocker: Rect2 = WorldLayoutScript.BLOCKERS[index]
		var body := StaticBody2D.new()
		body.name = "Blocker%02d" % index
		body.position = blocker.get_center()
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = blocker.size
		shape_node.shape = shape
		body.add_child(shape_node)
		collision_root.add_child(body)


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
	var schedule_button := _make_button("日程", _open_time_menu)
	schedule_button.custom_minimum_size.x = 74
	top_row.add_child(schedule_button)
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

	tutorial_panel = PanelContainer.new()
	tutorial_panel.name = "JourneyTutorialPanel"
	tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tutorial_panel.offset_left = 20
	tutorial_panel.offset_top = 90
	tutorial_panel.offset_right = 350
	tutorial_panel.offset_bottom = 300
	tutorial_panel.add_theme_stylebox_override("panel", _panel_style(Color("17363dea"), Color("d5bd68")))
	ui_root.add_child(tutorial_panel)
	var tutorial_box := VBoxContainer.new()
	tutorial_box.add_theme_constant_override("separation", 7)
	tutorial_panel.add_child(tutorial_box)
	var tutorial_header := HBoxContainer.new()
	tutorial_header.add_theme_constant_override("separation", 8)
	tutorial_box.add_child(tutorial_header)
	tutorial_progress_label = _make_text("旅程引导", Color("f3d77d"))
	tutorial_progress_label.add_theme_font_size_override("font_size", 18)
	tutorial_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_header.add_child(tutorial_progress_label)
	var tutorial_hide := _make_button("隐藏", _hide_journey_tutorial)
	tutorial_hide.name = "HideJourneyTutorial"
	tutorial_hide.custom_minimum_size = Vector2(64, 30)
	tutorial_header.add_child(tutorial_hide)
	tutorial_title_label = _make_text("", Color("eef4e8"))
	tutorial_title_label.add_theme_font_size_override("font_size", 20)
	tutorial_box.add_child(tutorial_title_label)
	tutorial_description_label = _make_text("", Color("c6d8d5"))
	tutorial_description_label.custom_minimum_size.y = 45
	tutorial_box.add_child(tutorial_description_label)
	tutorial_target_label = _make_text("", Color("8eddb7"))
	tutorial_box.add_child(tutorial_target_label)
	var tutorial_map := _make_button("在地图上查看目标", _open_tutorial_map)
	tutorial_map.name = "JourneyTutorialMap"
	tutorial_box.add_child(tutorial_map)

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
	modal_panel.anchor_left = 0.08
	modal_panel.anchor_top = 0.05
	modal_panel.anchor_right = 0.92
	modal_panel.anchor_bottom = 0.95
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
	synthesis_table = SynthesisTableScript.new()
	synthesis_table.setup(game)
	synthesis_table.closed.connect(_on_synthesis_table_closed)
	synthesis_table.collection_requested.connect(_on_synthesis_collection_requested)
	ui_root.add_child(synthesis_table)
	dive_table = DiveTableScript.new()
	dive_table.setup(game)
	dive_table.closed.connect(_on_dive_table_closed)
	dive_table.checkpoint_requested.connect(_on_dive_checkpoint_requested)
	ui_root.add_child(dive_table)
	race_arena = RaceArenaScript.new()
	race_arena.closed.connect(_on_race_arena_closed)
	race_arena.race_requested.connect(_run_race_from_arena)
	race_arena.history_requested.connect(_open_race_history_from_arena)
	ui_root.add_child(race_arena)


func _build_title_screen() -> void:
	title_overlay = Control.new()
	title_overlay.name = "TitleScreen"
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(title_overlay)

	var background := TextureRect.new()
	background.texture = IslandGroundMap
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color("c7d8cc")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_overlay.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.085, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_overlay.add_child(shade)

	var margin := MarginContainer.new()
	margin.anchor_left = 0.08
	margin.anchor_top = 0.08
	margin.anchor_right = 0.92
	margin.anchor_bottom = 0.92
	title_overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("15343bf2"), Color("89b4ac")))
	margin.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	panel.add_child(page)
	var eyebrow := _make_text("一座会记住你的选择、发现与财富起伏的海岛", Color("9edab9"))
	eyebrow.add_theme_font_size_override("font_size", 17)
	page.add_child(eyebrow)
	var title := _make_text("万物之岛", Color("f2d57c"))
	title.add_theme_font_size_override("font_size", 46)
	page.add_child(title)
	page.add_child(_make_text("从三种根源出发，发现万物；在潜捕、交易、牌会与竞速之间，经营一段属于自己的岛上生活。", Color("e8f0e9")))
	page.add_child(HSeparator.new())

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	page.add_child(content)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	content.add_child(left)
	left.add_child(_make_text("你的旅程没有唯一顺序", Color("f2d57c")))
	left.add_child(_make_text("• 在造化盆里建立四层万物谱系\n• 潜入海岸、阅读鱼市并完成角色订单\n• 从命运牌会与逐风竞速中承担风险\n• 用商会份契、居所收藏和归潮盛典留下长期成果", Color("c9ddda")))
	var principle := PanelContainer.new()
	principle.add_theme_stylebox_override("panel", _panel_style(Color("1d4146c8"), Color("6a8e8c")))
	left.add_child(principle)
	principle.add_child(_make_text("玩法提示会根据真实进度逐步推进。你可以随时隐藏引导，也可以先去任何感兴趣的地方。", Color("a8e0c1")))
	left.add_spacer(false)
	left.add_child(_make_text("版本 %d · 存档采用原子替换与7日轮换自动备份" % game.SAVE_VERSION, Color("8eaaa9")))

	var save_card := PanelContainer.new()
	save_card.custom_minimum_size.x = 355
	save_card.add_theme_stylebox_override("panel", _panel_style(Color("102a31ef"), Color("d0b963")))
	content.add_child(save_card)
	var save_box := VBoxContainer.new()
	save_box.add_theme_constant_override("separation", 11)
	save_card.add_child(save_box)
	save_box.add_child(_make_text("继续你的岛上生活", Color("f2d57c")))
	var summaries: Array = []
	if title_save_override_enabled:
		summaries = game.available_save_summaries(title_save_paths_override) if not title_save_paths_override.is_empty() else []
	else:
		summaries = game.available_save_summaries()
	title_latest_save = summaries[0].duplicate(true) if not summaries.is_empty() else {}
	var summary_copy := "还没有可读取的旅程。新游戏会从第1天清晨、120金贝与三种根源开始。"
	if not title_latest_save.is_empty():
		summary_copy = "%s · %s\n第%d天 %d/16潮刻 · %s · %s\n持有%d金贝 · 已发现%d项万物%s\n保存于 %s" % [
			str(title_latest_save.get("kind", "存档")), str(title_latest_save.get("area", "漂流湾")),
			int(title_latest_save.get("day", 1)), int(title_latest_save.get("tide", 1)), str(title_latest_save.get("weather", "晴")), str(title_latest_save.get("wind", "侧风")),
			int(title_latest_save.get("account_wealth", 0)), int(title_latest_save.get("discovered_count", 3)),
			" · 已完成归潮盛典" if bool(title_latest_save.get("finale_completed", false)) else "",
			_format_save_time(int(title_latest_save.get("saved_at_unix", 0)))
		]
	save_box.add_child(_make_text(summary_copy, Color("c8dcda")))
	title_status_label = _make_text("选择继续或开始一段新旅程。", Color("9fbbb8"))
	title_status_label.name = "TitleStatus"
	title_status_label.custom_minimum_size.y = 42
	save_box.add_child(title_status_label)
	title_continue_button = _make_button("继续游戏", _continue_latest_save, title_latest_save.is_empty())
	title_continue_button.name = "ContinueGame"
	title_continue_button.custom_minimum_size.y = 48
	save_box.add_child(title_continue_button)
	title_new_button = _make_button("新游戏", _start_new_game)
	title_new_button.name = "NewGame"
	title_new_button.custom_minimum_size.y = 48
	save_box.add_child(title_new_button)
	var quit_button := _make_button("退出游戏", _quit_from_title)
	quit_button.name = "QuitGame"
	save_box.add_child(quit_button)
	player.controls_enabled = false
	_refresh_tutorial_panel()


func _format_save_time(unix_time: int) -> String:
	if unix_time <= 0:
		return "未知时间"
	var parts: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [int(parts["year"]), int(parts["month"]), int(parts["day"]), int(parts["hour"]), int(parts["minute"])]


func _continue_latest_save() -> void:
	if title_latest_save.is_empty():
		title_status_label.text = "没有找到可读取的存档。"
		return
	var result: Dictionary = game.load_game(str(title_latest_save.get("path", "")))
	if not bool(result.get("ok", false)):
		title_status_label.text = str(result.get("text", "读档失败，当前状态未被修改。"))
		return
	var world = result.get("world", {})
	_apply_loaded_world(world if world is Dictionary else {})
	_enter_world("已读取%s。" % str(title_latest_save.get("kind", "存档")))


func _start_new_game() -> void:
	if not title_latest_save.is_empty() and not title_new_confirm_pending:
		title_new_confirm_pending = true
		title_status_label.text = "再次点击确认开始新旅程。现有存档不会立即删除；只有之后主动保存才会替换手动档。"
		title_status_label.add_theme_color_override("font_color", Color("f0d27e"))
		title_new_button.text = "确认开始新旅程"
		return
	_enter_world("新旅程开始了。旅程引导会记录真实玩法进度。")


func _enter_world(message: String) -> void:
	title_overlay.visible = false
	game.set_time_pause("title_screen", false)
	player.controls_enabled = true
	initial_player_position = player.global_position
	_refresh_hud()
	_show_toast(message)


func _quit_from_title() -> void:
	get_tree().quit()


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
	# Most modal actions rebuild the tree that owns the pressed button. Run the
	# action after BaseButton has finished emitting so a page transition cannot
	# free its own native signal emitter.
	button.pressed.connect(action, CONNECT_DEFERRED)
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


func _item_art(item_id: String, size_value: float = 150.0, discovered_value: bool = true) -> TextureRect:
	var atlas := AtlasTexture.new()
	var source: String = str(game.item_art_source(item_id))
	var index: int = int(game.item_art_index(item_id))
	if source == "creation":
		atlas.atlas = SynthesisCollectionAtlas
		var tile_width := float(SynthesisCollectionAtlas.get_width()) / 3.0
		var tile_height := float(SynthesisCollectionAtlas.get_height()) / 3.0
		atlas.region = Rect2((index % 3) * tile_width, (index / 3) * tile_height, tile_width, tile_height)
	else:
		atlas.atlas = ShopMaterialAtlas
		var tile_width := float(ShopMaterialAtlas.get_width()) / 4.0
		var tile_height := float(ShopMaterialAtlas.get_height()) / 4.0
		atlas.region = Rect2((index % 4) * tile_width, (index / 4) * tile_height, tile_width, tile_height)
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
	world_lighting.set_environment(game.phase_name(), game.weather)
	var coin_text := "金贝 %d" % game.cash
	if game.locked_principal > 0 or game.share_reserved_cash > 0:
		coin_text = "金贝总计 %d · 可用 %d · 活动中 %d · 待撮合 %d" % [game.account_wealth(), game.cash, game.locked_principal, game.share_reserved_cash]
	var progress_percent := int(round(game.tide_progress * 100.0))
	var clock_text := "日终停驻" if game.day_end_pending else "%s档 %d%% · %s" % [game.time_speed_mode, progress_percent, game.time_state_label()]
	hud_label.text = "第%d天 · %s %d/16 · %s · %s · %s\n%s · %s · %s · 建议留存 %d金贝" % [
		game.day, game.phase_name(), game.tide, game.weather, game.wind_direction, current_area,
		coin_text, game.wealth_title(), clock_text, game.suggested_reserve()
	]
	inventory_button.text = "万物 %d" % game.discovered_item_ids().size()
	_refresh_tutorial_panel()


func _refresh_tutorial_panel() -> void:
	if tutorial_panel == null or game == null:
		return
	var state: Dictionary = game.journey_tutorial_state()
	var title_open: bool = title_overlay != null and title_overlay.visible
	tutorial_panel.visible = not title_open and not bool(state.get("hidden", false)) and not bool(state.get("complete", false))
	if not tutorial_panel.visible:
		return
	var current: Dictionary = state.get("current", {})
	tutorial_progress_label.text = "旅程引导 · %d/%d" % [int(state.get("completed_count", 0)), int(state.get("total", 0))]
	tutorial_title_label.text = str(current.get("title", "继续探索"))
	tutorial_description_label.text = str(current.get("description", "岛上的系统会随你的真实行动逐步展开。"))
	tutorial_target_label.text = "下一站：%s" % str(current.get("target", "查看地图"))


func _hide_journey_tutorial() -> void:
	game.set_journey_tutorial_hidden(true)
	_show_toast("旅程引导已隐藏；可在“日程”中重新显示。")


func _show_journey_tutorial() -> void:
	var state: Dictionary = game.journey_tutorial_state()
	if bool(state.get("complete", false)):
		_show_result("旅程引导", "七个基础步骤已经全部完成。岛上的长期目标仍可继续自由推进。", _open_time_menu)
		return
	game.set_journey_tutorial_hidden(false)
	_close_modal()
	_show_toast("旅程引导已重新显示。")


func _open_tutorial_map() -> void:
	_open_map()


func _update_area_discovery() -> void:
	var next_area := WorldLayoutScript.area_for_position(player.global_position)
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
		prompt_label.text = "%s · WASD / 方向键移动 · I / Tab 万物图鉴" % current_area
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
		"fish": _open_dive("prep")
		"fish_market": _open_dive("market")
		"basin": _open_synthesis()
		"granny", "old_joe", "aqiu", "mia", "milo", "shopkeeper": _open_npc(nearest_marker.interaction_id)
		"shop": _open_shop()
		"exchange": _open_share_market()
		"tea": _open_poker()
		"news": _open_news()
		"tower": _open_tower()
		"race": _open_race()
		_:
			if str(nearest_marker.interaction_id).begins_with("resident_"):
				_open_resident(nearest_marker.interaction_id)


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


func _open_collection(view_value: String = "") -> void:
	if not view_value.is_empty():
		collection_view = view_value
	var titles := {
		"items": "万物图鉴",
		"recent": "最近发现与实验",
		"credentials": "账户凭证",
		"marine": "海生图鉴"
	}
	_open_modal(str(titles.get(collection_view, "万物图鉴")))
	var discovered_count: int = game.discovered_item_ids().size()
	var goal: Dictionary = game.synthesis_goal()
	modal_body.add_child(_make_text("永久万物 %d / %d · 稳定关系 %d / %d" % [discovered_count, game.ITEMS.size(), game.discovered_recipe_count(), game.RECIPES.size()], Color("f2d984")))
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 18
	progress.show_percentage = false
	progress.value = float(discovered_count) / float(game.ITEMS.size()) * 100.0
	progress.add_theme_stylebox_override("background", _progress_style(Color("173039"), Color("526f73")))
	progress.add_theme_stylebox_override("fill", _progress_style(Color("b3954f"), Color("f0d27e")))
	modal_body.add_child(progress)
	modal_body.add_child(_make_text("当前目标：%s · %s" % [str(goal.get("title", "")), str(goal.get("description", ""))], Color("9fdcc1")))

	var nav := GridContainer.new()
	nav.columns = 4
	nav.add_theme_constant_override("h_separation", 8)
	nav.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(nav)
	nav.add_child(_make_button("万物总览", _set_collection_view.bind("items"), collection_view == "items"))
	nav.add_child(_make_button("最近发现", _set_collection_view.bind("recent"), collection_view == "recent"))
	nav.add_child(_make_button("账户凭证", _set_collection_view.bind("credentials"), collection_view == "credentials"))
	nav.add_child(_make_button("海生图鉴", _set_collection_view.bind("marine"), collection_view == "marine"))

	match collection_view:
		"recent":
			_build_collection_recent()
		"credentials":
			_build_collection_credentials()
		"marine":
			_build_collection_marine()
		_:
			_build_collection_items()


func _set_collection_view(view_value: String) -> void:
	collection_view = view_value
	_open_collection()


func _build_collection_items() -> void:
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 10)
	modal_body.add_child(filter_row)
	var tier_filter := OptionButton.new()
	tier_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label in ["全部阶层", "一阶", "二阶", "三阶", "四阶"]:
		tier_filter.add_item(label)
	tier_filter.select(collection_tier_filter)
	tier_filter.item_selected.connect(_set_collection_tier_filter, CONNECT_DEFERRED)
	filter_row.add_child(tier_filter)
	var category_filter := OptionButton.new()
	category_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_filter.add_item("全部类别")
	var categories: Array[String] = game.collection_categories()
	for category in categories:
		category_filter.add_item(category)
	var selected_category_index := 0
	if collection_category_filter != "全部":
		var found_index: int = categories.find(collection_category_filter)
		selected_category_index = found_index + 1 if found_index >= 0 else 0
	category_filter.select(selected_category_index)
	category_filter.item_selected.connect(_set_collection_category_filter.bind(categories), CONNECT_DEFERRED)
	filter_row.add_child(category_filter)

	var tier_parts: Array[String] = []
	for tier in range(1, 5):
		var tier_progress: Dictionary = game.tier_discovery_progress(tier)
		tier_parts.append("%d阶 %d/%d" % [tier, int(tier_progress["found"]), int(tier_progress["total"])])
	modal_body.add_child(_make_text("　".join(tier_parts), Color("a9c7c4")))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	var all_ids: Array[String] = []
	for raw_id in game.ITEMS.keys():
		all_ids.append(str(raw_id))
	all_ids.sort_custom(func(a: String, b: String):
		if game.item_tier(a) != game.item_tier(b):
			return game.item_tier(a) < game.item_tier(b)
		return game.item_name(a) < game.item_name(b)
	)
	var visible_count := 0
	for item_id in all_ids:
		var known: bool = game.is_discovered(item_id)
		if collection_tier_filter > 0 and game.item_tier(item_id) != collection_tier_filter:
			continue
		if collection_category_filter != "全部":
			if not known or str(game.ITEMS[item_id].get("category", "")) != collection_category_filter:
				continue
		grid.add_child(_collection_item_card(item_id, known))
		visible_count += 1
	if visible_count == 0:
		modal_body.add_child(_make_text("当前筛选下没有可显示的条目。", Color("8fa1a3")))
	modal_body.add_child(_make_button("前往造化盆继续发现", _open_synthesis))


func _set_collection_tier_filter(index: int) -> void:
	collection_tier_filter = clampi(index, 0, 4)
	_open_collection("items")


func _set_collection_category_filter(index: int, categories: Array) -> void:
	collection_category_filter = "全部" if index <= 0 else str(categories[index - 1])
	_open_collection("items")


func _collection_item_card(item_id: String, known: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 278)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), Color("b99e5d") if known else Color("41565a")))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(_item_art(item_id, 132.0, known))
	var name_label := _make_text(game.item_name(item_id) if known else "◇ 未发现暗格", Color("f1d68b") if known else Color("7d9294"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 19)
	box.add_child(name_label)
	if known:
		var use_badges: Array[String] = []
		if game.RACE_AIDS.has(item_id):
			use_badges.append("逐风")
		if item_id in ["steam", "water_jar"] or game.item_tier(item_id) == 2:
			use_badges.append("委托")
		use_badges.append("塔")
		var detail := _make_text("%s · %d阶 · %s\n用途：%s" % [
			str(game.ITEMS[item_id]["category"]), game.item_tier(item_id),
			game.discovery_source_label(item_id), " / ".join(use_badges)
		], Color("bfd6d2"))
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(detail)
		box.add_child(_make_button("查看详情", _open_collection_item.bind(item_id)))
	else:
		var hint := _make_text("%d阶未知万物\n不会提前显示名称、类别或配方" % game.item_tier(item_id), Color("718487"))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
	return panel


func _build_collection_recent() -> void:
	modal_body.add_child(_make_text("最近永久发现", Color("f1d687")))
	var recent_grid := GridContainer.new()
	recent_grid.columns = 3
	recent_grid.add_theme_constant_override("h_separation", 10)
	recent_grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(recent_grid)
	for item_id in game.recent_discovered_item_ids(6):
		recent_grid.add_child(_collection_item_card(item_id, true))
	modal_body.add_child(_make_text("最近实验记录", Color("f1d687")))
	if game.recent_synthesis_pairs.is_empty():
		modal_body.add_child(_make_text("还没有提交过造化盆实验。"))
	for pair_key in game.recent_synthesis_pairs:
		var record: Dictionary = game.attempted_pairs.get(pair_key, {})
		if record.is_empty():
			continue
		var result_text: String = game.item_name(str(record.get("output", ""))) if bool(record.get("success", false)) else str(record.get("failure_title", "未成"))
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", _panel_style(Color("173039"), Color("55777b")))
		var row := HBoxContainer.new()
		line.add_child(row)
		var copy := _make_text("%s + %s → %s\n第%d天 %d/16 · 已付%d金贝 · 复查免费" % [
			game.item_name(str(record.get("left_id", ""))), game.item_name(str(record.get("right_id", ""))),
			result_text, int(record.get("day", 1)), int(record.get("tide", 1)), int(record.get("cost_paid", 0))
		], Color("c7dcda"))
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		row.add_child(_make_button("送回造化盆", _open_synthesis_with_pair.bind(str(record.get("left_id", "")), str(record.get("right_id", "")))))
		modal_body.add_child(line)


func _build_collection_credentials() -> void:
	modal_body.add_child(_make_text("凭证具有次数或资格，不能放入造化盆，也不与永久万物混排。", Color("a9c7c4")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	grid.add_child(_credential_card("逐风免费体验券", "%d次" % game.free_race_ticket, "在逐风竞速报名时自动优先使用；不会消耗永久万物。", Color("7ed5aa")))
	grid.add_child(_credential_card("实验折扣", "%d/6次" % game.synthesis_discount_uses, "只在真正执行未尝试组合时消耗，使实验费减半并向上取整。", Color("e5c96f")))
	grid.add_child(_credential_card("命运牌会资格", "正常牌会已完成" if game.normal_poker_completed else "尚未完成正常牌会", "影响米洛等人物事件，不替代任何桌级财富门槛。", Color("b99ad9")))
	grid.add_child(_credential_card("已认识核心人物", "%d/6名" % game.npc_map_entries().size(), "决定地图人物追踪与可分享对象，不关闭公共服务。", Color("7abdc8")))
	modal_body.add_child(_make_text("万象塔永久印记", Color("f1d687")))
	for raw_floor in game.tower_floor_states():
		var floor: Dictionary = raw_floor
		modal_body.add_child(_make_text("%s %s · %s" % [
			"✓" if bool(floor["unlocked"]) else "◇",
			str(floor["name"]), str(floor["description"])
		], Color("f0d27e") if bool(floor["unlocked"]) else Color("82989a")))


func _credential_card(title_text: String, value_text: String, description: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 130)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), accent))
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_make_text(title_text, accent))
	var value := _make_text(value_text, Color("f5edcf"))
	value.add_theme_font_size_override("font_size", 21)
	box.add_child(value)
	box.add_child(_make_text(description, Color("b9cfcd")))
	return panel


func _build_collection_marine() -> void:
	modal_body.add_child(_make_text("海生图鉴是永久观察记录；鱼获箱是可出售实例。出售鱼获不会删除海生记录，也不会改变万物图鉴。", Color("a9c7c4")))
	modal_body.add_child(_make_text("海生记录 %d/%d · 鱼获箱 %d条" % [game.marine_discoveries.size(), game.FISH_SPECIES.size(), game.fish_catch_inventory.size()], Color("f1d687")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	modal_body.add_child(grid)
	var species_ids: Array[String] = []
	for raw_id in game.FISH_SPECIES.keys():
		species_ids.append(str(raw_id))
	species_ids.sort()
	for species_id in species_ids:
		var known: bool = game.marine_discoveries.has(species_id)
		var species: Dictionary = game.FISH_SPECIES[species_id]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(230, 120)
		panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), species.get("color", Color("55777b")) if known else Color("41565a")))
		var box := VBoxContainer.new()
		panel.add_child(box)
		box.add_child(_make_text(str(species["name"]) if known else "◇ 未知海生记录", Color("c8edf0") if known else Color("7d9294")))
		if known:
			var record: Dictionary = game.marine_size_records.get(species_id, {})
			var held_count := 0
			for raw_catch in game.fish_catch_inventory:
				if str(raw_catch.get("species_id", "")) == species_id:
					held_count += 1
			box.add_child(_make_text("%s · %s\n最大尺寸：%s · 鱼获箱%d条" % [
				str(species["rarity"]), str(species["behavior"]), str(record.get("size", "尚无纪录")), held_count
			], Color("b9cfcd")))
		else:
			box.add_child(_make_text("通过海岸潜捕观察并捕获后记录。", Color("718487")))
		grid.add_child(panel)
	modal_body.add_child(_make_button("前往海岸潜捕", _open_dive.bind("prep")))


func _open_collection_item(item_id: String) -> void:
	if not game.is_discovered(item_id):
		_open_collection("items")
		return
	var record: Dictionary = game.discovery_record(item_id)
	_open_modal("%s · 万物详情" % game.item_name(item_id))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.add_child(_item_art(item_id, 210.0, true))
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(copy)
	var title := _make_text("%s · %s · %d阶" % [game.item_name(item_id), str(game.ITEMS[item_id]["category"]), game.item_tier(item_id)], Color("f1d687"))
	title.add_theme_font_size_override("font_size", 23)
	copy.add_child(title)
	copy.add_child(_make_text(game.item_description(item_id), Color("d5e6df")))
	copy.add_child(_make_text("首次来源：%s\n首次时间：第%d天 %d/16潮刻" % [
		game.discovery_source_label(item_id), int(record.get("first_day", 1)), int(record.get("first_tide", 1))
	], Color("9edbb6")))
	var inputs: Array = record.get("inputs", [])
	if inputs.size() == 2:
		copy.add_child(_make_text("首次关系：%s + %s → %s\n关系语法：%s\n%s" % [
			game.item_name(str(inputs[0])), game.item_name(str(inputs[1])), game.item_name(item_id),
			str(record.get("relation", "")), str(record.get("logic", ""))
		], Color("c4d9d5")))
	else:
		copy.add_child(_make_text("根万物：%s" % str(record.get("logic", "上岛时已经掌握。")), Color("c4d9d5")))
	copy.add_child(_make_text("已验证涉及关系 %d组 · 尚未尝试配对 %d组" % [
		game.item_verified_relation_count(item_id), game.item_untried_pair_count(item_id)
	], Color("f0cf82")))
	modal_body.add_child(header)
	modal_body.add_child(_make_text("已开放用途", Color("f1d687")))
	for raw_use in game.item_cross_module_uses(item_id):
		var use: Dictionary = raw_use
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), Color("55777b")))
		panel.add_child(_make_text("%s｜%s\n%s" % [str(use["module"]), str(use["label"]), str(use["detail"])], Color("c7dcda")))
		modal_body.add_child(panel)
	var actions := GridContainer.new()
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(actions)
	actions.add_child(_make_button("放入造化盆左侧", _open_synthesis_with_item.bind(item_id, "left")))
	actions.add_child(_make_button("放入造化盆右侧", _open_synthesis_with_item.bind(item_id, "right")))
	if game.RACE_AIDS.has(item_id):
		actions.add_child(_make_button("查看逐风用途", _open_race))
	actions.add_child(_make_button("查看万象塔", _open_tower))
	actions.add_child(_make_button("返回图鉴", _open_collection.bind("items")))


func _open_synthesis_with_item(item_id: String, side: String) -> void:
	modal_overlay.visible = false
	synthesis_table.open_with_item(item_id, side)
	player.controls_enabled = false


func _open_synthesis_with_pair(left_item_id: String, right_item_id: String) -> void:
	modal_overlay.visible = false
	synthesis_table.open_with_pair(left_item_id, right_item_id)
	player.controls_enabled = false


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

	modal_body.add_child(_make_text("净资产 = 当前金贝 + 活动中/待撮合金贝 + 鱼获保守变现值 + 份契保守变现值。永久万物、知识和凭证不折算现金。", Color("a9c9ca")))
	var today_report: Dictionary = game.current_day_economy_summary()
	modal_body.add_child(_make_text("今日分类账", Color("f0d27e")))
	modal_body.add_child(_make_text(_economy_report_text(today_report, true), Color("c7dcda")))
	modal_body.add_child(_make_button("查看潮汐商会份契", _open_share_market))
	modal_body.add_child(_make_button("把财富用于居所与收藏", _open_home))
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
	var activity_totals: Array = game.economy_activity_totals()
	if not activity_totals.is_empty():
		modal_body.add_child(_make_text("各玩法累计收支", Color("f0d27e")))
		for index in range(mini(8, activity_totals.size())):
			var activity: Dictionary = activity_totals[index]
			modal_body.add_child(_make_text("%s · 流入%d / 流出%d · 净资产%s%d" % [
				str(activity["name"]), int(activity["cash_in"]), int(activity["cash_out"]),
				"+" if int(activity["net_delta"]) >= 0 else "", int(activity["net_delta"])
			], Color("9edfc4") if int(activity["net_delta"]) >= 0 else Color("d9a09a")))

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
	modal_overlay.visible = false
	synthesis_table.open()
	player.controls_enabled = false


func _on_synthesis_table_closed() -> void:
	player.controls_enabled = true
	_refresh_hud()


func _on_synthesis_collection_requested() -> void:
	_open_collection()


func _open_dive(initial_mode: String = "prep") -> void:
	modal_overlay.visible = false
	dive_table.open(initial_mode)
	player.controls_enabled = false


func _on_dive_table_closed() -> void:
	player.controls_enabled = true
	_refresh_hud()


func _on_dive_checkpoint_requested(_reason: String) -> void:
	game.save_game("user://saves/activity_dive.json", _world_save_state(), true)


func _open_shop() -> void:
	_open_modal("椰影杂货铺")
	var shop_schedule: Dictionary = game.npc_schedule_entry("shopkeeper")
	var intro := PanelContainer.new()
	intro.add_theme_stylebox_override("panel", _panel_style(Color("183b41"), Color("c39b58")))
	var intro_row := HBoxContainer.new()
	intro_row.add_theme_constant_override("separation", 16)
	intro.add_child(intro_row)
	intro_row.add_child(_item_art("cloud", 112.0))
	var intro_copy := VBoxContainer.new()
	intro_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var welcome := _make_text("阿拓的知识铺", Color("f4dc96"))
	welcome.add_theme_font_size_override("font_size", 23)
	intro_copy.add_child(welcome)
	intro_copy.add_child(_make_text("这里提供配方方向线索与实验折扣。全部万物都要在造化盆中亲自发现，服务只帮助你理解关系。", Color("c9e5df")))
	intro_copy.add_child(_make_text("当前%d金贝 · 永久万物%d种 · 实验折扣%d次" % [game.cash, game.discovered_item_ids().size(), game.synthesis_discount_uses], Color("f0d27e")))
	if bool(shop_schedule.get("available", false)):
		intro_copy.add_child(_make_text("阿拓在场 · %s。\n“我卖的是别人走过的路。学会以后，那条路就归你了。”" % str(shop_schedule.get("activity", "整理研究记录")), Color("eab77f")))
	else:
		var substitute := str(shop_schedule.get("substitute", "代班店员"))
		intro_copy.add_child(_make_text("阿拓当前在%s；%s正在代班。两项公共研究服务照常开放，人物交谈请按地图行踪寻找阿拓。" % [str(shop_schedule.get("location", "岛上别处")), substitute], Color("a9c8c5")))
	intro_row.add_child(intro_copy)
	modal_body.add_child(intro)
	var purchase_title := _make_text("关系线索与研究服务", Color("ffe7a6"))
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
		card_box.add_child(_make_button("购买服务", _buy_shop_offer.bind(str(offer["id"])), disabled))
		purchase_grid.add_child(card)
	modal_body.add_child(purchase_grid)
	if not game.last_shop_hint.is_empty():
		modal_body.add_child(_make_text("最近线索：%s" % game.last_shop_hint, Color("f0d27e")))
	modal_body.add_child(_make_text("普通查看和购买不消耗潮刻。线索不会直接解锁万物，也不会改变固定配方。", Color("9bb5bc")))


func _buy_shop_offer(offer_id: String) -> void:
	var result: Dictionary = game.buy_shop_offer(offer_id)
	_show_toast(str(result.get("text", "服务未能交付。")))
	_open_shop()


func _open_time_menu() -> void:
	_open_modal("日程与时间")
	var progress_percent := int(round(game.tide_progress * 100.0))
	modal_body.add_child(_make_text(
		"第%d天 · %s第%d潮刻（%d%%）\n天气：%s · 风向：%s\n打开界面、阅读和决策时世界时间暂停。" % [
			game.day, game.phase_name(), game.tide, progress_percent, game.weather, game.wind_direction
		],
		Color("d7ece7")
	))
	var race_lines: Array[String] = []
	for raw_event in game.race_schedule_rows():
		var event: Dictionary = raw_event
		race_lines.append("%s 第%d潮刻 · %s" % [str(event["name"]), int(event["scheduled_tide"]), str(event["status"])])
	modal_body.add_child(_make_text("今日逐风赛事\n• %s" % "\n• ".join(race_lines), Color("e8cb82")))
	modal_body.add_child(_make_button("查看赛事票池", _open_race))
	var invitation_lines: Array[String] = []
	for raw_invitation in game.poker_invitation_rows():
		var invitation: Dictionary = raw_invitation
		invitation_lines.append("%s · %s · %s" % [str(invitation["host_name"]), str(invitation["title"]), str(invitation["status"])])
	if not invitation_lines.is_empty():
		modal_body.add_child(_make_text("今日牌会邀请\n• %s" % "\n• ".join(invitation_lines), Color("d7b6e8")))
		modal_body.add_child(_make_button("查看牌会场次", _open_poker))
	var share_status: Dictionary = game.share_market_status()
	modal_body.add_child(_make_text("潮汐商会 · %s · %s\n待撮合订单%d笔，冻结%d金贝。" % [
		str(share_status["label"]), str(share_status["next_boundary"]),
		game.share_pending_orders.size(), game.share_reserved_cash
	], Color("d8c17d")))
	modal_body.add_child(_make_button("查看商会份契", _open_share_market))
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	for mode in ["紧凑", "标准", "悠闲"]:
		var seconds := int(game.TIME_SPEED_SECONDS[mode])
		var label := "✓ %s · %d秒/潮刻" % [mode, seconds] if game.time_speed_mode == mode else "%s · %d秒/潮刻" % [mode, seconds]
		var speed_button := _make_button(label, _set_time_speed.bind(mode))
		speed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speed_row.add_child(speed_button)
	modal_body.add_child(_make_text("自然流速", Color("f0d27e")))
	modal_body.add_child(speed_row)

	var wait_row := HBoxContainer.new()
	wait_row.add_theme_constant_override("separation", 8)
	var wait_one := _make_button("等待1潮刻", _wait_tides.bind(1.0), game.day_end_pending)
	wait_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wait_row.add_child(wait_one)
	var to_phase := _time_to_next_phase()
	var wait_phase := _make_button("等待到下一时段 · %.2f潮刻" % to_phase, _wait_tides.bind(to_phase), game.day_end_pending)
	wait_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wait_row.add_child(wait_phase)
	modal_body.add_child(_make_text("主动等待会按顺序处理跨过的潮刻和时段边界。", Color("a9c4c0")))
	modal_body.add_child(wait_row)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	var save_button := _make_button("保存当前进度", _manual_save, not game.can_save_game())
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save_button)
	var load_button := _make_button("读取手动存档", _manual_load, not FileAccess.file_exists(game.MANUAL_SAVE_PATH))
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(load_button)
	modal_body.add_child(save_row)
	var tutorial_state: Dictionary = game.journey_tutorial_state()
	modal_body.add_child(_make_text("旅程引导：已完成%d/%d步。引导只读取真实玩法进度，不会限制探索顺序。" % [
		int(tutorial_state.get("completed_count", 0)), int(tutorial_state.get("total", 0))
	], Color("a8d9bd")))
	modal_body.add_child(_make_button(
		"查看已完成的旅程步骤" if bool(tutorial_state.get("complete", false)) else ("重新显示旅程引导" if bool(tutorial_state.get("hidden", false)) else "旅程引导正在显示"),
		_show_journey_tutorial,
		not bool(tutorial_state.get("hidden", false)) and not bool(tutorial_state.get("complete", false))
	))
	if game.day_end_pending:
		modal_body.add_child(_make_text("夜深了，时间已停驻。睡眠时先结算三家商会经营与分红，再以新报价撮合隔夜订单。", Color("ffd98a")))


func _set_time_speed(mode: String) -> void:
	game.set_time_speed_mode(mode)
	_open_time_menu()


func _time_to_next_phase() -> float:
	var current_time: float = float(game.tide - 1) + float(game.tide_progress)
	var boundary: float = 4.0
	for candidate in [4.0, 8.0, 12.0, 16.0]:
		if candidate > current_time + 0.000001:
			boundary = float(candidate)
			break
	return maxf(0.000001, boundary - current_time)


func _wait_tides(amount: float, confirmed: bool = false) -> void:
	var warnings := _time_advance_warnings(amount)
	if not confirmed and not warnings.is_empty():
		_open_modal("确认等待")
		modal_body.add_child(_make_text("等待%.2f潮刻会触发以下变化：\n• %s" % [amount, "\n• ".join(warnings)], Color("f0d27e")))
		modal_body.add_child(_make_text("确认后按统一边界顺序推进；取消不会消耗时间或金贝。", Color("bcd5d2")))
		var action_row := HBoxContainer.new()
		action_row.add_theme_constant_override("separation", 8)
		var cancel := _make_button("取消", _open_time_menu)
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(cancel)
		var confirm := _make_button("确认等待", _wait_tides.bind(amount, true))
		confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(confirm)
		modal_body.add_child(action_row)
		return
	var old_day: int = game.day
	var old_tide: int = game.tide
	if not game.fast_forward_time(amount, "主动等待"):
		_show_result("无法等待", "当前已经处于日终停驻，请回漂流小屋休息。", _open_time_menu)
		return
	_show_result(
		"时间已推进",
		"从第%d天第%d潮刻推进到第%d天%s第%d潮刻。%s" % [
			old_day, old_tide, game.day, game.phase_name(), game.tide,
			"世界已进入日终停驻。" if game.day_end_pending else "日程边界已按顺序结算。"
		],
		_open_time_menu
	)


func _time_advance_warnings(amount: float) -> Array[String]:
	var warnings: Array[String] = []
	var start_value := float(game.tide - 1) + float(game.tide_progress)
	var end_value := minf(16.0, start_value + maxf(0.0, amount))
	var crosses_phase := int(floor(start_value / 4.0)) != int(floor(minf(15.999, end_value) / 4.0))
	for raw_event in game.race_schedule_rows():
		var event: Dictionary = raw_event
		var event_time := float(int(event.get("scheduled_tide", 1)) - 1)
		if not bool(event.get("completed", false)) and event_time > start_value and event_time <= end_value:
			warnings.append("逐风赛事“%s”会封盘或变为错过" % str(event.get("name", "赛事")))
	for raw_order in game.fish_market_orders:
		var order: Dictionary = raw_order
		var deadline_time := float(int(order.get("deadline_tide", 16)) - 1)
		if not bool(order.get("completed", false)) and deadline_time > start_value and deadline_time <= end_value:
			warnings.append("鱼获专单“%s”会到达截止潮刻" % str(order.get("title", "人物订单")))
	if crosses_phase and not game.fish_catch_inventory.is_empty():
		warnings.append("你持有的鱼获会失鲜，鱼市供需与报价也会刷新")
	if crosses_phase and not game.share_pending_orders.is_empty():
		warnings.append("潮汐商会将跨过开收盘边界，待撮合订单可能成交或退款")
	return warnings


func _world_save_state() -> Dictionary:
	return {
		"discovered_areas": discovered_areas.duplicate(true),
		"current_area": current_area,
		"player_position": {"x": player.global_position.x, "y": player.global_position.y}
	}


func _apply_loaded_world(world: Dictionary) -> void:
	var restored_areas := {"漂流湾": true}
	var saved_areas = world.get("discovered_areas", {})
	if saved_areas is Dictionary:
		for area_name in WorldLayoutScript.AREA_ORDER:
			if bool(saved_areas.get(area_name, false)):
				restored_areas[area_name] = true
	discovered_areas = restored_areas
	var saved_area := str(world.get("current_area", "漂流湾"))
	current_area = saved_area if WorldLayoutScript.REGIONS.has(saved_area) else "漂流湾"
	var saved_position = world.get("player_position", {})
	if saved_position is Dictionary and saved_position.has("x") and saved_position.has("y"):
		var candidate := Vector2(float(saved_position["x"]), float(saved_position["y"]))
		if WorldLayoutScript.WORLD_RECT.has_point(candidate):
			player.global_position = candidate
		else:
			player.global_position = WorldLayoutScript.spawn_for_area(current_area)
	else:
		player.global_position = WorldLayoutScript.spawn_for_area(current_area)
	current_area = WorldLayoutScript.area_for_position(player.global_position)
	discovered_areas[current_area] = true
	day_end_notice_day = game.day if game.day_end_pending else 0
	_apply_npc_schedule()
	_refresh_hud()


func _manual_save() -> void:
	var result: Dictionary = game.save_game(game.MANUAL_SAVE_PATH, _world_save_state())
	_show_result("手动存档", str(result.get("text", "存档未完成。")), _open_time_menu)


func _manual_load() -> void:
	var result: Dictionary = game.load_game(game.MANUAL_SAVE_PATH)
	if bool(result.get("ok", false)):
		var world = result.get("world", {})
		_apply_loaded_world(world if world is Dictionary else {})
	_show_result("读取存档", str(result.get("text", "读档未完成。")), _open_time_menu)


func _open_home(message: String = "") -> void:
	var home: Dictionary = game.home_data()
	_open_modal("%s · 居所与收藏" % str(home["name"]))
	modal_body.add_child(_art_banner(IslandGroundMap, 135.0))
	if not message.is_empty():
		var positive := not ("不能" in message or "不足" in message or "没有" in message or "不可" in message)
		modal_body.add_child(_make_text(message, Color("9edbb6") if positive else Color("eda69b")))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(_wealth_stat("当前金贝", "%d" % game.cash, Color("8ee0b1")))
	stats.add_child(_wealth_stat("万物陈列", "%d/%d" % [int(home["display_count"]), int(home["display_slots"])], Color("f0d27e")))
	stats.add_child(_wealth_stat("水族收藏", "%d/%d" % [int(home["aquarium_count"]), int(home["aquarium_slots"])], Color("8fcfda")))
	stats.add_child(_wealth_stat("人物来访", "%d" % int(home["visits"]), Color("d7b6e8")))
	modal_body.add_child(stats)
	modal_body.add_child(_make_text("%s\n居所属于生活消费与收藏，不计入账户财富或净资产，也不提供固定收益。" % str(home["description"]), Color("c7dcda")))

	var upgrade: Dictionary = game.next_home_upgrade()
	var upgrade_panel := PanelContainer.new()
	upgrade_panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("c2a65f") if bool(upgrade.get("available", false)) else Color("54696c")))
	var upgrade_box := VBoxContainer.new()
	upgrade_panel.add_child(upgrade_box)
	if bool(upgrade.get("complete", false)):
		upgrade_box.add_child(_make_text("居所已达到四象宅邸", Color("f2d984")))
		upgrade_box.add_child(_make_text("当前拥有%d个万物陈列槽、%d个水族槽，并可每日邀请一名熟悉人物。" % [int(home["display_slots"]), int(home["aquarium_slots"])], Color("bcd5d2")))
	else:
		upgrade_box.add_child(_make_text("下一阶段 · %s" % str(upgrade["name"]), Color("f2d984")))
		upgrade_box.add_child(_make_text("%s\n费用%d金贝 · 账户财富%d · 永久万物%d种\n扩建后：陈列%d格 · 水族%d格 · 每日来访%d次" % [
			str(upgrade["description"]), int(upgrade["cost"]), int(upgrade["wealth_required"]), int(upgrade["discoveries_required"]),
			int(upgrade["display_slots"]), int(upgrade["aquarium_slots"]), int(upgrade["guest_slots"])
		], Color("bcd5d2")))
		if not bool(upgrade["available"]):
			upgrade_box.add_child(_make_text("尚缺：%s" % "；".join(upgrade["reasons"]), Color("d6b18b")))
		upgrade_box.add_child(_make_button("确认扩建 · 支付%d金贝" % int(upgrade["cost"]), _purchase_home_upgrade, not bool(upgrade["available"])))
	modal_body.add_child(upgrade_panel)

	modal_body.add_child(_make_text("万物陈列", Color("f1d687")))
	var display_grid := GridContainer.new()
	display_grid.columns = 3
	display_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_grid.add_theme_constant_override("h_separation", 8)
	display_grid.add_theme_constant_override("v_separation", 8)
	for item_id in game.home_display_items:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(225, 174)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("c2a65f")))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(box)
		box.add_child(_item_art(item_id, 86.0))
		var record: Dictionary = game.discovery_record(item_id)
		var title := _make_text("%s · %d阶" % [game.item_name(item_id), game.item_tier(item_id)], Color("f2d984"))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		box.add_child(_make_text("首次发现：第%d天 %d/16" % [int(record.get("first_day", 1)), int(record.get("first_tide", 1))], Color("9dbbb8")))
		box.add_child(_make_button("撤下陈列", _remove_home_display.bind(item_id)))
		display_grid.add_child(card)
	for empty_index in range(maxi(0, int(home["display_slots"]) - game.home_display_items.size())):
		var empty_panel := PanelContainer.new()
		empty_panel.custom_minimum_size = Vector2(225, 174)
		empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_panel.add_theme_stylebox_override("panel", _panel_style(Color("132b32"), Color("465e62")))
		var empty_label := _make_text("◇ 空陈列位", Color("718c8f"))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_panel.add_child(empty_label)
		display_grid.add_child(empty_panel)
	modal_body.add_child(display_grid)
	if game.home_display_items.size() < game.home_display_capacity():
		var display_option := OptionButton.new()
		for item_id in game.discovered_item_ids():
			if game.home_display_items.has(item_id):
				continue
			display_option.add_item("%d阶 · %s" % [game.item_tier(item_id), game.item_name(item_id)])
			display_option.set_item_metadata(display_option.item_count - 1, item_id)
		var display_row := HBoxContainer.new()
		display_row.add_theme_constant_override("separation", 8)
		display_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display_row.add_child(display_option)
		display_row.add_child(_make_button("陈列所选万物", _add_home_display_from_option.bind(display_option), display_option.item_count == 0))
		modal_body.add_child(display_row)
	modal_body.add_child(_make_text("陈列只保存图鉴引用，不消耗万物，也不影响造化盆、委托或万象塔。", Color("91adae")))

	modal_body.add_child(_make_text("水族收藏", Color("8fd6df")))
	if int(home["aquarium_slots"]) <= 0:
		modal_body.add_child(_make_text("潮木居所开放第一格水族收藏。水族只接收观赏、收藏标签或纪录级鱼获。", Color("91adae")))
	else:
		var aquarium_grid := GridContainer.new()
		aquarium_grid.columns = 2
		aquarium_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		aquarium_grid.add_theme_constant_override("h_separation", 8)
		aquarium_grid.add_theme_constant_override("v_separation", 8)
		for raw_fish in game.home_aquarium_rows():
			var fish: Dictionary = raw_fish
			var fish_panel := PanelContainer.new()
			fish_panel.custom_minimum_size = Vector2(340, 128)
			fish_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fish_panel.add_theme_stylebox_override("panel", _panel_style(Color("12343b"), Color("6fb7c2")))
			var fish_box := VBoxContainer.new()
			fish_panel.add_child(fish_box)
			fish_box.add_child(_make_text("%s · %s · %s" % [str(fish["name"]), str(fish.get("size", "标准")), str(fish["rarity"])], Color("b9edf2")))
			fish_box.add_child(_make_text("第%d天在%s捕获 · 已成为不可变现收藏" % [int(fish.get("caught_day", 1)), str(fish["area_name"])], Color("9dbbb8")))
			fish_box.add_child(_make_button("确认放流 · 不返还鱼获或金贝", _confirm_release_aquarium.bind(str(fish["catch_id"]))))
			aquarium_grid.add_child(fish_panel)
		for empty_index in range(maxi(0, int(home["aquarium_slots"]) - game.home_aquarium.size())):
			var empty_fish := PanelContainer.new()
			empty_fish.custom_minimum_size = Vector2(340, 128)
			empty_fish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_fish.add_theme_stylebox_override("panel", _panel_style(Color("102a31"), Color("3f6268")))
			var empty_fish_label := _make_text("≈ 空水族槽 ≈", Color("638a90"))
			empty_fish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_fish_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_fish.add_child(empty_fish_label)
			aquarium_grid.add_child(empty_fish)
		modal_body.add_child(aquarium_grid)
		var candidates: Array = game.aquarium_candidate_rows()
		if game.home_aquarium.size() < game.home_aquarium_capacity() and not candidates.is_empty():
			var fish_option := OptionButton.new()
			for raw_candidate in candidates:
				var candidate: Dictionary = raw_candidate
				fish_option.add_item("%s · %s · %s" % [str(candidate["name"]), str(candidate.get("size", "标准")), str(candidate["rarity"])])
				fish_option.set_item_metadata(fish_option.item_count - 1, str(candidate["catch_id"]))
			var fish_row := HBoxContainer.new()
			fish_row.add_theme_constant_override("separation", 8)
			fish_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fish_row.add_child(fish_option)
			fish_row.add_child(_make_button("转入水族 · 不再可出售", _place_home_fish_from_option.bind(fish_option)))
			modal_body.add_child(fish_row)
		elif candidates.is_empty():
			modal_body.add_child(_make_text("鱼获箱中暂无符合条件的鱼。纪录级鱼或带“观赏/收藏”标签的鱼可以转入。", Color("91adae")))

	modal_body.add_child(_make_text("人物来访", Color("d7b6e8")))
	if game.home_level < 2:
		modal_body.add_child(_make_text("风灯庭院开放人物来访。每次待客支出30金贝、推进0.5潮刻。", Color("91adae")))
	else:
		modal_body.add_child(_make_text("每天最多邀请一名已认识且关系达到熟悉的人物。首次来访关系+2，重复来访不重复加关系。", Color("b9c9cb")))
		var guest_grid := GridContainer.new()
		guest_grid.columns = 2
		guest_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for raw_guest in game.home_invite_rows():
			var guest: Dictionary = raw_guest
			var label := "%s · %s%s" % [
				str(guest["name"]), str(guest["relationship"]),
				" · 首次来访" if bool(guest["first_visit"]) else " · 来过居所"
			]
			if not bool(guest["available"]):
				label += "\n%s" % "；".join(guest["reasons"])
			var guest_button := _make_button(label, _invite_home_guest.bind(str(guest["npc_id"])), not bool(guest["available"]))
			guest_button.custom_minimum_size.y = 58
			guest_grid.add_child(guest_button)
		modal_body.add_child(guest_grid)

	var finale: Dictionary = game.finale_progress()
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_make_text("归潮盛典见证 %d/%d · %s" % [
		int(finale["completed"]), int(finale["total"]),
		"已经完成，可继续游玩" if game.finale_completed else "在万象塔查看完整条件"
	], Color("f2d984")))
	modal_body.add_child(_make_button("查看万象塔与归潮盛典", _open_tower))
	modal_body.add_child(_make_button("返回休息与存档", _open_bed))


func _purchase_home_upgrade() -> void:
	var result: Dictionary = game.purchase_home_upgrade()
	_open_home(str(result.get("text", "扩建未完成。")))


func _add_home_display_from_option(option: OptionButton) -> void:
	if option == null or option.item_count <= 0:
		return
	var result: Dictionary = game.add_home_display(str(option.get_selected_metadata()))
	_open_home(str(result.get("text", "陈列未更新。")))


func _remove_home_display(item_id: String) -> void:
	var result: Dictionary = game.remove_home_display(item_id)
	_open_home(str(result.get("text", "陈列未更新。")))


func _place_home_fish_from_option(option: OptionButton) -> void:
	if option == null or option.item_count <= 0:
		return
	var result: Dictionary = game.place_fish_in_aquarium(str(option.get_selected_metadata()))
	_open_home(str(result.get("text", "水族收藏未更新。")))


func _confirm_release_aquarium(catch_id: String) -> void:
	var selected: Dictionary = {}
	for raw_fish in game.home_aquarium_rows():
		if str(raw_fish.get("catch_id", "")) == catch_id:
			selected = raw_fish
			break
	if selected.is_empty():
		_open_home("水族箱中已经没有这条收藏。")
		return
	_open_modal("确认放流")
	modal_body.add_child(_make_text("%s（%s）将被放归海中。" % [str(selected["name"]), str(selected.get("size", "标准"))], Color("b9edf2")))
	modal_body.add_child(_make_text("放流不可撤销：不会回到鱼获箱，不能出售或交付订单，也不返还金贝。", Color("eda69b")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var confirm := _make_button("确认放流", _release_aquarium_fish.bind(catch_id))
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(confirm)
	var cancel := _make_button("保留收藏", _open_home)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	modal_body.add_child(row)


func _release_aquarium_fish(catch_id: String) -> void:
	var result: Dictionary = game.release_aquarium_fish(catch_id)
	_open_home(str(result.get("text", "放流未完成。")))


func _invite_home_guest(npc_id: String) -> void:
	var result: Dictionary = game.invite_npc_home(npc_id)
	_show_result(
		"居所来访",
		"%s%s" % [
			str(result.get("text", "邀请未完成。")),
			"\n\n世界已进入日终停驻，请休息到明天。" if game.day_end_pending else ""
		],
		_open_home
	)


func _run_finale() -> void:
	game.save_game("user://saves/activity_finale.json", _world_save_state(), true)
	var result: Dictionary = game.complete_finale()
	if not bool(result.get("ok", false)):
		_show_result("归潮盛典", str(result.get("text", "盛典尚未开放。")), _open_tower)
		return
	_show_result(
		"归潮盛典 · 万象仍在生长",
		"%s\n\n%s\n\n所有正式玩法、资产、人物关系和存档都将继续保留。" % [
			str(result.get("text", "")), _finale_summary_text(result.get("summary", {}))
		],
		_open_tower
	)


func _finale_summary_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "塔中还没有归潮盛典记录。"
	var display_names: Array[String] = []
	for raw_item_id in summary.get("display_items", []):
		display_names.append(game.item_name(str(raw_item_id)))
	var fish_names: Array[String] = []
	for raw_species_id in summary.get("aquarium_species", []):
		fish_names.append(str(game.FISH_SPECIES.get(str(raw_species_id), {}).get("name", raw_species_id)))
	return "第%d天第%d潮刻，%s成为你在岛上的居所。\n陈列：%s\n水族：%s\n来访：%s\n已记录牌会%d场、赛事%d场、鱼铺成交%d笔；当时账户财富%d金贝。" % [
		int(summary.get("completed_day", summary.get("started_day", 1))),
		int(summary.get("completed_tide", summary.get("started_tide", 1))),
		str(summary.get("home_name", "居所")),
		"、".join(display_names) if not display_names.is_empty() else "无",
		"、".join(fish_names) if not fish_names.is_empty() else "无",
		"、".join(summary.get("guest_names", [])) if not summary.get("guest_names", []).is_empty() else "无",
		int(summary.get("poker_sessions", 0)), int(summary.get("races", 0)),
		int(summary.get("fish_sales", 0)), int(summary.get("account_wealth", 0))
	]


func _open_bed() -> void:
	var home: Dictionary = game.home_data()
	_open_modal(str(home["name"]))
	modal_body.add_child(_make_text("这里可以保存、查看日终状态、管理居所并休息。睡眠会结束今天，生成并固定次日天气、风向与日程。"))
	modal_body.add_child(_make_text("当前：第%d天%s第%d潮刻 · %s · %s" % [game.day, game.phase_name(), game.tide, game.weather, game.wind_direction], Color("f0d27e")))
	modal_body.add_child(_make_text("居所：%s · 万物陈列%d/%d · 水族收藏%d/%d · 来访记录%d次" % [
		str(home["name"]), int(home["display_count"]), int(home["display_slots"]),
		int(home["aquarium_count"]), int(home["aquarium_slots"]), int(home["visits"])
	], Color("9edbb6")))
	modal_body.add_child(_make_text("睡眠结算顺序：三家商会经营与分红 → 次日天气/鱼市/赛事 → 新报价 → %d笔隔夜订单撮合。" % game.share_pending_orders.size(), Color("d9c47f")))
	modal_body.add_child(_make_text(_economy_report_text(game.current_day_economy_summary(), false), Color("bcd5d2")))
	var relief: Dictionary = game.relief_work_status()
	modal_body.add_child(_make_text("低谷恢复：%s" % str(relief.get("reason", "")), Color("8edcaf") if bool(relief.get("available", false)) else Color("9ab5b3")))
	if bool(relief.get("available", false)):
		modal_body.add_child(_make_button("完成巡岸修缮 · 1潮刻 / +40金贝", _perform_relief_work))
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 8)
	var save_button := _make_button("保存当前进度", _manual_save, not game.can_save_game())
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save_button)
	var load_button := _make_button("读取手动存档", _manual_load, not FileAccess.file_exists(game.MANUAL_SAVE_PATH))
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(load_button)
	modal_body.add_child(save_row)
	modal_body.add_child(_make_button("居所、陈列、水族与来访", _open_home))
	modal_body.add_child(_make_button("调整日长与主动等待", _open_time_menu))
	modal_body.add_child(_make_button("睡到明天", _sleep))


func _sleep() -> void:
	var closing_day := int(game.day)
	game.sleep_to_next_day()
	_apply_npc_schedule()
	var autosave: Dictionary = game.save_auto_game(_world_save_state())
	var dividend_total := 0
	if not game.share_dividend_history.is_empty() and int(game.share_dividend_history[0].get("day", 0)) == closing_day:
		dividend_total = int(game.share_dividend_history[0].get("total", 0))
	var quote_lines: Array[String] = []
	for raw_row in game.share_market_rows():
		var row: Dictionary = raw_row
		quote_lines.append("%s %d（%+d）" % [str(row["short_name"]), int(row["price"]), int(row["change"])])
	var executed_orders := 0
	for raw_trade in game.share_trade_history:
		if raw_trade is Dictionary and int(raw_trade.get("day", 0)) == game.day and str(raw_trade.get("source", "")) == "次日开盘撮合":
			executed_orders += 1
	var day_report: Dictionary = game.latest_day_end_report()
	_show_result(
		"新的一天",
		"%s\n\n第%d天清晨。今日天气：%s，风向：%s。\n商会分红%d金贝；开盘撮合%d笔。%s。\n%s" % [
			_economy_report_text(day_report, true),
			game.day, game.weather, game.wind_direction, dividend_total, executed_orders, "；".join(quote_lines),
			"日终自动存档已创建。" if bool(autosave.get("ok", false)) else str(autosave.get("text", "自动存档未完成。"))
		]
	)


func _perform_relief_work() -> void:
	var result: Dictionary = game.perform_relief_work()
	_show_result("巡岸修缮", str(result.get("text", "修缮工作未完成。")), _open_bed)


func _economy_report_text(report: Dictionary, include_categories: bool) -> String:
	if report.is_empty():
		return "今天还没有可汇总的经济记录。"
	var opening: Dictionary = report.get("opening", {})
	var closing: Dictionary = report.get("closing", {})
	var lines: Array[String] = []
	lines.append("第%d日账簿：期初%d + 流入%d − 流出%d = 期末%d金贝%s" % [
		int(report.get("day", game.day)), int(opening.get("cash", 0)), int(report.get("cash_in", 0)),
		int(report.get("cash_out", 0)), int(closing.get("cash", game.cash)),
		" · 已核对" if bool(report.get("cash_balanced", false)) else " · 账目待核对"
	])
	lines.append("账户财富%s%d · 净资产%s%d · %d笔经济事件" % [
		"+" if int(report.get("account_delta", 0)) >= 0 else "", int(report.get("account_delta", 0)),
		"+" if int(report.get("net_delta", 0)) >= 0 else "", int(report.get("net_delta", 0)), int(report.get("event_count", 0))
	])
	if include_categories:
		for raw_row in report.get("categories", []):
			var row: Dictionary = raw_row
			lines.append("• %s：流入%d / 流出%d · 净资产%s%d" % [
				str(row.get("name", "其他变化")), int(row.get("cash_in", 0)), int(row.get("cash_out", 0)),
				"+" if int(row.get("net_delta", 0)) >= 0 else "", int(row.get("net_delta", 0))
			])
	return "\n".join(lines)


func _open_granny() -> void:
	_open_npc("granny")


func _open_aqiu() -> void:
	_open_npc("aqiu")


func _open_mia() -> void:
	_open_npc("mia")


func _open_milo() -> void:
	_open_npc("milo")


func _open_npc(npc_id: String, notice_text: String = "") -> void:
	var profile: Dictionary = game.npc_profile(npc_id)
	if profile.is_empty():
		_show_result("无人回应", "这里没有可交谈的核心人物。")
		return
	game.meet_npc(npc_id)
	var schedule: Dictionary = game.npc_schedule_entry(npc_id)
	var npc_name := str(profile.get("name", npc_id))
	_open_modal("%s · %s" % [npc_name, game.relationship_state(npc_id)])
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation", 14)
	overview.add_child(_npc_portrait(npc_id))
	var overview_copy := VBoxContainer.new()
	overview_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_copy.add_theme_constant_override("separation", 7)
	overview.add_child(overview_copy)
	overview_copy.add_child(_make_text(str(profile.get("role", "岛民")), Color("f1d687")))
	overview_copy.add_child(_make_text("当前位置：%s\n正在：%s" % [
		str(schedule.get("location", "未知区域")),
		str(schedule.get("activity", ""))
	], Color("c8dedb")))
	var relationship_explanations := {
		"疏远": "减少私人话题与邀请，但公共服务照常开放。",
		"陌生": "提供公共信息与必要功能。",
		"熟悉": "开放普通委托、背景线索与深入交谈。",
		"信任": "开放私人话题、长期合作与更完整的个人信息。"
	}
	var relationship_state: String = game.relationship_state(npc_id)
	overview_copy.add_child(_make_text("关系：%s · %s" % [relationship_state, str(relationship_explanations[relationship_state])], Color("9edbb6")))
	var dialogue: Array = profile.get("dialogue", [])
	if not dialogue.is_empty():
		var thought_index := posmod(game.day + game.tide, dialogue.size())
		overview_copy.add_child(_make_text("此刻的话\n%s" % str(dialogue[thought_index]), Color("f4e2ad")))
	var current_phase_index := NpcCatalogScript.PHASES.find(game.phase_name())
	var next_phase := str(NpcCatalogScript.PHASES[(current_phase_index + 1) % NpcCatalogScript.PHASES.size()])
	var next_schedule: Dictionary = game.npc_schedule_entry(npc_id, next_phase)
	overview_copy.add_child(_make_text("下一时段：%s · %s" % [next_phase, str(next_schedule.get("location", "未知区域"))], Color("91abad")))
	modal_body.add_child(overview)
	if not notice_text.is_empty():
		var notice_panel := PanelContainer.new()
		notice_panel.add_theme_stylebox_override("panel", _panel_style(Color("173b3c"), Color("74b09a")))
		notice_panel.add_child(_make_text(notice_text, Color("d4f4df")))
		modal_body.add_child(notice_panel)
	if not bool(schedule.get("available", false)):
		var substitute := str(schedule.get("substitute", ""))
		modal_body.add_child(_make_text(
			"%s当前不在可交谈位置。%s" % [npc_name, ("基础服务由%s继续提供。" % substitute) if not substitute.is_empty() else "可以在地图人物栏查看下一时段的位置。"],
			Color("aab9ba")
		))
		modal_body.add_child(_make_button("查看人物地图", _open_map))
		_add_npc_service_buttons(npc_id)
		return

	var memory_lines: Array[String] = []
	var long_memories: Array = game.npc_long_memories(npc_id)
	for raw_memory in long_memories:
		memory_lines.append("长期记忆 · %s" % str(raw_memory.get("summary", "")))
	var recent_memories: Array = game.npc_recent_memories(npc_id)
	for index in range(mini(2, recent_memories.size())):
		memory_lines.append("最近记得 · %s" % str(recent_memories[index].get("summary", "")))
	if not memory_lines.is_empty():
		modal_body.add_child(_make_text("\n".join(memory_lines), Color("b8cecc")))

	var actions := GridContainer.new()
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(actions)
	actions.add_child(_make_button("交谈", _npc_talk_action.bind(npc_id)))
	actions.add_child(_make_button("询问话题", _open_npc_topics.bind(npc_id)))
	actions.add_child(_make_button("查看委托", _open_npc_request.bind(npc_id)))
	actions.add_child(_make_button("展示万物 / 鱼获", _open_npc_share.bind(npc_id)))
	var deep_available: bool = game.relationship_state(npc_id) in ["熟悉", "信任"] and int(game.npc_deep_talk_days.get(npc_id, 0)) != game.day
	actions.add_child(_make_button("深入交谈 · 0.5—1潮刻", _npc_deep_action.bind(npc_id), not deep_available))
	actions.add_child(_make_button("在地图上查看", _open_map))
	_add_npc_service_buttons(npc_id, actions)
	var invitations: Array = game.poker_invitation_rows(npc_id)
	if not invitations.is_empty():
		modal_body.add_child(_make_text("牌会邀请", Color("f1d687")))
		for raw_invitation in invitations:
			var invitation: Dictionary = raw_invitation
			var invitation_panel := PanelContainer.new()
			invitation_panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("b99e63") if bool(invitation["available"]) else Color("4e6265")))
			var invitation_row := HBoxContainer.new()
			invitation_panel.add_child(invitation_row)
			var invitation_copy := _make_text("%s\n%s · %s" % [str(invitation["title"]), str(invitation["description"]), str(invitation["status"])], Color("d6e6e2"))
			invitation_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			invitation_row.add_child(invitation_copy)
			invitation_row.add_child(_make_button("接受邀请", _accept_poker_invitation.bind(str(invitation["id"])), not bool(invitation["available"])))
			modal_body.add_child(invitation_panel)


func _npc_portrait(npc_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(154, 194)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("152f37"), Color("6c9791")))
	var center := CenterContainer.new()
	panel.add_child(center)
	var texture: Texture2D
	for raw_definition in WorldLayoutScript.NPC_VISUALS:
		var definition: Dictionary = raw_definition
		if str(definition.get("id", "")) == npc_id:
			texture = load(str(definition.get("atlas", "")))
			break
	if texture == null:
		center.add_child(_make_text("暂无肖像", Color("83999a")))
		return panel
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(0, 0, 48, 64)
	frame.filter_clip = true
	var art := TextureRect.new()
	art.texture = frame
	art.custom_minimum_size = Vector2(132, 176)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(art)
	return panel


func _add_npc_service_buttons(npc_id: String, target: Control = null) -> void:
	var parent: Control = modal_body if target == null else target
	var services: Array = game.npc_profile(npc_id).get("services", [])
	for raw_service in services:
		var service := str(raw_service)
		match service:
			"synthesis":
				parent.add_child(_make_button("使用造化盆", _open_synthesis))
			"poker":
				parent.add_child(_make_button("进入命运牌会", _open_poker))
			"race":
				parent.add_child(_make_button("查看逐风竞速", _open_race))
			"news":
				parent.add_child(_make_button("查看《晴潮晨报》", _open_news))
			"shop":
				parent.add_child(_make_button("使用研究商店", _open_shop))


func _npc_talk_action(npc_id: String) -> void:
	var result: Dictionary = game.npc_talk(npc_id)
	_open_npc(npc_id, str(result.get("text", "对方暂时没有新的话。")))


func _open_npc_topics(npc_id: String) -> void:
	var profile: Dictionary = game.npc_profile(npc_id)
	_open_modal("%s · 可询问话题" % str(profile.get("name", npc_id)))
	modal_body.add_child(_make_text("公开事实保证当前真实；有来源消息可能不完整；人物观点不保证正确。普通询问不消耗潮刻。", Color("a9c7c4")))
	var topics: Array = game.npc_topics(npc_id)
	if topics.is_empty():
		modal_body.add_child(_make_text("当前没有开放的话题。"))
	for raw_topic in topics:
		var topic: Dictionary = raw_topic
		var read_suffix := " · 本时段已读" if bool(topic.get("read", false)) else ""
		modal_body.add_child(_make_button(
			"%s｜%s%s" % [str(topic.get("type", "人物观点")), str(topic.get("label", "话题")), read_suffix],
			_npc_ask_action.bind(npc_id, str(topic.get("id", "")))
		))
	modal_body.add_child(_make_button("返回人物页", _open_npc.bind(npc_id)))


func _npc_ask_action(npc_id: String, topic_id: String) -> void:
	var result: Dictionary = game.npc_ask(npc_id, topic_id)
	var profile: Dictionary = game.npc_profile(npc_id)
	_open_modal("%s · 话题记录" % str(profile.get("name", npc_id)))
	modal_body.add_child(_make_text(str(result.get("text", "这条话题现在没有内容。")), Color("f4e2a9")))
	if bool(result.get("ok", false)):
		modal_body.add_child(_make_text("类型：%s\n来源：%s\n生成：%s\n有效期：%s%s" % [
			str(result.get("type", "")),
			str(result.get("source", "")),
			str(result.get("generated_at", "")),
			str(result.get("valid_until", "")),
			"\n本时段已读；重复查看不产生新奖励或新线索。" if bool(result.get("repeat", false)) else ""
		], Color("a9c7c4")))
	modal_body.add_child(_make_button("返回话题", _open_npc_topics.bind(npc_id)))
	modal_body.add_child(_make_button("返回人物页", _open_npc.bind(npc_id)))


func _open_npc_request(npc_id: String, notice_text: String = "") -> void:
	var profile: Dictionary = game.npc_profile(npc_id)
	var request: Dictionary = game.npc_request_info(npc_id)
	_open_modal("%s · 委托" % str(profile.get("name", npc_id)))
	if not notice_text.is_empty():
		modal_body.add_child(_make_text(notice_text, Color("d4f4df")))
	if request.is_empty():
		modal_body.add_child(_make_text("当前没有基础委托。"))
	else:
		var state_labels := {"locked": "尚未出现", "available": "可以接受", "active": "进行中", "completed": "已经完成"}
		var state := str(request.get("state", "available"))
		modal_body.add_child(_make_text("%s · %s" % [str(request.get("title", "人物请求")), str(state_labels.get(state, state))], Color("f1d687")))
		modal_body.add_child(_make_text("目标：%s\n线索：%s" % [str(request.get("objective", "")), str(request.get("hint", ""))]))
		if state == "available":
			modal_body.add_child(_make_button("接受委托", _npc_accept_request.bind(npc_id)))
		elif state == "active":
			modal_body.add_child(_make_text("目标状态：%s" % ("已经满足，可以交付" if bool(request.get("condition_met", false)) else "尚未满足"), Color("9edbb6") if bool(request.get("condition_met", false)) else Color("d3b58a")))
			modal_body.add_child(_make_button("尝试交付", _npc_turn_in_request.bind(npc_id)))
		elif state == "locked":
			modal_body.add_child(_make_text("先完成与该人物相关的基础引导，委托才会出现。", Color("aab9ba")))
		elif state == "completed":
			modal_body.add_child(_make_text("这项委托已经写入人物长期记忆，不能重复领取奖励。", Color("9edbb6")))
	modal_body.add_child(_make_button("返回人物页", _open_npc.bind(npc_id)))


func _npc_accept_request(npc_id: String) -> void:
	var result: Dictionary = game.accept_npc_request(npc_id)
	_open_npc_request(npc_id, str(result.get("text", "")))


func _npc_turn_in_request(npc_id: String) -> void:
	var result: Dictionary = game.turn_in_npc_request(npc_id)
	_open_npc_request(npc_id, str(result.get("text", "")))


func _open_npc_share(npc_id: String, notice_text: String = "") -> void:
	var profile: Dictionary = game.npc_profile(npc_id)
	_open_modal("%s · 展示与分享" % str(profile.get("name", npc_id)))
	if not notice_text.is_empty():
		modal_body.add_child(_make_text(notice_text, Color("d4f4df")))
	modal_body.add_child(_make_text("分享只读取永久图鉴，不会移除万物。同一人物与同一内容只在首次分享时产生关系或记忆变化。", Color("a9c7c4")))
	modal_body.add_child(_make_text("永久万物", Color("f1d687")))
	var item_grid := GridContainer.new()
	item_grid.columns = 3
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(item_grid)
	for item_id in game.discovered_item_ids():
		var share_key := "%s:%s" % [npc_id, item_id]
		item_grid.add_child(_make_button(
			"%d阶 · %s%s" % [game.item_tier(item_id), game.item_name(item_id), " · 已分享" if bool(game.npc_shared_creations.get(share_key, false)) else ""],
			_npc_share_creation.bind(npc_id, item_id),
			bool(game.npc_shared_creations.get(share_key, false))
		))
	modal_body.add_child(_make_text("海生尺寸纪录", Color("f1d687")))
	if game.marine_size_records.is_empty():
		modal_body.add_child(_make_text("尚未建立任何尺寸纪录。"))
	else:
		var fish_grid := GridContainer.new()
		fish_grid.columns = 3
		fish_grid.add_theme_constant_override("h_separation", 8)
		fish_grid.add_theme_constant_override("v_separation", 8)
		modal_body.add_child(fish_grid)
		for raw_species_id in game.marine_size_records.keys():
			var species_id := str(raw_species_id)
			var record: Dictionary = game.marine_size_records[species_id]
			var share_key := "%s:%s" % [npc_id, species_id]
			fish_grid.add_child(_make_button(
				"%s · %s%s" % [str(game.FISH_SPECIES.get(species_id, {}).get("name", species_id)), str(record.get("size", "标准")), " · 已展示" if bool(game.npc_shared_fish.get(share_key, false)) else ""],
				_npc_share_fish.bind(npc_id, species_id),
				bool(game.npc_shared_fish.get(share_key, false))
			))
	modal_body.add_child(_make_button("返回人物页", _open_npc.bind(npc_id)))


func _npc_share_creation(npc_id: String, item_id: String) -> void:
	var result: Dictionary = game.share_creation_with_npc(npc_id, item_id)
	_open_npc_share(npc_id, str(result.get("text", "")))


func _npc_share_fish(npc_id: String, species_id: String) -> void:
	var result: Dictionary = game.share_record_fish_with_npc(npc_id, species_id)
	_open_npc_share(npc_id, str(result.get("text", "")))


func _npc_deep_action(npc_id: String) -> void:
	var result: Dictionary = game.npc_deep_talk(npc_id)
	var profile: Dictionary = game.npc_profile(npc_id)
	var time_text: String = "\n\n统一结算：%.1f潮刻。" % float(result.get("time_cost", 0.0)) if bool(result.get("ok", false)) else ""
	_show_result(
		"深入交谈 · %s" % str(profile.get("name", npc_id)),
		"%s%s" % [str(result.get("text", "")), time_text],
		_open_npc.bind(npc_id)
	)


func _open_resident(resident_id: String) -> void:
	for raw_entry in game.environment_resident_entries():
		var entry: Dictionary = raw_entry
		if str(entry.get("id", "")) != resident_id:
			continue
		_open_modal("%s · %s" % [str(entry.get("name", "岛民")), str(entry.get("role", "环境居民"))])
		modal_body.add_child(_make_text(str(entry.get("dialogue", "")), Color("d6ece3")))
		modal_body.add_child(_make_text("位置：%s\n这是一条带明确说话人的环境闲谈；不会写入长期记忆，也不会保证未来价格、赛果或隐藏状态。" % str(entry.get("location", "")), Color("a9c7c4")))
		return
	_show_result("已经离开", "这名岛民当前不在这里。")


func _open_news() -> void:
	_open_modal("《晴潮晨报》")
	modal_body.add_child(_make_text("第%d日 · %s · %s · 公开赛事与鱼市观察" % [game.day, game.weather, game.wind_direction], Color("ffe7a6")))
	var port: Dictionary = game.port_economy_snapshot
	modal_body.add_child(_make_text("开放港口 · 常住%d人 · 今日流动%d人 · 到港船次%d · %d组公共经济账户" % [
		int(port.get("residents", 0)), int(port.get("visitors", 0)), int(port.get("arrivals", 0)), int(port.get("groups", game.world_group_accounts.size()))
	], Color("9edfc4")))
	if not game.world_economy_flows.is_empty():
		var recent_flows: Array[String] = []
		for raw_flow in game.world_economy_flows.slice(maxi(0, game.world_economy_flows.size() - 2)):
			var flow: Dictionary = raw_flow
			recent_flows.append("%s %d金贝" % [str(flow.get("tag", "公开经济流动")), int(flow.get("amount", 0))])
		modal_body.add_child(_make_text("最近港口流动：%s" % "；".join(recent_flows), Color("91bdb8")))
	var fish_rows: Array = game.fish_market_rows()
	if not fish_rows.is_empty():
		modal_body.add_child(_make_text("蓝鳍鱼铺 · 当前重点行情", Color("9edfc4")))
		for fish_index in range(mini(3, fish_rows.size())):
			var fish_row: Dictionary = fish_rows[fish_index]
			modal_body.add_child(_make_text("%s %d金贝 · 未完成订单%d · 库存%d · 预计到货%d · %s" % [str(fish_row["name"]), int(fish_row["quote"]), int(fish_row["demand"]), int(fish_row["stock"]), int(fish_row["expected_arrivals"]), "；".join(fish_row["reasons"])], Color("bfe2d7")))
		modal_body.add_child(_make_button("前往蓝鳍鱼铺", _open_dive.bind("market")))
	modal_body.add_child(HSeparator.new())
	var known_people: Array = game.npc_map_entries()
	if not known_people.is_empty():
		modal_body.add_child(_make_text("人物动态 · 只列已认识人物的公开活动", Color("e8c98a")))
		for raw_entry in known_people:
			var entry: Dictionary = raw_entry
			modal_body.add_child(_make_text("%s：%s · %s%s" % [
				str(entry.get("name", "人物")),
				str(entry.get("location", "未知区域")),
				str(entry.get("activity", "")),
				"" if bool(entry.get("available", false)) else "（当前不可交谈）"
			], Color("bcd5d2")))
		modal_body.add_child(HSeparator.new())
	var poker_summary: Dictionary = game.latest_poker_session_summary()
	if not poker_summary.is_empty():
		modal_body.add_child(_make_text("椰影茶摊 · 牌会传闻", Color("e8c98a")))
		modal_body.add_child(_make_text(game.poker_rumor_summary(), Color("bcd5d2")))
		modal_body.add_child(_make_button("查看牌会场次与邀请", _open_poker))
		modal_body.add_child(HSeparator.new())
	var share_news: Dictionary = game.share_market_news_summary()
	modal_body.add_child(_make_text("潮汐商会 · 产业份契", Color("e8c98a")))
	modal_body.add_child(_make_text(str(share_news.get("headline", "三家商会尚未形成经营消息。")), Color("bcd5d2")))
	modal_body.add_child(_make_text("%s · %s" % [str(share_news.get("status", {}).get("label", "")), str(share_news.get("status", {}).get("next_boundary", ""))], Color("91bdb8")))
	modal_body.add_child(_make_button("查看经营账目与份契", _open_share_market))
	modal_body.add_child(HSeparator.new())
	var race_news: Dictionary = game.race_news_summary()
	modal_body.add_child(_make_text("逐风竞速 · 今日赛场", Color("f0d27e")))
	modal_body.add_child(_make_text(str(race_news.get("headline", "今日赛事等待公开消息。")), Color("c7dcda")))
	var latest_race: Dictionary = race_news.get("latest", {})
	if not latest_race.is_empty():
		modal_body.add_child(_make_text("最近赛果：%s · %s夺魁 · %s" % [
			str(latest_race.get("name", "逐风赛事")),
			str(latest_race.get("winner_name", "未知")),
			"你的祝胜券命中" if bool(latest_race.get("won", false)) else "你的祝胜券未中"
		], Color("9edfc4")))
	modal_body.add_child(_make_button("查看今日赛程与票池", _open_race))
	modal_body.add_child(HSeparator.new())
	var finale: Dictionary = game.finale_progress()
	modal_body.add_child(_make_text("万象塔 · 归潮盛典", Color("f0d27e")))
	modal_body.add_child(_make_text(
		"归潮盛典已完成，岛上生活仍在继续。" if game.finale_completed else "岛上生活见证 %d/%d，全部完成后由万象塔举行盛典。" % [int(finale["completed"]), int(finale["total"])],
		Color("9edbb6") if game.finale_completed else Color("c7dcda")
	))
	modal_body.add_child(_make_button("查看万象塔与长期目标", _open_tower))


func _open_share_market(message: String = "") -> void:
	_open_modal("潮汐商会 · 产业份契")
	var status: Dictionary = game.share_market_status()
	var access := bool(game.can_trade_shares())
	if not message.is_empty():
		modal_body.add_child(_make_text(message, Color("9edbb6") if not ("不足" in message or "不能" in message or "不存在" in message) else Color("eda69b")))
	modal_body.add_child(_make_text("%s · %s\n%s" % [str(status["label"]), str(status["next_boundary"]), str(status["detail"])], Color("f1d687")))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	stats.add_child(_wealth_stat("可用金贝", "%d" % game.cash, Color("8ee0b1")))
	stats.add_child(_wealth_stat("待撮合", "%d" % game.share_reserved_cash, Color("f0d27e")))
	stats.add_child(_wealth_stat("份契估值", "%d" % game.share_liquidation_value(), Color("9edfc4")))
	modal_body.add_child(stats)
	modal_body.add_child(_make_text(
		"交易资格：%s。经营报告对所有人公开；账户财富首次达到20,000金贝后永久开放交易。份契可能上涨或下跌，不保证回本；当日买入次日才可卖出。"
		% ("已取得" if access else "未取得"),
		Color("c7dcda")
	))
	for raw_row in game.share_market_rows():
		var row: Dictionary = raw_row
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color(str(row["color"])) if access else Color("50666a")))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		var heading := HBoxContainer.new()
		var title := _make_text("%s · %s" % [str(row["name"]), str(row["sector"])], Color("f1d687"))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(title)
		var change := int(row["change"])
		var change_text := "±0" if change == 0 else ("%+d" % change)
		var price_label := _make_text("%d金贝 · %s（%+.1f%%）" % [int(row["price"]), change_text, float(row["change_rate"]) * 100.0], Color("8ee0b1") if change >= 0 else Color("eda69b"))
		price_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		price_label.custom_minimum_size.x = 220
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		heading.add_child(price_label)
		box.add_child(heading)
		box.add_child(_make_text(str(row["description"]), Color("a9c6c3")))
		var financials: Dictionary = row.get("financials", {})
		box.add_child(_make_text("总发行1,000份 · 校验%d · 玩家%d · 商会库存%d · 买方深度%d · 卖方深度%d" % [
			int(row.get("issued_total_check", 0)), int(row.get("quantity", 0)), int(row.get("company_inventory", 0)),
			int(row.get("bid_depth", 0)), int(row.get("ask_depth", 0))
		], Color("9edfc4")))
		box.add_child(_make_text("公司现金%d · 资产%d · 债务%d · 留存%+d · 分红准备%d · 基本价值约%.1f" % [
			int(financials.get("company_cash", 0)), int(financials.get("productive_assets", 0)), int(financials.get("debt", 0)),
			int(financials.get("retained_earnings", 0)), int(financials.get("dividend_reserve", 0)), float(row.get("fundamental_value", row["price"]))
		], Color("b8d3cf")))
		var report: Dictionary = row.get("report", {})
		box.add_child(_make_text("昨日经营：收入%d · 成本%d · 利润%+d · 每份分红%d" % [
			int(report.get("revenue", 0)), int(report.get("costs", 0)), int(report.get("profit", 0)), int(report.get("dividend_per_share", 0))
		], Color("d8e6df")))
		box.add_child(_make_text("公开原因：%s" % "；".join(report.get("drivers", ["尚无昨日经营数据"])), Color("91b9b6")))
		box.add_child(_make_text("%s · 持有%d / %d份 · 可售%d · 均价%.1f · 市值%d · 浮动%+.0f" % [
			str(row["influence"]), int(row["quantity"]), int(row["player_cap"]), int(row["sellable"]), float(row["average_cost"]),
			int(row["market_value"]), float(row["unrealized"])
		], Color("f0cf82")))
		var actions := GridContainer.new()
		actions.columns = 4
		actions.add_theme_constant_override("h_separation", 6)
		actions.add_theme_constant_override("v_separation", 6)
		var buy_one_total: int = int(row["price"]) + int(game.share_trade_fee(int(row["price"])))
		var buy_five_gross := int(row["price"]) * 5
		var buy_five_total: int = buy_five_gross + int(game.share_trade_fee(buy_five_gross))
		var sell_one_proceeds: int = int(row["price"]) - int(game.share_trade_fee(int(row["price"])))
		var cap_remaining := int(row["player_cap"]) - int(row["quantity"])
		if bool(status["open"]):
			actions.add_child(_make_button("买1 · %d" % buy_one_total, _trade_shares.bind(str(row["company_id"]), "buy", 1), not access or game.cash < buy_one_total or cap_remaining < 1 or int(row.get("ask_depth", 0)) < 1))
			actions.add_child(_make_button("买5 · %d" % buy_five_total, _trade_shares.bind(str(row["company_id"]), "buy", 5), not access or game.cash < buy_five_total or cap_remaining < 5 or int(row.get("ask_depth", 0)) < 1))
			actions.add_child(_make_button("卖1 · 收%d" % sell_one_proceeds, _trade_shares.bind(str(row["company_id"]), "sell", 1), not access or int(row["sellable"]) < 1 or int(row.get("bid_depth", 0)) < 1))
			actions.add_child(_make_button("卖出全部可售", _trade_shares.bind(str(row["company_id"]), "sell", int(row["sellable"])), not access or int(row["sellable"]) < 1 or int(row.get("bid_depth", 0)) < 1))
		else:
			var reserve_one := int(game.share_overnight_buy_reserve(str(row["company_id"]), 1))
			var reserve_five := int(game.share_overnight_buy_reserve(str(row["company_id"]), 5))
			actions.add_child(_make_button("挂次日买1 · 冻结%d" % reserve_one, _queue_share_order.bind(str(row["company_id"]), "buy", 1), not access or cap_remaining < 1 or game.cash < reserve_one))
			actions.add_child(_make_button("挂次日买5 · 冻结%d" % reserve_five, _queue_share_order.bind(str(row["company_id"]), "buy", 5), not access or cap_remaining < 5 or game.cash < reserve_five))
			actions.add_child(_make_button("挂次日卖1", _queue_share_order.bind(str(row["company_id"]), "sell", 1), not access or int(row["sellable"]) < 1))
			actions.add_child(_make_button("挂全部可售", _queue_share_order.bind(str(row["company_id"]), "sell", int(row["sellable"])), not access or int(row["sellable"]) < 1))
		box.add_child(actions)
		modal_body.add_child(panel)
	if not game.share_pending_orders.is_empty():
		modal_body.add_child(_make_text("待撮合订单", Color("f1d687")))
		for raw_order in game.share_pending_orders:
			var order: Dictionary = raw_order
			var company: Dictionary = game.SHARE_COMPANIES.get(str(order["company_id"]), {})
			var order_row := HBoxContainer.new()
			var order_text := "%s · 次日%s%d份 · 参考价%d%s" % [
				str(company.get("name", order["company_id"])),
				"买入" if str(order["side"]) == "buy" else "卖出",
				int(order["quantity"]), int(order["reference_price"]),
				(" · 冻结%d金贝" % int(order["reserved_cash"])) if int(order.get("reserved_cash", 0)) > 0 else ""
			]
			var order_label := _make_text(order_text, Color("c7dcda"))
			order_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			order_row.add_child(order_label)
			order_row.add_child(_make_button("撤销", _cancel_share_order.bind(str(order["order_id"]))))
			modal_body.add_child(order_row)
	if not game.share_trade_history.is_empty():
		modal_body.add_child(_make_text("最近成交", Color("f1d687")))
		for index in range(mini(6, game.share_trade_history.size())):
			var trade: Dictionary = game.share_trade_history[index]
			var company: Dictionary = game.SHARE_COMPANIES.get(str(trade["company_id"]), {})
			modal_body.add_child(_make_text("第%d天 · %s%s%d份 @ %d · 交易费%d · %s" % [
				int(trade["day"]), str(company.get("short_name", "")),
				"买" if str(trade["side"]) == "buy" else "卖", int(trade["quantity"]), int(trade["price"]),
				int(trade["fee"]), str(trade["source"])
			], Color("a9c6c3")))
	if not game.share_dividend_history.is_empty():
		var dividend: Dictionary = game.share_dividend_history[0]
		modal_body.add_child(_make_text("最近分红：第%d日共%d金贝。未满持有期或公司无可分利润时为0。" % [int(dividend["day"]), int(dividend["total"])], Color("9edfc4")))
	modal_body.add_child(_make_button("查看《晴潮晨报》产业消息", _open_news))
	modal_body.add_child(_make_button("查看财富轨迹", _open_wealth))


func _trade_shares(company_id: String, side: String, quantity: int) -> void:
	var result: Dictionary = game.trade_shares(company_id, side, quantity)
	_open_share_market(str(result.get("text", "交易未执行。")))


func _queue_share_order(company_id: String, side: String, quantity: int) -> void:
	var result: Dictionary = game.queue_share_order(company_id, side, quantity)
	_open_share_market(str(result.get("text", "订单未提交。")))


func _cancel_share_order(order_id: String) -> void:
	var result: Dictionary = game.cancel_share_order(order_id)
	_open_share_market(str(result.get("text", "订单未撤销。")))


func _open_tower() -> void:
	_open_modal("万象塔")
	modal_body.add_child(_art_banner(IslandGroundMap, 210.0))
	var count: int = int(game.discovered_recipe_count())
	modal_body.add_child(_make_text("塔身会回应你真正理解并留下的关系。当前谱系：%d / %d。" % [count, game.RECIPES.size()], Color("d8f4f8")))
	for raw_floor in game.tower_floor_states():
		var floor: Dictionary = raw_floor
		var unlocked: bool = bool(floor["unlocked"])
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(Color("173039"), Color("c0a65e") if unlocked else Color("465d61")))
		var box := VBoxContainer.new()
		panel.add_child(box)
		box.add_child(_make_text("%s　%s" % ["✓ 已点亮" if unlocked else "◇ 尚未点亮", str(floor["name"])], Color("f0d27e") if unlocked else Color("91a4a5")))
		box.add_child(_make_text("%s · %d/%d条关系" % [str(floor["description"]), int(floor["current"]), int(floor["need"])], Color("c5d8d5")))
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 15
		progress.show_percentage = false
		progress.value = float(floor["progress"]) * 100.0
		progress.add_theme_stylebox_override("background", _progress_style(Color("11272e"), Color("40585c")))
		progress.add_theme_stylebox_override("fill", _progress_style(Color("9d8747"), Color("e5c96f")))
		box.add_child(progress)
		modal_body.add_child(panel)
	var goal: Dictionary = game.synthesis_goal()
	if bool(goal.get("complete", false)):
		modal_body.add_child(_make_text("四象观台已经完整点亮。你获得永久头衔“万象之主”，仍可免费复查全部关系。", Color("f4df8a")))
	else:
		modal_body.add_child(_make_text("下一目标：%s · 还需%d条稳定关系。%s" % [
			str(goal.get("title", "")), int(goal.get("remaining", 0)),
			("建议从%s继续观察，它仍连接%d条可直接推导关系。" % [str(goal.get("anchor_name", "")), int(goal.get("anchor_opportunities", 0))]) if not str(goal.get("anchor_name", "")).is_empty() else ""
		], Color("9edbb6")))
		if not str(goal.get("anchor_id", "")).is_empty():
			modal_body.add_child(_make_button("把%s放入造化盆左侧" % str(goal.get("anchor_name", "")), _open_synthesis_with_item.bind(str(goal.get("anchor_id", "")), "left")))
	var finale: Dictionary = game.finale_progress()
	modal_body.add_child(HSeparator.new())
	modal_body.add_child(_make_text("归潮盛典 · 岛上生活见证 %d/%d" % [int(finale["completed"]), int(finale["total"])], Color("f0d27e")))
	for raw_requirement in finale["requirements"]:
		var requirement: Dictionary = raw_requirement
		modal_body.add_child(_make_text("%s %s · %s" % [
			"✓" if bool(requirement["complete"]) else "◇",
			str(requirement["name"]), str(requirement["description"])
		], Color("9edbb6") if bool(requirement["complete"]) else Color("91a4a5")))
	if game.finale_completed:
		modal_body.add_child(_make_text(_finale_summary_text(game.finale_summary), Color("f4df8a")))
		modal_body.add_child(_make_text("归潮之后，存档与全部正式玩法继续开放。", Color("9edbb6")))
		for raw_postgame in game.postgame_goals():
			var postgame: Dictionary = raw_postgame
			modal_body.add_child(_make_text("%s %s · %d/%d" % [
				"✓" if bool(postgame["complete"]) else "◇", str(postgame["name"]),
				int(postgame["current"]), int(postgame["target"])
			], Color("9edbb6") if bool(postgame["complete"]) else Color("a9c4c0")))
	else:
		modal_body.add_child(_make_button(
			"举行归潮盛典 · 1潮刻" if bool(finale["complete"]) else "见证尚未完整",
			_run_finale,
			not bool(finale["complete"]) or game.day_end_pending
		))
		if not bool(finale["complete"]):
			modal_body.add_child(_make_button("返回居所完善生活见证", _open_home))
	modal_body.add_child(_make_button("查看万物图鉴", _open_collection))
	modal_body.add_child(_make_button("前往造化盆", _open_synthesis))


func _open_poker(message: String = "") -> void:
	_open_modal("命运牌会 · 场次与桌级")
	modal_body.add_child(_make_text("短牌会最多8手并在离桌时统一推进2潮刻；完整牌会最多16手并推进4潮刻。桌内思考、规则查询和演出不额外走时。桌级提高会同步提高本局上限、基础投入和NPC带来的钱包。", Color("d5e8e4")))
	modal_body.add_child(_make_text("当前持有%d金贝 · 财富头衔：%s" % [game.cash, game.wealth_title()], Color("f0d27e")))
	var latest_summary: Dictionary = game.latest_poker_session_summary()
	if not latest_summary.is_empty():
		modal_body.add_child(_make_text("最近牌会：%s" % game.poker_rumor_summary(), Color("9edbb6")))
	if not game.poker_completed:
		var tutorial: Dictionary = game.poker_invitation_rows()[0]
		var tutorial_panel := PanelContainer.new()
		tutorial_panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("d0b765")))
		var tutorial_box := VBoxContainer.new()
		tutorial_panel.add_child(tutorial_box)
		tutorial_box.add_child(_make_text("首次入席 · 六手命象教学", Color("f2d984")))
		tutorial_box.add_child(_make_text("独立100金贝额度，亏损不动原有钱包；只有超过100的净盈利会带回。六手依次覆盖：命牌与天象、回响、升势/轮转、既济/双镜、下注信息、离桌结算。", Color("c5d9d5")))
		tutorial_box.add_child(_make_text(_poker_time_warning(2), Color("e7bd7d")))
		tutorial_box.add_child(_make_button("接受榕奶奶教学 · 6手 / 2潮刻", _accept_poker_invitation.bind(str(tutorial["id"]))))
		modal_body.add_child(tutorial_panel)
		return

	modal_body.add_child(_make_text("今日人物牌会邀请", Color("f1d687")))
	for raw_invitation in game.poker_invitation_rows():
		var invitation: Dictionary = raw_invitation
		var invite_panel := PanelContainer.new()
		invite_panel.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("b99e63") if bool(invitation["available"]) else Color("4e6265")))
		var invite_row := HBoxContainer.new()
		invite_panel.add_child(invite_row)
		var invite_copy := VBoxContainer.new()
		invite_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		invite_copy.add_child(_make_text("%s · %s" % [str(invitation["host_name"]), str(invitation["title"])], Color("f1d687") if bool(invitation["available"]) else Color("9babad")))
		invite_copy.add_child(_make_text("%s\n%s · %s · 上限%d金贝" % [
			str(invitation["description"]), str(invitation["phase"]),
			str(game.poker_session_mode_info(str(invitation["mode"]))["name"]), int(invitation["buy_in"])
		], Color("b9cfcd")))
		invite_row.add_child(invite_copy)
		invite_row.add_child(_make_button(str(invitation["status"]), _accept_poker_invitation.bind(str(invitation["id"])), not bool(invitation["available"])))
		modal_body.add_child(invite_panel)

	modal_body.add_child(_make_text("公共牌桌", Color("f1d687")))
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
		var actions := VBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		actions.add_child(_make_button("短牌会 · 8手 / 2潮刻" if available else "尚未开放", _enter_poker_tier.bind(buy_in, "short", "", message), not available))
		actions.add_child(_make_button("完整牌会 · 16手 / 4潮刻" if available else "尚未开放", _enter_poker_tier.bind(buy_in, "full", "", message), not available))
		row.add_child(actions)
		modal_body.add_child(panel)


func _poker_time_warning(time_cost: int) -> String:
	var current_value := float(game.tide - 1) + float(game.tide_progress)
	var end_value := current_value + float(time_cost)
	var crosses_phase := int(floor(current_value / 4.0)) != int(floor(minf(15.999, end_value) / 4.0))
	var end_text := "并进入日终停驻" if end_value >= 16.0 else ("，将跨过时段边界并刷新NPC日程、鱼价与赛事" if crosses_phase else "")
	return "离桌统一推进%d潮刻%s。" % [time_cost, end_text]


func _accept_poker_invitation(invitation_id: String) -> void:
	var selected: Dictionary = {}
	for raw_invitation in game.poker_invitation_rows():
		var invitation: Dictionary = raw_invitation
		if str(invitation["id"]) == invitation_id:
			selected = invitation
			break
	if selected.is_empty() or not bool(selected.get("available", false)):
		_show_result("邀请尚未开放", str(selected.get("status", "这份邀请当前不可接受。")), _open_poker)
		return
	_enter_poker_tier(int(selected["buy_in"]), str(selected["mode"]), invitation_id, "受%s邀请 · %s" % [str(selected["host_name"]), str(selected["title"])])


func _enter_poker_tier(buy_in: int, mode: String = "short", invitation_id: String = "", message: String = "") -> void:
	game.save_game("user://saves/activity_poker.json", _world_save_state(), true)
	modal_overlay.visible = false
	game.begin_poker_session(buy_in, mode, invitation_id)
	poker_table.open("%s%s" % [message, ("\n%s" % _poker_time_warning(game.poker_session_time_cost())) if not message.is_empty() else _poker_time_warning(game.poker_session_time_cost())])
	player.controls_enabled = false


func _on_poker_table_closed() -> void:
	game.end_poker_session()
	player.controls_enabled = true
	_apply_npc_schedule()
	_refresh_hud()


func _open_race() -> void:
	modal_overlay.visible = false
	race_arena.open(game)
	race_bet_spin = race_arena.bet_spin
	race_event_id = race_arena.event_id
	player.controls_enabled = false
	return
	_open_modal("逐风竞速 · 今日四场")
	modal_body.add_child(_art_banner(RaceBanner, 190.0))
	modal_body.add_child(_make_text("每个时段只有一场正式赛事。阵容、天气与开盘票池已经锁定；购票后仍会有NPC在封盘前加入，当前赔率是预计返还，结算使用封盘赔率。造物只提供信息，不改变赛果、票池或随机种子。", Color("c9f6d8")))
	var schedule := GridContainer.new()
	schedule.columns = 2
	schedule.add_theme_constant_override("h_separation", 8)
	schedule.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(schedule)
	for raw_event in game.race_schedule_rows():
		var event: Dictionary = raw_event
		var active: bool = bool(event.get("active", false))
		var completed: bool = bool(event.get("completed", false))
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(350, 112)
		panel.add_theme_stylebox_override("panel", _panel_style(
			Color("17343b"),
			Color("e2c467") if active else (Color("72ad91") if completed else Color("50696d"))
		))
		var box := VBoxContainer.new()
		panel.add_child(box)
		box.add_child(_make_text("%s · 第%d潮刻" % [str(event["name"]), int(event["scheduled_tide"])], Color("f1d687") if active else Color("c3d0cd")))
		box.add_child(_make_text("%s\n%s" % [str(event["status"]), str(event["weather"])], Color("8fe0b4") if active else Color("92a7a7")))
		if completed:
			box.add_child(_make_text("%s夺魁" % str(event.get("result_summary", {}).get("winner_name", "已完赛")), Color("9edfc4")))
		schedule.add_child(panel)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	nav.add_child(_make_button("赛事历史", _open_race_history))
	nav.add_child(_make_button("查看晨报", _open_news))
	modal_body.add_child(nav)

	var event: Dictionary = game.current_race_event()
	if event.is_empty():
		race_event_id = ""
		var next_event: Dictionary = game.next_race_event()
		if next_event.is_empty():
			modal_body.add_child(_make_text("今天四场赛事均已结束或错过。回漂流小屋休息后，明日阵容、天气快照与票池会重新生成。", Color("e3c987")))
		else:
			var wait_amount: float = float(game.tides_until_next_race())
			modal_body.add_child(_make_text("本时段赛事已经结束。下一场：%s · 第%d潮刻鸣钟；进入%s后开放购票。" % [
				str(next_event["name"]), int(next_event["scheduled_tide"]),
				["清晨", "白天", "傍晚", "夜晚"][int(next_event["slot"])]
			], Color("e3c987")))
			modal_body.add_child(_make_button("等待%.2f潮刻至下一场" % wait_amount, _wait_for_next_race.bind(wait_amount), wait_amount <= 0.0))
		return

	race_event_id = str(event["event_id"])
	modal_body.add_child(_make_text("%s · %s · %s\n%s" % [
		str(event["name"]), str(event["weather"]), str(event["wind"]), str(event["course_note"])
	], Color("f0d27e")))
	var roster_grid := GridContainer.new()
	roster_grid.columns = 2
	roster_grid.add_theme_constant_override("h_separation", 8)
	roster_grid.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(roster_grid)
	for beast_index in range(game.RACE_BEASTS.size()):
		var beast: Dictionary = game.RACE_BEASTS[beast_index]
		var roster_entry: Dictionary = event["roster"][beast_index]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(350, 145)
		card.add_theme_stylebox_override("panel", _panel_style(Color("163139"), Color("55777b")))
		var copy := VBoxContainer.new()
		card.add_child(copy)
		copy.add_child(_make_text("%d · %s · %s" % [beast_index + 1, str(beast["name"]), str(roster_entry["condition"])], Color("f1d687")))
		copy.add_child(_make_text("速%d 耐%d 爆%d 稳%d\n%s · %s" % [
			int(beast["speed"]), int(beast["stamina"]), int(beast["burst"]), int(beast["stability"]),
			str(roster_entry["strongest"]), game.race_beast_history_text(str(beast["id"]))
		], Color("b9cfcd")))
		copy.add_child(_make_text("独胜预计 %.2f · 入席预计 %.2f" % [
			game.race_event_odds(event, beast_index, "独胜"),
			game.race_event_odds(event, beast_index, "入席")
		], Color("8ed9ae")))
		roster_grid.add_child(card)

	var pool_rows: Array = game.race_pool_summary(event, "独胜")
	var pool_lines: Array[String] = []
	for pool_index in range(mini(3, pool_rows.size())):
		var row: Dictionary = pool_rows[pool_index]
		pool_lines.append("%s %d金贝（%.0f%%）" % [str(row["name"]), int(row["amount"]), float(row["share"]) * 100.0])
	modal_body.add_child(_make_text("当前独胜票池支持前三：%s。票池只是岛民选择，不是胜负答案。" % " · ".join(pool_lines), Color("a9c7c4")))
	var named_lines: Array[String] = []
	for ticket_index in range(mini(5, event.get("named_tickets", []).size())):
		var ticket: Dictionary = event["named_tickets"][ticket_index]
		named_lines.append("%s：%s %s %d金贝（%s）" % [
			str(ticket["name"]), str(ticket["ticket"]), str(ticket["beast_name"]), int(ticket["stake"]), str(ticket["style"])
		])
	modal_body.add_child(_make_text("公开购票观察\n• %s" % "\n• ".join(named_lines), Color("9dbbb8")))

	race_beast_option = OptionButton.new()
	for beast in game.RACE_BEASTS:
		race_beast_option.add_item(str(beast["name"]))
	race_beast_option.item_selected.connect(_update_race_preview, CONNECT_DEFERRED)
	modal_body.add_child(_labeled_control("选择逐风兽", race_beast_option))

	race_ticket_option = OptionButton.new()
	for ticket_type in game.ticket_types():
		race_ticket_option.add_item(ticket_type)
	race_ticket_option.item_selected.connect(_update_race_preview, CONNECT_DEFERRED)
	modal_body.add_child(_labeled_control("祝胜券类型", race_ticket_option))

	race_aid_option = OptionButton.new()
	race_aid_option.add_item("不使用造物")
	race_aid_option.set_item_metadata(0, "")
	for aid_id in game.race_aids_available():
		var aid: Dictionary = game.RACE_AIDS[aid_id]
		race_aid_option.add_item("%s · %d金贝" % [str(aid["name"]), int(aid["fee"])])
		race_aid_option.set_item_metadata(race_aid_option.item_count - 1, aid_id)
	race_aid_option.item_selected.connect(_update_race_preview, CONNECT_DEFERRED)
	modal_body.add_child(_labeled_control("赛前造物", race_aid_option))

	race_bet_spin = SpinBox.new()
	race_bet_spin.min_value = 10
	race_bet_spin.max_value = maxi(10, game.race_bet_cap())
	race_bet_spin.step = 10
	race_bet_spin.value = mini(20, maxi(10, game.race_bet_cap()))
	modal_body.add_child(_labeled_control("下注金贝", race_bet_spin))
	race_preview_label = _make_text("")
	modal_body.add_child(race_preview_label)
	modal_body.add_child(_make_button("确认购票并封盘", _run_race, game.free_race_ticket <= 0 and game.cash < 10))
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
	var event: Dictionary = game.race_event_by_id(race_event_id)
	if event.is_empty():
		race_preview_label.text = "这场赛事当前不可购票。"
		return
	var aid_info: Dictionary = game.race_aid_info(aid_id, beast_index, race_event_id)
	var free_text := "本场优先使用免费体验券（固定10金贝票面）" if game.free_race_ticket > 0 else "正式下注"
	var pool_row: Dictionary = {}
	for raw_row in game.race_pool_summary(event, ticket_type):
		if int(raw_row["beast_index"]) == beast_index:
			pool_row = raw_row
			break
	var expected_odds: float = float(game.race_event_odds(event, beast_index, ticket_type))
	race_preview_label.text = "%s · 速度%d / 耐力%d / 爆发%d / 稳定%d\n%s · 当前预计返还 %.2f倍 · 当前票池支持%.0f%% · 本场最多投入%d金贝\n封盘前赔率仍会随NPC购票变化；最终返还上限仍受真实概率约束。\n%s：%s" % [
		str(beast["name"]), int(beast["speed"]), int(beast["stamina"]), int(beast["burst"]), int(beast["stability"]),
		free_text, expected_odds, float(pool_row.get("share", 0.0)) * 100.0, game.race_bet_cap(game.cash - int(aid_info.get("fee", 0))),
		str(aid_info.get("name", "公开信息")), str(aid_info.get("insight", "本场不部署造物。"))
	]


func _run_race() -> void:
	if race_arena != null and race_arena.visible:
		_run_race_from_arena(race_arena.selected_beast, race_arena.selected_ticket, int(race_arena.bet_spin.value), race_arena.selected_aid, race_arena.event_id)
		return
	var beast_index := race_beast_option.selected
	var ticket_type := race_ticket_option.get_item_text(race_ticket_option.selected)
	var aid_id := str(race_aid_option.get_item_metadata(race_aid_option.selected))
	game.save_game("user://saves/activity_race.json", _world_save_state(), true)
	var result: Dictionary = game.run_race(beast_index, ticket_type, int(race_bet_spin.value), aid_id, race_event_id)
	_open_modal("逐风竞速 · 封盘与赛果")
	modal_body.add_child(_art_banner(RaceBanner, 160.0))
	modal_body.add_child(_make_text(str(result.get("text", "赛事未能开始。")), Color("fff2b0")))
	if bool(result.get("ok", false)):
		modal_body.add_child(_make_text("%s · 当前预计%.2f → 封盘%.2f（%+.2f）" % [
			str(result.get("event_name", "逐风赛事")),
			float(result.get("current_odds", 1.0)),
			float(result.get("final_odds", 1.0)),
			float(result.get("odds_shift", 0.0))
		], Color("f0d27e")))
		modal_body.add_child(_make_text("赛前造物：%s · 部署费%d金贝\n%s" % [str(result.get("aid_name", "不使用造物")), int(result.get("aid_fee", 0)), str(result.get("aid_insight", ""))], Color("9fe0ba")))
		modal_body.add_child(_make_text("票面%d金贝 · 赔率%.2f · 派彩%d金贝 · 本场净变化%+d金贝 · 当前%d金贝" % [int(result.get("stake", 0)), float(result.get("odds", 1.0)), int(result.get("payout", 0)), int(result.get("net_cash", 0)), int(result.get("cash_after", game.cash))], Color("f0d27e")))
		modal_body.add_child(_make_text("四段赛程动态回放", Color("f0d27e")))
		race_replay = RaceReplayScript.new()
		modal_body.add_child(race_replay)
		race_replay.setup(result, beast_index)
		var replay_actions := HBoxContainer.new()
		replay_actions.add_theme_constant_override("separation", 8)
		replay_actions.add_child(_make_button("重新播放", race_replay.replay))
		replay_actions.add_child(_make_button("跳到终点", race_replay.skip))
		modal_body.add_child(replay_actions)
		modal_body.add_child(_make_text("封盘前新增购票", Color("f0d27e")))
		var late_lines: Array[String] = []
		for late_index in range(mini(6, result.get("late_tickets", []).size())):
			var ticket: Dictionary = result["late_tickets"][late_index]
			late_lines.append("%s：%s %s %d金贝" % [str(ticket["name"]), str(ticket["ticket"]), str(ticket["beast_name"]), int(ticket["stake"])])
		modal_body.add_child(_make_text("• %s" % "\n• ".join(late_lines), Color("9dbbb8")))
		modal_body.add_child(_make_text("四段摘要", Color("f0d27e")))
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
		modal_body.add_child(_make_button("查看赛事历史", _open_race_history))
	else:
		modal_body.add_child(_make_button("返回今日赛程", _open_race))


func _run_race_from_arena(beast_index: int, ticket_type: String, stake: int, aid_id: String, event_id: String) -> void:
	game.save_game("user://saves/activity_race.json", _world_save_state(), true)
	var result: Dictionary = game.run_race(beast_index, ticket_type, stake, aid_id, event_id)
	race_arena.show_result(result)
	if bool(result.get("ok", false)):
		race_replay = race_arena.replay
	_refresh_hud()


func _on_race_arena_closed() -> void:
	player.controls_enabled = true
	_refresh_hud()


func _open_race_history_from_arena() -> void:
	race_arena.visible = false
	_open_race_history()


func _wait_for_next_race(amount: float) -> void:
	if amount <= 0.0 or not game.fast_forward_time(amount, "等待下一场逐风赛事"):
		_show_result("无法等待", "当前无法推进到下一场赛事。", _open_race)
		return
	_open_race()


func _open_race_history() -> void:
	_open_modal("逐风竞速 · 赛事历史")
	modal_body.add_child(_art_banner(RaceBanner, 140.0))
	if game.race_history.is_empty():
		modal_body.add_child(_make_text("还没有完成正式赛事。每场封盘快照、四段顺序、完整排名和玩家票据都会保存在这里。", Color("a9c7c4")))
	else:
		for history_index in range(game.race_history.size() - 1, maxi(-1, game.race_history.size() - 13), -1):
			var entry: Dictionary = game.race_history[history_index]
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", _panel_style(Color("17343b"), Color("55777b")))
			var copy := VBoxContainer.new()
			card.add_child(copy)
			copy.add_child(_make_text("第%d天 · %s · %s夺魁" % [
				int(entry["day"]), str(entry["name"]), str(entry["winner_name"])
			], Color("f1d687")))
			var ticket: Dictionary = entry.get("player_ticket", {})
			copy.add_child(_make_text("你：%s %s %d金贝 · 封盘%.2f · %s · 本场%+d金贝" % [
				str(ticket.get("ticket", "未购票")), str(ticket.get("beast_name", "")), int(ticket.get("stake", 0)),
				float(entry.get("final_odds", 1.0)), "命中" if bool(entry.get("won", false)) else "未中", int(entry.get("net_cash", 0))
			], Color("9edfc4") if bool(entry.get("won", false)) else Color("d7aaa2")))
			var stage_lines: Array[String] = []
			for raw_stage in entry.get("stage_reports", []):
				var stage: Dictionary = raw_stage
				stage_lines.append("%s：%s领先" % [str(stage["stage"]), str(stage["leader"])])
			copy.add_child(_make_text(" · ".join(stage_lines), Color("b9cfcd")))
			modal_body.add_child(card)
	modal_body.add_child(_make_button("返回今日赛程", _open_race))


func _open_map() -> void:
	_open_modal("岛屿地图")
	var overview = MapOverviewScript.new()
	var npc_entries: Array = game.npc_map_entries()
	var active_requests: Array[String] = []
	var quest_entries: Array = []
	for npc_id in NpcCatalogScript.core_ids():
		var request: Dictionary = game.npc_request_info(npc_id)
		if str(request.get("state", "")) == "active":
			var npc_name := str(game.npc_profile(npc_id).get("name", npc_id))
			active_requests.append("%s：%s" % [npc_name, str(request.get("objective", ""))])
			var schedule: Dictionary = game.npc_schedule_entry(npc_id)
			quest_entries.append({"npc_id": npc_id, "name": npc_name, "area": str(schedule.get("area", ""))})
	overview.setup(IslandGroundMap, discovered_areas, player.global_position, npc_entries, quest_entries)
	modal_body.add_child(overview)
	modal_body.add_child(_make_text("白圈是当前位置；地点节点对应真实入口。人物标记只显示已认识NPC所在的区域，不公开其精确脚下坐标。已发现区域之间快速前往消耗0.25潮刻。", Color("bde9f2")))
	modal_body.add_child(_make_text("当前：第%d天%s · %s · %s" % [game.day, game.phase_name(), game.weather, game.wind_direction], Color("f1d687")))
	var port: Dictionary = game.port_economy_snapshot
	modal_body.add_child(_make_text("开放港口：常住%d人 · 流动%d人 · 到港船次%d · %d组公共经济账户共同形成今日鱼市、商会与服务流量。" % [
		int(port.get("residents", 0)), int(port.get("visitors", 0)), int(port.get("arrivals", 0)), int(port.get("groups", game.world_group_accounts.size()))
	], Color("9edfc4")))
	if not npc_entries.is_empty():
		modal_body.add_child(_make_text("已认识人物", Color("f1d687")))
		for raw_entry in npc_entries:
			var entry: Dictionary = raw_entry
			var status := "%s · %s" % [str(entry.get("location", "未知区域")), str(entry.get("activity", ""))]
			if not bool(entry.get("available", false)):
				var substitute := str(entry.get("substitute", ""))
				status = "%s%s" % [status, (" · 基础服务由%s代班" % substitute) if not substitute.is_empty() else " · 当前不可交谈"]
			modal_body.add_child(_make_text("• %s：%s" % [str(entry.get("name", "人物")), status], Color("c7dcda") if bool(entry.get("available", false)) else Color("8fa1a3")))
	var business_lines: Array[String] = []
	var shop_schedule: Dictionary = game.npc_schedule_entry("shopkeeper")
	business_lines.append("椰影杂货铺：%s" % ("阿拓在场" if bool(shop_schedule.get("available", false)) else "%s代班" % str(shop_schedule.get("substitute", "店员"))))
	var fish_rows: Array = game.fish_market_rows()
	if not fish_rows.is_empty():
		business_lines.append("蓝鳍鱼铺：当前高价%s %d金贝 · 下个时段刷新" % [str(fish_rows[0].get("name", "鱼获")), int(fish_rows[0].get("quote", 0))])
	var share_status: Dictionary = game.share_market_status()
	business_lines.append("潮汐商会：%s · %s" % [str(share_status.get("label", "营业状态未知")), str(share_status.get("next_boundary", ""))])
	for raw_event in game.race_schedule_rows():
		var event: Dictionary = raw_event
		if bool(event.get("active", false)):
			business_lines.append("逐风竞速：%s正在开放" % str(event.get("name", "今日赛事")))
			break
	modal_body.add_child(_make_text("今日营业与活动\n• %s" % "\n• ".join(business_lines), Color("a9d9bf")))
	if not active_requests.is_empty():
		modal_body.add_child(_make_text("追踪中的委托（地图金色菱形）\n• %s" % "\n• ".join(active_requests), Color("f0cf82")))
	for area_name in WorldLayoutScript.AREA_ORDER:
		var unlocked := discovered_areas.has(area_name)
		var region: Dictionary = WorldLayoutScript.REGIONS[area_name]
		var label := "%s%s · %s" % ["前往 " if unlocked else "尚未发现 ", area_name, str(region["subtitle"])]
		if not unlocked:
			label += " · 沿岛上主路步行进入后开放"
		modal_body.add_child(_make_button(label, _travel_to.bind(area_name), not unlocked))


func _travel_to(area_name: String) -> void:
	if not discovered_areas.has(area_name) or not WorldLayoutScript.REGIONS.has(area_name):
		return
	player.global_position = WorldLayoutScript.spawn_for_area(area_name)
	current_area = area_name
	game.advance_time_fraction(0.25, "区域快速前往")
	_close_modal()
	_show_toast("已快速前往%s；消耗0.25潮刻。" % area_name)
