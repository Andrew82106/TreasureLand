extends Node2D

const WorldLayoutScript = preload("res://scripts/world_layout.gd")
const IslandGroundMap = preload("res://assets/art/environments/world_map_v2/island_ground_map_v2.png")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()


func _draw() -> void:
	# The image is a real ground plane.  Labels and task nodes stay in their own
	# runtime layers so art, collision and interaction coordinates cannot diverge.
	draw_texture_rect(IslandGroundMap, WorldLayoutScript.WORLD_RECT, false)
