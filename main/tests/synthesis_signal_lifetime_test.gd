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

	# The production crash occurred after Tween.finished resumed _submit(). Run
	# real presentations at high speed so the test also covers that native signal
	# lifetime instead of only the no-animation shortcut.
	table.animations_enabled = true
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
