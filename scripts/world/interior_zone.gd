class_name InteriorZone
extends Area3D
## A room the player can walk into (the guild common room). While the player is inside,
## `cutaway` (roof, upper walls) hides so the 3/4 camera sees in from any angle, and camera
## collision is off so the spring arm isn't pulled into the room. Wall collision stays.
## Derived from where the player stands, so there is nothing to save.
## Needs a CollisionShape3D child covering the room.

@export var camera_rig: CameraController
@export var cutaway: Node3D

var inside := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	monitorable = false
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			_set_inside(true))
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			_set_inside(false))


func _set_inside(value: bool) -> void:
	inside = value
	if is_instance_valid(cutaway): # the world may be tearing down (F5 reload)
		cutaway.visible = not value
	if is_instance_valid(camera_rig):
		camera_rig.set_collision_enabled(not value)
