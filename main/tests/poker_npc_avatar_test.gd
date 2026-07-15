extends SceneTree

const AvatarScript := preload("res://scripts/poker_npc_avatar.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var avatar = AvatarScript.new()
	avatar.setup(96.0)
	root.add_child(avatar)
	assert(avatar.sprite != null, "The seated pixel avatar must create an AnimatedSprite2D.")
	for animation_name in [
		&"table_idle", &"table_talk", &"table_think", &"table_call",
		&"table_raise", &"table_fold", &"table_win", &"table_lose",
	]:
		assert(avatar.sprite.sprite_frames.has_animation(animation_name), "Missing seated animation: %s" % animation_name)
		assert(avatar.sprite.sprite_frames.get_frame_count(animation_name) == 4, "Every seated sample action must contain four real frames.")
	avatar.play_for_action("思考中……", true, true)
	assert(avatar.current_animation() == &"table_think", "Thinking must use the drawn thinking frames.")
	avatar.play_for_action("加契8金贝", false, true)
	assert(avatar.current_animation() == &"table_raise", "Raising must use the drawn raise frames.")
	avatar.play_for_action("退契", false, true)
	assert(avatar.current_animation() == &"table_fold", "Folding must use the drawn fold frames.")
	avatar.play_for_action("赢得底池", false, true)
	assert(avatar.current_animation() == &"table_win", "Winning must use the drawn win frames.")
	avatar.free()
	print("POKER NPC AVATAR TEST PASS")
	quit(0)
