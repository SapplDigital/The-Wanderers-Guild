class_name InteriorZone
extends Area3D
## A room the player can walk into (the guild common room). While the player is inside,
## `cutaway` (roof, upper walls) hides so the 3/4 camera sees in from any angle, and camera
## collision is off so the spring arm isn't pulled into the room. Wall collision stays.
## Derived from where the player stands, so there is nothing to save.
## Needs a CollisionShape3D child covering the room.
##
## Doorstep (M15): just outside, with the camera behind the building, the roof used to catch the
## spring arm and slam the camera into the player's back. So near the building the same two
## effects also apply while `occluder` (the building's own body) blocks the camera's intended
## line of sight to the player. From every other side the exterior stays intact. Only this
## building is checked; this is not a general occlusion system.

## Found through the `camera_rig` group when left empty (the normal case). Don't set it as an
## override from the world scene: an override on a child of an instanced scene was lost in the
## exported build (M15), so the camera collided inside the guild only in exports.
@export var camera_rig: CameraController
@export var cutaway: Node3D
@export var occluder: CollisionObject3D ## the building body; empty = interior only
@export var doorstep_radius := 10.0 ## metres from the zone centre where the occlusion check runs
@export var doorstep_hold := 0.3 ## seconds the cutaway stays open after the view clears (no flicker)

var inside := false
var _occluded_for := 0.0 ## > 0 while the doorstep cutaway is open


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # actors
	monitorable = false
	if camera_rig == null:
		camera_rig = get_tree().get_first_node_in_group(CameraController.GROUP)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			inside = true
			_occluded_for = 0.0 # the first frames after a load run before this overlap is known
			_apply())
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			inside = false
			_apply())


func _physics_process(delta: float) -> void:
	if occluder == null or not is_instance_valid(camera_rig) or camera_rig.target == null:
		return
	var was := _occluded_for > 0.0
	_occluded_for = maxf(_occluded_for - delta, 0.0)
	if not inside and _near(camera_rig.target) and _blocks_view(camera_rig.target):
		_occluded_for = doorstep_hold
	if (_occluded_for > 0.0) != was:
		_apply()


func _apply() -> void:
	var open := inside or _occluded_for > 0.0
	if is_instance_valid(cutaway): # the world may be tearing down (F5 reload)
		cutaway.visible = not open
	if is_instance_valid(camera_rig):
		camera_rig.set_collision_enabled(not open)


func _near(target: Node3D) -> bool:
	var d := target.global_position - global_position
	return Vector2(d.x, d.z).length() < doorstep_radius


## True if the building sits between the player's head and where the camera wants to be
## (the spring arm's full length, not where collision has pulled it in to).
func _blocks_view(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(target.global_position + Vector3.UP * 1.2, camera_rig.ideal_camera_position(), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == occluder
