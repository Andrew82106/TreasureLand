extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")


func _init() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	assert(state.world_group_accounts.size() >= 5 and state.world_group_accounts.size() <= 7, "晴潮岛必须用5—7个群体账户表达居民、餐饮、渔民、加工、游客、港商与赛事组织者。")
	assert(int(state.port_economy_snapshot.get("residents", 0)) >= 60 and int(state.port_economy_snapshot.get("residents", 0)) <= 120, "港口快照必须表达60—120名常住居民。")
	assert(int(state.port_economy_snapshot.get("visitors", 0)) >= 10 and int(state.port_economy_snapshot.get("visitors", 0)) <= 60, "港口快照必须表达每日10—60名流动来客。")
	assert(int(state.port_economy_snapshot.get("arrivals", 0)) >= 1 and int(state.port_economy_snapshot.get("arrivals", 0)) <= 4, "港口快照必须表达每日1—4批船艇或飞艇抵离。")
	var idempotent = GameStateScript.new()
	idempotent.recording_enabled = false
	idempotent._settle_world_group_economy(idempotent.day)
	var once_total := idempotent.auditable_world_cash_total()
	var once_flows: int = idempotent.world_economy_flows.size()
	idempotent._ensure_fish_market_economy()
	idempotent._settle_world_group_economy(idempotent.day)
	assert(idempotent.auditable_world_cash_total() == once_total and idempotent.world_economy_flows.size() == once_flows, "同一日世界群体结算必须幂等，普通读取与交易不得清除已结算标记。")
	var cash_total_before := state.auditable_world_cash_total()
	var company_cash_before: Dictionary = state.share_company_financials.duplicate(true)
	state.tide = 16
	state.sleep_to_next_day()
	assert(state.auditable_world_cash_total() == cash_total_before, "玩家、群体、外岛、公司、持有人与维护账户之间的日终现金必须严格守恒。")
	assert(state.world_economy_flows.any(func(flow): return str(flow.get("external_flow", "")) == "inflow") and state.world_economy_flows.any(func(flow): return str(flow.get("external_flow", "")) == "outflow"), "所有外部流入与流出必须带方向标签进入世界经济流水。")
	var required_flow_fields := ["source", "target", "counterparty", "sector", "external_flow", "inventory_delta", "order_fulfilled", "company_cash_delta"]
	for raw_flow in state.world_economy_flows:
		var flow: Dictionary = raw_flow
		for field in required_flow_fields:
			assert(flow.has(field), "每条世界经济流水都必须保存字段%s。" % field)
		assert(not str(flow.get("source", "")).is_empty() and not str(flow.get("target", "")).is_empty(), "世界经济流水必须拥有明确来源与去向。")
	for company_id in state.share_company_ids():
		var report: Dictionary = state.share_company_reports[company_id]
		assert(int(report.get("revenue", 0)) > 0 and not report.get("drivers", []).is_empty(), "%s在玩家完全静止时仍必须产生基础业务与可解释报告。" % company_id)
		assert(int(state.share_company_financials[company_id].get("company_cash", 0)) != int(company_cash_before[company_id].get("company_cash", 0)), "%s必须拥有独立公司现金并随实际经营变化。" % company_id)
	var saved := state.build_save_data({})
	var restored = GameStateScript.new()
	restored.recording_enabled = false
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "版本10世界经济存档必须可恢复。")
	assert(restored.world_group_accounts == state.world_group_accounts and restored.world_external_account == state.world_external_account and restored.world_economy_flows == state.world_economy_flows and restored.port_economy_snapshot == state.port_economy_snapshot, "群体账户、外岛账户、流水与港口快照必须跨存档原样保留。")
	var legacy_saved: Dictionary = saved.duplicate(true)
	legacy_saved["state"]["world_economy_flows"] = [{"day": 1, "source": "external_islands", "target": "island_groups", "tag": "旧版流入", "amount": 88}]
	var legacy_restored = GameStateScript.new()
	legacy_restored.recording_enabled = false
	assert(bool(legacy_restored.restore_save_data(legacy_saved).get("ok", false)), "缺少新审计字段的现有存档必须可迁移。")
	var migrated_flow: Dictionary = legacy_restored.world_economy_flows[0]
	for field in ["counterparty", "sector", "external_flow", "inventory_delta", "order_fulfilled", "company_cash_delta"]:
		assert(migrated_flow.has(field), "旧版世界经济流水迁移后必须补齐%s。" % field)
	assert(str(migrated_flow["external_flow"]) == "inflow", "以外部群岛为来源的旧流水必须迁移为外部流入。")
	print("WORLD ECONOMY SYSTEM TEST PASS")
	quit(0)
