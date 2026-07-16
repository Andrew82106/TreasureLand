extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")
const WorldLayoutScript := preload("res://scripts/world_layout.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_market_rules_and_daily_settlement()
	_test_determinism_and_save_roundtrip()
	await _test_player_reachable_ui()
	print("SHARE MARKET SYSTEM TEST PASS")
	quit(0)


func _state():
	var state = GameStateScript.new()
	state.recording_enabled = false
	return state


func _test_market_rules_and_daily_settlement() -> void:
	var state = _state()
	assert(state.share_company_ids() == ["bluefin", "wayfarer", "windring"], "首版必须固定为三家可理解产业。")
	assert(not state.can_trade_shares(), "新玩家只能查看公开经营信息，不能直接交易。")
	assert(state.share_market_rows().size() == 3 and state.share_market_is_open(), "清晨必须以三家固定报价开盘。")
	state.tide = 10
	state.advance_time(1)
	assert(not state.share_market_is_open() and state.time_event_log.any(func(event): return str(event.get("kind", "")) == "share_close"), "跨入第11潮刻必须形成统一收盘边界事件。")
	state.tide = 1
	state.tide_progress = 0.0

	state.cash = 25000
	assert(state.can_trade_shares() and state.share_market_unlocked, "账户财富首次达到20,000金贝必须永久开放交易。")
	var bluefin_price := int(state.share_quotes["bluefin"])
	var fee := state.share_trade_fee(bluefin_price * 5)
	var cash_before := int(state.cash)
	var buy: Dictionary = state.trade_shares("bluefin", "buy", 5)
	assert(bool(buy.get("ok", false)), "开放时段必须能即时买入。")
	assert(state.cash == cash_before - bluefin_price * 5 - fee, "买入必须精确扣除成交额与1%费用。")
	assert(state.share_quantity("bluefin") == 5 and state.share_sellable_quantity("bluefin") == 0, "当日买入必须形成T+1锁定持仓。")
	assert(not bool(state.trade_shares("bluefin", "sell", 1).get("ok", true)), "当日买入不得立刻卖出套利。")
	assert(state.net_worth() == state.account_wealth() + state.share_liquidation_value(), "份契保守变现值必须进入净资产而非当前金贝。")

	state.tide = 11
	var wealth_before_order := int(state.account_wealth())
	var queued: Dictionary = state.queue_share_order("bluefin", "buy", 2)
	assert(bool(queued.get("ok", false)) and state.share_pending_orders.size() == 1, "休市后必须提交次日订单而非即时成交。")
	assert(state.share_reserved_cash > 0 and state.account_wealth() == wealth_before_order, "隔夜买单冻结现金必须仍计入账户财富，但不可继续消费。")
	var reserved := int(state.share_reserved_cash)
	var cancel: Dictionary = state.cancel_share_order(str(queued["order"]["order_id"]))
	assert(bool(cancel.get("ok", false)) and int(cancel["refund"]) == reserved, "撤销隔夜买单必须全额返还冻结现金。")
	assert(state.share_reserved_cash == 0 and state.share_pending_orders.is_empty(), "撤单后不得残留冻结额或幽灵订单。")

	var queued_again: Dictionary = state.queue_share_order("bluefin", "buy", 2)
	assert(bool(queued_again.get("ok", false)), "撤单后必须可以重新提交唯一订单。")
	var day_one_quotes: Dictionary = state.share_quotes.duplicate(true)
	state.sleep_to_next_day()
	assert(state.day == 2 and state.share_pending_orders.is_empty() and state.share_reserved_cash == 0, "次日开盘必须完成隔夜撮合并清空冻结状态。")
	assert(state.share_quantity("bluefin") == 7 and state.share_sellable_quantity("bluefin") == 5, "次日撮合份额仍需遵守各自取得日的T+1。")
	for company_id in state.share_company_ids():
		var old_price := int(day_one_quotes[company_id])
		var new_price := int(state.share_quotes[company_id])
		assert(new_price >= 20, "份契价格不得低于20金贝。")
		assert(abs(float(new_price - old_price) / float(old_price)) <= 0.120001, "单日涨跌不得超过12%。")
		var report: Dictionary = state.share_company_reports[company_id]
		assert(report.has("revenue") and report.has("costs") and report.has("profit") and not report.get("drivers", []).is_empty(), "每家公司必须形成可解释经营报告。")

	var quantity_before_sell := state.share_quantity("bluefin")
	var sell: Dictionary = state.trade_shares("bluefin", "sell", 3)
	assert(bool(sell.get("ok", false)) and state.share_quantity("bluefin") == quantity_before_sell - 3, "次日必须能按先进先出卖出已解锁批次。")
	assert(float(sell.get("realized", 0.0)) == float(state.share_trade_history[0].get("realized", 0.0)), "卖出必须记录已实现盈亏。")
	var cash_before_dividend := int(state.cash)
	state.tide = 16
	state.sleep_to_next_day()
	var latest_dividend: Dictionary = state.share_dividend_history[0]
	assert(int(latest_dividend.get("day", 0)) == 2, "日终必须生成当日分红记录，即使分红为0也可追溯。")
	assert(state.cash == cash_before_dividend + int(latest_dividend.get("total", 0)), "分红总额必须与玩家现金变化一致。")


func _test_determinism_and_save_roundtrip() -> void:
	var first = _state()
	var second = _state()
	for state in [first, second]:
		state.cash = 30000
		state.can_trade_shares()
		state._settle_share_market_day(1)
	assert(first.share_next_quotes == second.share_next_quotes, "相同日种子与经营输入必须生成相同次日价格。")
	assert(first.share_company_reports == second.share_company_reports, "经营报告和分红输入必须确定性复现。")

	first._open_share_market_day()
	first.tide = 11
	var order: Dictionary = first.queue_share_order("windring", "buy", 4)
	assert(bool(order.get("ok", false)), "休市订单必须可用于存档往返。")
	var saved := first.build_save_data({})
	assert(int(saved.get("version", 0)) == 6, "商会持仓与订单必须进入版本6存档。")
	var restored = _state()
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "版本6商会存档必须可读取。")
	assert(restored.share_quotes == first.share_quotes, "报价必须跨存档保留。")
	assert(restored.share_lots == first.share_lots, "持仓批次与成本必须跨存档保留。")
	assert(restored.share_pending_orders == first.share_pending_orders, "隔夜订单必须跨存档保留。")
	assert(restored.share_reserved_cash == first.share_reserved_cash and restored.account_wealth() == first.account_wealth(), "冻结现金必须跨存档保持资金守恒。")


func _test_player_reachable_ui() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	assert(not WorldLayoutScript.marker_definition("exchange").is_empty(), "椰影街必须存在潮汐商会实际地标。")
	assert(scene.marker_by_id.has("exchange"), "大地图必须实例化商会交互标记。")
	scene.game.cash = 25000
	scene._open_share_market()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "蓝鳍渔业") and _tree_contains_text(scene.modal_body, "万象行运") and _tree_contains_text(scene.modal_body, "逐风联合会"), "商会页必须同时展示三家产业。")
	assert(_tree_contains_text(scene.modal_body, "当日买入次日才可卖出") and _find_button(scene.modal_body, "买1 · 101") != null, "商会页必须直接展示风险提示和可执行交易。")
	scene._trade_shares("bluefin", "buy", 1)
	await process_frame
	assert(scene.game.share_quantity("bluefin") == 1 and _tree_contains_text(scene.modal_body, "持有1 / 600份"), "玩家必须能从可达UI完成实际买入并看到持仓刷新。")
	scene._open_news()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "潮汐商会 · 产业份契") and _find_button(scene.modal_body, "查看经营账目与份契") != null, "晨报必须读取同一商会状态并提供入口。")
	scene._open_wealth()
	await process_frame
	assert(_find_button(scene.modal_body, "查看潮汐商会份契") != null, "财富轨迹必须提供长期资产入口。")
	scene._open_bed()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "三家商会经营与分红") and _tree_contains_text(scene.modal_body, "隔夜订单撮合"), "漂流小屋必须提前说明睡眠时的份契结算顺序。")
	scene.free()


func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and str(node.text) == text_value:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text_value)
		if found != null:
			return found
	return null


func _tree_contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and needle in str(node.text):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
