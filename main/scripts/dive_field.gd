class_name DiveField
extends Control

signal oxygen_depleted
signal status_changed(text: String)

const FishCatalog = preload("res://scripts/fish_catalog.gd")

var game
var fish_states: Array = []
var diver_position := Vector2.ZERO
var elapsed: float = 0.0
var gameplay_paused: bool = false
var initialized: bool = false
var depletion_emitted: bool = false
var last_status: String = ""


func setup(state) -> void:
	game = state
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 10.0 and size.y > 10.0:
		_initialize_positions()


func _initialize_positions() -> void:
	if game == null or not game.dive_active:
		return
	diver_position = Vector2(size.x * 0.12, size.y * 0.52) if not initialized else Vector2(
		clampf(diver_position.x, 28.0, size.x - 28.0),
		clampf(diver_position.y, 34.0, size.y - 34.0)
	)
	if not initialized:
		fish_states.clear()
		for raw_candidate in game.dive_state.get("candidates", []):
			var candidate: Dictionary = raw_candidate
			var normalized: Dictionary = candidate.get("position", {})
			var angle := float(candidate.get("route_angle", 0.0))
			fish_states.append({
				"index": int(candidate["index"]),
				"species_id": str(candidate["species_id"]),
				"behavior": str(candidate["behavior"]),
				"size": str(candidate["size"]),
				"position": Vector2(float(normalized.get("x", 0.5)) * size.x, float(normalized.get("y", 0.5)) * size.y),
				"velocity": Vector2.from_angle(angle) * float(candidate.get("speed", 55.0)),
				"captured": game.dive_state.get("captured_indices", []).has(int(candidate["index"])),
				"phase": float(candidate["index"]) * 0.73
			})
	initialized = true
	queue_redraw()


func _process(delta: float) -> void:
	if game == null or not visible or not game.dive_active or gameplay_paused:
		return
	if not initialized:
		_initialize_positions()
		return
	elapsed += delta
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fast_swimming: bool = Input.is_key_pressed(KEY_SHIFT)
	var speed: float = 155.0 * float(game.dive_equipment.get("swim_speed", 1.0)) * (1.38 if fast_swimming else 1.0)
	diver_position += movement * speed * delta
	diver_position.x = clampf(diver_position.x, 26.0, size.x - 26.0)
	diver_position.y = clampf(diver_position.y, 32.0, size.y - 32.0)
	_update_fish(delta)
	var oxygen: float = float(game.update_dive_oxygen(delta, fast_swimming and movement.length_squared() > 0.01))
	if oxygen <= 0.0 and not depletion_emitted:
		depletion_emitted = true
		oxygen_depleted.emit()
	queue_redraw()


func _update_fish(delta: float) -> void:
	for index in range(fish_states.size()):
		var fish: Dictionary = fish_states[index]
		if bool(fish["captured"]):
			continue
		var position: Vector2 = fish["position"]
		var velocity: Vector2 = fish["velocity"]
		var behavior := str(fish["behavior"])
		var phase := float(fish["phase"])
		if behavior == "群游":
			velocity = velocity.rotated(sin(elapsed * 1.25 + phase) * 0.012)
		elif behavior == "藏礁":
			velocity *= 0.985
			if position.distance_to(diver_position) < 115.0:
				velocity = (position - diver_position).normalized() * 105.0
			elif velocity.length() < 28.0:
				velocity = Vector2.from_angle(phase + elapsed * 0.16) * 38.0
		else:
			velocity = velocity.rotated(sin(elapsed * 2.4 + phase) * 0.035)
			velocity = velocity.normalized() * (82.0 + sin(elapsed * 3.1 + phase) * 24.0)
		position += velocity * delta
		if position.x < 24.0 or position.x > size.x - 24.0:
			velocity.x *= -1.0
			position.x = clampf(position.x, 24.0, size.x - 24.0)
		if position.y < 28.0 or position.y > size.y - 28.0:
			velocity.y *= -1.0
			position.y = clampf(position.y, 28.0, size.y - 28.0)
		fish["position"] = position
		fish["velocity"] = velocity
		fish_states[index] = fish


func try_capture_nearest() -> Dictionary:
	if gameplay_paused or game == null or not game.dive_active:
		return {"ok": false, "text": "当前不能抓取。"}
	var nearest_index := -1
	var nearest_distance := 64.0
	for fish in fish_states:
		if bool(fish["captured"]):
			continue
		var distance := diver_position.distance_to(fish["position"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = int(fish["index"])
	if nearest_index < 0:
		_set_status("还没有进入抓取距离；靠近鱼影后再按 E。")
		return {"ok": false, "text": last_status}
	var result: Dictionary = game.dive_capture(nearest_index)
	if bool(result.get("ok", false)):
		for index in range(fish_states.size()):
			if int(fish_states[index]["index"]) == nearest_index:
				var fish: Dictionary = fish_states[index]
				fish["captured"] = true
				fish_states[index] = fish
				break
	_set_status(str(result.get("text", "抓取没有成功。")))
	queue_redraw()
	return result


func set_gameplay_paused(paused: bool) -> void:
	gameplay_paused = paused


func _set_status(text_value: String) -> void:
	last_status = text_value
	status_changed.emit(text_value)


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b5368"))
	for band in range(8):
		var band_rect := Rect2(0, float(band) / 8.0 * size.y, size.x, size.y / 8.0 + 1.0)
		draw_rect(band_rect, Color(0.05, 0.42 - band * 0.025, 0.52 - band * 0.028, 1.0))
	for rock_index in range(7):
		var rock_x := size.x * (0.18 + rock_index * 0.12)
		var rock_y := size.y - 20.0 - float((rock_index * 31) % 55)
		draw_circle(Vector2(rock_x, rock_y), 22.0 + float((rock_index * 9) % 18), Color("315f62"))
	for fish in fish_states:
		if bool(fish["captured"]):
			continue
		_draw_fish(fish)
	_draw_diver()


func _draw_fish(fish: Dictionary) -> void:
	var position: Vector2 = fish["position"]
	var velocity: Vector2 = fish["velocity"]
	var species_id := str(fish["species_id"])
	var species: Dictionary = FishCatalog.SPECIES.get(species_id, {})
	var color: Color = species.get("color", Color("b8dce0"))
	var scale_value: float = float({"小型": 0.82, "标准": 1.0, "大型": 1.22, "纪录级": 1.48}.get(str(fish["size"]), 1.0))
	var facing: float = -1.0 if velocity.x < 0.0 else 1.0
	_draw_fish_body(position, Vector2(18.0, 9.0) * scale_value, color)
	var tail := PackedVector2Array([
		position + Vector2(-facing * 15.0, 0.0) * scale_value,
		position + Vector2(-facing * 27.0, -10.0) * scale_value,
		position + Vector2(-facing * 27.0, 10.0) * scale_value
	])
	draw_colored_polygon(tail, color.darkened(0.08))
	draw_circle(position + Vector2(facing * 10.0, -2.0) * scale_value, 1.7 * scale_value, Color("10232b"))
	if str(species.get("rarity", "普通")) != "普通":
		draw_arc(position, 25.0 * scale_value, 0.0, TAU, 24, Color("f1d17b88"), 1.5)


func _draw_fish_body(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _draw_diver() -> void:
	draw_circle(diver_position, 13.0, Color("f1c56e"))
	draw_rect(Rect2(diver_position + Vector2(-8.0, 11.0), Vector2(16.0, 24.0)), Color("263b47"))
	draw_line(diver_position + Vector2(-6.0, 34.0), diver_position + Vector2(-18.0, 44.0), Color("8fd2d8"), 4.0)
	draw_line(diver_position + Vector2(6.0, 34.0), diver_position + Vector2(18.0, 44.0), Color("8fd2d8"), 4.0)
	draw_arc(diver_position, 20.0, 0.0, TAU, 24, Color("ffffff99"), 1.5)
