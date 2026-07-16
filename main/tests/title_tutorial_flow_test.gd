extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")
const TEST_SAVE_PATH := "user://tests/title_tutorial_save.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tutorial_state_and_version_migration()
	await _test_title_continue_and_new_game()
	_cleanup()
	print("TITLE TUTORIAL FLOW TEST PASS")
	quit(0)


func _state():
	var state = GameStateScript.new()
	state.recording_enabled = false
	return state


func _test_tutorial_state_and_version_migration() -> void:
	var state = _state()
	var initial: Dictionary = state.journey_tutorial_state()
	assert(int(initial["completed_count"]) == 0 and str(initial["current"]["id"]) == "explore", "新旅程必须从世界探索步骤开始。")
	state.record_journey_tutorial_action("move")
	assert(str(state.journey_tutorial_state()["current"]["id"]) == "synthesis", "真实移动后必须进入合成步骤。")
	var synthesis: Dictionary = state.synthesize_pair("water", "fire")
	assert(bool(synthesis.get("success", false)) and str(state.journey_tutorial_state()["current"]["id"]) == "dive", "成功发现首个万物后必须进入潜捕步骤。")
	var dive: Dictionary = state.begin_dive("sand_shallows")
	assert(bool(dive.get("ok", false)), "教学测试必须能从正式浅滩入口开始潜捕。")
	state.finish_dive(false)
	assert(str(state.journey_tutorial_state()["current"]["id"]) == "market", "完成真实潜捕结算后必须进入鱼市步骤。")
	state.fish_market_transactions.append({"sale_id": "tutorial-sale"})
	state.poker_completed = true
	state.race_history.append({"event_id": "tutorial-race"})
	state.sleep_to_next_day()
	var complete: Dictionary = state.journey_tutorial_state()
	assert(bool(complete["complete"]) and int(complete["completed_count"]) == 7, "七个步骤必须全部从真实模块状态得出完成结果。")
	state.set_journey_tutorial_hidden(true)
	var saved: Dictionary = state.build_save_data()
	assert(int(saved.get("version", 0)) == 9, "旅程引导必须进入版本9存档。")
	var restored = _state()
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "版本9引导状态必须可以往返读取。")
	assert(bool(restored.journey_tutorial_state()["complete"]) and restored.journey_tutorial_hidden, "引导动作、真实进度与隐藏偏好必须完整保存。")
	var legacy: Dictionary = saved.duplicate(true)
	legacy["version"] = 8
	legacy["state"].erase("journey_tutorial_actions")
	legacy["state"].erase("journey_tutorial_hidden")
	var migrated = _state()
	assert(bool(migrated.restore_save_data(legacy).get("ok", false)), "版本8存档必须迁移到版本9。")
	assert(not migrated.journey_tutorial_hidden and bool(migrated.journey_tutorial_state()["complete"]), "旧档迁移必须从已有模块事实重建进度，不能强迫老玩家重做。")


func _test_title_continue_and_new_game() -> void:
	_cleanup()
	var source = _state()
	source.cash = 456
	source.day = 4
	source.tide = 7
	var saved: Dictionary = source.save_game(TEST_SAVE_PATH, {"current_area": "椰影街", "player_position": {"x": 1500.0, "y": 520.0}, "discovered_areas": {"漂流湾": true, "椰影街": true}})
	assert(bool(saved.get("ok", false)), "标题页测试必须先创建隔离存档。")
	var summary: Dictionary = source.save_summary(TEST_SAVE_PATH)
	assert(bool(summary.get("ok", false)) and int(summary["day"]) == 4 and int(summary["account_wealth"]) == 456, "标题页必须只读提取日期、财富和区域摘要。")
	assert(source.available_save_summaries([TEST_SAVE_PATH]).size() == 1, "测试候选路径不得读取真实玩家存档。")

	root.size = Vector2i(1280, 720)
	var continue_scene = MainScene.instantiate()
	continue_scene.title_save_override_enabled = true
	continue_scene.title_save_paths_override.assign([TEST_SAVE_PATH])
	root.add_child(continue_scene)
	await process_frame
	assert(continue_scene.title_overlay.visible and not continue_scene.player.controls_enabled, "启动时标题页必须盖住世界并暂停角色控制。")
	assert(not continue_scene.title_continue_button.disabled and _tree_contains_text(continue_scene.title_overlay, "第4天"), "有效存档必须启用继续游戏并显示可核对摘要。")
	continue_scene.title_continue_button.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(not continue_scene.title_overlay.visible and continue_scene.game.cash == 456 and continue_scene.game.day == 4, "继续游戏必须读取所选最新存档后进入世界。")
	assert(continue_scene.player.controls_enabled and continue_scene.current_area == "椰影街", "继续游戏必须恢复角色控制、区域与世界位置。")
	continue_scene.free()
	await process_frame

	var new_scene = MainScene.instantiate()
	new_scene.title_save_override_enabled = true
	root.add_child(new_scene)
	await process_frame
	assert(new_scene.title_continue_button.disabled, "没有候选存档时继续游戏必须禁用。")
	new_scene.title_new_button.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(not new_scene.title_overlay.visible and new_scene.game.day == 1 and new_scene.game.cash == 120, "新游戏必须从干净初始状态进入世界。")
	assert(new_scene.tutorial_panel.visible, "新游戏进入世界后必须显示第一步旅程引导。")
	new_scene._open_shop()
	assert(_tree_contains_text(new_scene.modal_body, "阿拓在场") or _tree_contains_text(new_scene.modal_body, "正在代班"), "研究商店必须明确显示NPC在场或代班状态。")
	new_scene.game.known_npcs["granny"] = true
	new_scene.game.npc_request_states["granny"] = {"state": "active", "accepted_day": 1, "completed_day": 0}
	new_scene._open_map()
	assert(_tree_contains_text(new_scene.modal_body, "今日营业与活动") and _tree_contains_text(new_scene.modal_body, "地图金色菱形"), "地图必须同时显示营业摘要与主动委托追踪说明。")
	new_scene.game.tide = 4
	new_scene.game.tide_progress = 0.9
	new_scene.game.fish_catch_inventory = [{"catch_id": "warning-fish", "species_id": "bubble_sardine", "caught_day": 1}]
	var before_wait := float(new_scene.game.tide - 1) + float(new_scene.game.tide_progress)
	new_scene._wait_tides(0.2)
	assert(str(new_scene.modal_title.text) == "确认等待" and is_equal_approx(float(new_scene.game.tide - 1) + float(new_scene.game.tide_progress), before_wait), "跨鱼市刷新等待必须先确认，展示预警时不得推进时间。")
	var wait_confirm := _find_button(new_scene.modal_body, "确认等待")
	assert(wait_confirm != null, "等待预警必须提供明确确认按钮。")
	wait_confirm.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(float(new_scene.game.tide - 1) + float(new_scene.game.tide_progress) > before_wait, "确认等待后必须且只能由统一时间入口推进。")
	new_scene.free()


func _tree_contains_text(node: Node, fragment: String) -> bool:
	if node is Label and fragment in str((node as Label).text):
		return true
	if node is Button and fragment in str((node as Button).text):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, fragment):
			return true
	return false


func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and str((node as Button).text) == text_value:
		return node as Button
	for child in node.get_children():
		var result := _find_button(child, text_value)
		if result != null:
			return result
	return null


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
