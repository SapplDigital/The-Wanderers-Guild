class_name SurfaceArea
extends Area3D
## Marks ground as a footstep surface ("dirt", "wood", ...). Ground without one is "grass".

@export var surface := "dirt"


func _ready() -> void:
	collision_layer = 16 # layer 5 "surface"
	collision_mask = 0
	monitoring = false
