extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_daily_schedule_pool_and_odds()
	_test_seal_history_time_and_save()
	_test_aid_does_not_change_event()
	await _test_race_ui_history_and_replay()
	print("RACE EVENT SYSTEM TEST PASS")
	quit(0)


func _state():
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.cash = 10000
	state.free_race_ticket = 0
	return state


func _test_daily_schedule_pool_and_odds() -> void:
	var state = _state()
	var mirror = _state()
	assert(state.race_events.size() == 4, "每天必须生成清晨、白天、傍晚和夜晚四场赛事。")
	assert(state.race_events == mirror.race_events, "相同日种子必须生成完全相同的阵容、票池和赛事种子。")
	var expected_tides := [3, 7, 11, 15]
	for slot_index in range(4):
		var event: Dictionary = state.race_events[slot_index]
		assert(int(event["scheduled_tide"]) == expected_tides[slot_index], "四场鸣钟潮刻必须固定。")
		assert(event.get("roster", []).size() == 8, "每场必须锁定八兽阵容。")
		assert(event.get("named_tickets", []).size() >= 8, "开盘票池必须有可读的NPC购票来源。")
		for ticket_type in ["独胜", "入席"]:
			var amounts: Array = event.get("initial_pool", {}).get(ticket_type, [])
			assert(amounts.size() == 8 and amounts.all(func(value): return int(value) > 0), "每个票种必须为八兽建立非零开盘票池。")
			var probabilities: Array = state.RACE_TOP3_PROBABILITIES[str(event["weather"])] if ticket_type == "入席" else state.RACE_WIN_PROBABILITIES[str(event["weather"])]
			for beast_index in range(8):
				var odds := float(state.race_event_odds(event, beast_index, ticket_type))
				assert(float(probabilities[beast_index]) * odds <= 0.951, "动态预计赔率仍不得突破长期返还安全上限。")
	var rows := state.race_schedule_rows()
	assert(str(rows[0]["status"]) == "本时段开放" and rows.slice(1).all(func(row): return str(row["status"]) == "预告"), "开局只能开放清晨场，其余赛事必须保留日程状态。")
	assert(not state.race_news_summary().get("headline", "").is_empty(), "晨报必须能够读取当前赛事快照。")


func _test_seal_history_time_and_save() -> void:
	var state = _state()
	var event: Dictionary = state.current_race_event()
	var event_id := str(event["event_id"])
	var cash_before: int = int(state.cash)
	var tide_before: int = int(state.tide)
	var result: Dictionary = state.run_race(4, "入席", 999999, "", event_id)
	assert(bool(result.get("ok", false)), "本时段开放赛事必须可以封盘结算。")
	assert(bool(result.get("bet_was_capped", false)) and int(result.get("stake", 0)) == 1000, "正式祝胜券必须按账户财富10%限制投入。")
	assert(result.get("late_tickets", []).size() >= 6, "购票后必须模拟并公开封盘前NPC追加票。")
	assert(float(result.get("final_odds", 0.0)) > 0.0 and result.has("current_odds"), "结果必须同时保存当前预计与封盘赔率。")
	assert(result.get("stage_reports", []).size() == 4, "赛事必须保存完整四段回放。")
	for raw_stage in result["stage_reports"]:
		var stage: Dictionary = raw_stage
		assert(stage.get("order", []).size() == 8 and stage.get("order_indices", []).size() == 8, "每段必须保存八兽完整顺序，而非只保存领先者。")
	assert(state.race_history.size() == 1 and bool(state.race_events[0]["completed"]), "封盘结果必须进入赛事历史并关闭当前赛事。")
	assert(state.tide == tide_before + 1 and state.tide_progress == 0.0, "一场赛事必须固定推进1潮刻。")
	assert(state.cash == cash_before + int(result["net_cash"]), "票面、辅助费、派彩和账户净变化必须严格一致。")
	var duplicate_cash: int = int(state.cash)
	assert(not bool(state.run_race(4, "入席", 10, "", event_id).get("ok", true)) and state.cash == duplicate_cash, "已结算赛事不得重复购票或扣款。")
	assert(state.current_race_event().is_empty() and state.tides_until_next_race() > 0.0, "同一时段不能无限刷新赛事，必须等待下一场。")
	var wait_amount: float = float(state.tides_until_next_race())
	assert(state.fast_forward_time(wait_amount, "测试等待赛事"), "玩家必须能等待到下一时段赛事。")
	assert(int(state.current_race_event().get("slot", -1)) == 1, "进入白天后必须开放第二场固定赛事。")

	var saved := state.build_save_data({})
	assert(int(saved.get("version", 0)) == state.SAVE_VERSION, "赛事快照与历史必须随当前版本存档保留。")
	var restored = _state()
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "当前版本赛事状态必须可读取。")
	assert(restored.race_events == state.race_events and restored.race_history == state.race_history, "读档不能重掷已经锁定的票池、赛果或历史。")
	var legacy = _state()
	assert(bool(legacy.restore_save_data({
		"version": 3,
		"state": {
			"day": 2, "tide": 6, "daily_seed": 778899, "weather": "阵雨", "wind_direction": "逆风",
			"discovered": {"water": true, "fire": true, "earth": true}
		},
		"world": {}
	}).get("ok", false)), "版本3存档必须补建当天赛事快照。")
	assert(legacy.race_events.size() == 4 and int(legacy.race_events[0]["day"]) == 2, "旧存档迁移后必须立即拥有可复现的四场赛事。")


func _test_aid_does_not_change_event() -> void:
	var aided = _state()
	var plain = _state()
	aided.discover_item("rain", "test")
	var event_id := str(aided.current_race_event()["event_id"])
	var aided_result: Dictionary = aided.run_race(0, "独胜", 100, "rain", event_id)
	var plain_result: Dictionary = plain.run_race(0, "独胜", 100, "", event_id)
	assert(_result_order(aided_result) == _result_order(plain_result), "同一赛事快照下，部署造物不得改变四段结果或最终排名。")
	assert(aided_result.get("final_pool", {}) == plain_result.get("final_pool", {}), "造物不得改变NPC票池或封盘赔率来源。")
	assert(aided.cash == plain.cash - 4, "雨势推演只应额外扣除4金贝信息费。")
	assert(aided.is_discovered("rain"), "部署后永久造物必须继续保留。")


func _test_race_ui_history_and_replay() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	scene.title_screen_enabled = false
	root.add_child(scene)
	await process_frame
	scene.game.cash = 1000
	scene.game.free_race_ticket = 0
	scene._open_race()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "晨风试走") and _tree_contains_text(scene.modal_body, "当前独胜票池支持前三"), "赛前页面必须展示四场日程和公开票池。")
	assert(_tree_contains_text(scene.modal_body, "封盘前赔率仍会随NPC购票变化"), "确认区必须明确当前赔率不是固定承诺。")
	scene.race_bet_spin.value = 100
	scene._run_race()
	await process_frame
	assert(scene.race_replay != null and scene.race_replay.replay_result.get("stage_reports", []).size() == 4, "结算页必须创建可播放的四段动态回放。")
	assert(_tree_contains_text(scene.modal_body, "封盘前新增购票") and _tree_contains_text(scene.modal_body, "完整排名"), "结果页必须同时解释票池变化和完整排名。")
	scene.race_replay.skip()
	assert(scene.race_replay.current_stage_index() == 3, "玩家必须可以跳过动画并直接查看终点。")
	scene._open_race_history()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "本场") and _tree_contains_text(scene.modal_body, "夺魁"), "赛事历史必须显示玩家票据、盈亏与冠军。")
	scene._open_news()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "最近赛果"), "晨报必须在完赛后展示可追溯的赛事结果。")
	scene._open_time_menu()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "今日逐风赛事") and _tree_contains_text(scene.modal_body, "已完赛"), "日程页必须读取同一份赛事状态。")
	scene.free()
	var activity_path := "user://saves/activity_race.json"
	if FileAccess.file_exists(activity_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(activity_path))


func _result_order(result: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_entry in result.get("results", []):
		names.append(str(raw_entry.get("name", "")))
	return names


func _tree_contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and needle in str(node.text):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
