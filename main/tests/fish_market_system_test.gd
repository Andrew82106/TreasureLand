extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const FishCatalog := preload("res://scripts/fish_catalog.gd")


func _init() -> void:
	_test_catalog_and_deterministic_dive()
	_test_oxygen_basket_and_landing_order()
	_test_market_refresh_and_atomic_sale()
	_test_freshness_orders_and_save_state()
	_test_income_band()
	print("FISH MARKET SYSTEM TEST PASS")
	quit(0)


func _state() -> GameState:
	var state: GameState = GameStateScript.new()
	state.recording_enabled = false
	return state


func _test_catalog_and_deterministic_dive() -> void:
	assert(FishCatalog.SPECIES.size() == 12 and FishCatalog.AREAS.size() == 3, "首版必须固定12种鱼和3个潜捕区域。")
	var first := _state()
	var second := _state()
	var first_start := first.begin_dive("sand_shallows")
	var second_start := second.begin_dive("sand_shallows")
	assert(bool(first_start.get("ok", false)) and bool(second_start.get("ok", false)), "白沙浅湾必须开局可进入。")
	assert(first.dive_scene_seed == second.dive_scene_seed, "相同日程、区域和窗口必须锁定相同潜捕种子。")
	assert(first.dive_state["candidates"] == second.dive_state["candidates"], "相同种子必须生成相同鱼种、尺寸和初始路线。")
	assert(not first.dive_area_unlocked("coral_shelf") and not first.dive_area_unlocked("wreck_edge"), "深区资格必须随明确进程永久开放。")


func _test_oxygen_basket_and_landing_order() -> void:
	var state := _state()
	var start_cash := state.cash
	state.begin_dive("sand_shallows")
	var capacity := int(state.dive_state["basket_capacity"])
	for index in range(capacity):
		assert(bool(state.dive_capture(index).get("ok", false)), "鱼篓未满时必须能加入有效候选鱼。")
	var overflow := state.dive_capture(capacity)
	assert(not bool(overflow.get("ok", true)) and bool(overflow.get("basket_full", false)), "鱼篓容量必须严格限制单次携带量。")
	var oxygen := state.update_dive_oxygen(999.0)
	assert(is_zero_approx(oxygen) and is_zero_approx(float(state.dive_state["oxygen"])), "氧气不得降到0以下。")
	assert(bool(state.dive_capture(capacity).get("forced_surface", false)), "氧气归零后不得继续抓取。")
	var root_count := state.discovered_item_ids().size()
	var landed := state.finish_dive(true)
	assert(bool(landed.get("ok", false)) and bool(landed.get("forced_surface", false)), "氧气耗尽必须正常进入强制上浮结算。")
	assert(state.fish_catch_inventory.size() == capacity and state.cash == start_cash, "上岸必须创建鱼获实例且不得自动出售。")
	assert(state.discovered_item_ids().size() == root_count and not state.marine_discoveries.is_empty(), "鱼获与海生记录必须和永久万物集合分离。")
	assert(state.fishing_remaining_today() == 2 and state.tide == 2, "上岸必须只消耗一个鱼群窗口和1潮刻。")
	assert(not state.dive_active and state.dive_state.is_empty(), "结算后不得残留活动态。")
	assert(state.dive_area_unlocked("coral_shelf"), "完成首次潜捕后必须开放珊瑚礁棚。")


func _test_market_refresh_and_atomic_sale() -> void:
	var first := _state()
	var second := _state()
	assert(first.fish_market_quotes == second.fish_market_quotes and first.fish_market_stock == second.fish_market_stock, "相同每日种子必须生成相同初始行情。")
	var history_before := first.fish_market_history.size()
	first.tide = 4
	first.tide_progress = 0.9
	first.advance_time_fraction(0.1, "鱼市边界测试")
	assert(first.tide == 5 and first.fish_market_refresh_index == 1 and first.fish_market_history.size() == history_before + 1, "鱼市必须只在时段边界按序刷新。")

	var state := _state()
	var species_id := "bubble_sardine"
	state.fish_market_quotes[species_id] = 20
	state.fish_market_demand[species_id] = 2
	state.fish_market_stock[species_id] = 5
	for index in range(8):
		state.fish_catch_inventory.append(_catch("sale_catch_%d" % index, species_id, "标准", state.day))
	var ids: Array = state.fish_catch_inventory.map(func(catch_record): return str(catch_record["catch_id"]))
	var preview := state.create_fish_sale_preview(ids)
	assert(bool(preview.get("ok", false)) and int(preview["count"]) == 8, "批量出售必须为每条鱼获生成不可变预览。")
	var tiers: Array = preview["lines"].map(func(line): return str(line["tier"]))
	assert(tiers.count("重点需求") == 2 and tiers.count("普通加工85%") == 2 and tiers.count("大量加工60%") == 4, "超出重点需求后必须依次进入85%与大量加工档。")
	assert(int(preview["total"]) == 94, "分档售价必须同时应用报价、尺寸和新鲜度并准确汇总。")
	var cash_before := state.cash
	var settled := state.confirm_fish_sale(str(preview["sale_id"]))
	assert(bool(settled.get("ok", false)) and state.cash == cash_before + 94, "确认出售必须原子增加预览中的金贝。")
	assert(state.fish_catch_inventory.is_empty() and int(state.fish_market_stock[species_id]) == 13 and int(state.fish_market_demand[species_id]) == 0, "出售必须同步减少鱼获、增加库存并消耗重点需求。")
	var duplicate_cash := state.cash
	var duplicate := state.confirm_fish_sale(str(preview["sale_id"]))
	assert(not bool(duplicate.get("ok", true)) and bool(duplicate.get("duplicate", false)) and state.cash == duplicate_cash, "同一成交编号最多只能结算一次。")


func _test_freshness_orders_and_save_state() -> void:
	var state := _state()
	var fresh := _catch("freshness", "silverfin", "大型", state.day)
	state.fish_catch_inventory.append(fresh)
	assert(state.fish_freshness_state(fresh) == "鲜活", "捕获当日必须是鲜活。")
	state.day += 1
	assert(state.fish_freshness_state(fresh) == "尚鲜", "次日必须稳定进入尚鲜。")
	state.day += 1
	assert(state.fish_freshness_state(fresh) == "加工级", "第三日起必须进入加工级且不能消失。")

	var order_state := _state()
	var order: Dictionary = order_state.fish_market_orders[0]
	for index in range(int(order["quantity"])):
		order_state.fish_catch_inventory.append(_catch("order_%d" % index, str(order["species_id"]), "标准", order_state.day))
	var order_cash := order_state.cash
	var delivered := order_state.turn_in_fish_order(str(order["order_id"]))
	assert(bool(delivered.get("ok", false)) and order_state.cash == order_cash + int(delivered["reward"]), "订单必须原子移除合格鱼获并发放锁定奖励。")
	assert(not bool(order_state.turn_in_fish_order(str(order["order_id"])).get("ok", true)), "已完成订单不得重复交付。")

	var save_state := _state()
	save_state.begin_dive("sand_shallows")
	var saved := save_state.build_save_data({})
	var restored := _state()
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "潜捕与鱼市字段必须能通过版本化存档恢复。")
	assert(restored.dive_active and restored.dive_scene_seed == save_state.dive_scene_seed and restored.dive_state["candidates"] == save_state.dive_state["candidates"], "读档不得重掷已锁定潜捕场景。")
	assert(restored.fish_market_quotes == save_state.fish_market_quotes and restored.fish_market_history == save_state.fish_market_history, "读档不得重新计算历史行情。")


func _test_income_band() -> void:
	var state := _state()
	var total_value := 0
	var samples := 160
	for sample in range(samples):
		state.day = sample + 1
		state.daily_seed = 81013 + sample * 7919
		state.tide = 1
		state.tide_progress = 0.0
		state.dive_windows_remaining = 3
		state.fishing_attempts_today = 0
		state.dive_active = false
		state.dive_state.clear()
		state.dive_sequence = 0
		state.fish_catch_inventory.clear()
		state._initialize_fish_market()
		var landed := state.fish_once()
		total_value += int(landed.get("estimated_total", 0))
	var average := float(total_value) / float(samples)
	assert(average >= 40.0 and average <= 78.0, "自动完成四格鱼篓的长期平均估值必须位于保底路线目标附近，实际%.2f。" % average)


func _catch(catch_id: String, species_id: String, size_name: String, caught_day: int) -> Dictionary:
	return {
		"catch_id": catch_id,
		"species_id": species_id,
		"size": size_name,
		"size_score": 0.5,
		"caught_day": caught_day,
		"caught_tide": 1,
		"source_area": "sand_shallows",
		"scene_seed": "test"
	}
