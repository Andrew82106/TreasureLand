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
	scene.game.cash = 680
	scene.game._record_wealth("完成榕奶奶委托")
	scene.game.buy_dive_equipment_upgrade("oxygen")
	scene.game.buy_dive_equipment_upgrade("fins")
	scene.game.relationships["mia"] = 18
	scene.game.fish_catch_inventory = [
		{"catch_id": "snapshot_silver", "species_id": "silverfin", "size": "大型", "size_score": 0.87, "caught_day": 1, "caught_tide": 2, "source_area": "sand_shallows"},
		{"catch_id": "snapshot_lantern", "species_id": "coral_lantern", "size": "纪录级", "size_score": 0.98, "caught_day": 1, "caught_tide": 2, "source_area": "coral_shelf"}
	]
	scene.game._record_wealth("海岸潜捕 · 上岸")

	for size_value in [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = size_value
		if scene.dive_table.visible:
			scene.dive_table.request_close()
			await process_frame
		scene._open_wealth()
		await _settle_frames()
		assert(_save_snapshot(output_dir.path_join("economy_%dx%d.png" % [size_value.x, size_value.y])) == OK, "Economy snapshot must be writable.")
		scene._open_dive("equipment")
		await _settle_frames()
		assert(_save_snapshot(output_dir.path_join("equipment_%dx%d.png" % [size_value.x, size_value.y])) == OK, "Equipment snapshot must be writable.")

	root.size = Vector2i(1280, 720)
	scene._open_dive("market")
	await _settle_frames()
	assert(_save_snapshot(output_dir.path_join("special_orders_1280x720.png")) == OK, "Special order snapshot must be writable.")
	print("ECONOMY EQUIPMENT SNAPSHOT PASS")
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
