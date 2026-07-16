extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const WorldLayoutScript := preload("res://scripts/world_layout.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.35).timeout
	if not _save("world_morning_driftwood_1280x720.png"):
		quit(1)
		return

	scene.player.global_position = Vector2(1810, 850)
	scene.current_area = "椰影街"
	scene.game.tide = 14
	scene.game.weather = "晴"
	scene._refresh_hud()
	await create_timer(0.75).timeout
	if not _save("world_night_coconut_1280x720.png"):
		quit(1)
		return

	scene.discovered_areas = {"漂流湾": true, "椰影街": true, "逐风海岸": true}
	scene._open_map()
	await process_frame
	await create_timer(0.25).timeout
	if not _save("world_map_overview_1280x720.png"):
		quit(1)
		return

	scene.free()
	print("WORLD VISUAL QA PASS")
	quit(0)


func _save(file_name: String) -> bool:
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Visual QA needs a rendering display driver.")
		return false
	var image := viewport_texture.get_image()
	if image == null:
		push_error("Visual QA display driver returned no image.")
		return false
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	return image.save_png(output_dir.path_join(file_name)) == OK
