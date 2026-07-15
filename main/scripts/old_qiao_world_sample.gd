extends Node2D

## Small in-world animation proof. Lao Qiao alternates between a short walk and
## an idle pause beside his existing interaction marker, exercising both the
## true frame sequence and four-direction state switching.

@export var patrol_distance: float = 18.0
@export var patrol_speed: float = 22.0
@export var pause_seconds: float = 1.4

@onready var character_visual: PixelCharacterAnimator = $PixelCharacterAnimator

var _origin_x: float
var _direction: float = 1.0
var _pause_remaining: float = 0.8


func _ready() -> void:
	_origin_x = position.x
	character_visual.set_motion(Vector2.ZERO)


func _process(delta: float) -> void:
	if _pause_remaining > 0.0:
		_pause_remaining = maxf(0.0, _pause_remaining - delta)
		character_visual.set_motion(Vector2.ZERO)
		return

	position.x += _direction * patrol_speed * delta
	character_visual.set_motion(Vector2(_direction, 0.0))
	if absf(position.x - _origin_x) >= patrol_distance:
		position.x = _origin_x + patrol_distance * _direction
		_direction *= -1.0
		_pause_remaining = pause_seconds

