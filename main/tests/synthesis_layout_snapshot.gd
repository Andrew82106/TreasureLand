extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const SynthesisTableScript := preload("res://scripts/synthesis_table.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1280, 720)
	var state = GameStateScript.new()
	state.recording_enabled = false
	var table = SynthesisTableScript.new()
	table.setup(state)
	root.add_child(table)
	table.open()
	await process_frame
	await process_frame
	assert(table.page_root.size.round() == Vector2(1280, 720), "The synthesis page must cover the full baseline viewport.")
	assert(table.center_stage != null and not _tree_contains_class(table.center_stage, "ScrollContainer"), "The central basin stage must remain fixed.")
	assert(table.left_library != null and table.right_library != null, "Both permanent discovery libraries must exist.")
	if _save_snapshot(output_dir.path_join("synthesis_fullscreen_1280x720.png")) != OK:
		push_error("The synthesis snapshot must be writable with an active rendering driver.")
		quit(1)
		return
	table._show_graph()
	await process_frame
	await process_frame
	assert(table.graph_overlay.visible, "The four-tier graph overlay must open.")
	if _save_snapshot(output_dir.path_join("synthesis_graph_1280x720.png")) != OK:
		push_error("The graph snapshot must be writable with an active rendering driver.")
		quit(1)
		return
	print("SYNTHESIS LAYOUT SNAPSHOT PASS")
	quit(0)


func _save_snapshot(path: String) -> Error:
	var viewport_texture = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	var image = viewport_texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)


func _tree_contains_class(node: Node, class_name_value: String) -> bool:
	if node.is_class(class_name_value):
		return true
	for child in node.get_children():
		if _tree_contains_class(child, class_name_value):
			return true
	return false
