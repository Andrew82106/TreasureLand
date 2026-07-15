extends Control
class_name WealthChart

var history: Array = []


func setup(points: Array) -> void:
	history = points.duplicate(true)
	custom_minimum_size = Vector2(0, 285)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var chart_rect := Rect2(62, 18, maxf(80.0, size.x - 82.0), maxf(120.0, size.y - 58.0))
	draw_style_box(_chart_background(), chart_rect.grow(8.0))
	if history.is_empty():
		draw_string(ThemeDB.fallback_font, chart_rect.get_center(), "还没有财富记录", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color("a9c0c2"))
		return

	var values: Array[float] = []
	for raw_point in history:
		if raw_point is Dictionary:
			values.append(float(raw_point.get("net_worth", 0)))
	var minimum: float = values.min()
	var maximum: float = values.max()
	var spread: float = maxf(1.0, maximum - minimum)
	var padding: float = maxf(8.0, spread * 0.16)
	var graph_min: float = maxf(0.0, minimum - padding)
	var graph_max: float = maximum + padding
	var graph_range: float = maxf(1.0, graph_max - graph_min)
	var font := ThemeDB.fallback_font

	for line_index in range(5):
		var ratio: float = float(line_index) / 4.0
		var y: float = chart_rect.position.y + chart_rect.size.y * ratio
		draw_line(Vector2(chart_rect.position.x, y), Vector2(chart_rect.end.x, y), Color("45656b66"), 1.0)
		var grid_value: float = lerpf(graph_max, graph_min, ratio)
		draw_string(font, Vector2(4, y + 5), _compact_number(int(round(grid_value))), HORIZONTAL_ALIGNMENT_RIGHT, 52, 12, Color("8eaaac"))

	var line_points := PackedVector2Array()
	for index in range(values.size()):
		var x_ratio: float = 0.5 if values.size() == 1 else float(index) / float(values.size() - 1)
		var x: float = chart_rect.position.x + chart_rect.size.x * x_ratio
		var normalized: float = (values[index] - graph_min) / graph_range
		var y: float = chart_rect.end.y - chart_rect.size.y * normalized
		line_points.append(Vector2(x, y))

	if line_points.size() >= 2:
		var fill_points := PackedVector2Array(line_points)
		fill_points.append(Vector2(line_points[line_points.size() - 1].x, chart_rect.end.y))
		fill_points.append(Vector2(line_points[0].x, chart_rect.end.y))
		draw_colored_polygon(fill_points, Color("5bc19b24"))
	var rising: bool = values[values.size() - 1] >= values[0]
	var line_color := Color("69d5a6") if rising else Color("e58d83")
	if line_points.size() >= 2:
		draw_polyline(line_points, line_color, 3.0, true)
	for index in range(line_points.size()):
		if index == 0 or index == line_points.size() - 1 or values[index] == maximum:
			draw_circle(line_points[index], 5.0, Color("f4db87"))
			draw_circle(line_points[index], 2.5, line_color)

	var first_point: Dictionary = history[0]
	var last_point: Dictionary = history[history.size() - 1]
	draw_string(font, Vector2(chart_rect.position.x, chart_rect.end.y + 24), _time_label(first_point), HORIZONTAL_ALIGNMENT_LEFT, chart_rect.size.x * 0.45, 12, Color("9eb7b8"))
	draw_string(font, Vector2(chart_rect.position.x + chart_rect.size.x * 0.55, chart_rect.end.y + 24), _time_label(last_point), HORIZONTAL_ALIGNMENT_RIGHT, chart_rect.size.x * 0.45, 12, Color("9eb7b8"))


func _time_label(point: Dictionary) -> String:
	return "第%d天 · %d/16潮刻" % [int(point.get("day", 1)), int(point.get("tide", 1))]


func _compact_number(value: int) -> String:
	if value >= 10000000:
		return "%.1f千万" % (float(value) / 10000000.0)
	if value >= 10000:
		return "%.1f万" % (float(value) / 10000.0)
	return str(value)


func _chart_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142c34")
	style.border_color = Color("52757a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style
