extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")


func _init() -> void:
	_test_economy_ledger_and_day_report()
	_test_public_relief_work()
	_test_equipment_growth_and_save_migration()
	_test_specialist_orders_and_memories()
	print("ECONOMY EQUIPMENT ORDER TEST PASS")
	quit(0)


func _state() -> GameState:
	var state: GameState = GameStateScript.new()
	state.recording_enabled = false
	return state


func _test_economy_ledger_and_day_report() -> void:
	var state := _state()
	var upgrade := state.buy_dive_equipment_upgrade("oxygen")
	assert(bool(upgrade.get("ok", false)) and state.cash == 40, "呼吸设备首级升级必须原子扣除80金贝。")
	state.fish_market_quotes["bubble_sardine"] = 20
	state.fish_market_demand["bubble_sardine"] = 1
	state.fish_catch_inventory.append(_catch("ledger-sale", "bubble_sardine", "标准", state.day))
	var preview := state.create_fish_sale_preview(["ledger-sale"])
	assert(bool(preview.get("ok", false)) and int(preview["total"]) == 20, "账簿测试的出售预览必须锁定20金贝。")
	assert(bool(state.confirm_fish_sale(str(preview["sale_id"])).get("ok", false)) and state.cash == 60, "出售必须在分类账前完成真实原子结算。")
	var current := state.current_day_economy_summary()
	assert(int(current["opening"]["cash"]) == 120 and int(current["cash_in"]) == 20 and int(current["cash_out"]) == 80 and int(current["closing"]["cash"]) == 60, "日内账簿必须显示期初120、流入20、流出80与期末60。")
	assert(bool(current["cash_balanced"]), "日内现金必须满足期初+流入-流出=期末。")
	assert(_report_has_category(current, "equipment") and _report_has_category(current, "fish_market"), "设备购买与鱼铺出售必须进入不同活动分类。")
	state.sleep_to_next_day()
	var report := state.latest_day_end_report()
	assert(int(report.get("day", 0)) == 1 and bool(report.get("cash_balanced", false)), "睡眠必须固定并保存上一日可核对账单。")
	assert(int(state.current_day_economy_summary()["opening"]["cash"]) == state.cash, "次日必须以刷新完成后的真实现金建立新期初。")

	var order_state := _state()
	order_state.cash = 25000
	order_state._record_wealth("测试准备 · 富商资格")
	order_state.tide = 11
	var queued := order_state.queue_share_order("bluefin", "buy", 2)
	assert(bool(queued.get("ok", false)) and order_state.share_reserved_cash > 0, "跨日账簿测试必须成功冻结一笔隔夜买单。")
	order_state.sleep_to_next_day()
	assert(bool(order_state.latest_day_end_report().get("cash_balanced", false)), "冻结隔夜买单后的结束日现金必须守恒。")
	assert(bool(order_state.current_day_economy_summary().get("cash_balanced", false)), "新报价重估、退款与开盘撮合进入次日后现金仍必须守恒。")


func _test_public_relief_work() -> void:
	var state := _state()
	state.cash = 40
	state.dive_windows_remaining = 0
	state.fishing_attempts_today = state.DAILY_FISHING_LIMIT
	state.fish_catch_inventory.clear()
	state.share_lots.clear()
	state.share_reserved_cash = 0
	state._record_wealth("测试准备 · 低谷状态")
	var status := state.relief_work_status()
	assert(bool(status.get("available", false)), "鱼群窗口用尽、无鱼获无份契且账户低于80时必须开放公开恢复工作。")
	var tide_before := state.tide
	var result := state.perform_relief_work()
	assert(bool(result.get("ok", false)) and state.cash == 80 and state.tide == tide_before + 1, "巡岸修缮必须一次发放40金贝并统一推进1潮刻。")
	assert(not bool(state.perform_relief_work().get("ok", true)), "同一天的公开恢复工作不得重复领取。")
	assert(_report_has_category(state.current_day_economy_summary(), "relief"), "巡岸修缮必须进入独立经济分类。")


func _test_equipment_growth_and_save_migration() -> void:
	var state := _state()
	state.cash = 3000
	state._record_wealth("测试准备 · 装备资金")
	for slot_id in ["oxygen", "fins", "basket", "preservation"]:
		assert(bool(state.buy_dive_equipment_upgrade(slot_id).get("ok", false)), "四类装备的第一轮升级必须无需高阶万物即可购买：%s。" % slot_id)
	assert(is_equal_approx(float(state.dive_equipment["oxygen"]), 62.0) and int(state.dive_equipment["basket"]) == 5, "首轮装备升级必须同步修改潜捕氧气与鱼篓参数。")
	assert(is_equal_approx(float(state.dive_equipment["swim_speed"]), 1.15) and int(state.dive_equipment["preservation_days"]) == 1, "首轮装备升级必须同步修改移动与保存参数。")
	assert(not bool(state.buy_dive_equipment_upgrade("oxygen").get("ok", true)), "潮息罐必须读取水罐知识，不能绕过永久发现门槛。")
	state.discovered["water_jar"] = true
	assert(bool(state.buy_dive_equipment_upgrade("oxygen").get("ok", false)) and is_equal_approx(float(state.dive_equipment["oxygen"]), 78.0), "发现水罐后必须能完成呼吸设备二级升级。")
	assert(state.dive_area_unlocked("wreck_edge"), "二级呼吸设备必须作为沉船外缘的一条公开资格。")

	var saved := state.build_save_data({})
	assert(int(saved.get("version", 0)) == 8, "分类账、恢复工作、装备等级与专属订单必须进入版本8存档。")
	var restored := _state()
	assert(bool(restored.restore_save_data(saved).get("ok", false)) and restored.dive_equipment_levels == state.dive_equipment_levels, "版本8必须完整往返装备等级与派生参数。")
	assert(restored.economy_events == state.economy_events and restored.economy_day_opening == state.economy_day_opening, "版本8必须完整往返日内分类账与期初快照。")

	var legacy: Dictionary = saved.duplicate(true)
	legacy["version"] = 7
	legacy["state"].erase("dive_equipment_levels")
	legacy["state"].erase("economy_events")
	legacy["state"].erase("economy_day_opening")
	legacy["state"].erase("day_end_reports")
	var migrated := _state()
	assert(bool(migrated.restore_save_data(legacy).get("ok", false)), "版本7存档必须迁移到版本8。")
	assert(int(migrated.dive_equipment_levels["oxygen"]) == 2 and int(migrated.dive_equipment_levels["basket"]) == 1, "旧存档必须从已有效的装备参数反推等级，不能抹除升级。")


func _test_specialist_orders_and_memories() -> void:
	var state := _state()
	assert(state.fish_market_orders.size() == 3, "鱼铺每天必须生成渔民、厨师与收藏家三类专属订单。")
	assert(str(state.fish_market_orders[0].get("role", "")) == "渔民专单" and str(state.fish_market_orders[1].get("role", "")) == "厨师专单" and str(state.fish_market_orders[2].get("role", "")) == "收藏家专单", "三类专属订单必须有稳定身份与可读顺序。")

	var fisher: Dictionary = state.fish_market_orders[0]
	for index in range(int(fisher["quantity"])):
		state.fish_catch_inventory.append(_catch("fisher-%d" % index, str(fisher["species_id"]), "标准", state.day))
	var old_joe_before := int(state.relationships["old_joe"])
	assert(bool(state.turn_in_fish_order(str(fisher["order_id"])).get("ok", false)), "渔民专单必须能用符合物种与数量的真实鱼获交付。")
	assert(int(state.relationships["old_joe"]) == old_joe_before + 2 and not state.npc_recent_memories("old_joe").is_empty(), "渔民订单必须同时写入人物记忆并只发放一次关系奖励。")

	var chef: Dictionary = state.fish_market_orders[1]
	for index in range(int(chef["quantity"])):
		state.fish_catch_inventory.append(_catch("stale-chef-%d" % index, str(chef["species_id"]), "标准", state.day - 3))
	assert(not bool(state.turn_in_fish_order(str(chef["order_id"])).get("ok", true)), "厨师专单必须拒绝低于尚鲜要求的加工级鱼获。")
	for index in range(int(chef["quantity"])):
		state.fish_catch_inventory.append(_catch("fresh-chef-%d" % index, str(chef["species_id"]), "标准", state.day))
	assert(bool(state.turn_in_fish_order(str(chef["order_id"])).get("ok", false)), "厨师专单必须接受达到新鲜度条件的鱼获。")

	var collector: Dictionary = state.fish_market_orders[2]
	state.fish_catch_inventory.append(_catch("collector", str(collector["species_id"]), "标准", state.day))
	assert(not bool(state.turn_in_fish_order(str(collector["order_id"])).get("ok", true)), "收藏家私人订单必须明确执行关系门槛。")
	state.relationships["mia"] = int(collector["relationship_required"])
	assert(bool(state.turn_in_fish_order(str(collector["order_id"])).get("ok", false)), "达到关系门槛后收藏家订单必须可交付。")
	assert(not state.npc_recent_memories("mia").is_empty(), "收藏家订单必须进入米娅的海生报道记忆。")


func _report_has_category(report: Dictionary, category_id: String) -> bool:
	for raw_row in report.get("categories", []):
		if raw_row is Dictionary and str(raw_row.get("id", "")) == category_id:
			return true
	return false


func _catch(catch_id: String, species_id: String, size_name: String, caught_day: int) -> Dictionary:
	return {
		"catch_id": catch_id,
		"species_id": species_id,
		"size": size_name,
		"size_score": 0.6,
		"caught_day": caught_day,
		"caught_tide": 1,
		"source_area": "sand_shallows",
		"scene_seed": "economy-test"
	}
