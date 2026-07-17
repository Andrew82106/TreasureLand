extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")


func _init() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	assert(state.world_group_accounts.size() >= 5 and state.world_group_accounts.size() <= 7, "晴潮岛必须用5—7个群体账户表达居民、餐饮、渔民、加工、游客、港商与赛事组织者。")
	assert(int(state.port_economy_snapshot.get("residents", 0)) >= 60 and int(state.port_economy_snapshot.get("residents", 0)) <= 120, "港口快照必须表达60—120名常住居民。")
	assert(int(state.port_economy_snapshot.get("visitors", 0)) >= 10 and int(state.port_economy_snapshot.get("visitors", 0)) <= 60, "港口快照必须表达每日10—60名流动来客。")
	assert(int(state.port_economy_snapshot.get("arrivals", 0)) >= 1 and int(state.port_economy_snapshot.get("arrivals", 0)) <= 4, "港口快照必须表达每日1—4批船艇或飞艇抵离。")
	var group_cash_before := _group_cash(state)
	var external_before := int(state.world_external_account.get("cash", 0))
	var company_cash_before: Dictionary = state.share_company_financials.duplicate(true)
	state.tide = 16
	state.sleep_to_next_day()
	var group_delta := _group_cash(state) - group_cash_before
	var external_delta := int(state.world_external_account.get("cash", 0)) - external_before
	assert(group_delta + external_delta == 0, "外岛与岛内群体之间的游客、出口、进口与航运现金必须严格双边守恒。")
	assert(state.world_economy_flows.any(func(flow): return str(flow.get("tag", "")) == "游客与出口流入") and state.world_economy_flows.any(func(flow): return str(flow.get("tag", "")) == "进口、维护与航运流出"), "所有外部流入与流出必须带来源标签进入世界经济流水。")
	for company_id in state.share_company_ids():
		var report: Dictionary = state.share_company_reports[company_id]
		assert(int(report.get("revenue", 0)) > 0 and not report.get("drivers", []).is_empty(), "%s在玩家完全静止时仍必须产生基础业务与可解释报告。" % company_id)
		assert(int(state.share_company_financials[company_id].get("company_cash", 0)) != int(company_cash_before[company_id].get("company_cash", 0)), "%s必须拥有独立公司现金并随实际经营变化。" % company_id)
	var saved := state.build_save_data({})
	var restored = GameStateScript.new()
	restored.recording_enabled = false
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "版本10世界经济存档必须可恢复。")
	assert(restored.world_group_accounts == state.world_group_accounts and restored.world_external_account == state.world_external_account and restored.world_economy_flows == state.world_economy_flows and restored.port_economy_snapshot == state.port_economy_snapshot, "群体账户、外岛账户、流水与港口快照必须跨存档原样保留。")
	print("WORLD ECONOMY SYSTEM TEST PASS")
	quit(0)


func _group_cash(state) -> int:
	var total := 0
	for raw_group in state.world_group_accounts.values():
		total += int(raw_group.get("cash", 0))
	return total
