extends SceneTree

const MainScene := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var scene = MainScene.instantiate()
	scene.title_screen_enabled = false
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.game.cash = 6480
	scene.game.home_level = 2
	for item_id in ["water", "fire", "earth", "steam", "mud", "cloud", "rain", "river", "water_jar"]:
		scene.game.discovered[item_id] = true
	scene.game.home_display_items.assign(["steam", "cloud", "water_jar"])
	scene.game.home_aquarium = [{
		"catch_id": "snapshot_moon_ray",
		"species_id": "moon_ray",
		"size": "纪录级",
		"caught_day": 3,
		"caught_tide": 12,
		"source_area": "wreck_edge",
		"caught_weather": "晴",
	}]
	scene.game.fish_catch_inventory = [{
		"catch_id": "snapshot_lantern",
		"species_id": "coral_lantern",
		"size": "大型",
		"caught_day": 4,
		"caught_tide": 3,
		"source_area": "coral_shelf",
		"caught_weather": "阵雨",
	}]
	scene.game.known_npcs["old_joe"] = true
	scene.game.relationships["old_joe"] = 24

	for size_value in [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = size_value
		scene._open_home()
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var path := output_dir.path_join("home_%dx%d.png" % [size_value.x, size_value.y])
		assert(_save_snapshot(path) == OK, "Home snapshot must be writable at %s." % str(size_value))

	root.size = Vector2i(1280, 720)
	scene._open_tower()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(_save_snapshot(output_dir.path_join("finale_progress_1280x720.png")) == OK, "Finale progress snapshot must be writable.")
	print("HOME FINALE SNAPSHOT PASS")
	quit(0)


func _save_snapshot(path: String) -> Error:
	var viewport_texture = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	var image = viewport_texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)
