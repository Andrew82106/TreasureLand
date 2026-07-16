extends SceneTree

const MainScene := preload("res://main.tscn")
const NpcCatalogScript := preload("res://scripts/npc_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame

	assert(scene.get_node("ResidentVisuals").get_child_count() == NpcCatalogScript.RESIDENTS.size(), "全部环境居民必须生成可见世界占位形象。")
	for raw_profile in NpcCatalogScript.RESIDENTS:
		var profile: Dictionary = raw_profile
		assert(scene.marker_by_id.has(str(profile["id"])), "每名环境居民必须有可交互世界标记。")

	scene._open_npc("granny")
	await process_frame
	assert(scene.modal_overlay.visible, "核心NPC必须打开统一人物界面。")
	for button_text in ["交谈", "询问话题", "查看委托", "展示万物 / 鱼获", "深入交谈 · 0.5—1潮刻"]:
		assert(_find_button(scene.modal_body, button_text) != null, "统一人物界面缺少操作：%s" % button_text)
	assert(_tree_contains_text(scene.modal_body, "当前位置：漂流湾造化盆"), "人物页必须显示当前日程位置。")
	assert(bool(scene.game.known_npcs.get("granny", false)), "与人物交互后必须写入认识状态。")

	var granny_marker = scene.marker_by_id["granny"]
	var dawn_position: Vector2 = granny_marker.position
	scene.game.tide = 5
	scene._apply_npc_schedule()
	assert(granny_marker.position != dawn_position, "跨时段后核心NPC世界标记必须移动。")
	assert(str(scene.game.npc_location("granny")) == "椰影茶摊", "人物页、地图与世界必须读取同一份日程。")
	assert(scene.npc_visual_by_id["granny"].visible and scene.npc_visual_by_id["granny"].position != Vector2(918, 555), "NPC像素形象必须与标记一起移动。")

	scene._open_npc("mia")
	await process_frame
	assert(bool(scene.game.known_npcs.get("mia", false)), "第二名人物也必须进入已认识集合。")
	assert(scene.game.npc_map_entries().size() == 2, "地图人物数据只能包含已经认识的核心NPC。")
	scene._open_map()
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "已认识人物"), "地图必须提供已认识人物区域列表。")
	assert(_tree_contains_text(scene.modal_body, "榕奶奶") and _tree_contains_text(scene.modal_body, "米娅"), "地图人物列表必须展示已认识角色。")

	scene.game.tide = 13
	scene._apply_npc_schedule()
	assert(not scene.marker_by_id["shopkeeper"].visible, "阿拓夜间离店时人物标记必须隐藏。")
	assert(scene.marker_by_id["shop"].visible, "阿拓离店时公共研究商店入口必须继续开放。")

	scene.game.tide = 1
	scene._apply_npc_schedule()
	var fisher = scene.marker_by_id["resident_fisher"]
	assert(fisher.visible and fisher.position != Vector2.ZERO, "环境居民必须按时段出现在实际世界坐标。")
	scene._open_resident("resident_fisher")
	await process_frame
	assert(_tree_contains_text(scene.modal_body, "不会写入长期记忆"), "环境居民界面必须说明其不建立独立关系线。")

	scene.free()
	print("NPC SOCIAL UI TEST PASS")
	quit(0)


func _find_button(node: Node, text_value: String) -> Button:
	if node is Button and (node as Button).text == text_value:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text_value)
		if found != null:
			return found
	return null


func _tree_contains_text(node: Node, needle: String) -> bool:
	if node is Label and needle in (node as Label).text:
		return true
	if node is Button and needle in (node as Button).text:
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
