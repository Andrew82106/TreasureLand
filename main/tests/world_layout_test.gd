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
	scene.title_screen_enabled = false
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
	for marker_id in ["road_sign", "lifestyle", "square", "race", "race_ticket", "race_stand", "stable", "vip_terrace"]:
		assert(scene.marker_by_id.has(marker_id), "首版规格中的公共兴趣点必须拥有可达地图入口：%s" % marker_id)
	var port: Dictionary = scene.game.port_economy_snapshot
	var port_visuals: Node2D = scene.port_activity_root
	assert(_activity_count(port_visuals, "ship") == int(port["arrivals"]), "地图船只数量必须直接读取当日到港批次。")
	assert(_activity_count(port_visuals, "crowd") == clampi(int(ceil(float(port["visitors"]) / 8.0)), 2, 8), "椰影街人流必须直接读取当日流动人口。")
	assert(_activity_count(port_visuals, "race_crowd") == clampi(int(ceil(float(port["visitors"]) / 15.0)), 1, 4), "逐风看台人流必须与同一港口快照同步。")
	scene._open_lifestyle_display()
	assert(_tree_contains_text(scene.modal_body, "首版不售卖衣服"), "生活陈列店不得重新引入已取消的服装售卖。")
	scene._open_public_square()
	assert(_tree_contains_text(scene.modal_body, "常住%d人" % int(port["residents"])) and _tree_contains_text(scene.modal_body, "到港%d批" % int(port["arrivals"])), "公共广场必须显示同一港口快照。")
	scene._open_stable()
	assert(_tree_contains_text(scene.modal_body, "前往逐风赛场"), "马厩与骑师区必须提供共享赛事状态入口。")
	scene._open_vip_terrace()
	assert(_tree_contains_text(scene.modal_body, "首版保持锁定"), "贵宾露台必须可见但在首版明确锁定。")

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


func _activity_count(root_node: Node, kind: String) -> int:
	var count := 0
	for child in root_node.get_children():
		if str(child.get_meta("economy_kind", "")) == kind:
			count += 1
	return count


func _tree_contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and needle in str(node.text):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
