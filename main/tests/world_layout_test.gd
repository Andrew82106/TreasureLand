extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const WorldLayoutScript := preload("res://scripts/world_layout.gd")
const GroundMap := preload("res://assets/art/environments/world_map_v2/island_ground_map_v2.png")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(GroundMap.get_width() == int(WorldLayoutScript.WORLD_SIZE.x), "Ground-map width must match the coordinate contract.")
	assert(GroundMap.get_height() == int(WorldLayoutScript.WORLD_SIZE.y), "Ground-map height must match the coordinate contract.")
	for definition in WorldLayoutScript.MARKERS:
		var marker_position: Vector2 = definition["position"]
		assert(WorldLayoutScript.WORLD_RECT.has_point(marker_position), "Marker must remain inside the ground map: %s" % definition["id"])
		assert(WorldLayoutScript.area_for_position(marker_position) == str(definition["area"]), "Marker region must match its painted submap: %s" % definition["id"])

	root.size = Vector2i(1280, 720)
	var scene = MAIN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var player_animator: PixelCharacterAnimator = scene.get_node("Player/PixelCharacterAnimator")
	assert(not player_animator.is_using_placeholder(), "Player must use the production atlas.")
	assert(scene.get_node("NPCVisuals").get_child_count() == WorldLayoutScript.NPC_VISUALS.size(), "Every configured NPC must be instantiated.")
	for holder in scene.get_node("NPCVisuals").get_children():
		var animator: PixelCharacterAnimator = holder.get_node("PixelCharacterAnimator")
		assert(not animator.is_using_placeholder(), "NPC must not fall back to the blue placeholder: %s" % holder.name)
		assert(animator.atlas_texture.get_width() == 384 and animator.atlas_texture.get_height() == 512, "NPC world atlas must satisfy the 48x64 8x8 contract: %s" % holder.name)
	assert(scene.get_node("World/GeneratedCollision").get_child_count() == WorldLayoutScript.BLOCKERS.size(), "Every configured map blocker must be instantiated.")

	var lighting: WorldLighting = scene.get_node("WorldLighting")
	lighting.set_environment("夜晚", "晴", true)
	assert(lighting.canvas_modulate.color.is_equal_approx(Color("526989")), "Night must visibly grade the ground map.")
	for lantern in lighting.lanterns:
		assert(lantern.enabled and lantern.energy > 1.0, "Night must enable landmark lantern light.")

	var player: CharacterBody2D = scene.get_node("Player")
	player.global_position = WorldLayoutScript.spawn_for_area("逐风海岸")
	scene._update_area_discovery()
	assert(scene.current_area == "逐风海岸", "Area discovery must use the shared large-map coordinates.")
	assert(scene.discovered_areas.has("逐风海岸"), "Walking into a region must unlock its fast travel.")
	scene.free()
	print("WORLD LAYOUT TEST PASS")
	quit(0)
