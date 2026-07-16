extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.9).timeout
	var old_qiao := scene.get_node("NPCVisuals/old_joe")
	var animator: PixelCharacterAnimator = old_qiao.get_node("PixelCharacterAnimator")
	assert(not animator.is_using_placeholder(), "The in-world Lao Qiao must use the production atlas.")
	assert(animator.sprite.animation == &"idle_down", "The stationary Lao Qiao must retain the configured facing.")
	var player_animator: PixelCharacterAnimator = scene.get_node("Player/PixelCharacterAnimator")
	assert(not player_animator.is_using_placeholder(), "The player must use the new production atlas, not the blue placeholder.")
	assert(scene.get_node("World").get_script() != null, "The large ground map renderer must be present.")
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("The selected display driver does not expose a viewport texture; run this visual test with a rendering display driver, not Dummy/headless.")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("The rendering display driver returned no image for the world snapshot.")
		quit(1)
		return
	assert(image.save_png(output_dir.path_join("world_old_qiao_1280x720.png")) == OK, "The world visual snapshot must be writable.")
	print("WORLD PIXEL SNAPSHOT PASS")
	quit(0)
