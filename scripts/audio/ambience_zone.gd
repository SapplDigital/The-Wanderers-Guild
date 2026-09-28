class_name AmbienceZone
extends Area3D
## While the player is inside, these ambience layers play (the most recently entered zone wins).

@export var layers: Array[StringName] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			AudioManager.push_ambience(_id(), layers))
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			AudioManager.pop_ambience(_id()))


func _exit_tree() -> void:
	AudioManager.pop_ambience(_id())


func _id() -> StringName:
	return StringName(str(get_path()))
