extends SceneTree

const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	scene.title_screen_enabled = false
	root.add_child(scene)
	await process_frame
	await process_frame
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)

	scene._open_poker()
	await process_frame
	assert(_save_snapshot(output_dir.path_join("poker_tutorial_entry_1280x720.png")) == OK, "Tutorial entry snapshot must be writable.")

	var tutorial_id := str(scene.game.poker_invitation_rows()[0]["id"])
	scene._accept_poker_invitation(tutorial_id)
	scene.poker_table.animations_enabled = false
	scene.game.start_poker_hand()
	scene.poker_table._refresh()
	await process_frame
	await process_frame
	assert(_save_snapshot(output_dir.path_join("poker_tutorial_table_1280x720.png")) == OK, "Tutorial table snapshot must be writable.")

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
	await process_frame
	assert(_save_snapshot(output_dir.path_join("poker_session_modes_1280x720.png")) == OK, "Poker session modes snapshot must be writable.")

	var activity_path := "user://saves/activity_poker.json"
	if FileAccess.file_exists(activity_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(activity_path))
	print("POKER SESSION SNAPSHOT PASS")
	quit(0)


func _save_snapshot(path: String) -> Error:
	var viewport_texture = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	var image = viewport_texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)
