class_name IslandMapOverview
extends Control

const WorldLayoutScript = preload("res://scripts/world_layout.gd")

var map_texture: Texture2D
var discovered_areas: Dictionary = {}
var player_position := Vector2.ZERO


func setup(texture_value: Texture2D, discovered_value: Dictionary, player_value: Vector2) -> void:
	map_texture = texture_value
	discovered_areas = discovered_value.duplicate()
	player_position = player_value
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

	var player_point := map_rect.position + player_position * scale_value
	draw_circle(player_point, 7.0, Color("ffffff"), false, 2.0)
	draw_circle(player_point, 2.5, Color("4fe0df"))
