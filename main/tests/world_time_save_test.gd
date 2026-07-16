extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")

const TEST_SAVE_PATH := "user://tests/world_time_save.json"


func _init() -> void:
	_test_continuous_clock_and_pause_stack()
	_test_boundaries_and_day_end_hold()
	_test_fixed_activity_costs()
	_test_save_round_trip_and_validation()
	_cleanup_save_files()
	print("WORLD TIME SAVE TEST PASS")
	quit(0)


func _state() -> GameState:
	var state: GameState = GameStateScript.new()
	state.recording_enabled = false
	return state


func _test_continuous_clock_and_pause_stack() -> void:
	var state := _state()
	assert(state.seconds_per_tide() == 120.0, "标准档每潮刻必须是120秒。")
	assert(state.advance_world_delta(60.0), "世界活动状态下现实时间必须推进。")
	assert(is_equal_approx(state.tide_progress, 0.5) and state.tide == 1, "60秒标准档必须推进半个潮刻。")
	state.set_time_pause("menu", true, state.TIME_STATE_UI)
	assert(state.time_state == state.TIME_STATE_UI and not state.advance_world_delta(120.0), "界面打开时自然时钟必须完全暂停。")
	assert(is_equal_approx(state.tide_progress, 0.5), "暂停期间不得补算现实delta。")
	state.set_time_pause("activity", true, state.TIME_STATE_ACTIVITY)
	assert(state.time_state == state.TIME_STATE_ACTIVITY, "正式活动快照必须优先于普通界面暂停。")
	state.set_time_pause("activity", false)
	assert(state.time_state == state.TIME_STATE_UI, "活动结束后仍有菜单时必须保持停表。")
	state.set_time_pause("menu", false)
	assert(state.time_state == state.TIME_STATE_WORLD, "清空暂停原因后必须恢复世界流动。")
	state.advance_world_delta(60.0)
	assert(state.tide == 2 and is_zero_approx(state.tide_progress), "恢复后只推进新的60秒，不补算暂停时间。")

	for mode in ["紧凑", "标准", "悠闲"]:
		var speed_state := _state()
		assert(speed_state.set_time_speed_mode(mode), "三档自然流速都必须可选择。")
		speed_state.advance_world_delta(speed_state.seconds_per_tide() * 0.5)
		assert(is_equal_approx(speed_state.tide_progress, 0.5), "每档经过半个潮刻秒数都必须只推进半个潮刻。")
		var before_fixed := speed_state.tide_progress
		speed_state.advance_time_fraction(0.25, "固定测试")
		assert(is_equal_approx(speed_state.tide_progress, before_fixed + 0.25), "日长设置不得缩放固定活动耗时。")


func _test_boundaries_and_day_end_hold() -> void:
	var state := _state()
	state.tide = 4
	state.tide_progress = 0.75
	state.fast_forward_time(0.5, "跨时段测试")
	assert(state.tide == 5 and is_equal_approx(state.tide_progress, 0.25), "跨时段推进必须保留潮刻内余量。")
	assert(state.phase_name() == "白天", "第5潮刻必须进入白天。")
	assert(state.time_event_log.any(func(event): return str(event.get("kind", "")) == "phase"), "跨时段必须留下边界记录。")

	state.tide = 16
	state.tide_progress = 0.75
	state.fast_forward_time(0.5, "日终测试")
	assert(state.day == 1 and state.tide == 16 and state.day_end_pending, "第16潮刻末必须停驻，不能无人值守跨日。")
	assert(state.time_state == state.TIME_STATE_DAY_END and is_zero_approx(state.tide_progress), "日终必须冻结在明确的停表状态。")
	assert(not state.advance_world_delta(999.0) and not state.fast_forward_time(1.0), "日终停驻后任何自然或等待推进都不得跨日。")
	state.sleep_to_next_day()
	assert(state.day == 2 and state.tide == 1 and is_zero_approx(state.tide_progress), "只有睡眠确认才能进入次日清晨。")
	assert(not state.day_end_pending and state.time_state == state.TIME_STATE_WORLD, "次日必须恢复世界活动状态。")
	assert(int(state.daily_schedule.get("day", 0)) == 2 and int(state.daily_schedule.get("seed", 0)) == state.daily_seed, "次日日程必须在睡眠时生成并绑定当日种子。")


func _test_fixed_activity_costs() -> void:
	var state := _state()
	state.cash = 10000
	var first := state.synthesize_pair("water", "fire")
	assert(bool(first.get("ok", false)) and is_equal_approx(state.tide_progress, 0.25), "首次新组合必须统一消耗0.25潮刻。")
	var repeated := state.synthesize_pair("water", "fire")
	assert(bool(repeated.get("repeat", false)) and is_equal_approx(state.tide_progress, 0.25), "历史组合复查不得再次消耗时间。")
	state.free_race_ticket = 0
	var race := state.run_race(0, "独胜", 10)
	assert(bool(race.get("ok", false)) and state.tide == 2 and is_equal_approx(state.tide_progress, 0.25), "竞速必须固定推进1潮刻且保留小数进度。")


func _test_save_round_trip_and_validation() -> void:
	_cleanup_save_files()
	var state := _state()
	state.cash = 987
	state.day = 3
	state.tide = 7
	state.tide_progress = 0.625
	state.set_time_speed_mode("悠闲")
	state.weather = "阵雨"
	state.wind_direction = "逆风"
	state.discover_item("steam")
	state.set_time_pause("menu", true, state.TIME_STATE_UI)
	var world := {
		"discovered_areas": {"漂流湾": true, "椰影街": true},
		"current_area": "椰影街",
		"player_position": {"x": 1700.0, "y": 650.0}
	}
	var built := state.build_save_data(world)
	assert(str(built["state"].get("time_state", "")) == state.TIME_STATE_UI, "存档必须记录当前时间状态。")
	assert(built["state"].get("time_pause_reasons", {}) is Dictionary, "存档必须记录暂停原因栈。")
	state.set_time_pause("menu", false)
	var save_result := state.save_game(TEST_SAVE_PATH, world)
	assert(bool(save_result.get("ok", false)) and FileAccess.file_exists(TEST_SAVE_PATH), "手动存档必须写入可读取文件。")
	var expected_next_random := state.rng.randi()

	state.cash = 1
	state.day = 99
	state.tide = 16
	state.tide_progress = 0.0
	state.discovered.clear()
	var load_result := state.load_game(TEST_SAVE_PATH)
	assert(bool(load_result.get("ok", false)), "刚写入的存档必须能无损读取。")
	assert(state.cash == 987 and state.day == 3 and state.tide == 7 and is_equal_approx(state.tide_progress, 0.625), "读档必须恢复经济和连续世界时间。")
	assert(state.time_speed_mode == "悠闲" and state.weather == "阵雨" and state.wind_direction == "逆风", "读档必须恢复日长、天气和风向。")
	assert(state.is_discovered("steam") and state.is_discovered("water"), "读档必须恢复永久发现并保证三根源存在。")
	assert(state.rng.randi() == expected_next_random, "读档后主随机序列必须从保存点继续，不能重掷。")
	assert(load_result.get("world", {}) == world, "地图发现与玩家位置必须随存档一同返回。")

	var cash_before_invalid := state.cash
	var invalid := state.restore_save_data({"version": 1, "state": {"discovered": "broken"}, "world": {}})
	assert(not bool(invalid.get("ok", true)) and state.cash == cash_before_invalid, "损坏存档必须在修改当前进度前被拒绝。")
	state.begin_poker_session(80)
	assert(not state.can_save_game(), "活动本金或牌会状态尚未结算时必须禁止手动存档。")


func _cleanup_save_files() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
