class_name PixelCharacterAnimator
extends Node2D

## Reusable four-direction pixel character renderer.
##
## Production atlas contract (48x64 cells and 8 columns by default):
##   row 0 idle_down    row 4 walk_down
##   row 1 idle_left    row 5 walk_left
##   row 2 idle_right   row 6 walk_right
##   row 3 idle_up      row 7 walk_up
## Idle rows use their first `idle_frame_count` cells; walk rows use their
## first `walk_frame_count` cells. Empty cells may remain transparent.

signal animation_state_changed(animation_name: StringName)
signal frame_event(event_name: StringName, animation_name: StringName, frame_index: int)
signal animation_cycle_completed(animation_name: StringName)

enum Facing {
	DOWN,
	LEFT,
	RIGHT,
	UP,
}

const ANIMATION_IDLE_DOWN: StringName = &"idle_down"
const ANIMATION_IDLE_LEFT: StringName = &"idle_left"
const ANIMATION_IDLE_RIGHT: StringName = &"idle_right"
const ANIMATION_IDLE_UP: StringName = &"idle_up"
const ANIMATION_WALK_DOWN: StringName = &"walk_down"
const ANIMATION_WALK_LEFT: StringName = &"walk_left"
const ANIMATION_WALK_RIGHT: StringName = &"walk_right"
const ANIMATION_WALK_UP: StringName = &"walk_up"

const ROW_LAYOUT := [
	{"name": ANIMATION_IDLE_DOWN, "row": 0, "state": &"idle"},
	{"name": ANIMATION_IDLE_LEFT, "row": 1, "state": &"idle"},
	{"name": ANIMATION_IDLE_RIGHT, "row": 2, "state": &"idle"},
	{"name": ANIMATION_IDLE_UP, "row": 3, "state": &"idle"},
	{"name": ANIMATION_WALK_DOWN, "row": 4, "state": &"walk"},
	{"name": ANIMATION_WALK_LEFT, "row": 5, "state": &"walk"},
	{"name": ANIMATION_WALK_RIGHT, "row": 6, "state": &"walk"},
	{"name": ANIMATION_WALK_UP, "row": 7, "state": &"walk"},
]

@export_group("Sprite Sheet")
@export var atlas_texture: Texture2D
@export var frame_size: Vector2i = Vector2i(48, 64)
@export_range(1, 16, 1) var atlas_columns: int = 8
@export_range(1, 16, 1) var idle_frame_count: int = 4
@export_range(1, 16, 1) var walk_frame_count: int = 8
@export_range(1.0, 24.0, 0.5) var idle_fps: float = 4.0
@export_range(1.0, 24.0, 0.5) var walk_fps: float = 8.0
@export var use_placeholder_when_missing: bool = true
## Moves the sprite's feet relative to the logical body origin. For the current
## centered capsule collider this is (0, 17); foot-anchored NPCs can keep zero.
@export var foot_anchor_offset: Vector2 = Vector2.ZERO

@export_group("Frame Events")
## Keys use "animation_name:frame_index". Values may be one StringName or an
## Array of names. Gameplay listens to `frame_event`; the renderer owns no logic.
@export var frame_events: Dictionary = {
	"walk_down:1": &"footstep",
	"walk_down:5": &"footstep",
	"walk_left:1": &"footstep",
	"walk_left:5": &"footstep",
	"walk_right:1": &"footstep",
	"walk_right:5": &"footstep",
	"walk_up:1": &"footstep",
	"walk_up:5": &"footstep",
}

@onready var sprite: AnimatedSprite2D = $Sprite

var facing: int = Facing.DOWN
var _is_moving: bool = false
var _using_placeholder: bool = false


func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	_update_sprite_origin()
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_looped.connect(_on_sprite_animation_looped)
	rebuild_sprite_frames()


func _process(_delta: float) -> void:
	# Physics remains sub-pixel precise; only the visual presentation is snapped.
	var logical_parent := get_parent() as Node2D
	if logical_parent != null:
		position = logical_parent.global_position.round() - logical_parent.global_position


func set_motion(input_vector: Vector2) -> void:
	_is_moving = input_vector.length_squared() > 0.0001
	if _is_moving:
		facing = _facing_from_vector(input_vector)
	_play_current_state()


func set_facing(new_facing: int) -> void:
	if new_facing < Facing.DOWN or new_facing > Facing.UP:
		push_warning("PixelCharacterAnimator received an invalid facing value: %s" % new_facing)
		return
	facing = new_facing
	_play_current_state()


func set_atlas(texture: Texture2D) -> bool:
	atlas_texture = texture
	return rebuild_sprite_frames()


func is_using_placeholder() -> bool:
	return _using_placeholder


func rebuild_sprite_frames() -> bool:
	_update_sprite_origin()
	var source := atlas_texture
	_using_placeholder = false
	if not _atlas_layout_is_valid(source):
		if source != null:
			push_warning(
				"Pixel character atlas must be at least %dx%d for %dx%d cells. Using the safe placeholder."
				% [frame_size.x * atlas_columns, frame_size.y * ROW_LAYOUT.size(), frame_size.x, frame_size.y]
			)
		if not use_placeholder_when_missing:
			sprite.sprite_frames = SpriteFrames.new()
			sprite.visible = false
			return false
		source = _create_placeholder_atlas()
		_using_placeholder = true

	sprite.sprite_frames = _slice_atlas(source)
	sprite.visible = true
	_play_current_state(true)
	return not _using_placeholder


func _slice_atlas(source: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	for specification in ROW_LAYOUT:
		var animation_name: StringName = specification["name"]
		var animation_state: StringName = specification["state"]
		var frame_count := idle_frame_count if animation_state == &"idle" else walk_frame_count
		frame_count = mini(frame_count, atlas_columns)
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(animation_name, idle_fps if animation_state == &"idle" else walk_fps)
		for column in range(frame_count):
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = source
			frame_texture.region = Rect2(
				column * frame_size.x,
				int(specification["row"]) * frame_size.y,
				frame_size.x,
				frame_size.y
			)
			frame_texture.filter_clip = true
			frames.add_frame(animation_name, frame_texture)
	return frames


func _atlas_layout_is_valid(source: Texture2D) -> bool:
	if source == null or frame_size.x < 16 or frame_size.y < 24:
		return false
	if idle_frame_count > atlas_columns or walk_frame_count > atlas_columns:
		return false
	return (
		source.get_width() >= frame_size.x * atlas_columns
		and source.get_height() >= frame_size.y * ROW_LAYOUT.size()
	)


func _play_current_state(force_restart: bool = false) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var desired := _animation_for(_is_moving, facing)
	if not sprite.sprite_frames.has_animation(desired):
		return
	if force_restart or sprite.animation != desired or not sprite.is_playing():
		sprite.play(desired)
		animation_state_changed.emit(desired)


func _animation_for(moving: bool, direction: int) -> StringName:
	if moving:
		match direction:
			Facing.LEFT:
				return ANIMATION_WALK_LEFT
			Facing.RIGHT:
				return ANIMATION_WALK_RIGHT
			Facing.UP:
				return ANIMATION_WALK_UP
			_:
				return ANIMATION_WALK_DOWN
	match direction:
		Facing.LEFT:
			return ANIMATION_IDLE_LEFT
		Facing.RIGHT:
			return ANIMATION_IDLE_RIGHT
		Facing.UP:
			return ANIMATION_IDLE_UP
		_:
			return ANIMATION_IDLE_DOWN


func _facing_from_vector(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return Facing.RIGHT if direction.x > 0.0 else Facing.LEFT
	return Facing.DOWN if direction.y > 0.0 else Facing.UP


func _on_sprite_frame_changed() -> void:
	var key := "%s:%d" % [sprite.animation, sprite.frame]
	if not frame_events.has(key):
		return
	var configured_events = frame_events[key]
	if configured_events is Array:
		for event_name in configured_events:
			frame_event.emit(StringName(str(event_name)), sprite.animation, sprite.frame)
	else:
		frame_event.emit(StringName(str(configured_events)), sprite.animation, sprite.frame)


func _on_sprite_animation_looped() -> void:
	animation_cycle_completed.emit(sprite.animation)


func _update_sprite_origin() -> void:
	if sprite != null:
		# The component origin is the character's feet, not its frame center.
		sprite.position = Vector2(-frame_size.x * 0.5, -frame_size.y) + foot_anchor_offset


func _create_placeholder_atlas() -> Texture2D:
	var image := Image.create(
		frame_size.x * atlas_columns,
		frame_size.y * ROW_LAYOUT.size(),
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)
	for row_index in range(ROW_LAYOUT.size()):
		var state_name: StringName = ROW_LAYOUT[row_index]["state"]
		var used_frames := idle_frame_count if state_name == &"idle" else walk_frame_count
		for column in range(mini(used_frames, atlas_columns)):
			_draw_placeholder_frame(image, column, row_index, state_name == &"walk")
	return ImageTexture.create_from_image(image)


func _draw_placeholder_frame(image: Image, column: int, row: int, walking: bool) -> void:
	var origin := Vector2i(column * frame_size.x, row * frame_size.y)
	var center_x := origin.x + int(frame_size.x / 2)
	var floor_y := origin.y + frame_size.y - 5
	var bob := 1 if (walking and column % 4 in [1, 2]) else 0
	var stride := 2 if walking and column % 4 in [0, 3] else -2
	var outline := Color("17353d")
	var skin := Color("f0b37c")
	var cloth := Color("2d8292")
	var light := Color("f5d873")

	# A deliberately simple animated pixel mannequin. It is a safe missing-asset
	# indicator, not production art, and can be replaced without touching logic.
	image.fill_rect(Rect2i(center_x - 8, floor_y - 34 - bob, 16, 13), outline)
	image.fill_rect(Rect2i(center_x - 6, floor_y - 32 - bob, 12, 10), skin)
	image.fill_rect(Rect2i(center_x - 9, floor_y - 22 - bob, 18, 17), outline)
	image.fill_rect(Rect2i(center_x - 7, floor_y - 20 - bob, 14, 14), cloth)
	image.fill_rect(Rect2i(center_x - 6 + stride, floor_y - 6 - bob, 5, 6 + bob), outline)
	image.fill_rect(Rect2i(center_x + 1 - stride, floor_y - 6 - bob, 5, 6 + bob), outline)

	match row % 4:
		Facing.DOWN:
			image.fill_rect(Rect2i(center_x - 4, floor_y - 28 - bob, 2, 2), outline)
			image.fill_rect(Rect2i(center_x + 2, floor_y - 28 - bob, 2, 2), outline)
		Facing.LEFT:
			image.fill_rect(Rect2i(center_x - 6, floor_y - 28 - bob, 2, 2), outline)
		Facing.RIGHT:
			image.fill_rect(Rect2i(center_x + 4, floor_y - 28 - bob, 2, 2), outline)
		Facing.UP:
			image.fill_rect(Rect2i(center_x - 6, floor_y - 32 - bob, 12, 3), light)
	image.fill_rect(Rect2i(center_x - 7, floor_y - 17 - bob, 14, 3), light)
