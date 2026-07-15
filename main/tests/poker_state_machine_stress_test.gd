extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var policy := RandomNumberGenerator.new()
	policy.seed = 20260714
	var completed_hands := 0
	for _session in range(80):
		var state = GameStateScript.new()
		state.recording_enabled = false
		state.poker_completed = true
		state.cash = 10000
		state.begin_poker_session(80)
		var initial_total: int = int(state.cash) + _sum(state.poker_npc_wallets)
		var accumulated_fee: int = 0
		for _hand in range(8):
			var started: Dictionary = state.start_poker_hand()
			if not bool(started.get("ok", false)):
				break
			var player_decisions := 0
			while not bool(state.poker.get("completed", false)) and player_decisions < 80:
				player_decisions += 1
				assert(int(state.poker.get("current_actor", -1)) == 0, "引擎只能在轮到玩家时返回控制权")
				var roll := policy.randf()
				var result: Dictionary
				if roll < 0.08:
					result = state.poker_action("fold")
				elif roll < 0.16:
					result = state.poker_action("all_in")
				elif roll < 0.34:
					result = state.poker_action("raise", int(state.poker.get("min_raise", 2)))
				else:
					result = state.poker_action("call")
				if not bool(result.get("ok", false)):
					result = state.poker_action("all_in")
				assert(bool(result.get("ok", false)), "合法玩家行动必须能够推进状态机")
			assert(player_decisions < 80 and bool(state.poker.get("completed", false)), "单手下注状态机必须在有限行动内收敛")
			var settlement: Dictionary = state.poker.get("settlement", {})
			var accounted := _sum(settlement.get("payouts", [])) + _sum(settlement.get("refunds", [])) + int(settlement.get("service_fee", 0))
			assert(accounted == int(settlement.get("committed_total", -1)), "每手派彩、返还与服务费必须等于总投入")
			accumulated_fee += int(settlement.get("service_fee", 0))
			assert(state.locked_principal == 0, "每手结束后不得残留锁定本金")
			assert(state.cash >= 0, "玩家现金不得为负")
			for wallet in state.poker_npc_wallets:
				assert(int(wallet) >= 0, "NPC钱包不得为负")
			assert(state.cash + _sum(state.poker_npc_wallets) + accumulated_fee == initial_total, "跨手资金只能在六席与服务费之间转移")
			completed_hands += 1
			if not state.poker_session_active:
				break
		state.end_poker_session()
	assert(completed_hands >= 300, "压力测试必须覆盖足够多的随机完整手牌")
	print("POKER STATE MACHINE STRESS PASS: %d hands" % completed_hands)
	quit(0)


func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total
