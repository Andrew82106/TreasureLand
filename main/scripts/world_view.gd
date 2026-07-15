extends Node2D

const WORLD_RECT := Rect2(0, 0, 1800, 640)
const IslandPanorama = preload("res://assets/art/island_panorama_v1.png")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# 正式全景素材负责岛屿、建筑、道路与万象塔；代码层只保留可读区域标识和交互标记。
	draw_texture_rect(IslandPanorama, WORLD_RECT, false)
	draw_rect(Rect2(0, 0, 1800, 82), Color("092a3866"))
	_draw_region_title(Vector2(70, 42), "漂流湾", "采集 · 合成 · 起居")
	_draw_region_title(Vector2(640, 42), "椰影街", "交易 · 社交 · 牌会")
	_draw_region_title(Vector2(1300, 42), "逐风海岸", "赛事 · 委托")
	draw_circle(Vector2(1050, 195), 58, Color("f2d98218"))
	draw_arc(Vector2(1050, 195), 58, 0.0, TAU, 48, Color("f2d98288"), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(990, 275), "万象塔", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("f7edbd"))


func _draw_branch(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, Color("a98658"), 20.0, true)
	draw_line(from, to, Color("f5e7bd"), 13.0, true)


func _draw_house(position_value: Vector2, size_value: Vector2, body: Color, roof: Color) -> void:
	draw_rect(Rect2(position_value, size_value), Color(0.1, 0.16, 0.16, 0.16))
	draw_rect(Rect2(position_value + Vector2(5, 5), size_value - Vector2(10, 5)), body)
	draw_colored_polygon(PackedVector2Array([
		position_value + Vector2(-12, 9),
		position_value + Vector2(size_value.x + 12, 9),
		position_value + Vector2(size_value.x * 0.5, -27)
	]), roof)
	draw_rect(Rect2(position_value + Vector2(size_value.x * 0.42, size_value.y - 29), Vector2(22, 29)), Color("594c3f"))


func _draw_basin(position_value: Vector2) -> void:
	draw_circle(position_value, 34, Color("8a7650"))
	draw_circle(position_value, 27, Color("ddc66d"))
	draw_circle(position_value, 17, Color("557b76"))


func _draw_notice_board(position_value: Vector2) -> void:
	draw_line(position_value + Vector2(10, 25), position_value + Vector2(10, 78), Color("674f3a"), 7)
	draw_line(position_value + Vector2(75, 25), position_value + Vector2(75, 78), Color("674f3a"), 7)
	draw_rect(Rect2(position_value, Vector2(86, 52)), Color("f2e5b4"))
	draw_rect(Rect2(position_value + Vector2(7, 8), Vector2(72, 5)), Color("b99a67"))
	draw_rect(Rect2(position_value + Vector2(7, 20), Vector2(56, 4)), Color("b99a67"))
	draw_rect(Rect2(position_value + Vector2(7, 31), Vector2(67, 4)), Color("b99a67"))


func _draw_race_gate(position_value: Vector2) -> void:
	draw_line(position_value, position_value + Vector2(0, 108), Color("315c52"), 13)
	draw_line(position_value + Vector2(120, 0), position_value + Vector2(120, 108), Color("315c52"), 13)
	draw_line(position_value, position_value + Vector2(120, 0), Color("e6d88b"), 18)
	draw_string(ThemeDB.fallback_font, position_value + Vector2(14, -9), "逐 风", HORIZONTAL_ALIGNMENT_CENTER, 92, 17, Color("315c52"))


func _draw_stands(position_value: Vector2) -> void:
	for index in range(3):
		draw_rect(Rect2(position_value + Vector2(index * 16, index * 18), Vector2(150 - index * 32, 18)), Color("4e7766"))


func _draw_region_title(position_value: Vector2, title: String, subtitle: String) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, position_value, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("f7fbef"))
	draw_string(font, position_value + Vector2(0, 25), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e6f0df"))
	draw_line(position_value + Vector2(0, 34), position_value + Vector2(116, 34), Color(1, 1, 1, 0.45), 2)
