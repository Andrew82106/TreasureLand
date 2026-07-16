extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_discovery_records_and_migration()
	_test_tower_goals_and_cross_module_uses()
	await _test_collection_ui_and_shortcuts()
	print("COLLECTION PROGRESSION TEST PASS")
	quit(0)


func _state():
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.cash = 100000
	return state


func _test_discovery_records_and_migration() -> void:
	var state = _state()
	for root_id in ["water", "fire", "earth"]:
		var root_record := state.discovery_record(root_id)
		assert(str(root_record.get("first_source", "")) == "initial", "根万物必须记录为上岛时掌握：%s" % root_id)
		assert(int(root_record.get("first_day", 0)) == 1 and int(root_record.get("first_tide", 0)) == 1, "根万物必须具有稳定的首次时间。")

	state.day = 2
	state.tide = 4
	var result := state.synthesize_pair("water", "fire")
	assert(bool(result.get("success", false)) and bool(result.get("first_discovery", false)), "水火首次关系必须发现蒸汽。")
	var steam := state.discovery_record("steam")
	assert(str(steam.get("first_source", "")) == "synthesis", "非根万物必须记录造化盆来源。")
	assert(int(steam.get("first_day", 0)) == 2 and int(steam.get("first_tide", 0)) == 4, "首次档案必须记录结算前的真实日与潮刻。")
	assert(steam.get("inputs", []) == ["water", "fire"], "首次档案必须保存两项输入。")
	assert(str(steam.get("relation", "")) == "相变" and not str(steam.get("logic", "")).is_empty(), "首次档案必须保存关系语法与因果。")
	assert(state.item_verified_relation_count("water") == 1 and state.item_untried_pair_count("water") > 0, "详情统计必须区分已验证与尚未尝试的配对。")

	var save_data := state.build_save_data({})
	assert(int(save_data.get("version", 0)) == 5, "发现档案、赛事与牌会场次必须进入版本5存档。")
	var restored = _state()
	assert(bool(restored.restore_save_data(save_data).get("ok", false)), "当前版本发现档案必须可往返读取。")
	assert(restored.discovery_record("steam") == steam, "发现来源、输入、关系和时间必须完整跨存档保留。")

	var legacy = _state()
	var legacy_result := legacy.restore_save_data({
		"version": 2,
		"state": {
			"discovered": {"water": true, "fire": true, "earth": true, "steam": true},
			"attempted_pairs": {
				"fire|water": {
					"pair_key": "fire|water", "left_id": "water", "right_id": "fire",
					"success": true, "output": "steam", "result_id": "steam",
					"day": 3, "tide": 6, "cost_paid": 2
				}
			}
		},
		"world": {}
	})
	assert(bool(legacy_result.get("ok", false)), "版本2布尔发现存档必须迁移到当前版本。")
	var migrated := legacy.discovery_record("steam")
	assert(str(migrated.get("first_source", "")) == "synthesis" and migrated.get("inputs", []) == ["water", "fire"], "迁移必须从固定配方恢复首次来源与输入。")
	assert(int(migrated.get("first_day", 0)) == 3 and int(migrated.get("first_tide", 0)) == 6, "迁移必须优先使用旧实验记录的真实时间。")


func _test_tower_goals_and_cross_module_uses() -> void:
	var state = _state()
	var initial_goal := state.synthesis_goal()
	assert(str(initial_goal.get("floor_id", "")) == "tidefire_base" and int(initial_goal.get("target", 0)) == 3, "开局目标必须指向潮火基座三条根关系。")
	assert(not str(initial_goal.get("anchor_id", "")).is_empty() and int(initial_goal.get("anchor_opportunities", 0)) > 0, "目标链必须给出不泄露答案的已知锚点。")

	for index in range(3):
		var recipe: Dictionary = state.RECIPES[index]
		state.discover_item(str(recipe["output"]), "test", {
			"inputs": recipe["inputs"], "relation": recipe["relation"], "logic": recipe["logic"]
		})
	assert(bool(state.tower_milestones.get("tidefire_base", false)), "完成3条二阶关系必须点亮潮火基座。")
	assert(state.tower_floor_states()[0].get("unlocked", false), "塔层运行状态必须与永久发现同步。")
	var tower_memory_count := state.npc_long_memories("granny").filter(func(memory): return str(memory.get("memory_id", "")) == "tower_tidefire_base").size()
	state._sync_tower_milestones(true)
	assert(state.npc_long_memories("granny").filter(func(memory): return str(memory.get("memory_id", "")) == "tower_tidefire_base").size() == tower_memory_count, "已点亮塔层不能重复写记忆或奖励。")

	var steam_uses := state.item_cross_module_uses("steam")
	assert(steam_uses.any(func(use): return str(use.get("module", "")) == "人物委托"), "蒸汽详情必须展示榕奶奶委托用途。")
	state.discover_item("rain", "test", {})
	var rain_uses := state.item_cross_module_uses("rain")
	assert(rain_uses.any(func(use): return str(use.get("module", "")) == "逐风竞速"), "雨必须展示真实存在的逐风研读用途。")
	assert(rain_uses.any(func(use): return str(use.get("module", "")) == "万象塔"), "每项永久发现都必须展示万象塔用途。")

	for raw_recipe in state.RECIPES:
		var recipe: Dictionary = raw_recipe
		if not state.is_discovered(str(recipe["output"])):
			state.discover_item(str(recipe["output"]), "test", {
				"inputs": recipe["inputs"], "relation": recipe["relation"], "logic": recipe["logic"]
			})
	assert(bool(state.synthesis_goal().get("complete", false)), "发现72项万物后目标链必须进入完成状态。")
	assert(bool(state.tower_milestones.get("fourfold_observatory", false)) and state.ultimate_created, "完整谱系必须点亮四象观台并授予万象之主状态。")
	assert(state.wealth_title() == "万象之主", "最终塔层必须接入现有头衔反馈。")


func _test_collection_ui_and_shortcuts() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene.game.cash = 1000
	scene.game.synthesize_pair("water", "fire")
	scene._open_collection("items")
	await process_frame
	for button_text in ["万物总览", "最近发现", "账户凭证", "海生图鉴"]:
		assert(_find_button(scene.modal_body, button_text) != null, "图鉴必须具有四类清楚分离的入口：%s" % button_text)
	assert(_tree_contains_text(scene.modal_body, "当前目标："), "图鉴总览必须显示当前万象塔目标链。")
	assert(_find_option_button(scene.modal_body) != null, "永久万物页必须提供阶层与类别筛选。")

	scene._open_collection_item("steam")
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "造化盆首次合成"), "万物详情必须显示首次来源。")
	assert(_tree_contains_text(scene.modal_body, "水 + 火 → 蒸汽"), "万物详情必须显示首次关系。")
	assert(_tree_contains_text(scene.modal_body, "已开放用途"), "万物详情必须汇总跨模块用途。")
	var cash_before: int = scene.game.cash
	var discovered_before: int = scene.game.discovered_item_ids().size()
	scene._open_synthesis_with_item("steam", "left")
	await process_frame
	assert(scene.synthesis_table.visible and scene.synthesis_table.left_id == "steam", "详情快捷入口必须把指定万物预填到造化盆对应一侧。")
	assert(scene.game.cash == cash_before and scene.game.discovered_item_ids().size() == discovered_before, "预填造化盆不能扣款、写历史或改变发现。")
	scene.synthesis_table.request_collection()
	await process_frame
	assert(scene.modal_overlay.visible and _tree_contains_text(scene.modal_body, "永久万物"), "造化盆必须能无损返回图鉴。")

	scene._open_collection("credentials")
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "逐风免费体验券") and _tree_contains_text(scene.modal_body, "实验折扣"), "有限凭证必须在独立页面显示。")
	assert(_find_button(scene.modal_body, "放入造化盆左侧") == null and _find_button(scene.modal_body, "放入造化盆右侧") == null, "账户凭证页面不能把凭证伪装成永久万物。")
	scene._open_collection("marine")
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "鱼获箱") and _tree_contains_text(scene.modal_body, "出售鱼获不会删除海生记录"), "海生图鉴必须与永久万物、鱼获实例明确区分。")

	scene.free()


func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and (node as Button).text == text_value:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text_value)
		if found != null:
			return found
	return null


func _find_option_button(node: Node) -> OptionButton:
	if node is OptionButton:
		return node as OptionButton
	for child in node.get_children():
		var found := _find_option_button(child)
		if found != null:
			return found
	return null


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
