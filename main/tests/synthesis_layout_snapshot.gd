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
	table._select_item("left", "water")
	table._select_item("right", "fire")
	await process_frame
	table.action_button.pressed.emit()
	await create_timer(0.50).timeout
	await process_frame
	await process_frame
	assert(table.busy and _tree_contains_name(table.motion_layer, "RelationshipMotion"), "The relationship effect must be visible during a real synthesis presentation.")
	if _save_snapshot(output_dir.path_join("synthesis_relation_motion_1280x720.png")) != OK:
		push_error("The synthesis motion snapshot must be writable with an active rendering driver.")
		quit(1)
		return
	for _attempt in range(180):
		if not table.busy:
			break
		await process_frame
	assert(not table.busy, "The synthesis presentation must finish before opening the graph overlay.")
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


func _tree_contains_name(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _tree_contains_name(child, node_name):
			return true
	return false
