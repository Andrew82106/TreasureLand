extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const PokerTableScript := preload("res://scripts/poker_table.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1672, 938),
		Vector2i(1920, 1080),
	]:
		root.size = viewport_size
		var state = GameStateScript.new()
		state.recording_enabled = false
		state.start_poker_hand()
		var table = PokerTableScript.new()
		table.animations_enabled = true
		table.setup(state)
		root.add_child(table)
		table.open()
		table.thinking_index = 0
		table.action_overrides[0] = "思考中……"
		table.speech_bubbles[0] = "潮声急不得，我再看一眼。"
		table._refresh()
		await process_frame
		await process_frame
		assert(table.center_stage != null, "The fixed table stage must exist.")
		assert(not _tree_contains_class(table.center_stage, "ScrollContainer"), "The fixed table stage must never scroll.")
		for slot in table.opponent_slots + [table.board_slot, table.player_slot]:
			assert(Rect2(Vector2.ZERO, table.center_stage.size).encloses(Rect2(slot.position, slot.size)), "Every seat and board slot must remain inside the table stage.")
		var image := root.get_texture().get_image()
		var file_name := "poker_fixed_stage_%dx%d.png" % [viewport_size.x, viewport_size.y]
		assert(image.save_png(output_dir.path_join(file_name)) == OK, "The visual snapshot must be writable.")
		table.free()
		await process_frame
	print("POKER LAYOUT SNAPSHOT PASS")
	quit(0)


func _tree_contains_class(node: Node, class_name_value: String) -> bool:
	if node.is_class(class_name_value):
		return true
	for child in node.get_children():
		if _tree_contains_class(child, class_name_value):
			return true
	return false
