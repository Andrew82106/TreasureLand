extends SceneTree

const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scene = MainScene.instantiate()
	scene.title_save_override_enabled = true
	root.add_child(scene)
	await process_frame
	await process_frame
	for size_value in [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = size_value
		await _settle_frames()
		assert(_save_snapshot(output_dir.path_join("title_%dx%d.png" % [size_value.x, size_value.y])) == OK, "Title snapshot must be writable.")
	scene._start_new_game()
	for size_value in [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = size_value
		await _settle_frames()
		assert(_save_snapshot(output_dir.path_join("tutorial_%dx%d.png" % [size_value.x, size_value.y])) == OK, "Tutorial snapshot must be writable.")
	scene.game.known_npcs["granny"] = true
	scene.game.npc_request_states["granny"] = {"state": "active", "accepted_day": 1, "completed_day": 0}
	for size_value in [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = size_value
		scene._open_map()
		await _settle_frames()
		assert(_save_snapshot(output_dir.path_join("map_guidance_%dx%d.png" % [size_value.x, size_value.y])) == OK, "Map guidance snapshot must be writable.")
	root.size = Vector2i(1280, 720)
	scene._open_shop()
	await _settle_frames()
	assert(_save_snapshot(output_dir.path_join("shop_schedule_1280x720.png")) == OK, "Shop schedule snapshot must be writable.")
	print("TITLE TUTORIAL SNAPSHOT PASS")
	quit(0)


func _settle_frames() -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw


func _save_snapshot(path: String) -> Error:
	var texture = root.get_texture()
	if texture == null:
		return ERR_UNAVAILABLE
	var image = texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)
