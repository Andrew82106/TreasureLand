extends Node2D
class_name InteractableMarker

var interaction_id: String = ""
var display_name: String = ""
var marker_color: Color = Color("f2c14e")
var interaction_radius: float = 78.0
var highlighted: bool = false
var label_node: Label
var last_distance: float = INF


func setup(id_value: String, label_value: String, color_value: Color) -> void:
	interaction_id = id_value
	display_name = label_value
	marker_color = color_value
	name = id_value
	label_node = Label.new()
	label_node.text = label_value
	label_node.position = Vector2(-66, 22)
	label_node.size = Vector2(132, 25)
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_node.add_theme_font_size_override("font_size", 14)
	label_node.add_theme_color_override("font_color", Color("f7fbff"))
	add_child(label_node)
	queue_redraw()


func set_proximity(distance: float) -> void:
	last_distance = distance
	_refresh_label_visibility()
	self_modulate.a = 0.52 if distance > 560.0 else 1.0


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	_refresh_label_visibility()
	queue_redraw()


func _refresh_label_visibility() -> void:
	if label_node == null:
		return
	var should_show := last_distance <= 390.0 or highlighted
	if label_node.visible != should_show:
		label_node.visible = should_show
		queue_redraw()


func _draw() -> void:
	var halo_radius := 25.0 if highlighted else 20.0
	draw_circle(Vector2.ZERO, halo_radius, Color(marker_color, 0.18 if not highlighted else 0.30))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -13), Vector2(12, 0), Vector2(0, 16), Vector2(-12, 0)
	]), marker_color)
	draw_arc(Vector2.ZERO, halo_radius, 0.0, TAU, 32, Color("f7fbff"), 2.0 if not highlighted else 3.0)
	if label_node != null and label_node.visible:
		var label_width := clampf(ThemeDB.fallback_font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0, 64.0, 132.0)
		draw_rect(Rect2(-label_width * 0.5, 22, label_width, 25), Color("18313bd9"), true)
		draw_line(Vector2(-label_width * 0.38, 47), Vector2(label_width * 0.38, 47), Color(marker_color, 0.75), 2.0)
