extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_six_hand_tutorial()
	_test_short_full_time_and_determinism()
	_test_invitations_social_summary_and_save()
	await _test_session_ui()
	print("POKER SESSION FLOW TEST PASS")
	quit(0)


func _state():
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.poker_test_passive_ai = true
	return state


func _test_six_hand_tutorial() -> void:
	var state = _state()
	var cash_before := int(state.cash)
	var tide_before := int(state.tide)
	state.begin_poker_session(80)
	assert(state.poker_session_tutorial and state.poker_session_mode == "tutorial", "首次80桌必须进入六手教学场次。")
	assert(state.poker_hand_limit() == 15 and state.poker_tutorial_balance == 100, "教学必须使用独立100金贝额度和每手15金贝上限。")
	var expected_patterns := {2: "回响", 3: "轮转", 4: "既济", 6: "双镜"}
	for step in range(1, 7):
		var start: Dictionary = state.start_poker_hand()
		assert(bool(start.get("ok", false)), "六手教学的每一步都必须可以开始：%d" % step)
		var lesson: Dictionary = state.poker.get("tutorial_lesson", {})
		assert(int(lesson.get("step", 0)) == step and not str(lesson.get("objective", "")).is_empty(), "每手必须绑定独立教学目标。")
		assert(int(state.poker.get("buy_in", 0)) == 15, "教学每手风险上限必须固定为15金贝。")
		if expected_patterns.has(step):
			var reading: Dictionary = state.oracle_best_reading(state.poker["player_hand"], state.poker["community"].slice(0, 2))
			assert(str(reading.get("name", "")) == str(expected_patterns[step]), "固定教学牌序必须真实展示%s。" % str(expected_patterns[step]))
		var completed: Dictionary = state.poker_action("fold")
		assert(bool(completed.get("completed", false)) and bool(state.poker.get("completed", false)), "退契后其余席位必须透明完成教学手牌。")
	assert(not state.poker_session_active and state.poker_completed, "第六手后必须完成教学并关闭场次。")
	assert(not state.normal_poker_completed, "完成教学不能伪装成已经完成正常牌会。")
	assert(state.cash == cash_before, "教学全程退契的亏损不能触及原有钱包。")
	assert(state.tide == tide_before + 2, "六手教学整场只能统一推进2潮刻。")
	assert(state.poker_session_history.size() == 1, "教学结束必须形成整场摘要。")
	var summary: Dictionary = state.poker_session_history[0]
	assert(int(summary.get("hands", 0)) == 6 and bool(summary.get("tutorial_completed", false)), "教学摘要必须记录六手完成状态。")
	assert(state.poker_invitation_rows().any(func(invitation): return str(invitation.get("host_id", "")) == "old_joe"), "教学完成后必须生成后续人物牌会邀请。")


func _test_short_full_time_and_determinism() -> void:
	var first = _state()
	var second = _state()
	for state in [first, second]:
		state.poker_completed = true
		state.cash = 1000
		state.begin_poker_session(80, "short")
		state.start_poker_hand()
	assert(first.poker_session_seed == second.poker_session_seed, "同一日、同一场次序号和模式必须得到相同牌会种子。")
	assert(first.poker["player_hand"] == second.poker["player_hand"] and first.poker["community"] == second.poker["community"], "活动前存档重进同一场次不得重掷命牌或天象。")
	first.poker_action("fold")
	second.poker_action("fold")
	var short_tide := int(first.tide)
	first.end_poker_session()
	assert(first.tide == short_tide + 2 and str(first.poker_session_history[0]["mode"]) == "short", "短牌会手动离桌也必须统一推进2潮刻。")

	var full = _state()
	full.poker_completed = true
	full.cash = 1000
	var full_tide := int(full.tide)
	full.begin_poker_session(80, "full")
	assert(full.poker_session_max_hands() == 16 and full.poker_session_time_cost() == 4, "完整牌会必须提供16手上限与4潮刻成本。")
	full.start_poker_hand()
	full.poker_action("fold")
	full.end_poker_session()
	assert(full.tide == full_tide + 4 and str(full.poker_session_history[0]["mode"]) == "full", "完整牌会离桌必须统一推进4潮刻。")


func _test_invitations_social_summary_and_save() -> void:
	var state = _state()
	state.poker_completed = true
	state.normal_poker_completed = true
	state.cash = 1000
	state.tide = 9
	state._initialize_poker_invitations()
	var old_joe_invitation: Dictionary = {}
	for raw_invitation in state.poker_invitation_rows("old_joe"):
		if bool(raw_invitation.get("available", false)):
			old_joe_invitation = raw_invitation
	assert(not old_joe_invitation.is_empty(), "傍晚必须能够接受老乔的短牌会邀请。")
	var relation_before := int(state.relationships["old_joe"])
	state.begin_poker_session(80, "short", str(old_joe_invitation["id"]))
	state.poker_session_hands = 7
	state.start_poker_hand()
	state.poker_action("fold")
	assert(not state.poker_session_active, "邀请短牌会的第8手必须自动结束整场。")
	var summary: Dictionary = state.latest_poker_session_summary()
	assert(bool(summary.get("completed_mode", false)) and str(summary.get("host_id", "")) == "old_joe", "整场摘要必须保存邀请人和完成状态。")
	assert(state.relationships["old_joe"] == relation_before + 1, "完成邀请必须形成一次人物关系反馈。")
	assert("完成短牌会" in state.poker_rumor_summary(), "整场结果必须生成可供晨报和NPC读取的完成传闻。")
	var used_invitation: Dictionary = state.poker_invitation_rows("old_joe")[0]
	assert(not bool(used_invitation.get("available", true)) and str(used_invitation.get("status", "")) == "今日已完成", "同一人物邀请每日只能完成一次，不能重复刷取关系。")

	var saved := state.build_save_data({})
	assert(int(saved.get("version", 0)) == 6, "牌会场次历史与邀请必须随版本6存档保留。")
	var restored = _state()
	assert(bool(restored.restore_save_data(saved).get("ok", false)), "版本6牌会进程必须可读取。")
	assert(restored.poker_session_history == state.poker_session_history, "整场摘要、邀请来源和行为统计必须跨存档保留。")
	assert(str(restored.poker_invitation_rows("old_joe")[0].get("status", "")) == "今日已完成", "邀请的一日一次状态必须由场次历史跨存档恢复。")

	var early = _state()
	early.poker_completed = true
	early.cash = 1000
	early.begin_poker_session(80, "short")
	early.start_poker_hand()
	early.poker_action("fold")
	early.end_poker_session()
	assert("离开了短牌会" in early.poker_rumor_summary(), "未达到场次手数上限时，传闻必须明确写成离开而不是完成。")


func _test_session_ui() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene._open_poker()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "六手命象教学") and _tree_contains_text(scene.modal_body, "独立100金贝额度"), "首次牌会页面必须明确展示完整六手教学，而非直接丢进普通桌。")
	var tutorial_id := str(scene.game.poker_invitation_rows()[0]["id"])
	scene._accept_poker_invitation(tutorial_id)
	await process_frame
	assert(scene.poker_table.visible and scene.game.poker_session_tutorial, "接受教学邀请必须进入独立牌桌。")
	scene.game.start_poker_hand()
	scene.poker_table._refresh()
	assert(_tree_contains_text(scene.poker_table.right_box, "教学 1/6") and _tree_contains_text(scene.poker_table.right_box, "两张命牌必须使用"), "牌桌右栏必须显示当前教学目标与提示。")
	scene.game.poker_action("fold")
	scene.game.end_poker_session()
	scene.poker_table.visible = false
	scene.game.poker_completed = true
	scene.game.normal_poker_completed = true
	scene.game.cash = 5000
	scene.game.tide = 13
	scene.game._initialize_poker_invitations()
	scene._open_poker()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "短牌会 · 8手 / 2潮刻") and _tree_contains_text(scene.modal_body, "完整牌会 · 16手 / 4潮刻"), "正常牌会入口必须让玩家明确选择短场或完整场。")
	assert(_tree_contains_text(scene.modal_body, "米洛") and _tree_contains_text(scene.modal_body, "当前可接受"), "夜晚满足资格时必须显示米洛完整牌会邀请。")
	scene._open_npc("milo")
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "牌会邀请") and _find_button(scene.modal_body, "接受邀请") != null, "人物页必须能直接接受当前牌会邀请。")
	scene.free()
	var activity_path := "user://saves/activity_poker.json"
	if FileAccess.file_exists(activity_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(activity_path))


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
