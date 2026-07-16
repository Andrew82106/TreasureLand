class_name IslandMapOverview
extends Control

const WorldLayoutScript = preload("res://scripts/world_layout.gd")

var map_texture: Texture2D
var discovered_areas: Dictionary = {}
var player_position := Vector2.ZERO
var npc_entries: Array = []
var quest_entries: Array = []


func setup(texture_value: Texture2D, discovered_value: Dictionary, player_value: Vector2, npc_value: Array = [], quest_value: Array = []) -> void:
	map_texture = texture_value
	discovered_areas = discovered_value.duplicate()
	player_position = player_value
	npc_entries = npc_value.duplicate(true)
	quest_entries = quest_value.duplicate(true)
	custom_minimum_size = Vector2(730, 266)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if map_texture == null:
		return
	var scale_value := minf(size.x / WorldLayoutScript.WORLD_SIZE.x, size.y / WorldLayoutScript.WORLD_SIZE.y)
	var map_size := WorldLayoutScript.WORLD_SIZE * scale_value
	var map_rect := Rect2((size - map_size) * 0.5, map_size)
	draw_rect(map_rect.grow(3.0), Color("d9c982"), false, 2.0)
	draw_texture_rect(map_texture, map_rect, false)
	for area_name in WorldLayoutScript.AREA_ORDER:
		if discovered_areas.has(area_name):
			continue
		var region: Rect2 = WorldLayoutScript.REGIONS[area_name]["rect"]
		var hidden_rect := Rect2(
			map_rect.position + region.position * scale_value,
			region.size * scale_value
		)
		draw_rect(hidden_rect, Color("07161dcc"))
		draw_string(
			ThemeDB.fallback_font,
			hidden_rect.get_center() + Vector2(-28, 5),
			"尚未发现",
			HORIZONTAL_ALIGNMENT_CENTER,
			56,
			11,
			Color("a8b8b8")
		)

	for definition in WorldLayoutScript.MARKERS:
		if WorldLayoutScript.CORE_NPC_IDS.has(str(definition["id"])):
			continue
		if not discovered_areas.has(str(definition["area"])):
			continue
		var marker_position: Vector2 = definition["position"]
		var point := map_rect.position + marker_position * scale_value
		var marker_color: Color = definition["color"]
		var label_offset: Vector2 = WorldLayoutScript.MAP_LABEL_OFFSETS.get(str(definition["id"]), Vector2(6, 3))
		draw_circle(point, 5.0, Color("102b34"))
		draw_circle(point, 3.3, marker_color)
		draw_string(
			ThemeDB.fallback_font,
			point + label_offset,
			str(definition["label"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color("f8f1d8")
		)

	var area_npc_counts := {}
	for raw_entry in npc_entries:
		var entry: Dictionary = raw_entry
		var area_name := str(entry.get("area", ""))
		if area_name.is_empty() or not discovered_areas.has(area_name) or not WorldLayoutScript.REGIONS.has(area_name):
			continue
		var region: Rect2 = WorldLayoutScript.REGIONS[area_name]["rect"]
		var area_index := int(area_npc_counts.get(area_name, 0))
		area_npc_counts[area_name] = area_index + 1
		# The map intentionally resolves a known person only to their current
		# region, never to the exact world coordinate at their feet.
		var region_anchor := region.position + Vector2(115 + area_index * 78, 72)
		var point := map_rect.position + region_anchor * scale_value
		var marker_color: Color = entry.get("color", Color("f8f1d8"))
		draw_circle(point, 6.0, Color("102b34"))
		draw_circle(point, 4.0, marker_color if bool(entry.get("available", false)) else Color("687a7d"))
		draw_string(
			ThemeDB.fallback_font,
			point + Vector2(7, 4),
			str(entry.get("name", "人物")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color("fff0bc") if bool(entry.get("available", false)) else Color("9eaaab")
		)

	var quest_area_counts := {}
	for raw_quest in quest_entries:
		var quest: Dictionary = raw_quest
		var area_name := str(quest.get("area", ""))
		if area_name.is_empty() or not discovered_areas.has(area_name) or not WorldLayoutScript.REGIONS.has(area_name):
			continue
		var region: Rect2 = WorldLayoutScript.REGIONS[area_name]["rect"]
		var quest_index := int(quest_area_counts.get(area_name, 0))
		quest_area_counts[area_name] = quest_index + 1
		var anchor := region.position + Vector2(145 + quest_index * 92, region.size.y - 105)
		var point := map_rect.position + anchor * scale_value
		var diamond := PackedVector2Array([point + Vector2(0, -6), point + Vector2(6, 0), point + Vector2(0, 6), point + Vector2(-6, 0)])
		draw_colored_polygon(diamond, Color("f2cf69"))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("4b3b18"), 1.5)
		draw_string(ThemeDB.fallback_font, point + Vector2(8, 4), "委托 · %s" % str(quest.get("name", "目标")), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("ffe99e"))

	var player_point := map_rect.position + player_position * scale_value
	draw_circle(player_point, 7.0, Color("ffffff"), false, 2.0)
	draw_circle(player_point, 2.5, Color("4fe0df"))
