class_name EventRegion
extends Area3D
## Marks a region for the WorldEventDirector. Entering it hands the region to the EventHost,
## which decides whether that's an evaluation opportunity. Needs a CollisionShape3D child.

@export var region: StringName


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			get_tree().call_group("event_host", "on_region_entered", region))
