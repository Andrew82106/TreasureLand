extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_daily_schedule_pool_and_odds()
	_test_seal_history_time_and_save()
	_test_aid_does_not_change_event()
	_test_race_world_cash_funding()
	await _test_fullscreen_race_arena()
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
	var old_time_saved: Dictionary = saved.duplicate(true)
	for index in range(old_time_saved["state"]["race_events"].size()):
		var old_event: Dictionary = old_time_saved["state"]["race_events"][index]
		if bool(old_event.get("completed", false)):
			var old_summary: Dictionary = old_event.get("result_summary", {})
			old_summary.erase("time_settled")
			old_event["result_summary"] = old_summary
			old_time_saved["state"]["race_events"][index] = old_event
	for index in range(old_time_saved["state"]["race_history"].size()):
		old_time_saved["state"]["race_history"][index].erase("time_settled")
	var old_time_restored = _state()
	assert(bool(old_time_restored.restore_save_data(old_time_saved).get("ok", false)), "即时走时旧赛事存档必须可迁移。")
	var migrated_tide: int = int(old_time_restored.tide)
	assert(not old_time_restored.finalize_race_time(event_id) and old_time_restored.tide == migrated_tide, "旧版已完赛记录必须迁移为已结算时间，不能读档后二次推进。")
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


func _test_race_world_cash_funding() -> void:
	var state = _state()
	state.cash = 50000000
	var event: Dictionary = state.current_race_event()
	var simulated: Dictionary = state._simulate_race_event(event, 0)
	var winning_index := int(simulated.get("results", [])[0].get("index", 0))
	var total_before := state.auditable_world_cash_total()
	var result: Dictionary = state.run_race(winning_index, "独胜", 5000, "", str(event["event_id"]))
	assert(bool(result.get("ok", false)) and bool(result.get("won", false)), "资金压力测试必须选择确定性冠军并命中。")
	assert(state.auditable_world_cash_total() == total_before, "高财富玩家命中后，票款与派彩仍必须跨账户严格守恒。")
	assert(int(state.world_external_account.get("cash", 0)) >= 0 and state.world_group_accounts.values().all(func(group): return int(group.get("cash", 0)) >= 0), "赛事组织方、岛内群体与外部账户不得因派彩变成负数。")


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


func _test_fullscreen_race_arena() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	scene.title_screen_enabled = false
	root.add_child(scene)
	await process_frame
	scene.game.cash = 1000
	scene.game.free_race_ticket = 0
	var cash_before_view: int = int(scene.game.cash)
	var tide_before_view: int = int(scene.game.tide)
	var world_cash_before_view: int = scene.game.auditable_world_cash_total()
	scene._open_race()
	await process_frame
	assert(scene.race_arena.visible and scene.race_arena.arena_grid != null and scene.race_arena.beast_buttons.size() == 8, "逐风竞速必须使用独立全屏赛场，并把八匹赛兽放在中央直接选择。")
	assert(_tree_contains_text(scene.race_arena, "晨风试走") and _tree_contains_text(scene.race_arena, "票池显示岛民选择"), "赛前页面必须在中央赛兽周围展示四场日程和公开票池解释。")
	var public_ticket: Dictionary = scene.race_arena.event.get("named_tickets", [])[0]
	assert(_tree_contains_text(scene.race_arena, str(public_ticket.get("name", ""))) and _tree_contains_text(scene.race_arena, str(public_ticket.get("beast_name", ""))), "赛场公开消息必须读取本场真实NPC票据，而不是只显示泛化文案。")
	scene.race_arena._select_beast(4)
	assert(scene.race_arena.selected_beast == 4 and _tree_contains_text(scene.race_arena.right_panel, "雾步"), "点击中央赛兽后，右侧近况、风险和赔率必须同步同一选择。")
	assert(scene.game.cash == cash_before_view and scene.game.tide == tide_before_view, "赛前查看、选兽和研读不得提前扣款或推进潮刻。")
	scene.race_arena.close()
	assert(scene.game.cash == cash_before_view and scene.game.tide == tide_before_view and scene.game.auditable_world_cash_total() == world_cash_before_view, "封盘前离开赛场不得扣款、收费、改变世界总账或推进时间。")
	scene._open_race()
	scene.race_arena._select_beast(4)
	scene.race_bet_spin.value = 100
	scene.race_arena._request_start()
	await process_frame
	assert(scene.race_replay != null and scene.race_replay.replay_result.get("stage_reports", []).size() == 4, "正式比赛必须创建可播放的四段动态赛道。")
	assert(scene.race_arena.mode == "race" and is_equal_approx(scene.race_replay.duration, 28.0), "正式比赛必须在同一全屏页面进入25—35秒实际赛道演出。")
	assert(scene.game.tide == tide_before_view and scene.race_arena.close_button.disabled and scene.race_arena.history_button.disabled, "正式比赛演出期间必须冻结离场与历史入口，固定潮刻只能在冲线后结算。")
	scene.race_arena.close()
	scene.race_arena._request_history()
	assert(scene.race_arena.visible and not scene.modal_overlay.visible, "比赛进行中不得通过返回、Esc或历史入口中断活动快照。")
	var settled_cash: int = int(scene.game.cash)
	var settled_history: int = scene.game.race_history.size()
	scene.race_arena._request_start()
	scene.race_arena._set_replay_speed(scene.race_replay.replay_result, 2.0)
	scene.race_arena._set_replay_speed(scene.race_replay.replay_result, 2.0, true)
	assert(scene.race_replay.reduced_motion, "降低动态必须切换为分段跳变并关闭跑动抖动，而不只是加速播放。")
	assert(scene.game.cash == settled_cash and scene.game.tide == tide_before_view and scene.game.race_history.size() == settled_history, "重复开始、2倍速和重看只能改变表现，不能重复扣款、重掷或提前结算时间。")
	scene.race_replay.skip()
	await process_frame
	assert(scene.race_arena.mode == "finish" and _tree_contains_text(scene.race_arena, "判断与结果") and _tree_contains_text(scene.race_arena, "完整排名"), "冲线后必须在同一页面显示排名、资金和判断复盘，不打开结果弹窗。")
	assert(scene.game.tide == tide_before_view + 1 and scene.game.auditable_world_cash_total() == world_cash_before_view, "冲线后必须只推进一次固定潮刻，票款和派彩在玩家、赛事组织者与外部账户间严格守恒。")
	var completed_tide := int(scene.game.tide)
	assert(not scene.game.finalize_race_time(str(scene.race_arena.event_id)) and scene.game.tide == completed_tide, "重复完成信号不得再次推进潮刻或重复记录财富。")
	scene._open_race_history_from_arena()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "本场") and _tree_contains_text(scene.modal_body, "夺魁"), "赛事历史必须显示玩家票据、盈亏与冠军。")
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
