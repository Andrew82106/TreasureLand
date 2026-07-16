extends Control

signal replay_finished

const BEAST_COLORS := [
	Color("74c9d8"), Color("e5a36e"), Color("e7e4d0"), Color("e3c45e"),
	Color("a88bd8"), Color("77c49a"), Color("d27e91"), Color("d8b77c")
]
const STAGE_NAMES := ["起步", "巡航", "地形", "冲刺"]

var replay_result: Dictionary = {}
var selected_beast_index: int = -1
var elapsed: float = 0.0
var duration: float = 5.2
var playing: bool = false


func setup(result: Dictionary, selected_index: int, speed_scale: float = 1.0) -> void:
	replay_result = result.duplicate(true)
	selected_beast_index = selected_index
	elapsed = 0.0
	duration = 5.2 / maxf(0.25, speed_scale)
	playing = not replay_result.is_empty()
	custom_minimum_size = Vector2(700, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(playing)
	queue_redraw()


func skip() -> void:
	if replay_result.is_empty():
		return
	elapsed = duration
	playing = false
	set_process(false)
	queue_redraw()
	replay_finished.emit()


func replay() -> void:
	if replay_result.is_empty():
		return
	elapsed = 0.0
	playing = true
	set_process(true)
	queue_redraw()


func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(elapsed / duration, 0.0, 1.0)


func current_stage_index() -> int:
	return mini(3, int(floor(progress() * 4.0)))


func _process(delta: float) -> void:
	if not playing:
		return
	elapsed = minf(duration, elapsed + delta)
	queue_redraw()
	if elapsed >= duration:
		playing = false
		set_process(false)
		replay_finished.emit()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), bounds)
	if replay_result.is_empty():
		_draw_centered("暂无可回放的赛事。", bounds, Color("9fb5b5"), 18)
		return
	var left := 110.0
	var right := maxf(left + 420.0, size.x - 26.0)
	var top := 48.0
	var bottom := maxf(top + 220.0, size.y - 34.0)
	var point_count := 5
	var x_step := (right - left) / float(point_count - 1)
	var lane_step := (bottom - top) / 7.0
	for lane in range(8):
		var y := top + lane * lane_step
		draw_line(Vector2(left, y), Vector2(right, y), Color("52707855"), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(18, y + 5), "%d" % (lane + 1), HORIZONTAL_ALIGNMENT_LEFT, 28, 14, Color("789296"))
	for stage in range(4):
		var stage_x := left + (stage + 1) * x_step
		var active := stage <= current_stage_index()
		draw_line(Vector2(stage_x, top - 18), Vector2(stage_x, bottom + 10), Color("d9bd67aa") if active else Color("48616877"), 1.5)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(stage_x - 30, 28),
			STAGE_NAMES[stage],
			HORIZONTAL_ALIGNMENT_CENTER,
			60,
			15,
			Color("f0d27e") if active else Color("809596")
		)
	var overall := progress() * 4.0
	var segment := mini(3, int(floor(overall)))
	var local_t := clampf(overall - float(segment), 0.0, 1.0)
	for beast_index in range(8):
		var color: Color = BEAST_COLORS[beast_index % BEAST_COLORS.size()]
		var points: PackedVector2Array = []
		for point_index in range(5):
			points.append(Vector2(
				left + point_index * x_step,
				top + (_rank_at(beast_index, point_index) - 1) * lane_step
			))
		for line_index in range(segment + 1):
			if line_index >= 4:
				break
			var line_end := points[line_index + 1]
			if line_index == segment:
				line_end = points[line_index].lerp(points[line_index + 1], local_t)
			draw_line(points[line_index], line_end, Color(color, 0.92 if beast_index == selected_beast_index else 0.58), 4.0 if beast_index == selected_beast_index else 2.0, true)
		var marker := points[segment].lerp(points[segment + 1], local_t)
		draw_circle(marker, 8.0 if beast_index == selected_beast_index else 5.5, color)
		if beast_index == selected_beast_index:
			draw_arc(marker, 12.0, 0.0, TAU, 24, Color("fff1a8"), 2.0, true)
			draw_string(ThemeDB.fallback_font, marker + Vector2(14, 5), _beast_name(beast_index), HORIZONTAL_ALIGNMENT_LEFT, 90, 14, Color("fff1a8"))
	var status := "回放完成" if not playing and progress() >= 1.0 else "%s · 第%d段进行中" % [_beast_name(selected_beast_index), current_stage_index() + 1]
	draw_string(ThemeDB.fallback_font, Vector2(18, size.y - 12), status, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 15, Color("b9d8d2"))


func _rank_at(beast_index: int, point_index: int) -> int:
	if point_index <= 0:
		return beast_index + 1
	var reports: Array = replay_result.get("stage_reports", [])
	var report_index := point_index - 1
	if report_index < 0 or report_index >= reports.size():
		return beast_index + 1
	var order: Array = reports[report_index].get("order_indices", [])
	var found := order.find(beast_index)
	return found + 1 if found >= 0 else beast_index + 1


func _beast_name(beast_index: int) -> String:
	for raw_result in replay_result.get("results", []):
		var result: Dictionary = raw_result
		if int(result.get("index", -1)) == beast_index:
			return str(result.get("name", "逐风兽"))
	return "逐风兽"


func _draw_centered(text_value: String, rect: Rect2, color: Color, font_size: int) -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5),
		text_value,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		font_size,
		color
	)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102a31e8")
	style.border_color = Color("6d9392")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
