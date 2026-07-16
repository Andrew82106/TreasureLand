extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const DiveTableScript := preload("res://scripts/dive_table.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var state: GameState = GameStateScript.new()
	state.recording_enabled = false
	var table = DiveTableScript.new()
	table.setup(state)
	root.add_child(table)
	table.open("prep")
	await process_frame
	await process_frame
	assert(table.visible and table.mode == "prep" and table.page_root.size.round() == Vector2(1280, 720), "潜捕准备必须是独立全屏页面。")
	assert(_tree_has_text(table, "白沙浅湾") and _tree_has_text(table, "珊瑚礁棚") and _tree_has_text(table, "沉船外缘"), "准备页必须同时展示三个区域与开放条件。")

	table._start_dive("sand_shallows")
	await process_frame
	await process_frame
	assert(table.mode == "dive" and state.dive_active and table.dive_field != null, "下水后必须进入带独立氧气时钟的水下场景。")
	var tide_before := state.tide
	var progress_before := state.tide_progress
	var oxygen_before := float(state.dive_state["oxygen"])
	table.dive_field.set_gameplay_paused(true)
	table.dive_field._process(2.0)
	assert(is_equal_approx(float(state.dive_state["oxygen"]), oxygen_before), "说明或暂停状态必须冻结水下氧气。")
	table.dive_field.set_gameplay_paused(false)
	table.dive_field._process(1.0)
	assert(float(state.dive_state["oxygen"]) < oxygen_before and state.tide == tide_before and is_equal_approx(state.tide_progress, progress_before), "水下现实秒数只能消耗氧气，不能推进世界时间。")

	var first_fish: Dictionary = table.dive_field.fish_states[0]
	table.dive_field.diver_position = first_fish["position"]
	var captured: Dictionary = table.dive_field.try_capture_nearest()
	assert(bool(captured.get("ok", false)), "玩家靠近鱼影按抓取键时必须把鱼放入鱼篓。")
	table._finish_dive(false)
	await process_frame
	await process_frame
	assert(table.mode == "result" and not state.dive_active and state.fish_catch_inventory.size() == 1, "主动上浮必须进入逐条识别的上岸结算。")
	assert(state.tide == tide_before + 1 and is_equal_approx(state.tide_progress, progress_before), "上岸只允许统一提交一次1潮刻。")

	table._show_mode("market")
	await process_frame
	assert(table.mode == "market" and _tree_has_text(table, "当前报价") and _tree_has_text(table, "你的鱼获箱"), "蓝鳍鱼铺必须同时展示供需行情和独立鱼获箱。")
	var cash_before := state.cash
	table._preview_all_sale()
	await process_frame
	assert(table.mode == "sale_preview" and not table.current_sale_preview.is_empty(), "出售前必须进入不可变分档预览。")
	table._confirm_sale(str(table.current_sale_preview["sale_id"]))
	await process_frame
	assert(table.mode == "market" and state.fish_catch_inventory.is_empty() and state.cash > cash_before, "确认出售必须回到鱼铺并完成鱼获、金贝和库存结算。")

	print("DIVE UI FLOW TEST PASS")
	quit(0)


func _tree_has_text(node: Node, fragment: String) -> bool:
	if node is Label and (node as Label).text.contains(fragment):
		return true
	if node is Button and (node as Button).text.contains(fragment):
		return true
	for child in node.get_children():
		if _tree_has_text(child, fragment):
			return true
	return false
