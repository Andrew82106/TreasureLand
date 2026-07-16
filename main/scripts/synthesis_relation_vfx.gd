class_name SynthesisRelationVfx
extends Control

## Lightweight, deterministic relationship motion for the synthesis basin.
##
## The gameplay layer has already resolved the recipe before this node plays.
## This node only visualizes one of the seven relationship families and never
## reads or mutates discovery, currency, or recipe state.

var family: String = "converge"
var left_color: Color = Color("65b9c5")
var right_color: Color = Color("d58a52")
var successful: bool = true
var reduced_motion: bool = false
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func configure(
	family_value: String,
	left_value: Color,
	right_value: Color,
	is_successful: bool,
	use_reduced_motion: bool = false
) -> void:
	family = family_value
	left_color = left_value
	right_color = right_value
	successful = is_successful
	reduced_motion = use_reduced_motion
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0 or progress <= 0.0:
		return
	var center := size * Vector2(0.5, 0.48)
	var radius := minf(size.x, size.y) * 0.23
	var approach := _ease_out(clampf(progress / 0.48, 0.0, 1.0))
	var resolution := _ease_out(clampf((progress - 0.42) / 0.58, 0.0, 1.0))
	var source_distance := lerpf(radius * 1.55, radius * 0.22, approach)
	if not successful and progress > 0.62:
		source_distance = lerpf(radius * 0.22, radius * 1.05, _ease_out((progress - 0.62) / 0.38))
	var left_source := center + Vector2(-source_distance, 0.0)
	var right_source := center + Vector2(source_distance, 0.0)
	var alpha := sin(clampf(progress, 0.0, 1.0) * PI) * 0.75 + 0.18
	_draw_basin_rings(center, radius, alpha)
	_draw_source(left_source, left_color, radius, -1.0)
	_draw_source(right_source, right_color, radius, 1.0)
	if reduced_motion:
		_draw_reduced(center, radius, resolution, alpha)
		return
	if not successful:
		_draw_unstable(center, radius, resolution, alpha)
		return
	match family:
		"thermal":
			_draw_thermal(center, radius, resolution, alpha)
		"flow":
			_draw_flow(center, radius, resolution, alpha)
		"burst":
			_draw_burst(center, radius, resolution, alpha)
		"geology":
			_draw_geology(center, radius, resolution, alpha)
		"craft":
			_draw_craft(center, radius, resolution, alpha)
		"life":
			_draw_life(center, radius, resolution, alpha)
		_:
			_draw_converge(center, radius, resolution, alpha)


func _draw_basin_rings(center: Vector2, radius: float, alpha: float) -> void:
	var warm := left_color.lerp(right_color, 0.5)
	draw_arc(center, radius * (0.72 + progress * 0.08), -PI * 0.92, PI * 0.05, 40, Color(left_color, 0.28 * alpha), 3.0, true)
	draw_arc(center, radius * (0.72 + progress * 0.08), PI * 0.08, PI * 1.05, 40, Color(right_color, 0.28 * alpha), 3.0, true)
	draw_arc(center, radius, 0.0, TAU * progress, 56, Color(warm, 0.18 * alpha), 2.0, true)


func _draw_source(position_value: Vector2, color_value: Color, radius: float, direction: float) -> void:
	var pulse := 1.0 + sin(progress * PI * 5.0 + direction) * 0.08
	draw_circle(position_value, radius * 0.075 * pulse, Color(color_value, 0.82))
	draw_circle(position_value, radius * 0.14 * pulse, Color(color_value, 0.22), false, 2.0, true)
	for index in range(3):
		var offset := Vector2(direction * float(9 + index * 7), sin(float(index) * 2.1 + progress * 8.0) * 6.0)
		draw_circle(position_value + offset, 2.5 - float(index) * 0.45, Color(color_value, 0.42))


func _draw_reduced(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var mixed := left_color.lerp(right_color, 0.5)
	if successful:
		draw_circle(center, radius * (0.12 + resolution * 0.38), Color(mixed, 0.12 * alpha))
		draw_arc(center, radius * 0.52, 0.0, TAU * resolution, 40, Color(mixed, 0.68 * alpha), 4.0, true)
	else:
		_draw_unstable(center, radius, resolution, alpha)


func _draw_converge(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var mixed := left_color.lerp(right_color, 0.5)
	for index in range(3):
		var ring_radius := radius * (0.22 + float(index) * 0.15) * resolution
		draw_arc(center, ring_radius, -PI * 0.85, PI * 0.85, 32, Color(mixed, (0.62 - index * 0.12) * alpha), 3.0, true)
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.25 * resolution),
		center + Vector2(radius * 0.31 * resolution, 0.0),
		center + Vector2(0.0, radius * 0.25 * resolution),
		center + Vector2(-radius * 0.31 * resolution, 0.0),
	])
	if diamond.size() == 4:
		draw_colored_polygon(diamond, Color(mixed, 0.13 * alpha))
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(mixed, 0.58 * alpha), 2.0, true)


func _draw_thermal(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var mixed := left_color.lerp(right_color, 0.55)
	draw_circle(center, radius * 0.22 * resolution, Color(mixed, 0.26 * alpha))
	for index in range(5):
		var x := (float(index) - 2.0) * radius * 0.15
		var height := radius * (0.28 + float(index % 2) * 0.14) * resolution
		var points := PackedVector2Array()
		for step in range(7):
			var t := float(step) / 6.0
			points.append(center + Vector2(x + sin(t * PI * 2.0 + index) * 5.0, -t * height))
		draw_polyline(points, Color(mixed, (0.72 - index * 0.07) * alpha), 3.0, true)
	for index in range(3):
		var angle := -PI * 0.72 + float(index) * PI * 0.72
		var inner := center + Vector2.from_angle(angle) * radius * 0.12
		var outer := center + Vector2.from_angle(angle) * radius * (0.35 + 0.08 * resolution)
		draw_line(inner, outer, Color(right_color, 0.58 * alpha * resolution), 2.0, true)


func _draw_flow(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	for stream_index in range(3):
		var points := PackedVector2Array()
		for step in range(13):
			var t := float(step) / 12.0
			var x := lerpf(-radius * 0.72, radius * 0.72, t) * resolution
			var y := sin(t * TAU + stream_index * 1.3) * radius * (0.12 + stream_index * 0.025)
			points.append(center + Vector2(x, y))
		var stream_color := left_color.lerp(right_color, float(stream_index) / 2.0)
		draw_polyline(points, Color(stream_color, (0.70 - stream_index * 0.12) * alpha), 3.0, true)
	for index in range(4):
		var t := clampf(resolution - float(index) * 0.08, 0.0, 1.0)
		var mote := center + Vector2(lerpf(-radius * 0.55, radius * 0.55, t), sin(t * TAU + index) * radius * 0.13)
		draw_circle(mote, 3.0, Color(left_color.lerp(right_color, t), 0.72 * alpha))


func _draw_burst(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var mixed := left_color.lerp(right_color, 0.5)
	draw_circle(center, radius * 0.15 * resolution, Color(mixed, 0.28 * alpha))
	for index in range(12):
		var angle := float(index) / 12.0 * TAU - PI * 0.5
		var length := radius * (0.25 + float(index % 3) * 0.08) * resolution
		var start := center + Vector2.from_angle(angle) * radius * 0.12
		var finish := center + Vector2.from_angle(angle) * length
		draw_line(start, finish, Color(mixed, (0.68 - float(index % 2) * 0.18) * alpha), 3.0, true)


func _draw_geology(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	for index in range(5):
		var width := radius * (0.28 + float(index) * 0.11) * resolution
		var y := center.y + radius * 0.32 - float(index) * radius * 0.13
		var layer_color := left_color.lerp(right_color, float(index) / 4.0)
		draw_line(Vector2(center.x - width, y), Vector2(center.x + width, y), Color(layer_color, (0.76 - index * 0.08) * alpha), 4.0, true)
	for index in range(6):
		var angle := -PI + float(index) / 5.0 * PI
		var point := center + Vector2(cos(angle) * radius * 0.42 * resolution, radius * 0.33 + sin(angle) * radius * 0.13)
		draw_circle(point, 3.0, Color(right_color, 0.48 * alpha))


func _draw_craft(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var mixed := left_color.lerp(right_color, 0.5)
	var half_size := Vector2(radius * 0.34, radius * 0.28) * resolution
	var rect := Rect2(center - half_size, half_size * 2.0)
	draw_rect(rect, Color(mixed, 0.12 * alpha), true)
	draw_rect(rect, Color(mixed, 0.76 * alpha), false, 3.0, true)
	for index in range(3):
		var inset := float(index + 1) * radius * 0.075
		draw_arc(center, maxf(2.0, radius * 0.32 - inset), -PI * 0.82, -PI * 0.18, 18, Color(right_color, 0.42 * alpha), 2.0, true)


func _draw_life(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var stem_bottom := center + Vector2(0.0, radius * 0.30 * resolution)
	var stem_top := center + Vector2(0.0, -radius * 0.32 * resolution)
	draw_line(stem_bottom, stem_top, Color(left_color.lerp(right_color, 0.5), 0.78 * alpha), 4.0, true)
	for index in range(5):
		var t := float(index + 1) / 6.0 * resolution
		var branch_root := stem_bottom.lerp(stem_top, t)
		var direction := -1.0 if index % 2 == 0 else 1.0
		var branch_end := branch_root + Vector2(direction * radius * (0.18 + index * 0.015), -radius * 0.12)
		draw_line(branch_root, branch_end, Color(right_color, 0.66 * alpha), 3.0, true)
		draw_circle(branch_end, radius * 0.055, Color(left_color, 0.54 * alpha))
	draw_circle(stem_top, radius * 0.08 * resolution, Color(right_color, 0.62 * alpha))


func _draw_unstable(center: Vector2, radius: float, resolution: float, alpha: float) -> void:
	var muted := left_color.lerp(right_color, 0.5).lerp(Color("6f8585"), 0.58)
	draw_arc(center, radius * 0.42, -PI * 0.85, -PI * 0.12, 20, Color(muted, 0.72 * alpha * resolution), 4.0, true)
	draw_arc(center, radius * 0.42, PI * 0.15, PI * 0.88, 20, Color(muted, 0.72 * alpha * resolution), 4.0, true)
	var gap := radius * 0.12
	draw_line(center + Vector2(-gap, -gap), center + Vector2(gap, gap), Color("b9a58a", 0.42 * alpha * resolution), 2.0, true)
	draw_line(center + Vector2(-gap, gap), center + Vector2(gap, -gap), Color("b9a58a", 0.42 * alpha * resolution), 2.0, true)


func _ease_out(value: float) -> float:
	var inverted := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverted * inverted * inverted
