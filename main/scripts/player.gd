extends CharacterBody2D

signal interact_requested
signal inventory_requested

@export var speed: float = 230.0
var controls_enabled: bool = true

@onready var character_visual := $PixelCharacterAnimator


func _ready() -> void:
	character_visual.set_motion(Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		character_visual.set_motion(Vector2.ZERO)
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
	global_position.x = clampf(global_position.x, 25.0, 1775.0)
	global_position.y = clampf(global_position.y, 55.0, 585.0)
	character_visual.set_motion(direction)

	if Input.is_action_just_pressed("interact"):
		interact_requested.emit()
	if Input.is_action_just_pressed("inventory"):
		inventory_requested.emit()
