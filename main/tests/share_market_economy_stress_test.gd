extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first = _simulate_idle_market()
	var second = _simulate_idle_market()
	assert(first["quotes"] == second["quotes"], "相同长期输入必须生成完全相同的80日价格路径终点。")
	assert(first["directions"] == second["directions"], "长期涨跌次数必须可由存档种子复现。")
	print("SHARE MARKET 80-DAY SAMPLE: %s" % str(first["directions"]))
	var total_flat_days := 0
	for company_id in first["directions"].keys():
		var direction: Dictionary = first["directions"][company_id]
		assert(int(direction["up"]) > 0 and int(direction["down"]) > 0, "%s在无玩家经营贡献时也必须同时存在上涨和下跌日，不能成为只涨或只跌教学资产。" % company_id)
		total_flat_days += int(direction["flat"])
		assert(int(direction["toward_value"]) > 0, "%s的80日样本必须出现向基本价值回归。" % company_id)
		var company: Dictionary = GameStateScript.SHARE_COMPANIES[company_id]
		var final_price := int(first["quotes"][company_id])
		assert(final_price >= 20 and final_price <= int(company["base_price"]) * 4, "%s的80日空闲价格不得失控指数增长。" % company_id)
	assert(total_flat_days > 0, "80日市场样本必须存在至少一个无成交或撮合价不变的横盘日。")
	print("SHARE MARKET ECONOMY STRESS PASS: %s" % str(first["directions"]))
	quit(0)


func _simulate_idle_market() -> Dictionary:
	var state = GameStateScript.new()
	state.recording_enabled = false
	var directions := {}
	for company_id in state.share_company_ids():
		directions[company_id] = {"up": 0, "down": 0, "flat": 0, "toward_value": 0}
	var weathers := ["晴", "阵雨", "强风"]
	for simulation_day in range(80):
		var before: Dictionary = state.share_quotes.duplicate(true)
		state._settle_share_market_day(state.day)
		state.day += 1
		state.tide = 1
		state.daily_seed = int(state.rng.randi())
		state.weather = weathers[simulation_day % weathers.size()]
		state._open_share_market_day()
		for company_id in state.share_company_ids():
			var delta := int(state.share_quotes[company_id]) - int(before[company_id])
			var key := "up" if delta > 0 else ("down" if delta < 0 else "flat")
			directions[company_id][key] = int(directions[company_id][key]) + 1
			var value := float(state.share_company_financials[company_id].get("fundamental_value", state.share_quotes[company_id]))
			if absf(float(state.share_quotes[company_id]) - value) < absf(float(before[company_id]) - value):
				directions[company_id]["toward_value"] = int(directions[company_id]["toward_value"]) + 1
			assert(state.share_issued_total(company_id) == 1000, "80日空闲模拟中总发行量不得漂移。")
	return {"quotes": state.share_quotes.duplicate(true), "directions": directions}
