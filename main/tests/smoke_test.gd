extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const PokerTableScript = preload("res://scripts/poker_table.gd")
const WealthChartScript = preload("res://scripts/wealth_chart.gd")


func _init() -> void:
	_test_direct_synthesis()
	_test_ordered_recipe_resolution()
	_test_refinement_feedback_and_tiers()
	_test_shop_material_boundary()
	_test_protection_and_request()
	_test_oracle_patterns()
	_test_poker_betting_state_machine()
	_test_wealth_history_and_chart()
	_test_oracle_deal_and_showdown()
	_test_race_balance()
	_test_race_and_poker_settlement()
	_test_oracle_npc_wallets()
	_test_oracle_record_file()
	_test_oracle_action_buttons()
	_test_oracle_record_window()
	print("SMOKE TEST PASS: synthesis, inventory, request, race, oracle table, economy and time")
	quit(0)


func _test_refinement_feedback_and_tiers() -> void:
	var synthesis_state = GameStateScript.new()
	synthesis_state.add_item("wood", 1)
	var failed: Dictionary = synthesis_state.synthesize(["water", "wood"])
	assert(not bool(failed.get("success", true)), "无效材料组合必须明确判定为合成失败")
	assert(not str(failed.get("failure_reason", "")).is_empty() and not str(failed.get("suggestion", "")).is_empty(), "合成失败必须说明原因并给出不泄露答案的下一步建议")
	assert(failed.get("consumed_names", []).size() == 2, "失败反馈必须列出实际消耗的材料")

	var fishing_state = GameStateScript.new()
	var tide_before: int = int(fishing_state.tide)
	for _attempt in range(fishing_state.DAILY_FISHING_LIMIT):
		assert(bool(fishing_state.fish_once().get("ok", false)), "每日限制内的浅滩采集必须成功")
	var cash_after_limit: int = int(fishing_state.cash)
	var blocked: Dictionary = fishing_state.fish_once()
	assert(not bool(blocked.get("ok", true)) and fishing_state.cash == cash_after_limit, "浅滩达到每日上限后不得继续刷出金贝")
	assert(fishing_state.tide == tide_before + fishing_state.DAILY_FISHING_LIMIT, "被限制的额外点击不得继续消耗潮刻")
	fishing_state.sleep_to_next_day()
	assert(fishing_state.fishing_remaining_today() == fishing_state.DAILY_FISHING_LIMIT, "次日必须刷新浅滩采集次数")

	var poker_state = GameStateScript.new()
	poker_state.cash = 10000
	assert(poker_state.poker_tiers().size() == 4 and poker_state.can_enter_poker_tier(500), "牌会必须提供多档桌级并按财富开放")
	poker_state.begin_poker_session(500)
	var started: Dictionary = poker_state.start_poker_hand()
	assert(bool(started.get("ok", false)), "满足财富要求时必须能够进入500金贝桌")
	assert(int(poker_state.poker["buy_in"]) == 500 and int(poker_state.poker["player_stack"]) + int(poker_state.poker.get("player_hand_commit", 0)) == 500, "高桌本局额度必须为500，玩家盲注计入本手投入")
	assert(int(poker_state.poker["small_blind"]) == 5 and int(poker_state.poker["big_blind"]) == 10, "高桌基础投入必须随桌级缩放")
	poker_state.poker_action("fold")


func _test_shop_material_boundary() -> void:
	var state = GameStateScript.new()
	state.add_item("mud", 1)
	state.refresh_day()
	assert(not state.shop_catalog().has("mud") and not state.shop_catalog().has("shell_shirt"), "商店采购目录只能出售原材料，造物与衣服不能因发现而上架")
	assert(not bool(state.buy_item("mud", 1).get("ok", true)), "玩家不能从商店购买尚未亲手合成的造物")
	var cash_before := int(state.cash)
	var sold: Dictionary = state.sell_item("mud", 1)
	assert(bool(sold.get("ok", false)) and state.cash > cash_before, "背包里真实存在的合成品必须可以卖给商店")
	assert(not bool(state.sell_item("mud", 1).get("ok", true)), "背包里没有实物时不能继续出售造物")


func _test_wealth_history_and_chart() -> void:
	var state = GameStateScript.new()
	assert(state.wealth_history.size() == 1, "财富轨迹必须从上岛时的初始净资产开始")
	var start_worth := state.net_worth()
	assert(start_worth == state.account_wealth() + state.asset_liquidation_value(), "净资产必须包含金贝、活动中本金和背包保守回收价")
	var bought: Dictionary = state.buy_item("water", 1)
	assert(bool(bought.get("ok", false)) and state.wealth_history.size() == 2, "购买结算后必须留下财富节点")
	var after_buy := state.net_worth()
	assert(after_buy < start_worth, "按零售购买后净资产应体现买卖价差")
	var sold: Dictionary = state.sell_item("water", 1)
	assert(bool(sold.get("ok", false)) and state.wealth_history.size() == 3, "出售即使只是资产转换也必须留下可解释节点")
	assert(state.net_worth() == after_buy, "按保守回收价出售物品不应凭空改变净资产")
	state.fish_once()
	assert(state.net_worth() > after_buy and str(state.wealth_history[-1].get("reason", "")) == "浅滩采集", "采集收益必须推动财富曲线并记录来源")
	var milestone: Dictionary = state.next_wealth_milestone()
	assert(str(milestone.get("title", "")) == "学徒" and int(milestone.get("remaining", 0)) > 0, "财富页面必须给出下一头衔目标")
	var chart = WealthChartScript.new()
	chart.setup(state.wealth_history_for_chart())
	assert(chart.history.size() == state.wealth_history_for_chart().size() and chart.custom_minimum_size.y >= 280.0, "财富曲线控件必须接收完整历史并保留可读高度")
	chart.free()


func _test_direct_synthesis() -> void:
	var state = GameStateScript.new()
	var result: Dictionary = state.synthesize(["water", "earth"])
	assert(bool(result.get("success", false)), "正确材料应该直接合成")
	assert(int(state.inventory.get("mud", 0)) == 1, "水+土应该生成泥")
	assert(int(state.inventory.get("water", 0)) == 1, "合成应该消耗水")
	assert(int(state.inventory.get("earth", 0)) == 1, "合成应该消耗土")


func _test_ordered_recipe_resolution() -> void:
	var state = GameStateScript.new()
	state.add_item("fire", 1)
	state.add_item("wood", 1)
	var result: Dictionary = state.synthesize(["fire", "wood", "water"])
	assert(bool(result.get("success", false)), "子集配方应该成功")
	assert(str(result.get("output", "")) == "charcoal", "最先被投入顺序完成的配方应该获胜")
	assert(int(state.inventory.get("water", 0)) == 1, "额外投入的水也应该消耗")


func _test_protection_and_request() -> void:
	var state = GameStateScript.new()
	state.toggle_lock("water")
	var protected_result: Dictionary = state.synthesize(["water", "earth"])
	assert(not bool(protected_result.get("ok", true)), "锁定材料不能合成")
	state.toggle_lock("water")
	state.add_item("fish", 1)
	state.add_item("salt", 1)
	var crafted: Dictionary = state.synthesize(["fish", "salt"])
	assert(str(crafted.get("output", "")) == "salted_fish", "鱼+盐应该生成咸鱼")
	state.activate_aqiu_request()
	assert(state.is_protected("salted_fish"), "委托材料应该被保留")
	var delivery: Dictionary = state.turn_in_aqiu_request()
	assert(bool(delivery.get("ok", false)), "咸鱼应该能够提交给阿葵")
	assert(state.cash == 200, "阿葵委托应奖励80金贝")


func _test_race_and_poker_settlement() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	var start_tide: int = state.tide
	var race: Dictionary = state.run_race(0, "独胜", 20)
	assert(bool(race.get("ok", false)), "免费体验券应该允许首场竞速")
	assert(state.free_race_ticket == 0, "免费体验券应该被消耗")
	assert(state.locked_principal == 0, "竞速结算后不应残留锁定本金")
	assert(state.tide == start_tide + 1, "竞速应该消耗1潮刻")
	state.cash = maxi(state.cash, 100)
	var original_cash: int = int(state.cash)
	var poker_start: Dictionary = state.start_poker_hand()
	assert(bool(poker_start.get("ok", false)), "持有80金贝应该能够进入低桌")
	assert(state.poker_session_tutorial and state.locked_principal == 0 and state.cash == original_cash, "首次教学必须使用独立100金贝额度")
	var poker_end: Dictionary = state.poker_action("fold")
	assert(bool(poker_end.get("completed", false)), "退契应该结束本手")
	assert(state.locked_principal == 0, "牌局结束后应该释放锁定本金")
	assert(state.tide == start_tide + 1, "牌会进行中必须冻结世界时间")
	state.end_poker_session()
	assert(state.tide == start_tide + 3, "整场牌会离桌时只统一推进2潮刻")
	var settlement: Dictionary = state.poker.get("settlement", {})
	assert(not settlement.is_empty(), "牌局结束后必须生成结算明细")
	assert(int(settlement["cash_after"]) - int(settlement["cash_before"]) == int(settlement["net_cash"]), "净变化必须等于账户前后差额")
	assert(str(state.poker["result"]).contains("当前") and str(state.poker["result"]).contains("本手"), "结算文案必须明确显示当前额度与本手变化")
	assert(not str(state.poker["result"]).contains("岛币") and not str(state.poker["result"]).contains("筹印") and not str(state.poker["result"]).contains("兑换"), "玩家结算文案只能使用金贝")
	assert(str(state.recent_oracle_records[0].get("hand_id", "")) == str(state.poker["hand_id"]), "完成的牌局必须加入内存复盘记录")


func _test_race_balance() -> void:
	var state = GameStateScript.new()
	state.weather = "晴"
	state.cash = 1000
	state.free_race_ticket = 0
	assert(state.race_bet_cap() == 100, "常规赛事单场投入应限制为持有金贝的10%")
	assert(state.ticket_types() == ["独胜", "入席"], "未实现的高阶票种不得提前开放")
	assert(state.race_odds(4, "入席") < 2.10, "雾步入席赔率必须按重平衡后的真实前三概率定价")
	for weather_name in ["晴", "阵雨", "强风"]:
		state.weather = weather_name
		for index in range(state.RACE_BEASTS.size()):
			var win_probability := float(state.RACE_WIN_PROBABILITIES[weather_name][index])
			var top3_probability := float(state.RACE_TOP3_PROBABILITIES[weather_name][index])
			assert(win_probability * state.race_odds(index, "独胜") <= 0.97, "独胜票长期返还不得超过投入")
			assert(top3_probability * state.race_odds(index, "入席") <= 0.97, "入席票长期返还不得超过投入")
	state.weather = "晴"
	var race: Dictionary = state.run_race(4, "入席", 999999)
	assert(int(race.get("stake", 0)) == 100 and bool(race.get("bet_was_capped", false)), "超额输入必须自动限制到本场上限")
	assert(state.cash <= 1110, "单场雾步入席不得让1000金贝发生指数增长")


func _test_oracle_npc_wallets() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.poker_test_passive_ai = true
	state.begin_poker_session()
	assert(state.poker_npc_wallets.size() == 5 and state.poker_npc_brought.size() == 5, "本次牌会必须为五名NPC生成钱包")
	var total_before: int = _sum_int_array(state.poker_npc_wallets) + int(state.poker_tutorial_balance)
	state.start_poker_hand()
	var first_dealer := int(state.poker["dealer_seat"])
	var first_actor := int(state.poker["first_actor_seat"])
	state.poker_action("fold")
	assert(not state.poker.get("winner_names", []).is_empty(), "玩家退契后底池也必须结算给一名NPC")
	assert(state.poker.get("showdown", []).size() == 5, "玩家退契后，其余在场NPC必须继续解契并公开命象")
	assert(str(state.poker.get("final_readings", [])[0].get("status", "")).contains("未参与最终比较"), "玩家退契后应明确显示不参与最终比较")
	var first_fee := int(state.poker.get("settlement", {}).get("service_fee", 0))
	assert(_sum_int_array(state.poker_npc_wallets) + state.poker_tutorial_balance + first_fee == total_before, "玩家、NPC与服务费必须严格守恒")
	var leaderboard: Array = state.poker_wealth_leaderboard()
	assert(leaderboard.size() == 6, "财富榜必须包含玩家与五名NPC")
	var wallets_after_first: Array = state.poker_npc_wallets.duplicate()
	state.start_poker_hand()
	assert(int(state.poker["dealer_seat"]) != first_dealer, "每一手司契位必须在六席中轮换")
	assert(int(state.poker["first_actor_seat"]) != first_actor, "每一手首位行动者必须随司契位轮换")
	for index in range(5):
		assert(state.poker_npc_available(index) <= int(wallets_after_first[index]), "下一手必须沿用NPC上一手结算后的钱包")
	state.poker_npc_wallets[0] = 0
	state.poker["seats"][1]["stack"] = 0
	state.poker["seats"][1]["folded"] = true
	state.poker["seats"][1]["all_in"] = false
	state.poker["seats"][1]["needs_action"] = false
	state.poker_action("fold")
	assert(not bool(state.poker_npc_present[0]) and str(state.poker["opponent_actions"][0]) == "输光离桌", "NPC钱包归零后必须离桌")
	assert(bool(state.poker.get("session_ended", false)) and not state.poker_session_active, "任一NPC钱包归零后必须结束本次牌会")
	assert(not bool(state.start_poker_hand().get("ok", true)), "牌会结束后不得从结算页继续下一手")


func _test_oracle_patterns() -> void:
	var state = GameStateScript.new()
	_assert_pattern(state, [_oracle_card(0, 4, 0), _oracle_card(0, 4, 1), _oracle_card(0, 4, 2), _oracle_card(0, 4, 3)], 8, "归一")
	_assert_pattern(state, [_oracle_card(0, 1, 0), _oracle_card(1, 2, 0), _oracle_card(0, 3, 0), _oracle_card(1, 4, 0)], 7, "轮转")
	_assert_pattern(state, [_oracle_card(0, 1, 0), _oracle_card(0, 6, 0), _oracle_card(1, 2, 0), _oracle_card(1, 5, 0)], 6, "既济")
	_assert_pattern(state, [_oracle_card(0, 4, 0), _oracle_card(0, 4, 1), _oracle_card(0, 4, 2), _oracle_card(1, 1, 0)], 5, "三叠")
	_assert_pattern(state, [_oracle_card(0, 2, 0), _oracle_card(1, 2, 0), _oracle_card(0, 5, 0), _oracle_card(1, 5, 0)], 4, "双镜")
	_assert_pattern(state, [_oracle_card(0, 2, 0), _oracle_card(0, 3, 0), _oracle_card(1, 4, 0), _oracle_card(1, 5, 0)], 3, "升势")
	_assert_pattern(state, [_oracle_card(0, 1, 0), _oracle_card(0, 1, 1), _oracle_card(1, 2, 0), _oracle_card(1, 2, 1)], 2, "双回响")
	_assert_pattern(state, [_oracle_card(0, 1, 0), _oracle_card(0, 1, 1), _oracle_card(1, 3, 0), _oracle_card(0, 6, 0)], 1, "回响")
	_assert_pattern(state, [_oracle_card(0, 1, 0), _oracle_card(1, 2, 0), _oracle_card(1, 4, 0), _oracle_card(0, 6, 0)], 0, "微兆")
	var higher_jiji := state._oracle_score_four([_oracle_card(0, 1, 0), _oracle_card(1, 2, 0), _oracle_card(1, 5, 0), _oracle_card(0, 6, 0)])
	var lower_jiji := state._oracle_score_four([_oracle_card(0, 1, 0), _oracle_card(1, 3, 0), _oracle_card(1, 4, 0), _oracle_card(0, 6, 0)])
	assert(state._compare_scores(higher_jiji, lower_jiji) > 0, "既济总势相同时必须继续按势阶从高到低比较")


func _test_poker_betting_state_machine() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.poker_test_passive_ai = true
	state.start_poker_hand()
	assert(state.poker.get("seats", []).size() == 6, "玩家与五名NPC必须处于同一六席状态机")
	state.poker_action("call")
	for seat in state.poker["seats"]:
		assert(int(seat["hand_commit"]) == 2, "1/2桌首轮全部跟契后每席总投入必须恰好为2")
	assert(int(state.poker["pot"]) == 12, "六人1/2桌首轮全部跟契后的正确底池必须为12")

	var seats: Array = state.poker["seats"]
	for index in range(seats.size()):
		seats[index]["hand_commit"] = [80, 20, 50, 0, 0, 0][index]
		seats[index]["folded"] = index >= 3
	state.poker["seats"] = seats
	state.poker_session_tutorial = false
	state.poker["dealer_seat"] = 5
	var pots: Dictionary = state._poker_build_pots({0: {"score": [0, 1]}, 1: {"score": [8, 6]}, 2: {"score": [7, 6]}})
	assert(int(pots["refunds"][0]) == 30, "无人跟注的最上层30金贝必须退还深筹码玩家")
	assert(pots["pots"].size() == 2, "80/20/50投入必须形成主池和一个边池")
	assert(int(pots["payouts"][1]) == 58 and int(pots["payouts"][2]) == 60, "短筹码只能赢主池，边池必须由有资格者获得")
	assert(_sum_int_array(pots["payouts"]) + _sum_int_array(pots["refunds"]) + int(pots["service_fee"]) == 150, "分池、返还与服务费之和必须等于总投入")

	for index in range(seats.size()):
		seats[index]["hand_commit"] = 1 if index < 3 else 0
		seats[index]["folded"] = index == 2 or index >= 3
	state.poker["seats"] = seats
	var odd: Dictionary = state._poker_build_pots({0: {"score": [2, 3]}, 1: {"score": [2, 3]}})
	assert(int(odd["payouts"][0]) + int(odd["payouts"][1]) == 3, "奇数金贝必须按座位顺序分配，不能向下取整销毁")

	var rotation = GameStateScript.new()
	rotation.recording_enabled = false
	rotation.poker_test_passive_ai = true
	rotation.poker_completed = true
	rotation.cash = 10000
	rotation.begin_poker_session(80)
	var dealer_seats := {}
	for _hand in range(6):
		rotation.start_poker_hand()
		dealer_seats[int(rotation.poker["dealer_seat"])] = true
		while not bool(rotation.poker.get("completed", false)):
			rotation.poker_action("call")
	assert(dealer_seats.size() == 6 and dealer_seats.has(0), "六手内司契位必须遍历玩家与五名NPC全部六席")
	rotation.end_poker_session()

	var capped = GameStateScript.new()
	capped.recording_enabled = false
	capped.poker_test_passive_ai = true
	var tide_before: int = int(capped.tide)
	capped.begin_poker_session(80)
	capped.poker_session_hands = 7
	capped.start_poker_hand()
	capped.poker_action("fold")
	assert(not capped.poker_session_active and bool(capped.poker.get("session_ended", false)), "第8手结算后必须自动结束短牌会")
	assert(capped.tide == tide_before + 2, "8手牌会也只能在整场结束时推进2潮刻")


func _test_oracle_deal_and_showdown() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.poker_test_passive_ai = true
	var started: Dictionary = state.start_poker_hand()
	assert(bool(started.get("ok", false)), "占卜牌会应该能够开始")
	var dealt: Array = state.poker["player_hand"].duplicate()
	for hand in state.poker["opponent_hands"]:
		dealt.append_array(hand)
	dealt.append_array(state.poker["community"])
	var unique := {}
	for card in dealt:
		assert(int(card) >= 0 and int(card) < 48, "占卜牌编号必须在48张牌内")
		assert(not unique.has(card), "同一实体牌不能重复发出")
		unique[card] = true
	assert(dealt.size() == 17 and unique.size() == 17, "六人牌局应发出12张命牌和5张天象")
	assert(state.poker_visible_community().size() == 0, "藏命阶段不公开天象")
	for expected_count in [2, 4, 5]:
		var action: Dictionary = state.poker_action("call")
		assert(bool(action.get("ok", false)), "静观或跟契应该成功")
		if not bool(state.poker.get("completed", false)):
			assert(state.poker_visible_community().size() == expected_count, "天象应按2/2/1公开")
	if not bool(state.poker.get("completed", false)):
		state.poker_action("call")
	assert(bool(state.poker.get("completed", false)), "第四轮行动后应该解契")
	assert(state.locked_principal == 0, "解契后应该释放牌会本金")
	var final_readings: Array = state.poker.get("final_readings", [])
	assert(final_readings.size() == 6, "解契后必须生成玩家和五个NPC的席位结果")
	var winner_count := 0
	for entry in final_readings:
		assert(bool(entry.get("folded", false)) or not str(entry.get("reading_name", "")).is_empty(), "所有参与解契的席位都必须显示最终命象")
		if bool(entry.get("winner", false)):
			winner_count += 1
	assert(winner_count >= 1, "解契结果必须明确标出至少一名赢家")


func _test_oracle_record_file() -> void:
	var state = GameStateScript.new()
	state.poker_test_passive_ai = true
	state.oracle_record_relative_path = "user://play_records/oracle_table_smoke_test.jsonl"
	var absolute_path: String = ProjectSettings.globalize_path(state.oracle_record_relative_path)
	if FileAccess.file_exists(state.oracle_record_relative_path):
		DirAccess.remove_absolute(absolute_path)
	var started: Dictionary = state.start_poker_hand()
	assert(bool(started.get("ok", false)), "记录测试牌局应该能够开始")
	state.poker_action("fold")
	assert(FileAccess.file_exists(state.oracle_record_relative_path), "牌局事件必须写入JSONL记录")
	var file := FileAccess.open(state.oracle_record_relative_path, FileAccess.READ)
	var events: Array[String] = []
	var final_record: Dictionary = {}
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		assert(parsed is Dictionary, "JSONL每行都必须是完整JSON对象")
		events.append(str(parsed.get("event", "")))
		if str(parsed.get("event", "")) == "hand_end":
			final_record = parsed
	if file != null:
		file.close()
	assert(events.has("hand_start") and events.has("player_action") and events.has("hand_end"), "记录必须覆盖开局、玩家行动和结算")
	assert(not final_record.get("settlement", {}).is_empty(), "最终记录必须包含资金结算明细")
	DirAccess.remove_absolute(absolute_path)


func _test_oracle_record_window() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.start_poker_hand()
	for _round in range(4):
		if not bool(state.poker.get("completed", false)):
			state.poker_action("call")
	var table = PokerTableScript.new()
	table.setup(state)
	table.animations_enabled = false
	root.add_child(table)
	table.open()
	assert(table.center_stage != null and table.board_slot.get_parent() == table.center_stage and table.player_slot.get_parent() == table.center_stage, "牌桌中央必须使用固定舞台与固定挂载位")
	assert(not _tree_contains_class(table.center_stage, "ScrollContainer"), "牌桌核心舞台不得滚动或折叠")
	assert(table.right_scroll != null and table.right_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "右侧命象栏不得横向溢出或被裁切")
	assert(table.header_cash.text.contains("教学额度") or table.header_cash.text.contains("持有"), "牌桌顶部必须显示玩家当前可用额度")
	assert(_tree_contains_text(table, "各席最终命象"), "牌局结束后右侧必须显示各席位最终命象")
	assert(_tree_count_text(table, "赢家：") == 1, "结算摘要只能在底部显示一次，中央不得重复")
	assert(not _tree_contains_text(table, "解契结果："), "中央牌桌不得保留重复的结算横幅")
	assert(not _tree_contains_text(table, "岛币") and not _tree_contains_text(table, "筹印") and not _tree_contains_text(table, "启印") and not _tree_contains_text(table, "兑换"), "牌桌玩家界面只能使用金贝作为货币名称")
	table._show_records()
	assert(table.records_overlay.visible, "牌桌内必须能够打开牌局记录窗口")
	assert(table.records_body.get_child_count() > 0, "牌局记录窗口必须生成当前状态和历史记录内容")
	table._hide_records()
	assert(not table.records_overlay.visible, "牌局记录窗口必须能够关闭")
	table.free()


func _test_oracle_action_buttons() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.poker_test_passive_ai = true
	state.start_poker_hand()
	var table = PokerTableScript.new()
	table.setup(state)
	table.animations_enabled = false
	root.add_child(table)
	table.open()
	assert(_tree_contains_text(table, "小盲1金贝") or _tree_contains_text(table, "大盲2金贝"), "强制投入必须直接显示在对应席位上")
	var to_call := int(state.poker["to_call"])
	var remaining := int(state.poker["player_stack"])
	var min_raise := int(state.poker["min_raise"])
	var pot_after_call := int(state.poker["pot"]) + to_call
	var min_total := mini(remaining, to_call + min_raise)
	var half_total := mini(remaining, to_call + maxi(min_raise, int(round(float(pot_after_call) * 0.5))))
	var full_total := mini(remaining, to_call + maxi(min_raise, pot_after_call))
	assert(_tree_contains_text(table, "加到%d金贝" % min_total), "最低加契按钮必须显示本次实际投入")
	assert(_tree_contains_text(table, "半池 · 投入%d金贝" % half_total), "半池必须按跟契后的池量计算")
	assert(_tree_contains_text(table, "满池 · 投入%d金贝" % full_total), "满池必须按跟契后的池量计算")
	assert(not _tree_contains_text(table, "1/3池") and not _tree_contains_class(table, "SpinBox"), "下注区不得保留间接比例选择或数字输入框")
	var stack_before := int(state.poker["player_stack"])
	table._act("raise", min_raise)
	assert(stack_before - int(state.poker["player_stack"]) == min_total, "最低加契必须只扣除跟契额加最低加注额")
	table.free()


func _tree_contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and str(node.text).contains(needle):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _tree_count_text(node: Node, needle: String) -> int:
	var count := 0
	if (node is Label or node is Button) and str(node.text).contains(needle):
		count += 1
	for child in node.get_children():
		count += _tree_count_text(child, needle)
	return count


func _tree_contains_class(node: Node, class_name_value: String) -> bool:
	if node.is_class(class_name_value):
		return true
	for child in node.get_children():
		if _tree_contains_class(child, class_name_value):
			return true
	return false


func _sum_int_array(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total


func _assert_pattern(state, cards: Array, expected_rank: int, expected_name: String) -> void:
	var reading: Dictionary = state.oracle_best_reading([cards[0], cards[1]], [cards[2], cards[3]])
	assert(int(reading["score"][0]) == expected_rank, "命象判定错误：期望%s，实际%s" % [expected_name, reading["name"]])
	assert(str(reading["name"]) == expected_name, "命象名称错误")


func _oracle_card(element: int, rank: int, copy_index: int) -> int:
	return element * 24 + (rank - 1) * 4 + copy_index
