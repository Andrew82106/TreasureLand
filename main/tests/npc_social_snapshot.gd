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

	scene._open_npc("granny")
	await process_frame
	await process_frame
	assert(_save_snapshot(output_dir.path_join("npc_profile_1280x720.png")) == OK, "NPC profile snapshot must be writable.")

	scene._open_map()
	await process_frame
	await process_frame
	assert(_save_snapshot(output_dir.path_join("npc_map_tracking_1280x720.png")) == OK, "NPC map snapshot must be writable.")

	print("NPC SOCIAL SNAPSHOT PASS")
	quit(0)


func _save_snapshot(path: String) -> Error:
	var viewport_texture = root.get_texture()
	if viewport_texture == null:
		return ERR_UNAVAILABLE
	var image = viewport_texture.get_image()
	if image == null:
		return ERR_UNAVAILABLE
	return image.save_png(path)
