extends Node3D
## Footstep sounds for the parent CharacterBody3D, picked by the SurfaceArea under its feet.

@export var walk_stride := 0.8 ## metres per step
@export var run_stride := 1.3
@export var run_speed_threshold := 5.5

var _distance := 0.0


func _physics_process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if not body.is_on_floor() or speed < 0.5:
		_distance = walk_stride * 0.6 # the first step comes quickly after starting to move
		return
	_distance += speed * delta
	if _distance >= (run_stride if speed > run_speed_threshold else walk_stride):
		_distance = 0.0
		AudioManager.play_at(StringName("step_" + surface()), self)


func surface() -> String:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position + Vector3.UP * 0.1
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 16
	for hit in get_world_3d().direct_space_state.intersect_point(query, 4):
		if hit.collider is SurfaceArea:
			return hit.collider.surface
	return "grass"
