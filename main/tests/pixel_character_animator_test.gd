extends SceneTree

const COMPONENT_SCENE := preload("res://scenes/components/pixel_character_animator.tscn")
const OLD_QIAO_ATLAS := preload("res://assets/art/characters/old_qiao/world/old_qiao_world_atlas_v1.png")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var component := COMPONENT_SCENE.instantiate()
	root.add_child(component)
	assert(component.is_using_placeholder(), "Missing production art must use the animated safe placeholder.")
	component.walk_frame_count = 4
	assert(component.set_atlas(OLD_QIAO_ATLAS), "The production Lao Qiao atlas must satisfy the 48x64 eight-row contract.")
	assert(not component.is_using_placeholder(), "The production atlas must replace the safe placeholder.")
	for animation_name in [
		&"idle_down", &"idle_left", &"idle_right", &"idle_up",
		&"walk_down", &"walk_left", &"walk_right", &"walk_up",
	]:
		assert(component.sprite.sprite_frames.has_animation(animation_name), "Every four-direction state must exist.")
	component.set_motion(Vector2.RIGHT)
	assert(component.sprite.animation == &"walk_right", "Moving right must select walk_right.")
	component.set_motion(Vector2.ZERO)
	assert(component.sprite.animation == &"idle_right", "Stopping must retain the last facing direction.")
	component.set_motion(Vector2.UP)
	assert(component.sprite.animation == &"walk_up", "Moving up must select walk_up.")
	component.free()
	print("PIXEL CHARACTER ANIMATOR TEST PASS")
	quit(0)
