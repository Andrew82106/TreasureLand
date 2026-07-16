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

	scene.game.cash = 25000
	scene._open_share_market()
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(_save_snapshot(output_dir.path_join("share_market_open_1280x720.png")) == OK, "Open market snapshot must be writable.")

	scene._trade_shares("bluefin", "buy", 5)
	for frame in range(3):
		await process_frame
	scene.game.tide = 11
	scene._open_share_market()
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(_save_snapshot(output_dir.path_join("share_market_closed_1280x720.png")) == OK, "Closed market snapshot must be writable.")

	print("SHARE MARKET SNAPSHOT PASS")
	quit(0)


func _save_snapshot(path: String) -> Error:
	var viewport_texture = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	var image = viewport_texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)
