extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const SynthesisTableScript := preload("res://scripts/synthesis_table.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var state = GameStateScript.new()
	state.recording_enabled = false
	state.cash = 10000
	var table = SynthesisTableScript.new()
	table.setup(state)
	table.animations_enabled = false
	root.add_child(table)
	table.open()
	await process_frame

	# These callbacks all replace the UI tree that owns the signal emitter.
	# Repeating real signal emissions catches immediate free()/rebuild regressions
	# that can otherwise crash Godot itself before a GDScript assertion runs.
	for attempt in range(30):
		var left_button := _find_button(table.left_library, "水")
		assert(left_button != null, "The left water selector must exist.")
		left_button.pressed.emit()
		await process_frame
		await process_frame

		var right_button := _find_button(table.right_library, "火")
		assert(right_button != null, "The right fire selector must exist.")
		right_button.pressed.emit()
		await process_frame
		await process_frame

		var submit_button: Button = table.action_button
		assert(submit_button != null and not submit_button.disabled, "A selected pair must be submittable.")
		submit_button.pressed.emit()
		await process_frame
		await process_frame
		await process_frame
		assert(not table.busy, "A no-animation synthesis must finish after its deferred rebuild.")
		assert(bool(table.last_result.get("ok", false)), "The synthesis result must survive rebuilding its emitter tree.")

	# Reproduce the player path at normal animation speed with a first discovery.
	# This is the path that previously replaced a Tween while its own finished
	# signal was still being emitted and could terminate Godot with signal 11.
	table.animations_enabled = true
	table.reduced_motion = false
	table.animation_speed_scale = 1.0
	var normal_left := _find_button(table.left_library, "水")
	assert(normal_left != null, "The normal-speed left selector must exist.")
	normal_left.pressed.emit()
	await process_frame
	await process_frame
	var normal_right := _find_button(table.right_library, "土")
	assert(normal_right != null, "The normal-speed right selector must exist.")
	normal_right.pressed.emit()
	await process_frame
	await process_frame
	table.action_button.pressed.emit()
	var normal_start_budget := 20
	while not table.busy and normal_start_budget > 0:
		await process_frame
		normal_start_budget -= 1
	assert(table.busy, "The normal-speed submit callback must start.")
	var normal_frame_budget := 360
	while table.busy and normal_frame_budget > 0:
		await process_frame
		normal_frame_budget -= 1
	assert(not table.busy and state.is_discovered("mud"), "A normal-speed first discovery must finish without releasing a Tween inside its own signal.")
	# A player commonly pauses after the result animation. The decorative pulse
	# has finished and its native Tween has been invalidated by this point; the
	# next selection must not touch a stale member reference.
	await create_timer(0.45).timeout
	var delayed_left := _find_button(table.left_library, "火")
	assert(delayed_left != null, "A selector must remain usable after an idle pause.")
	delayed_left.pressed.emit()
	await process_frame
	await process_frame
	assert(table.left_id == "fire", "A post-animation selection must rebuild safely.")

	# Keep a fast repeated stress section as protection against emitter-tree and
	# completed-Tween lifetime regressions that may only appear after many runs.
	table.reduced_motion = true
	table.animation_speed_scale = 40.0
	for attempt in range(8):
		var left_button := _find_button(table.left_library, "水")
		assert(left_button != null, "The animated left selector must exist.")
		left_button.pressed.emit()
		await process_frame
		await process_frame

		var right_button := _find_button(table.right_library, "火")
		assert(right_button != null, "The animated right selector must exist.")
		right_button.pressed.emit()
		await process_frame
		await process_frame

		var submit_button: Button = table.action_button
		assert(submit_button != null and not submit_button.disabled, "An animated selected pair must be submittable.")
		submit_button.pressed.emit()
		var start_budget := 20
		while not table.busy and start_budget > 0:
			await process_frame
			start_budget -= 1
		assert(table.busy, "The deferred animated submit callback must start.")
		var frame_budget := 180
		while table.busy and frame_budget > 0:
			await process_frame
			frame_budget -= 1
		assert(not table.busy, "An animated synthesis must finish within the frame budget.")
		await process_frame
		await process_frame
		assert(bool(table.last_result.get("ok", false)), "The animated result must survive its post-signal rebuild.")

	# Retired UI generations remain hidden for several frames so native signal
	# dispatch can unwind, but must still be collected instead of leaking forever.
	for frame in range(table.SIGNAL_RETIREMENT_FRAMES + 3):
		await process_frame
	assert(table.get_child_count() == 1, "Only the active synthesis page may remain after the retirement window.")

	print("SYNTHESIS SIGNAL LIFETIME TEST PASS")
	quit(0)


func _find_button(node: Node, item_name: String) -> Button:
	if node is Button:
		var button := node as Button
		if button.text.trim_prefix("✓ ") == item_name:
			return button
	for child in node.get_children():
		var found := _find_button(child, item_name)
		if found != null:
			return found
	return null
