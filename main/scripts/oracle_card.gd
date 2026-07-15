extends Control
class_name OracleCardView

var game
var card_id: int = -1
var face_up: bool = true
var emphasized: bool = false
var compact: bool = false


func setup(game_state, value: int, is_face_up: bool = true, is_emphasized: bool = false, is_compact: bool = false) -> void:
	game = game_state
	card_id = value
	face_up = is_face_up
	emphasized = is_emphasized
	compact = is_compact
	custom_minimum_size = Vector2(58, 82) if compact else Vector2(82, 116)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	var border := Color("e7d78d") if emphasized else Color("76939a")
	if not face_up or card_id < 0:
		_draw_back(bounds, border)
		return

	var element: int = game.oracle_card_element(card_id)
	var rank: int = game.oracle_card_rank(card_id)
	var is_water: bool = element == 0
	var background := Color("e2f3f1") if is_water else Color("fff0d9")
	var accent := Color("3c91a6") if is_water else Color("d46b43")
	var ink := Color("153d4a") if is_water else Color("5e3022")
	_draw_card_box(bounds, background, border, 4 if emphasized else 2)

	var font := ThemeDB.fallback_font
	var top_text := "水之兆" if is_water else "火之兆"
	draw_string(font, Vector2(7, 18 if compact else 21), top_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 14, 11 if compact else 13, accent)
	if is_water:
		draw_circle(Vector2(size.x * 0.5, size.y * 0.38), 10 if compact else 15, Color(accent, 0.24))
		draw_arc(Vector2(size.x * 0.5, size.y * 0.38), 8 if compact else 12, 0.1, PI - 0.1, 20, accent, 2.0)
		draw_circle(Vector2(size.x * 0.5, size.y * 0.34), 4 if compact else 6, accent)
	else:
		var center := Vector2(size.x * 0.5, size.y * 0.38)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -16 if not compact else -11),
			center + Vector2(12 if not compact else 8, 8),
			center + Vector2(0, 14 if not compact else 10),
			center + Vector2(-12 if not compact else -8, 8)
		]), accent)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -5), center + Vector2(5, 8), center + Vector2(-5, 8)
		]), background)

	draw_string(font, Vector2(5, size.y * 0.68), game.oracle_card_name(card_id), HORIZONTAL_ALIGNMENT_CENTER, size.x - 10, 13 if compact else 16, ink)
	var gap := (size.x - 18.0) / 6.0
	for index in range(6):
		var pip_position := Vector2(9.0 + gap * index + gap * 0.5, size.y - (10 if compact else 13))
		draw_circle(pip_position, 2.0 if compact else 2.8, accent if index < rank else Color(accent, 0.18))


func _draw_back(bounds: Rect2, border: Color) -> void:
	_draw_card_box(bounds, Color("243a47"), border, 2)
	var center := bounds.size * 0.5
	draw_circle(center, minf(size.x, size.y) * 0.24, Color("90aeb4"), false, 2.0)
	draw_circle(center, minf(size.x, size.y) * 0.14, Color("d7cb8b"), false, 2.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -9), center + Vector2(9, 0),
		center + Vector2(0, 9), center + Vector2(-9, 0)
	]), Color("66858e"))


func _draw_card_box(bounds: Rect2, background: Color, border: Color, width: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8 if compact else 11)
	draw_style_box(style, bounds.grow(-1))
