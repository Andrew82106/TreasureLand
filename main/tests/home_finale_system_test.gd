extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_home_progression_and_collection()
	_test_guest_and_finale_flow()
	_test_save_and_migration()
	await _test_player_reachable_ui()
	print("HOME FINALE SYSTEM TEST PASS")
	quit(0)


func _test_home_progression_and_collection() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	assert(str(state.home_data()["name"]) == "漂流小屋", "新存档必须从漂流小屋开始。")
	assert(state.home_display_capacity() == 1 and state.home_aquarium_capacity() == 0, "初始居所只能陈列一项万物且没有水族槽。")
	assert(not bool(state.purchase_home_upgrade().get("ok", false)), "未满足财富与发现要求时不能扩建。")

	_discover_first_items(state, 12)
	state.cash = 1000
	var before_upgrade: int = state.cash
	var upgraded: Dictionary = state.purchase_home_upgrade()
	assert(bool(upgraded.get("ok", false)) and state.home_level == 1, "满足要求后必须能扩建为潮木居所。")
	assert(state.cash == before_upgrade - 400, "居所升级必须只扣固定400金贝。")
	assert(state.home_display_capacity() == 3 and state.home_aquarium_capacity() == 1, "潮木居所槽位必须符合规格。")

	var display_id := state.discovered_item_ids()[3]
	var discovered_before := state.discovered_item_ids().size()
	assert(bool(state.add_home_display(display_id).get("ok", false)), "已发现万物必须能够陈列。")
	assert(not bool(state.add_home_display(display_id).get("ok", false)), "同一万物不能重复占用陈列槽。")
	assert(state.is_discovered(display_id) and state.discovered_item_ids().size() == discovered_before, "陈列不能消耗或复制永久万物。")
	assert(bool(state.remove_home_display(display_id).get("ok", false)) and state.is_discovered(display_id), "撤下陈列不能改变发现状态。")

	state.fish_catch_inventory = [
		_fish("ornamental", "coral_lantern", "大型"),
		_fish("record", "bubble_sardine", "纪录级"),
		_fish("ordinary", "bubble_sardine", "标准"),
	]
	assert(state.aquarium_candidate_rows().size() == 2, "只有观赏/收藏标签或纪录级鱼获可以进入水族。")
	var inventory_value_before := state.fish_inventory_value()
	var placed: Dictionary = state.place_fish_in_aquarium("ornamental")
	assert(bool(placed.get("ok", false)) and state.home_aquarium.size() == 1, "合格真实鱼获必须能转入水族收藏。")
	assert(state.fish_catch_inventory.size() == 2 and state.fish_inventory_value() < inventory_value_before, "转入水族后不能继续留在可出售鱼获与净资产中。")
	assert(not bool(state.create_fish_sale_preview(["ornamental"]).get("ok", false)), "水族收藏不能进入鱼铺出售预览。")
	assert(not bool(state.place_fish_in_aquarium("ordinary").get("ok", false)), "普通非纪录鱼不能进入水族。")
	assert(bool(state.release_aquarium_fish("ornamental").get("ok", false)), "水族收藏必须可以明确放流腾出槽位。")
	assert(state.home_aquarium.is_empty() and state.fish_catch_inventory.size() == 2, "放流不能把鱼返还鱼获箱。")


func _test_guest_and_finale_flow() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	_discover_first_items(state, 36)
	state.cash = 10000
	assert(bool(state.purchase_home_upgrade().get("ok", false)), "测试状态必须先完成潮木居所。")
	assert(bool(state.purchase_home_upgrade().get("ok", false)) and state.home_level == 2, "满足中期要求后必须能完成风灯庭院。")
	state.known_npcs["old_joe"] = true
	state.relationships["old_joe"] = 10
	var cash_before_visit: int = state.cash
	var relationship_before := int(state.relationships["old_joe"])
	var invited: Dictionary = state.invite_npc_home("old_joe")
	assert(bool(invited.get("ok", false)), "风灯庭院必须能邀请熟悉人物来访。")
	assert(state.cash == cash_before_visit - 30 and is_equal_approx(state.tide_progress, 0.5), "来访必须支付30金贝并推进0.5潮刻。")
	assert(state.home_guest_history.size() == 1 and int(state.relationships["old_joe"]) == relationship_before + 2, "首次来访必须记录历史并只增加2点关系。")
	var time_after_visit: float = float(state.tide - 1) + state.tide_progress
	assert(not bool(state.invite_npc_home("old_joe").get("ok", false)), "同一天不能重复邀请人物。")
	assert(is_equal_approx(float(state.tide - 1) + state.tide_progress, time_after_visit), "失败邀请不能推进时间或重复扣款。")

	var progress_before: Dictionary = state.finale_progress()
	assert(not bool(progress_before["complete"]), "未完成全模块见证时归潮盛典不能开放。")
	for item_id in state.ITEMS.keys():
		state.discovered[str(item_id)] = true
	state.ultimate_created = true
	state.home_display_items.assign(["water", "fire", "earth"])
	state.home_aquarium = [_fish("finale_fish", "moon_ray", "大型")]
	state.normal_poker_completed = true
	state.poker_session_history = [{"session_id": "normal"}]
	state.race_history = [{"event_id": "race"}]
	state.fish_market_transactions = [{"sale_id": "sale"}]
	var progress: Dictionary = state.finale_progress()
	assert(bool(progress["complete"]) and int(progress["completed"]) == 8, "八项正式见证全部满足后必须开放归潮盛典。")
	var time_before_finale: float = float(state.tide - 1) + state.tide_progress
	var finale: Dictionary = state.complete_finale()
	assert(bool(finale.get("ok", false)) and state.finale_completed, "归潮盛典必须只在完整见证后正式完成。")
	assert(is_equal_approx(float(state.tide - 1) + state.tide_progress, time_before_finale + 1.0), "归潮盛典必须统一推进1潮刻。")
	assert(not state.finale_summary.is_empty() and int(state.finale_summary.get("fish_sales", 0)) == 1, "终局摘要必须固定保存跨模块事实。")
	var repeat_time: float = float(state.tide - 1) + state.tide_progress
	assert(not bool(state.complete_finale().get("ok", false)), "归潮盛典不能重复结算。")
	assert(is_equal_approx(float(state.tide - 1) + state.tide_progress, repeat_time), "回看终局不能再次推进时间。")
	assert(state.postgame_goals().size() >= 5, "终局后必须提供可继续游玩的长期目标。")


func _test_save_and_migration() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.home_level = 2
	state.home_display_items.assign(["water", "fire", "earth"])
	state.home_aquarium = [_fish("saved_fish", "moon_ray", "纪录级")]
	state.home_guest_history = [{"npc_id": "old_joe", "name": "老乔", "day": 2, "tide": 4}]
	state.home_last_invite_day = 2
	state.finale_completed = true
	state.finale_day = 8
	state.finale_tide = 9
	state.finale_summary = {"completed_day": 8, "completed_tide": 9, "home_name": "风灯庭院"}
	var saved: Dictionary = state.build_save_data()
	assert(int(saved.get("version", 0)) == 7, "居所与终局必须进入版本7存档。")
	var restored = GameStateScript.new()
	restored.recording_enabled = false
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "版本7居所与终局存档必须可读取。")
	assert(restored.home_level == 2 and restored.home_display_items.size() == 3 and restored.home_aquarium.size() == 1, "居所、陈列和水族必须完整往返。")
	assert(restored.finale_completed and int(restored.finale_summary.get("completed_day", 0)) == 8, "终局完成状态与固定摘要必须完整往返。")

	var legacy: Dictionary = saved.duplicate(true)
	legacy["version"] = 6
	for key in ["home_level", "home_display_items", "home_aquarium", "home_guest_history", "home_last_invite_day", "finale_completed", "finale_day", "finale_tide", "finale_summary"]:
		legacy["state"].erase(key)
	var migrated = GameStateScript.new()
	migrated.recording_enabled = false
	assert(bool(migrated.restore_save_data(legacy).get("ok", false)), "版本6存档必须迁移到版本7。")
	assert(migrated.home_level == 0 and migrated.home_display_items.is_empty() and migrated.home_aquarium.is_empty() and not migrated.finale_completed, "旧档迁移不能虚构居所收藏或终局经历。")


func _test_player_reachable_ui() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene._open_bed()
	assert(str(scene.modal_title.text) == "漂流小屋" and _tree_contains_text(scene.modal_body, "居所、陈列、水族与来访"), "玩家必须能从漂流小屋进入居所管理。")
	scene._open_home()
	assert(_tree_contains_text(scene.modal_body, "居所属于生活消费") and _tree_contains_text(scene.modal_body, "万物陈列"), "居所页必须解释资产口径并显示陈列入口。")
	scene._open_tower()
	assert(_tree_contains_text(scene.modal_body, "归潮盛典") and _tree_contains_text(scene.modal_body, "生计见证"), "万象塔必须展示完整终局清单。")
	scene._open_wealth()
	assert(_tree_contains_text(scene.modal_body, "把财富用于居所与收藏"), "财富页必须把长期财富导向居所消费。")
	scene.free()


func _discover_first_items(state, count: int) -> void:
	var ids: Array = state.ITEMS.keys()
	ids.sort()
	for index in range(mini(count, ids.size())):
		state.discovered[str(ids[index])] = true


func _fish(catch_id: String, species_id: String, size_value: String) -> Dictionary:
	return {
		"catch_id": catch_id,
		"species_id": species_id,
		"size": size_value,
		"size_score": 1.0,
		"caught_day": 1,
		"caught_tide": 2,
		"source_area": "coral_shelf",
		"caught_weather": "晴",
		"caught_phase": "清晨",
		"scene_seed": "1",
	}


func _tree_contains_text(node: Node, fragment: String) -> bool:
	if node is Label and fragment in str((node as Label).text):
		return true
	if node is Button and fragment in str((node as Button).text):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, fragment):
			return true
	return false
