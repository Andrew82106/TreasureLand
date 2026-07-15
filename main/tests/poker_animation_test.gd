extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const PokerTableScript = preload("res://scripts/poker_table.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.start_poker_hand()
	var table = PokerTableScript.new()
	table.setup(state)
	root.add_child(table)
	table.open()
	var active_before: Array = [false, true, true, true, true]
	var stacks_before: Array = [80, 80, 0, 80, 80]
	var eligible: Array[int] = table._eligible_opponent_animation_order(active_before, stacks_before)
	assert(not eligible.has(0), "已经退契的NPC不能再次进入思考队列")
	assert(not eligible.has(2), "已经全投的NPC不能再次进入思考队列")
	table._act("call")
	await create_timer(0.12).timeout
	assert(table.animation_busy and table.thinking_index >= 0, "NPC行动必须进入逐席思考演出")
	assert(table.speech_bubbles[table.thinking_index].is_empty(), "思考阶段只能播放动作，不能提前说一遍对白")
	await create_timer(8.0).timeout
	assert(not table.animation_busy and table.thinking_index == -1, "逐席演出结束后必须恢复玩家操作")
	table.free()
	print("POKER ANIMATION TEST PASS: portrait, pause, speech and action sequence")
	quit(0)
