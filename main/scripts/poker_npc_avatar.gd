class_name PokerNpcAvatar
extends Control

## Animated seated portrait used by the first art-direction vertical slice.
##
## The atlas is four columns by eight rows. Every row contains four genuine
## hand-drawn pixel poses; this component never fakes character motion by
## scaling or rotating a static portrait.

const TABLE_ATLAS: Texture2D = preload(
	"res://assets/art/characters/old_qiao/oracle_table/old_qiao_table_atlas_v1.png"
)
const FRAME_SIZE := Vector2i(96, 96)
const FRAME_COUNT := 4

const TABLE_IDLE: StringName = &"table_idle"
const TABLE_TALK: StringName = &"table_talk"
const TABLE_THINK: StringName = &"table_think"
const TABLE_CALL: StringName = &"table_call"
const TABLE_RAISE: StringName = &"table_raise"
const TABLE_FOLD: StringName = &"table_fold"
const TABLE_WIN: StringName = &"table_win"
const TABLE_LOSE: StringName = &"table_lose"

const ANIMATION_ROWS := [
	{"name": TABLE_IDLE, "row": 0, "fps": 4.0, "loop": true},
	{"name": TABLE_TALK, "row": 1, "fps": 6.0, "loop": true},
	{"name": TABLE_THINK, "row": 2, "fps": 6.0, "loop": true},
	{"name": TABLE_CALL, "row": 3, "fps": 8.0, "loop": false},
	{"name": TABLE_RAISE, "row": 4, "fps": 8.0, "loop": false},
	{"name": TABLE_FOLD, "row": 5, "fps": 8.0, "loop": false},
	{"name": TABLE_WIN, "row": 6, "fps": 8.0, "loop": false},
	{"name": TABLE_LOSE, "row": 7, "fps": 8.0, "loop": false},
]

var sprite: AnimatedSprite2D
var requested_animation: StringName = TABLE_IDLE


func setup(size_value: float) -> void:
	custom_minimum_size = Vector2(size_value, size_value)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedPortrait"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = _build_sprite_frames()
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	resized.connect(_layout_sprite)
	_layout_sprite()
	_play_requested()


func play_for_action(action_text: String, thinking: bool, talking: bool = false) -> void:
	requested_animation = _animation_for_action(action_text, thinking, talking)
	if sprite != null:
		_play_requested()


func current_animation() -> StringName:
	return requested_animation if sprite == null else sprite.animation


func _animation_for_action(action_text: String, thinking: bool, talking: bool) -> StringName:
	if thinking:
		return TABLE_THINK
	if action_text.contains("赢得") or action_text.contains("平分"):
		return TABLE_WIN
	if action_text.contains("输光") or action_text.contains("未胜"):
		return TABLE_LOSE
	if action_text.contains("退契") or action_text.contains("离桌"):
		return TABLE_FOLD
	if action_text.contains("跟契") or action_text.contains("起始投入"):
		return TABLE_CALL
	if action_text.contains("加契") or action_text.contains("立契") or action_text.contains("投入"):
		return TABLE_RAISE
	if talking:
		return TABLE_TALK
	return TABLE_IDLE


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for specification in ANIMATION_ROWS:
		var animation_name: StringName = specification["name"]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(specification["fps"]))
		frames.set_animation_loop(animation_name, bool(specification["loop"]))
		for column in range(FRAME_COUNT):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = TABLE_ATLAS
			frame_texture.region = Rect2(
				column * FRAME_SIZE.x,
				int(specification["row"]) * FRAME_SIZE.y,
				FRAME_SIZE.x,
				FRAME_SIZE.y
			)
			frame_texture.filter_clip = true
			frames.add_frame(animation_name, frame_texture)
	return frames


func _play_requested() -> void:
	if sprite == null or not sprite.sprite_frames.has_animation(requested_animation):
		return
	if sprite.animation != requested_animation or not sprite.is_playing():
		sprite.play(requested_animation)


func _on_animation_finished() -> void:
	if sprite == null or sprite.animation in [TABLE_IDLE, TABLE_TALK, TABLE_THINK]:
		return
	requested_animation = TABLE_IDLE
	sprite.play(TABLE_IDLE)


func _layout_sprite() -> void:
	if sprite == null:
		return
	var available := maxf(1.0, minf(size.x, size.y))
	var pixel_scale := available / float(FRAME_SIZE.x)
	sprite.position = size * 0.5
	sprite.scale = Vector2.ONE * pixel_scale
