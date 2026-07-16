extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const PokerTableScript = preload("res://scripts/poker_table.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.poker_completed = true
	state.rng.seed = 20260715
	state.start_poker_hand()
	var table = PokerTableScript.new()
	table.setup(state)
	root.add_child(table)
	table.open()
	table.animation_speed_scale = 4.0
	assert(table.motion_layer != null and table.motion_layer.name == "TableMotionLayer", "牌桌必须提供独立表现层承载发牌、金贝和结算代理")
	assert(table._shell_proxy_count(1) == 1 and table._shell_proxy_count(8) == 3 and table._shell_proxy_count(80) == 7, "金贝数量必须映射为可读而有上限的动画代理")
	assert(table._community_count_for_stage("初兆") == 2 and table._community_count_for_stage("交汇") == 4 and table._community_count_for_stage("定命") == 5, "牌局阶段必须映射为2、4、5张公共牌的揭示节奏")
	var active_before: Array = [false, true, true, true, true]
	var stacks_before: Array = [80, 80, 0, 80, 80]
	var eligible: Array[int] = table._eligible_opponent_animation_order(active_before, stacks_before)
	assert(not eligible.has(0), "已经退契的NPC不能再次进入思考队列")
	assert(not eligible.has(2), "已经全投的NPC不能再次进入思考队列")
	assert(table._npc_think_delay(3, "静观") > table._npc_think_delay(1, "静观"), "榕奶奶的礁石型人格必须具有更长思考时间")
	assert(table._npc_think_delay(4, "静观") > table._npc_think_delay(2, "静观"), "旅人洛沙必须保持海雾型中最慢的思考节奏")
	assert(table._signed_amount(0) == "0" and table._signed_amount(5) == "+5" and table._signed_amount(-5) == "-5", "金额符号必须正确区分正数、零和负数")
	var action_button := _find_call_button(table)
	assert(action_button != null, "牌桌必须提供真实可触发的跟契或静观按钮")
	action_button.pressed.emit()
	await process_frame
	await create_timer(0.03).timeout
	assert(table.animation_busy and table.motion_layer.get_child_count() > 0, "真实行动按钮信号必须先启动玩家金贝或座位反馈")
	var saw_thinking := false
	for _attempt in range(80):
		if table.thinking_index >= 0:
			saw_thinking = true
			assert(table.speech_bubbles[table.thinking_index].is_empty(), "思考阶段只能播放动作，不能提前说一遍对白")
			break
		await create_timer(0.03).timeout
	assert(saw_thinking, "NPC行动必须进入逐席思考演出")
	for _attempt in range(200):
		if not table.animation_busy:
			break
		await create_timer(0.03).timeout
	assert(not table.animation_busy and table.thinking_index == -1, "逐席演出结束后必须恢复玩家操作")
	table.free()
	print("POKER ANIMATION TEST PASS: signal, motion layer, shell flow, pause, speech and action sequence")
	quit(0)


func _find_call_button(node: Node) -> Button:
	if node is Button:
		var button := node as Button
		if button.text == "静观" or button.text.begins_with("跟契"):
			return button
	for child in node.get_children():
		var found := _find_call_button(child)
		if found != null:
			return found
	return null
