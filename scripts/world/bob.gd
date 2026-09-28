extends Node3D
## Gentle float for small living things (wisps, motes). Phase comes from position so neighbours drift apart.

@export var height := 0.25
@export var speed := 1.3

@onready var _base_y := position.y


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * speed + global_position.x
	position.y = _base_y + sin(t) * height
