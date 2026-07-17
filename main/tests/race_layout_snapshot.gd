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
	scene.game.cash = 1000
	scene.game.free_race_ticket = 0
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)

	scene._open_race()
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		assert(_save_snapshot(output_dir.path_join("race_pre_%dx%d.png" % [resolution.x, resolution.y])) == OK, "Race pre-race snapshot must be writable.")
	root.size = Vector2i(1280, 720)
	assert(_save_snapshot(output_dir.path_join("race_schedule_1280x720.png")) == OK, "Race schedule snapshot must be writable.")

	scene.race_arena.bet_spin.value = 100
	scene.race_arena._request_start()
	await create_timer(0.2).timeout
	assert(_save_snapshot(output_dir.path_join("race_replay_1280x720.png")) == OK, "Race replay snapshot must be writable.")
	for resolution in [Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		assert(_save_snapshot(output_dir.path_join("race_live_%dx%d.png" % [resolution.x, resolution.y])) == OK, "Race live snapshot must be writable.")

	scene.race_arena.replay.skip()
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		assert(_save_snapshot(output_dir.path_join("race_finish_%dx%d.png" % [resolution.x, resolution.y])) == OK, "Race finish snapshot must be writable.")
	root.size = Vector2i(1280, 720)
	scene._open_race_history_from_arena()
	await process_frame
	await process_frame
	assert(_save_snapshot(output_dir.path_join("race_history_1280x720.png")) == OK, "Race history snapshot must be writable.")

	var activity_path := "user://saves/activity_race.json"
	if FileAccess.file_exists(activity_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(activity_path))
	print("RACE LAYOUT SNAPSHOT PASS")
	quit(0)


func _save_snapshot(path: String) -> Error:
	var viewport_texture = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	var image = viewport_texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)
