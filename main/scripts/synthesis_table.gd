extends Control

signal closed
signal collection_requested

const MaterialAtlas = preload("res://assets/art/shop_material_atlas_v1.png")
const CreationAtlas = preload("res://assets/art/synthesis_collection_atlas_v1.png")
const IslandBackdrop = preload("res://assets/art/island_panorama_v1.png")
const BasinBackdrop = preload("res://assets/art/synthesis_basin_backdrop_v1.svg")
const RelationVfxScript = preload("res://scripts/synthesis_relation_vfx.gd")
const SIGNAL_RETIREMENT_FRAMES := 4

const RELATION_FAMILY_BY_LABEL := {
	"聚集": "converge", "汇聚": "converge", "混合": "converge", "调和": "converge",
	"蓄积": "converge", "蓄压": "converge", "容纳": "converge", "约束": "converge",
	"封堵": "converge", "固岸": "converge", "附着": "converge", "嵌合": "converge",
	"熔合": "converge", "铺展": "converge", "分层": "converge", "裹挟": "converge",
	"相变": "thermal", "冷凝": "thermal", "冷却": "thermal", "增温": "thermal",
	"保温": "thermal", "聚热": "thermal", "围火": "thermal", "烧结": "thermal",
	"烘结": "thermal", "蒸干": "thermal", "激发": "thermal", "催化": "thermal",
	"做功": "thermal", "转化": "thermal", "放电": "thermal",
	"导流": "flow", "渗流": "flow", "渗压": "flow", "冲刷": "flow",
	"侵蚀": "flow", "磨蚀": "flow", "悬浮": "flow", "降水": "flow", "对流": "flow",
	"喷发": "burst", "释放": "burst", "冲击": "burst", "卷扬": "burst", "抬升": "burst",
	"地貌": "geology", "沉积": "geology", "堆积": "geology", "富集": "geology",
	"压积": "geology", "压实": "geology", "配土": "geology", "整平": "geology",
	"滞水": "geology", "侵入": "geology",
	"塑形": "craft", "模制": "craft",
	"生境": "life", "孕育": "life", "滋养": "life", "适应": "life",
}

var game
var left_id: String = ""
var right_id: String = ""
var left_tier_filter: int = 0
var right_tier_filter: int = 0
var last_result: Dictionary = {}
var busy: bool = false
var rebuild_queued: bool = false
var pulse_after_rebuild: bool = false
var strong_pulse_after_rebuild: bool = false
var rebuild_in_progress: bool = false
var center_pulse_tween: Tween
var presentation_tween: Tween
var presentation_generation: int = 0
var animations_enabled: bool = true
var reduced_motion: bool = false
var animation_speed_scale: float = 1.0

var page_root: Control
var left_library: GridContainer
var right_library: GridContainer
var center_stage: PanelContainer
var action_button: Button
var status_label: Label
var graph_overlay: ColorRect
var motion_layer: Control
var left_input_card: Control
var right_input_card: Control


func setup(state) -> void:
	game = state


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open() -> void:
	visible = true
	busy = false
	last_result = {}
	rebuild_queued = false
	pulse_after_rebuild = false
	strong_pulse_after_rebuild = false
	_rebuild()


func open_with_item(item_id: String, side: String = "left") -> void:
	if not game.is_discovered(item_id):
		open()
		return
	if side == "right":
		right_id = item_id
	else:
		left_id = item_id
	open()


func open_with_pair(left_item_id: String, right_item_id: String) -> void:
	if game.is_discovered(left_item_id):
		left_id = left_item_id
	if game.is_discovered(right_item_id):
		right_id = right_item_id
	open()


func request_close() -> void:
	if graph_overlay != null and is_instance_valid(graph_overlay) and graph_overlay.visible:
		graph_overlay.visible = false
		return
	if busy:
		return
	visible = false
	closed.emit()


func request_collection() -> void:
	if busy:
		return
	visible = false
	collection_requested.emit()


func _rebuild() -> void:
	if rebuild_in_progress:
		_queue_rebuild()
		return
	rebuild_in_progress = true
	presentation_generation += 1
	_retire_tween(presentation_tween)
	presentation_tween = null
	_retire_tween(center_pulse_tween)
	center_pulse_tween = null
	motion_layer = null
	left_input_card = null
	right_input_card = null
	for child in get_children():
		# Godot 4.7 can keep native BaseButton, Tween and layout signal dispatch
		# alive beyond a deferred call and even beyond one process frame. Do not
		# detach or free an emitter tree while rebuilding. Retire it invisibly,
		# keep it inside the SceneTree for several complete frames, then free it.
		_retire_ui_root(child)
	page_root = ColorRect.new()
	page_root.color = Color("08191f")
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_root)
	var island := TextureRect.new()
	island.texture = IslandBackdrop
	island.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	island.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	island.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	island.modulate = Color("8fb8ae70")
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_root.add_child(island)
	var shade := ColorRect.new()
	shade.color = Color("06171dcc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_root.add_child(shade)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 14)
	outer.add_theme_constant_override("margin_right", 14)
	outer.add_theme_constant_override("margin_top", 12)
	outer.add_theme_constant_override("margin_bottom", 12)
	page_root.add_child(outer)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	outer.add_child(page)
	page.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.add_child(_build_library_panel("left"))
	body.add_child(_build_center_stage())
	body.add_child(_build_library_panel("right"))
	page.add_child(body)
	page.add_child(_build_footer())
	graph_overlay = _build_graph_overlay()
	page_root.add_child(graph_overlay)
	graph_overlay.visible = false
	rebuild_in_progress = false


func _retire_ui_root(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_release_ui_root_after_signal_unwind(node)


func _release_ui_root_after_signal_unwind(node: Node) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for frame in range(SIGNAL_RETIREMENT_FRAMES):
		await tree.process_frame
	if is_instance_valid(node):
		node.queue_free()


func _retire_tween(tween: Tween) -> void:
	if tween == null:
		return
	if tween.is_valid() and tween.is_running():
		tween.kill()
	_hold_tween_after_signal_unwind(tween)


func _hold_tween_after_signal_unwind(tween: Tween) -> void:
	var tree := get_tree()
	if tree == null:
		return
	# The coroutine-local reference deliberately keeps a completed Tween alive.
	# Releasing the last reference from Tween.finished can crash Godot 4.7.
	for frame in range(SIGNAL_RETIREMENT_FRAMES):
		await tree.process_frame
	if tween != null and tween.is_valid() and tween.is_running():
		tween.kill()


func _queue_rebuild(pulse_center: bool = false, strong_pulse: bool = false) -> void:
	pulse_after_rebuild = pulse_after_rebuild or pulse_center
	strong_pulse_after_rebuild = strong_pulse_after_rebuild or strong_pulse
	if rebuild_queued:
		return
	rebuild_queued = true
	# call_deferred() alone is not a sufficient lifetime boundary here. The
	# request can originate from BaseButton.pressed or Tween.finished and Godot
	# 4.7 may drain deferred calls before the native signal dispatch has fully
	# unwound. Rebuilding then releases the emitter tree and can crash in C++.
	# Crossing a process-frame boundary guarantees the original signal stack is
	# gone before any controls or completed tweens are released.
	_begin_queued_rebuild.call_deferred()


func _begin_queued_rebuild() -> void:
	if not rebuild_queued:
		return
	if not is_inside_tree():
		rebuild_queued = false
		return
	await get_tree().process_frame
	_flush_queued_rebuild()


func _flush_queued_rebuild() -> void:
	if not rebuild_queued:
		return
	rebuild_queued = false
	var should_pulse := pulse_after_rebuild
	var strong_pulse := strong_pulse_after_rebuild
	pulse_after_rebuild = false
	strong_pulse_after_rebuild = false
	if not is_inside_tree() or not visible:
		return
	_rebuild()
	if should_pulse:
		_pulse_center(strong_pulse)


func _build_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 66
	panel.add_theme_stylebox_override("panel", _panel_style(Color("153039"), Color("6f9997"), 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var title := _label("万物合成 · 造化盆", Color("f4d77d"), 27)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.custom_minimum_size.x = 250
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var tier_parts: Array[String] = []
	for tier in range(1, 5):
		var progress: Dictionary = game.tier_discovery_progress(tier)
		tier_parts.append("%d阶 %d/%d" % [tier, int(progress["found"]), int(progress["total"])])
	var tier_label := _label("　".join(tier_parts), Color("a9d8c5"), 15)
	tier_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tier_label.custom_minimum_size.x = 330
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(tier_label)
	row.add_child(_button("图鉴 %d/%d" % [game.discovered_item_ids().size(), game.ITEMS.size()], request_collection, false, 104))
	var cash_label := _label("%d金贝" % game.cash, Color("8ee0b1"), 18)
	cash_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(cash_label)
	row.add_child(_button("组合谱", _show_graph, false, 92))
	row.add_child(_button("返回岛上", request_close, false, 112))
	return panel


func _build_library_panel(side: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 286
	panel.add_theme_stylebox_override("panel", _panel_style(Color("102931"), Color("557d80"), 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := _label("选择第一项" if side == "left" else "选择第二项", Color("f0d27e"), 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var copy := _label("选择一个永久万物 · 左右图鉴完全相同", Color("91afae"), 14)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(copy)
	var filter := OptionButton.new()
	filter.custom_minimum_size.y = 36
	for option_name in ["全部阶层", "一阶 · 根源", "二阶 · 反应", "三阶 · 环境与工艺", "四阶 · 世界成形"]:
		filter.add_item(option_name)
	filter.select(left_tier_filter if side == "left" else right_tier_filter)
	filter.item_selected.connect(_set_tier_filter.bind(side), CONNECT_DEFERRED)
	box.add_child(filter)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(grid)
	if side == "left":
		left_library = grid
	else:
		right_library = grid
	var tier_filter := left_tier_filter if side == "left" else right_tier_filter
	for item_id in game.discovered_item_ids():
		if tier_filter > 0 and game.item_tier(item_id) != tier_filter:
			continue
		grid.add_child(_item_card(side, item_id))
	return panel


func _item_card(side: String, item_id: String) -> PanelContainer:
	var selected := left_id == item_id if side == "left" else right_id == item_id
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(122, 137)
	card.add_theme_stylebox_override("panel", _panel_style(Color("18383f"), Color("f0ce68") if selected else Color("426d70"), 8))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	box.add_child(_item_art(item_id, 70.0))
	var choose := _button(("✓ " if selected else "") + game.item_name(item_id), _select_item.bind(side, item_id), busy, 0)
	choose.tooltip_text = game.item_description(item_id)
	box.add_child(choose)
	var relations: int = int(game.available_relation_count(item_id))
	var detail := _label("%d阶 · %s" % [game.item_tier(item_id), ("可研究%d条" % relations) if relations > 0 else str(game.ITEMS[item_id]["category"])], Color("9ec4bf"), 13)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	return card


func _build_center_stage() -> PanelContainer:
	center_stage = PanelContainer.new()
	center_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_stage.clip_contents = true
	center_stage.add_theme_stylebox_override("panel", _panel_style(Color("0e282ddd"), Color("b9a45c"), 12))
	var stage_root := Control.new()
	stage_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_stage.add_child(stage_root)
	var basin_art := TextureRect.new()
	basin_art.texture = BasinBackdrop
	basin_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	basin_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	basin_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	basin_art.modulate = Color("ffffffa8")
	basin_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(basin_art)
	var content_margin := MarginContainer.new()
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	stage_root.add_child(content_margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	content_margin.add_child(box)
	var title := _label("关系实验", Color("ffe399"), 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("观察两种万物如何彼此改变", Color("a6c6be"), 15)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	if not last_result.is_empty() and bool(last_result.get("ok", false)):
		box.add_child(_build_result_relation())
	else:
		box.add_child(_build_selection_relation())

	status_label = _label(_stage_status_text(), _stage_status_color(), 17)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 52
	box.add_child(status_label)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	var ready := not left_id.is_empty() and not right_id.is_empty()
	var prior: Dictionary = game.synthesis_attempt_record(left_id, right_id) if ready else {}
	var cost: int = int(game.synthesis_cost(left_id, right_id)) if ready else 0
	var terminal: bool = ready and not game.can_synthesize_pair(left_id, right_id)
	var blocked: bool = busy or not ready or terminal or (prior.is_empty() and game.cash < cost)
	var action_text := "四阶终点" if terminal else ("查看记录 · 0金贝" if not prior.is_empty() else "开始实验 · %d金贝" % cost)
	action_button = _button(action_text, _submit, blocked, 172)
	action_row.add_child(action_button)
	action_row.add_child(_button("清空", _clear_selection, busy or not ready, 82))
	box.add_child(action_row)
	box.add_child(_label("折扣凭证 %d次 · 历史组合永久免费复查" % game.synthesis_discount_uses, Color("9bb9b7"), 14))
	motion_layer = Control.new()
	motion_layer.name = "SynthesisMotionLayer"
	motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motion_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_layer.clip_contents = true
	motion_layer.z_index = 30
	stage_root.add_child(motion_layer)
	return center_stage


func _build_selection_relation() -> HBoxContainer:
	var relation := HBoxContainer.new()
	relation.alignment = BoxContainer.ALIGNMENT_CENTER
	relation.add_theme_constant_override("separation", 11)
	left_input_card = _selected_card(left_id, "左槽")
	relation.add_child(left_input_card)
	relation.add_child(_relation_symbol("＋"))
	right_input_card = _selected_card(right_id, "右槽")
	relation.add_child(right_input_card)
	return relation


func _build_result_relation() -> HBoxContainer:
	var relation := HBoxContainer.new()
	relation.alignment = BoxContainer.ALIGNMENT_CENTER
	relation.add_theme_constant_override("separation", 8)
	var result_left := str(last_result.get("left_id", left_id))
	var result_right := str(last_result.get("right_id", right_id))
	relation.add_child(_selected_card(result_left, ""))
	relation.add_child(_relation_symbol("＋"))
	relation.add_child(_selected_card(result_right, ""))
	if bool(last_result.get("success", false)):
		relation.add_child(_relation_symbol("→"))
		relation.add_child(_selected_card(str(last_result.get("output", "")), "新发现"))
	return relation


func _selected_card(item_id: String, placeholder: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(126, 170)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("102a31"), Color("d7bc68") if not item_id.is_empty() else Color("48666a"), 8))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	if item_id.is_empty() or not game.ITEMS.has(item_id):
		var empty := _label(placeholder, Color("799396"), 17)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(empty)
	else:
		box.add_child(_item_art(item_id, 102.0))
		var name_label := _label(game.item_name(item_id), Color("f4df9d"), 19)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name_label)
		var tier := _label("%d阶 · %s" % [game.item_tier(item_id), str(game.ITEMS[item_id]["category"])], Color("9fc5bf"), 13)
		tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tier)
	return panel


func _relation_symbol(text_value: String) -> Label:
	var label := _label(text_value, Color("f0d27e"), 27)
	label.custom_minimum_size.x = 30
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _stage_status_text() -> String:
	if busy:
		return "造化盆正在辨认这段关系……"
	if not last_result.is_empty():
		if not bool(last_result.get("ok", false)):
			return str(last_result.get("text", "实验未能开始。"))
		if bool(last_result.get("success", false)):
			var tower_text := ""
			var tower_unlocks: Array = last_result.get("tower_unlocks", [])
			if not tower_unlocks.is_empty():
				tower_text = "\n万象塔点亮：%s" % "、".join(tower_unlocks)
			return "%s · %s\n%s%s" % [str(last_result.get("relation", "稳定关系")), str(last_result.get("text", "发现新的万物。")), str(last_result.get("logic", "")), tower_text]
		return "%s\n%s\n%s" % [str(last_result.get("failure_title", "没有形成稳定关系")), str(last_result.get("failure_reason", "")), str(last_result.get("suggestion", ""))]
	if left_id.is_empty() or right_id.is_empty():
		return "从左右图鉴各选择一个万物。"
	if not game.can_synthesize_pair(left_id, right_id):
		return "四阶万物是当前谱系终点；五阶开放前不能继续推演，也不会收取金贝。"
	var prior: Dictionary = game.synthesis_attempt_record(left_id, right_id)
	if not prior.is_empty():
		return "这段关系已有记录，再次查看不收取金贝。"
	var cost: int = int(game.synthesis_cost(left_id, right_id))
	return "首次尝试这段关系需要%d金贝。万物本身永久保留。" % cost


func _stage_status_color() -> Color:
	if not last_result.is_empty() and bool(last_result.get("success", false)):
		return Color("9fe4b4")
	if not last_result.is_empty() and bool(last_result.get("ok", false)):
		return Color("e2ada3")
	return Color("d4e5d8")


func _build_footer() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 76
	panel.add_theme_stylebox_override("panel", _panel_style(Color("132e36"), Color("53777a"), 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var goal: Dictionary = game.synthesis_goal()
	copy.add_child(_label("当前目标 · %s" % str(goal.get("title", "谱系推进")), Color("f0d27e"), 17))
	copy.add_child(_label("%s%s" % [
		str(goal.get("description", _recent_progress_text())),
		(" · 可从%s继续推导" % str(goal.get("anchor_name", ""))) if not str(goal.get("anchor_name", "")).is_empty() else ""
	], Color("b9d3cf"), 14))
	row.add_child(copy)
	var visible_relations: int = int(game.count_untried_visible_pairs())
	var relation_count := _label("当前可推导的新关系 %d 条" % visible_relations, Color("8ee0b1"), 17)
	relation_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	relation_count.custom_minimum_size.x = 240
	relation_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(relation_count)
	return panel


func _recent_progress_text() -> String:
	if not last_result.is_empty() and bool(last_result.get("success", false)):
		var output_id := str(last_result.get("output", ""))
		return "%s进入%d阶图鉴；它现在有%d条可直接研究的关系。" % [game.item_name(output_id), game.item_tier(output_id), game.available_relation_count(output_id)]
	if game.recent_synthesis_pairs.is_empty():
		return "水、火、土构成三组根关系；任意两个不同根万物都能开启世界。"
	var record: Dictionary = game.attempted_pairs.get(str(game.recent_synthesis_pairs[0]), {})
	return "最近记录：%s + %s · %s" % [game.item_name(str(record.get("left_id", ""))), game.item_name(str(record.get("right_id", ""))), game.item_name(str(record.get("output", ""))) if bool(record.get("success", false)) else "未形成稳定关系"]


func _build_graph_overlay() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color("061419f2")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 42)
	overlay.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("142f38"), Color("9b8850"), 12))
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var header := HBoxContainer.new()
	var title := _label("四阶万物组合谱", Color("f3d77e"), 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("关闭组合谱", _hide_graph, false, 130))
	column.add_child(header)
	column.add_child(_label("已发现关系显示完整因果；未知节点保留暗格。四阶原型共%d个万物、%d条固定关系。" % [game.ITEMS.size(), game.RECIPES.size()], Color("a9c7c4"), 15))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	for tier in range(1, 5):
		content.add_child(_graph_tier_section(tier))
	return overlay


func _graph_tier_section(tier: int) -> PanelContainer:
	var progress: Dictionary = game.tier_discovery_progress(tier)
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _panel_style(Color("10272e"), Color("496b6d"), 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	section.add_child(box)
	box.add_child(_label("%d阶 · %d/%d" % [tier, int(progress["found"]), int(progress["total"])], Color("8ee0b1") if bool(progress["complete"]) else Color("f0d27e"), 20))
	var item_names: Array[String] = []
	var hidden_items := 0
	for raw_id in game.ITEMS.keys():
		var item_id := str(raw_id)
		if game.item_tier(item_id) == tier:
			if game.is_discovered(item_id):
				item_names.append(game.item_name(item_id))
			else:
				hidden_items += 1
	if not item_names.is_empty():
		box.add_child(_label("已发现：%s" % "　".join(item_names), Color("c7dad7"), 15))
	if hidden_items > 0:
		box.add_child(_label("◇ 未发现暗格 × %d" % hidden_items, Color("718c8f"), 15))
	if tier > 1:
		var hidden_relations := 0
		for raw_recipe in game.RECIPES:
			var recipe: Dictionary = raw_recipe
			var output_id := str(recipe["output"])
			if game.item_tier(output_id) != tier:
				continue
			if game.is_discovered(output_id):
				var inputs: Array = recipe["inputs"]
				box.add_child(_label("%s + %s → %s　[%s] %s" % [game.item_name(str(inputs[0])), game.item_name(str(inputs[1])), game.item_name(output_id), str(recipe.get("relation", "关系")), str(recipe.get("logic", ""))], Color("a8cbc4"), 14))
			else:
				hidden_relations += 1
		if hidden_relations > 0:
			box.add_child(_label("尚有%d条本阶关系等待验证" % hidden_relations, Color("647f82"), 14))
	return section


func _set_tier_filter(index: int, side: String) -> void:
	if busy:
		return
	if side == "left":
		left_tier_filter = index
	else:
		right_tier_filter = index
	_queue_rebuild()


func _select_item(side: String, item_id: String) -> void:
	if busy:
		return
	if side == "left":
		left_id = item_id
	else:
		right_id = item_id
	last_result = {}
	_queue_rebuild(true)


func _clear_selection() -> void:
	if busy:
		return
	left_id = ""
	right_id = ""
	last_result = {}
	_queue_rebuild()


func _submit() -> void:
	if busy or left_id.is_empty() or right_id.is_empty():
		return
	busy = true
	presentation_generation += 1
	var generation := presentation_generation
	var submitted_left := left_id
	var submitted_right := right_id
	if action_button != null:
		action_button.disabled = true
	if status_label != null:
		status_label.text = "两项万物正在进入造化盆……"
	# Resolve exactly once before presentation. Animation reveals this immutable
	# result and can never change recipes, currency, or discovery state.
	last_result = game.synthesize_pair(submitted_left, submitted_right)
	if animations_enabled and is_inside_tree():
		await get_tree().process_frame
		if _presentation_alive(generation):
			await _play_synthesis_presentation(generation, submitted_left, submitted_right, last_result)
	if not _presentation_alive(generation):
		return
	busy = false
	_queue_rebuild(true, true)


func _play_synthesis_presentation(
	generation: int,
	submitted_left: String,
	submitted_right: String,
	result: Dictionary
) -> void:
	if motion_layer == null or not is_instance_valid(motion_layer):
		return
	var left_start := _control_center_in_motion(left_input_card, Vector2(motion_layer.size.x * 0.31, motion_layer.size.y * 0.48))
	var right_start := _control_center_in_motion(right_input_card, Vector2(motion_layer.size.x * 0.69, motion_layer.size.y * 0.48))
	var basin_center := motion_layer.size * Vector2(0.5, 0.47)
	var left_proxy := _motion_card(submitted_left, left_start)
	var right_proxy := _motion_card(submitted_right, right_start)
	left_proxy.z_index = 2
	right_proxy.z_index = 2
	if left_input_card != null and is_instance_valid(left_input_card):
		left_input_card.modulate.a = 0.26
	if right_input_card != null and is_instance_valid(right_input_card):
		right_input_card.modulate.a = 0.26
	var approach_duration := _animation_duration(0.34 if not reduced_motion else 0.16)
	var approach_tween := create_tween().bind_node(self).set_parallel(true)
	presentation_tween = approach_tween
	approach_tween.tween_method(
		_set_motion_arc.bind(left_proxy, left_start, basin_center + Vector2(-22.0, 0.0), -38.0),
		0.0, 1.0, approach_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_method(
		_set_motion_arc.bind(right_proxy, right_start, basin_center + Vector2(22.0, 0.0), 38.0),
		0.0, 1.0, approach_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_property(left_proxy, "scale", Vector2(0.64, 0.64), approach_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	approach_tween.tween_property(right_proxy, "scale", Vector2(0.64, 0.64), approach_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _finish_presentation_tween(approach_tween)
	if not _presentation_alive(generation):
		return
	var successful := bool(result.get("ok", false)) and bool(result.get("success", false))
	var relation_family := _relation_family(str(result.get("relation", "")), successful)
	var effect = RelationVfxScript.new()
	effect.name = "RelationshipMotion"
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.z_index = 1
	effect.configure(
		relation_family,
		_item_motion_color(submitted_left),
		_item_motion_color(submitted_right),
		successful,
		reduced_motion
	)
	motion_layer.add_child(effect)
	motion_layer.move_child(effect, 0)
	if status_label != null and is_instance_valid(status_label):
		status_label.text = "%s正在发生……" % str(result.get("relation", "关系")) if successful else "两项万物正在寻找稳定关系……"
	var is_repeat := bool(result.get("repeat", false))
	var effect_duration := 0.40 if is_repeat else (0.64 if successful else 0.50)
	effect_duration = _animation_duration(effect_duration if not reduced_motion else 0.24)
	var relation_tween := create_tween().bind_node(self).set_parallel(true)
	presentation_tween = relation_tween
	relation_tween.tween_property(effect, "progress", 1.0, effect_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	relation_tween.tween_property(left_proxy, "modulate:a", 0.0, effect_duration * 0.52).set_delay(effect_duration * 0.28)
	relation_tween.tween_property(right_proxy, "modulate:a", 0.0, effect_duration * 0.52).set_delay(effect_duration * 0.28)
	await _finish_presentation_tween(relation_tween)
	if not _presentation_alive(generation):
		return
	left_proxy.queue_free()
	right_proxy.queue_free()
	if successful:
		await _reveal_synthesis_result(generation, str(result.get("output", "")), bool(result.get("first_discovery", false)), is_repeat)
	else:
		await _reveal_unstable_result(generation, result)
	if is_instance_valid(effect):
		effect.queue_free()


func _reveal_synthesis_result(generation: int, output_id: String, first_discovery: bool, is_repeat: bool) -> void:
	if output_id.is_empty() or motion_layer == null:
		return
	var result_card := _motion_card(output_id, motion_layer.size * Vector2(0.5, 0.46), "新发现" if first_discovery else "已验证")
	result_card.z_index = 3
	result_card.scale = Vector2(0.34, 0.34)
	result_card.modulate.a = 0.0
	var duration := _animation_duration(0.24 if is_repeat else (0.38 if not reduced_motion else 0.20))
	var reveal_tween := create_tween().bind_node(self).set_parallel(true)
	presentation_tween = reveal_tween
	reveal_tween.tween_property(result_card, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(result_card, "modulate:a", 1.0, duration * 0.72)
	reveal_tween.tween_property(result_card, "position:y", result_card.position.y - 6.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _finish_presentation_tween(reveal_tween)
	if not _presentation_alive(generation):
		return
	if status_label != null and is_instance_valid(status_label):
		status_label.text = ("新发现 · %s" if first_discovery else "已验证 · %s") % game.item_name(output_id)
	await get_tree().create_timer(_animation_duration(0.22 if is_repeat else 0.34)).timeout
	if is_instance_valid(result_card):
		result_card.queue_free()


func _reveal_unstable_result(generation: int, result: Dictionary) -> void:
	if motion_layer == null:
		return
	var badge := PanelContainer.new()
	badge.name = "UnstableRelationBadge"
	badge.custom_minimum_size = Vector2(236, 84)
	badge.size = Vector2(236, 84)
	badge.position = motion_layer.size * Vector2(0.5, 0.48) - badge.size * 0.5
	badge.pivot_offset = badge.size * 0.5
	badge.scale = Vector2(0.82, 0.82)
	badge.modulate.a = 0.0
	badge.z_index = 3
	badge.add_theme_stylebox_override("panel", _panel_style(Color("21373ad9"), Color("a99578"), 10))
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(copy)
	var title := _label("未成 · %s" % str(result.get("failure_title", "关系未稳")), Color("e7d0a7"), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(title)
	var hint := _label("两项万物保留，实验关系已记录", Color("9fb9b5"), 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(hint)
	motion_layer.add_child(badge)
	var duration := _animation_duration(0.28 if not reduced_motion else 0.16)
	var reveal_tween := create_tween().bind_node(self).set_parallel(true)
	presentation_tween = reveal_tween
	reveal_tween.tween_property(badge, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(badge, "modulate:a", 1.0, duration)
	await _finish_presentation_tween(reveal_tween)
	if not _presentation_alive(generation):
		return
	if status_label != null and is_instance_valid(status_label):
		status_label.text = str(result.get("failure_title", "这段关系没有稳定下来。"))
	await get_tree().create_timer(_animation_duration(0.32)).timeout
	if is_instance_valid(badge):
		badge.queue_free()


func _motion_card(item_id: String, center_value: Vector2, caption: String = "") -> Control:
	var card := _selected_card(item_id, caption)
	card.custom_minimum_size = Vector2(112, 152)
	card.size = Vector2(112, 152)
	card.position = center_value - card.size * 0.5
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_layer.add_child(card)
	return card


func _control_center_in_motion(control: Control, fallback: Vector2) -> Vector2:
	if control == null or not is_instance_valid(control) or motion_layer == null:
		return fallback
	return control.global_position + control.size * 0.5 - motion_layer.global_position


func _set_motion_arc(progress_value: float, node: Control, start: Vector2, finish: Vector2, arc_height: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var t := clampf(progress_value, 0.0, 1.0)
	var control_point := (start + finish) * 0.5 + Vector2(0.0, arc_height)
	var center_value := start * ((1.0 - t) * (1.0 - t)) + control_point * (2.0 * (1.0 - t) * t) + finish * (t * t)
	node.position = center_value - node.size * 0.5
	node.rotation = deg_to_rad(lerpf(-3.0 if arc_height < 0.0 else 3.0, 0.0, t))


func _relation_family(relation: String, successful: bool) -> String:
	if not successful:
		return "unstable"
	return str(RELATION_FAMILY_BY_LABEL.get(relation, "converge"))


func _item_motion_color(item_id: String) -> Color:
	if item_id == "water":
		return Color("64bbca")
	if item_id == "fire":
		return Color("e1844f")
	if item_id == "earth":
		return Color("b79a62")
	var category := str(game.ITEMS.get(item_id, {}).get("category", ""))
	return {
		"天象": Color("8fc8d4"), "气候": Color("8fc8d4"), "水系": Color("61aeba"),
		"地貌": Color("aa9568"), "地质": Color("aa9568"), "生境": Color("79ae72"),
		"生命": Color("77b878"), "材料": Color("c19b70"), "工艺": Color("d39b69"),
		"机械": Color("c8b66d"), "原理": Color("d7b85c"),
	}.get(category, Color("83b8ad"))


func _animation_duration(base_duration: float) -> float:
	return base_duration / maxf(0.1, animation_speed_scale)


func _finish_presentation_tween(tween: Tween) -> void:
	# Awaiting Tween.finished resumes inside the signal emission. Dropping the
	# last reference or replacing the member there can free the Tween from its
	# own callback and crash Godot 4.7. Cross one full frame before releasing it.
	await tween.finished
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_hold_tween_after_signal_unwind(tween)
	if presentation_tween == tween:
		presentation_tween = null


func _presentation_alive(generation: int) -> bool:
	return generation == presentation_generation and is_inside_tree() and visible


func _pulse_center(strong: bool = false) -> void:
	if center_stage == null:
		return
	center_stage.pivot_offset = center_stage.size * 0.5
	center_stage.scale = Vector2(0.985, 0.985) if strong else Vector2(0.994, 0.994)
	center_stage.modulate = Color("fff2b8") if strong else Color("d9f6ed")
	_retire_tween(center_pulse_tween)
	center_pulse_tween = create_tween().set_parallel(true)
	center_pulse_tween.tween_property(center_stage, "scale", Vector2.ONE, 0.28 if strong else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	center_pulse_tween.tween_property(center_stage, "modulate", Color.WHITE, 0.28 if strong else 0.14)


func _show_graph() -> void:
	graph_overlay.visible = true


func _hide_graph() -> void:
	graph_overlay.visible = false


func _item_art(item_id: String, size_value: float) -> TextureRect:
	var art := TextureRect.new()
	if not game.ITEMS.has(item_id):
		art.custom_minimum_size = Vector2(size_value, size_value)
		return art
	var source: String = str(game.item_art_source(item_id))
	var atlas_texture := AtlasTexture.new()
	if source == "creation":
		atlas_texture.atlas = CreationAtlas
		var tile_width := float(CreationAtlas.get_width()) / 3.0
		var tile_height := float(CreationAtlas.get_height()) / 3.0
		var index: int = int(game.item_art_index(item_id))
		atlas_texture.region = Rect2((index % 3) * tile_width, (index / 3) * tile_height, tile_width, tile_height)
	else:
		atlas_texture.atlas = MaterialAtlas
		var tile_width := float(MaterialAtlas.get_width()) / 4.0
		var tile_height := float(MaterialAtlas.get_height()) / 4.0
		var index: int = int(game.item_art_index(item_id))
		atlas_texture.region = Rect2((index % 4) * tile_width, (index / 4) * tile_height, tile_width, tile_height)
	art.texture = atlas_texture
	art.custom_minimum_size = Vector2(size_value, size_value)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


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
	button.custom_minimum_size = Vector2(width, 38)
	button.add_theme_color_override("font_color", Color("f5f2df"))
	button.add_theme_color_override("font_disabled_color", Color("77888a"))
	button.add_theme_stylebox_override("normal", _button_style(Color("29464e"), Color("62858a")))
	button.add_theme_stylebox_override("hover", _button_style(Color("38616a"), Color("a5c5bb")))
	button.add_theme_stylebox_override("pressed", _button_style(Color("1c343b"), Color("e5cd78")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("20343a"), Color("3e5559")))
	# Every button lives inside a tree that may be rebuilt by its own action.
	# Defer the callback so no action can detach or replace controls while the
	# native BaseButton signal is still being emitted (Godot 4.7 can otherwise
	# terminate with Object freed while a signal is being emitted).
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


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
