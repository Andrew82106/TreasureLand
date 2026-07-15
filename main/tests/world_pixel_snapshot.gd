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
	var old_qiao := scene.get_node("World/OldQiaoSample")
	var animator: PixelCharacterAnimator = old_qiao.get_node("PixelCharacterAnimator")
	assert(not animator.is_using_placeholder(), "The in-world Lao Qiao sample must use the production atlas.")
	assert(animator.sprite.animation in [&"idle_left", &"walk_left", &"idle_right", &"walk_right"], "The sample must visibly alternate between idle and walking.")
	var output_dir := ProjectSettings.globalize_path("res://tests/artifacts")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := root.get_texture().get_image()
	assert(image.save_png(output_dir.path_join("world_old_qiao_1280x720.png")) == OK, "The world visual snapshot must be writable.")
	print("WORLD PIXEL SNAPSHOT PASS")
	quit(0)
