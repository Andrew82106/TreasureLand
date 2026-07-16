class_name WorldLighting
extends Node2D

const WorldLayoutScript = preload("res://scripts/world_layout.gd")

@onready var canvas_modulate: CanvasModulate = $CanvasModulate

var lanterns: Array[PointLight2D] = []
var current_phase := "白天"
var current_weather := "晴"


func _ready() -> void:
	_build_lanterns()
	set_environment(current_phase, current_weather, true)


func set_environment(phase_name: String, weather_name: String, immediate: bool = false) -> void:
	if not immediate and phase_name == current_phase and weather_name == current_weather:
		return
	current_phase = phase_name
	current_weather = weather_name
	var target_color := _phase_color(phase_name)
	if weather_name == "阵雨":
		target_color = target_color.lerp(Color("6f8290"), 0.22)
	elif weather_name == "强风":
		target_color = target_color.lerp(Color("a9bdc4"), 0.10)
	if immediate or not is_node_ready():
		canvas_modulate.color = target_color
	else:
		var tween := create_tween()
		tween.tween_property(canvas_modulate, "color", target_color, 0.55)

	var night_strength := 0.0
	if phase_name == "傍晚":
		night_strength = 0.72
	elif phase_name == "夜晚":
		night_strength = 1.35
	for lantern in lanterns:
		lantern.enabled = night_strength > 0.0
		lantern.energy = night_strength


func _phase_color(phase_name: String) -> Color:
	match phase_name:
		"清晨":
			return Color("ffe9cf")
		"傍晚":
			return Color("d89270")
		"夜晚":
			return Color("526989")
		_:
			return Color("fffdf4")


func _build_lanterns() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	gradient.colors = PackedColorArray([
		Color("ffd788e8"),
		Color("ffb85a82"),
		Color("ff8a3300"),
	])
	var light_texture := GradientTexture2D.new()
	light_texture.width = 128
	light_texture.height = 128
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	light_texture.gradient = gradient
	for index in range(WorldLayoutScript.LANTERNS.size()):
		var light := PointLight2D.new()
		light.name = "Lantern%02d" % index
		light.position = WorldLayoutScript.LANTERNS[index]
		light.texture = light_texture
		light.texture_scale = 2.7
		light.color = Color("ffd58a")
		light.energy = 0.0
		light.enabled = false
		light.shadow_enabled = false
		add_child(light)
		lanterns.append(light)
