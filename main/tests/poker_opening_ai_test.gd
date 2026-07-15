extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var opening_actions := 0
	var opening_folds := 0
	var all_npc_fold_hands := 0
	var completed_hands := 0
	var style_actions := {"礁石型": 0, "潮汐型": 0, "海雾型": 0}
	var style_folds := {"礁石型": 0, "潮汐型": 0, "海雾型": 0}
	for _session in range(40):
		var state = GameStateScript.new()
		state.recording_enabled = false
		state.poker_completed = true
		state.cash = 10000
		state.begin_poker_session(80)
		for _hand in range(8):
			var started: Dictionary = state.start_poker_hand()
			if not bool(started.get("ok", false)):
				break
			while not bool(state.poker.get("completed", false)) and int(state.poker.get("stage", 0)) == 0:
				state.poker_action("call")
			var folded_npcs := 0
			for raw_event in state.poker.get("action_history", []):
				if not raw_event is Dictionary or int(raw_event.get("seat", 0)) == 0 or str(raw_event.get("stage", "")) != "藏命":
					continue
				var npc_index := int(raw_event.get("npc_index", -1))
				var style := str(state.ORACLE_OPPONENTS[npc_index]["style"])
				opening_actions += 1
				style_actions[style] = int(style_actions[style]) + 1
				if str(raw_event.get("action", "")) == "fold":
					opening_folds += 1
					folded_npcs += 1
					style_folds[style] = int(style_folds[style]) + 1
			if folded_npcs == 5:
				all_npc_fold_hands += 1
			while not bool(state.poker.get("completed", false)):
				state.poker_action("call")
			completed_hands += 1
			if not state.poker_session_active:
				break
	var fold_rate := float(opening_folds) / maxf(1.0, float(opening_actions))
	var reef_rate := float(style_folds["礁石型"]) / maxf(1.0, float(style_actions["礁石型"]))
	var tide_rate := float(style_folds["潮汐型"]) / maxf(1.0, float(style_actions["潮汐型"]))
	assert(completed_hands >= 250, "开局AI测试必须覆盖足够多的手牌")
	assert(fold_rate >= 0.15 and fold_rate <= 0.40, "无加契开局的NPC退契率应处于15%—40%的可玩区间")
	assert(reef_rate > tide_rate, "礁石型应比潮汐型更谨慎，但不能让全桌普遍退契")
	assert(float(all_npc_fold_hands) / float(completed_hands) < 0.03, "无人施压时五名NPC全部退契不应成为常见结果")
	print("POKER OPENING AI PASS: %d hands, fold %.1f%%, reef %.1f%%, tide %.1f%%" % [completed_hands, fold_rate * 100.0, reef_rate * 100.0, tide_rate * 100.0])
	quit(0)
